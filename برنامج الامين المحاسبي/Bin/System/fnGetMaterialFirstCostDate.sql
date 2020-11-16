#########################################################
CREATE FUNCTION fnGetMaterialFirstCostDate(@Materiald UNIQUEIDENTIFIER)
RETURNS DATE
AS
BEGIN

RETURN ( SELECT ISNULL(MIN(rm.Date), '1980-1-1') FROM vwBuBi bi 
		 JOIN RecostMaterials000 rm ON bi.buGUID = rm.OutBillGuid
		 WHERE bi.biMatPtr = @Materiald
	   )
END
#########################################################
#END
