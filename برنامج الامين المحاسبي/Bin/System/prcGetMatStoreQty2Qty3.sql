###############################################
CREATE PROCEDURE prcGetMatStoreQty2Qty3
	@MatGUID 	AS 	[UNIQUEIDENTIFIER],
	@StoreGUID 	AS 	[UNIQUEIDENTIFIER]
AS
SET NOCOUNT ON
SELECT
	ISNULL(SUM( [biQty2]), 0) AS [Qty2Total],
	ISNULL(SUM( [biQty3]), 0)AS [Qty3Total]
FROM
	[vwbi]
WHERE
	[biMatPtr] = @MatGUID
	AND [biStorePtr] = @StoreGUID
/*
EXEC prcGetMatStoreQty2Qty3 0x0, 0x0
*/
##############################################
CREATE PROCEDURE prcGetMatInfoTable
	@matGUID UNIQUEIDENTIFIER
AS  
	/* 
	Optimize the procedure
	 the previous consumes more inner joins we don't need
	
	*/
	SET NOCOUNT ON 

	SELECT   
		st.stName, 
		mt.StoreGuid msStoreGUID, 
		mt.Qty msQty
		
	FROM  
		ms000 mt  
		INNER JOIN vwSt st on mt.StoreGuid = st.stGUID 
	WHERE  
		MatGuid = @matGUID AND st.stSecurity <= dbo.fnGetUserStoreSec_Browse([dbo].[fnGetCurrentUserGUID]()) 
##############################################
#END