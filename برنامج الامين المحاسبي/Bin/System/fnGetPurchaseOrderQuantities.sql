########################################################
CREATE FUNCTION fnGetPurchaseOrderQuantities
	(
	@EndDate		DATETIME,
	@MaterialGuid	UNIQUEIDENTIFIER = 0x0,
	@StoreGuid		UNIQUEIDENTIFIER = 0x0,
	@Type			INT /*0 Purchase, 1 Sell*/
	)
RETURNS @Result Table
	(
    MaterialGuid UNIQUEIDENTIFIER,
    --BillGuid UNIQUEIDENTIFIER,
    --BillName VARCHAR(MAX),
    BillType  UNIQUEIDENTIFIER,
    --ADDate DATE,
    Required FLOAT,
    Achived FLOAT,
    Remainder FLOAT,
    Fininshed int,
    Cancle int
    )
BEGIN
	INSERT INTO @Result
    SELECT 
		bi.biMatPtr,
        --bi.buGUID,
        --bi.btAbbrev + ' ' + CAST(bi.buNumber AS VARCHAR),
        bi.buType,
        --inf.ADDate,
        SUM(ori.Qty),
        SUM(CASE WHEN Operation > 0 THEN ori.Qty ELSE 0 END),
        SUM(CASE WHEN Operation > 0 THEN 0 ELSE ori.Qty END),
        Finished,
        Add1
	FROM 
		ori000 AS ori 
        INNER JOIN OIT000 AS oit ON oit.[Guid] = ori.TypeGuid
        INNER JOIN vwExtended_bi AS bi 
			ON bi.btType = CASE WHEN @Type = 0 THEN 6 WHEN @Type  = 1 THEN 5 END
			AND bi.biGuid = ori.POIGUID
        INNER JOIN orAddInfo000 AS inf ON inf.ParentGuid = bi.buGuid
	WHERE 
        inf.ADDate <= @EndDate
        AND (@MaterialGuid = 0x0 OR @MaterialGuid = bi.biMatPtr)
        AND (@StoreGuid = 0x0 OR @StoreGuid = bi.buStorePtr)
    GROUP BY 
        bi.biMatPtr,
        --bi.buGUID,
        --bi.btAbbrev + ' ' + CAST(bi.buNumber AS VARCHAR),
        ---inf.ADDate,
        bi.buType,
        Finished,
        add1;
RETURN;
END
########################################################
CREATE FUNCTION fnGetPurchaseOrderQty
	(
	@EndDate		DATETIME,
	@MaterialGuid	UNIQUEIDENTIFIER = 0x0,
	@StoreGuid		UNIQUEIDENTIFIER = 0x0,
	@Type			INT /*0 Purchase, 1 Sell*/
	)
RETURNS @Result Table
	(
    MaterialGuid UNIQUEIDENTIFIER,
    --BillGuid UNIQUEIDENTIFIER,
    --BillName VARCHAR(MAX),
    BillType  UNIQUEIDENTIFIER,
    --ADDate DATE,
    Required FLOAT,
    Achived FLOAT,
    Remainder FLOAT,
    Fininshed int,
    Cancle int
    )
BEGIN
	INSERT INTO @Result
    SELECT 
		bi.biMatPtr,
        --bi.buGUID,
        --bi.btAbbrev + ' ' + CAST(bi.buNumber AS VARCHAR),
        bi.buType,
        --inf.ADDate,
        SUM(ori.Qty),
        SUM(CASE WHEN Operation > 0 THEN ori.Qty ELSE 0 END),
        SUM(CASE WHEN Operation > 0 THEN 0 ELSE ori.Qty END),
        Finished,
        Add1
	FROM 
		ori000 AS ori 
        INNER JOIN OIT000 AS oit ON oit.[Guid] = ori.TypeGuid
        INNER JOIN vwExtended_bi AS bi 
			ON bi.btType = CASE WHEN @Type = 0 THEN 6 WHEN @Type  = 1 THEN 5 END
			AND bi.biGuid = ori.POIGUID
        INNER JOIN orAddInfo000 AS inf ON inf.ParentGuid = bi.buGuid
	WHERE 
        (@MaterialGuid = 0x0 OR @MaterialGuid = bi.biMatPtr)
        AND (@StoreGuid = 0x0 OR @StoreGuid = bi.buStorePtr)
    GROUP BY 
        bi.biMatPtr,
        --bi.buGUID,
        --bi.btAbbrev + ' ' + CAST(bi.buNumber AS VARCHAR),
        ---inf.ADDate,
        bi.buType,
        Finished,
        add1;
