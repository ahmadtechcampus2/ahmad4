################################################################################
CREATE FUNCTION fnGetOrdersQty
	(
		@FromDate		DATETIME = '1980-1-1',
		@EndDate		DATETIME = '2099-1-1',
		@MaterialGUID	UNIQUEIDENTIFIER = 0x0,
		@StoreGUID		UNIQUEIDENTIFIER = 0x0,
		@Type			TINYINT = 1, -- 0 Purchase, 1 Sell
		@CustGUID		UNIQUEIDENTIFIER = 0x0,
		@OrderGUID		UNIQUEIDENTIFIER = 0x0
	)

RETURNS @Result Table
	(
		MaterialGuid UNIQUEIDENTIFIER,
		BillGuid UNIQUEIDENTIFIER,
		--BillName VARCHAR(MAX),   
		BillType  UNIQUEIDENTIFIER,
		--ADDate DATE,       
		Required FLOAT,
		Achived FLOAT,
		Remainder FLOAT,   
		Fininshed TINYINT,    
		Cancle TINYINT
    )
BEGIN
	INSERT INTO @Result
    SELECT 
		BI.biMatPtr,
        bi.buGUID,
        --bi.btAbbrev + ' ' + CAST(bi.buNumber AS VARCHAR),
        BI.buType,
        --inf.ADDate,
        SUM(ori.Qty),
        SUM(CASE WHEN Operation > 0 THEN ORI.Qty ELSE 0 END),
        SUM(CASE WHEN Operation > 0 THEN 0 ELSE ORI.Qty END),
        Finished,
        Add1
	FROM 
		ORI000 AS ORI 
        INNER JOIN OIT000 AS OIT ON OIT.[GUID] = ORI.TypeGUID
        INNER JOIN vwExtended_bi AS BI 
			ON BI.btType = CASE WHEN @Type = 0 THEN 6 WHEN @Type  = 1 THEN 5 END
			AND BI.biGUID = ORI.POIGUID
        INNER JOIN ORADDINFO000 AS INF ON INF.ParentGUID = BI.buGUID
	WHERE 
       -- INF.ADDate >= @FromDate AND INF.ADDate <= @EndDate   AND
        (@MaterialGuid = 0x0 OR @MaterialGuid = BI.biMatPtr)
        AND (@StoreGuid = 0x0 OR @StoreGuid = BI.buStorePtr)
        AND (@CustGuid = 0x0 OR @CustGuid = BI.buCustPtr)
        AND (@OrderGUID = 0x0 OR @OrderGUID = INF.ParentGuid)
    GROUP BY 
        BI.biMatPtr,
        bi.buGUID,  
        --bi.btAbbrev + ' ' + CAST(bi.buNumber AS VARCHAR),
        ---inf.ADDate,
        BI.buType,
        Finished,
        add1;
RETURN;
END
################################################################################
#END
