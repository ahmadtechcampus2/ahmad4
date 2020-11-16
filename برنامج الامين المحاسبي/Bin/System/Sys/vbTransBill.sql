##########################################################################
CREATE VIEW vbTransBill
AS
	SELECT 
		CASE WHEN a.GUID IS NULL THEN 1 ELSE 0 END inDir,
		ISNULL(a.GUID,b.GUID) [Guid],
		ISNULL(a.Guid,0X00) OutGuid,
		ISNULL(b.GUID,0X00) InGuid,
		ISNULL(a.TypeGuid,b.OutTypeGUID) trnType,
		ISNULL(a.Number,b.Number) Number,
		ISNULL(a.Security,b.Security) Security,
		a.Number OutNumber,
		b.Number InNumber,
		ISNULL(a.Date,b.Date) buDate,
		ISNULL(A.CurrencyGuid,b.CurrencyGuid) buCurrencyPtr,
		ISNULL(a.CurrencyVal,b.CurrencyVal) buCurrencyVal,
		CASE WHEN  a.GUID IS NULL OR b.GUID IS NULL THEN 1 ELSE 0 END AS Half,
		ISNULL(a.StoreGuid,0X00) OutStore,
		ISNULL(a.CostGuid,0X00) OutCost,
		ISNULL(a.MatAccGUID,0X00) OutMatAccGUID,
		ISNULL(a.Branch,0X00) OutBranch,
		ISNULL(b.StoreGuid,0X00) InStore,
		ISNULL(b.CostGuid,0x00) InCost,
		ISNULL(b.MatAccGUID,0x00) InMatAccGUID,
		ISNULL(b.Branch,0X00) InBranch,
		ISNULL(b.CustAccGUID,0x00) InCustAccGUID
	FROM (SELECT A1.GUID,TypeGuid,Date,CurrencyGuid,CurrencyVal,Number,StoreGuid,CostGuid,[Security],MatAccGUID,Branch,CustAccGUID FROM vbbu a1 
	INNER  JOIN TT000 tt2 on tt2.outTypeGUID = a1.TypeGuid) a 
	FULL OUTER JOIN ts000 ts ON ts.OutBillGUID  = a.Guid 
	FULL OUTER JOIN (SELECT B2.GUID,TypeGuid,Date,CurrencyGuid,CurrencyVal,Number,StoreGuid,CostGuid,[Security],MatAccGUID,Branch,OutTypeGUID,CustAccGUID FROM vbbu b2
	INNER  JOIN TT000 tt on tt.InTypeGUID = b2.TypeGuid)  b on ts.InBillGUID = B.Guid
##########################################################################
CREATE FUNCTION fnGetTrasBill(@Type UNIQUEIDENTIFIER)
RETURNS TABLE
AS 
	RETURN 
	(
			SELECT 
		CASE WHEN a.GUID IS NULL THEN 1 ELSE 0 END inDir,
		ISNULL(a.GUID,b.GUID) [Guid],
		ISNULL(a.Number,b.Number) Number,
		ISNULL(a.Security,b.Security) Security
		FROM (SELECT A1.GUID,TypeGuid,Number,[Security] FROM vbbu a1 
		WHERE  a1.TypeGuid = @Type ) a 
		FULL OUTER JOIN ts000 ts ON ts.OutBillGUID  = a.Guid 
		FULL OUTER JOIN (SELECT B2.GUID,Number,[Security],MatAccGUID FROM vbbu b2
		INNER  JOIN TT000 tt on tt.InTypeGUID = b2.TypeGuid WHERE TT.OutTypeGUID = @Type)  b on ts.InBillGUID = B.Guid
	
	)
#############################################################################
#END