RETURN;
END
########################################################
CREATE FUNCTION fnGetPurchaseOrderRemaindedQty
	(
		@MatGuid UNIQUEIDENTIFIER = 0x0,
		@StoreGuid UNIQUEIDENTIFIER = 0x0,
		@BranchGuid UNIQUEIDENTIFIER = 0x0
	) 
RETURNS FLOAT 
AS
	BEGIN
		RETURN( 
				SELECT 
					ISNULL(SUM(fn.RemainingQty),0) AS Remaining_Qty
				FROM
			        fnGetPurchaseOrderRemainingQtyDetails(@MatGuid,@StoreGuid,@BranchGuid) fn
	          ) 
	END
########################################################
CREATE FUNCTION fnGetPurchaseOrderRemainingQtyDetails
	(
		@MatGuid UNIQUEIDENTIFIER = 0x0,
		@StoreGuid UNIQUEIDENTIFIER = 0x0,
		@BranchGuid UNIQUEIDENTIFIER = 0x0
	) 
RETURNS TABLE
AS
	RETURN
	(
		SELECT 
			  ((MAX(bi.biQty + bi.biBonusQnt) - SUM(CASE WHEN ori.oribuGuid <> 0x0 AND ori.oriBonusPostedQty > 0 THEN ori.oriBonusPostedQty ELSE 0 END)) 
			    - 
			   SUM(CASE WHEN ori.oribuGuid <> 0x0 AND OIT.QtyStageCompleted <> 0 AND ori.oriQty > 0 THEN ori.oriQty ELSE 0 END)
			  ) AS RemainingQty,
			  bi.biStorePtr,
			  bi.biMatPtr,
			  bi.buDate,
			  ori.oripoiguid
		FROM vwORI ori 
			 INNER JOIN vwExtended_bi bi ON bi.biGUID = ori.oriPOIGUID 
			 INNER JOIN oit000 oit ON oit.GUID = ORI.oriTypeGUID
			 INNER JOIN bt000 bt on bt.guid = bi.buType
			 INNER JOIN vwOrderInformation orderInfo ON orderInfo.ParentGuid = ori.oriPOGUID 
		WHERE 
			 bt.Type = 6
			 AND orderInfo.Add1 = 0
			 AND orderInfo.Finished  = 0
			 AND bt.bAffectCalcStoredQty = 1 
			 AND bi.biMatPtr =  CASE WHEN @MatGuid = 0x0 THEN bi.biMatPtr ELSE @MatGuid END
			 AND bi.buStorePtr = CASE @StoreGuid WHEN 0x0 THEN  bi.buStorePtr ELSE  @StoreGuid END
			 AND bi.buBranch = CASE @BranchGuid WHEN 0x0 THEN  bi.buBranch ELSE  @BranchGuid END     
		GROUP BY 
				bi.biStorePtr,
			    bi.biMatPtr,
			    bi.buDate,
			    ori.oripoiguid
		HAVING 
			  ((MAX(bi.biQty + bi.biBonusQnt) - SUM(CASE WHEN ori.oribuGuid <> 0x0 AND ori.oriBonusPostedQty > 0 THEN ori.oriBonusPostedQty ELSE 0 END)) 
			    - 
			   SUM(CASE WHEN ori.oribuGuid <> 0x0 AND OIT.QtyStageCompleted <> 0 AND ori.oriQty > 0 THEN ori.oriQty ELSE 0 END)
			  ) > 0
	)
########################################################
CREATE FUNCTION fnGetPurchaseOrdRemaindedQty2
	(
		@MatGuid UNIQUEIDENTIFIER = 0x0,
		@StoreGuid UNIQUEIDENTIFIER = 0x0,
		@BranchGuid UNIQUEIDENTIFIER = 0x0
	) 
RETURNS FLOAT 
AS
	BEGIN
	 DECLARE @CalcPurchaseOrderRemindedQtyIsChecked INT = dbo.fnOption_GetInt('AmnCfg_CalcPurchaseOrderRemindedQty', '0') 
 

		RETURN(CASE @CalcPurchaseOrderRemindedQtyIsChecked WHEN 1
				THEN (SELECT  dbo.fnGetPurchaseOrderRemaindedQty(@MatGuid,@StoreGuid,@BranchGuid))
				ELSE 0
				END
	          ) 
	END
########################################################