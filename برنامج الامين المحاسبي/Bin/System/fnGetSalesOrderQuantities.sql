########################################################
CREATE FUNCTION fnGetSalesOrderRemaindedQty
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
			        fnGetSalesOrderRemainingQtyDetails(@MatGuid,@StoreGuid,@BranchGuid) fn
	          ) 
	END
########################################################
CREATE FUNCTION fnGetSalesOrderRemainingQtyDetails
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
			 INNER JOIN  vwOrderInformation orderInfo ON orderInfo.ParentGuid = ori.oriPOGUID 
		WHERE 
			 bt.Type = 5
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
CREATE FUNCTION fnGetSalesOrdRemaindedQty2
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
				THEN (SELECT  dbo.fnGetSalesOrderRemaindedQty(@MatGuid,@StoreGuid,@BranchGuid))
				ELSE 0
				END
	          ) 
	END
########################################################