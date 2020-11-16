##############################################
CREATE FUNCTION fnGetBillCustName(@BillGuid UNIQUEIDENTIFIER) 
	RETURNS NVARCHAR(250) 
AS  
BEGIN  
	DECLARE @name NVARCHAR(250) 
	SET @name = (SELECT CASE WHEN dbo.fnConnections_GetLanguage() = 0 THEN cu.CustomerName ELSE (CASE cu.LatinName WHEN '' THEN cu.CustomerName ELSE cu.LatinName END) END AS Name 
	FROM 
		[bu000] AS bu
		INNER JOIN cu000 AS cu ON bu.CustGUID = cu.[GUID] 
	WHERE 
		bu.[GUID] = @Billguid) 
	
	RETURN ISNULL( @name, '')
END 
##############################################
#END