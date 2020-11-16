########################################
CREATE PROCEDURE repGCCCustomerTool
AS
	SET NOCOUNT ON

	CREATE TABLE [#RESULT]( [custGUID] UNIQUEIDENTIFIER)

	INSERT INTO [#RESULT]
	SELECT 
		cu.GUID 
	FROM
		cu000 AS [cu] 
		LEFT JOIN [GCCCustLocations000] cl ON cu.GCCLocationGUID = cl.GUID 
	WHERE 
		cu.GCCLocationGUID = 0x0
		OR 
		cl.GUID IS NULL

	INSERT INTO [#RESULT]
	SELECT 
		cu.GUID 
	FROM
		cu000 AS [cu] 
		LEFT JOIN [GCCCustomerTax000] t ON cu.GUID = t.[CustGUID] AND t.TaxType = 1 /*VAT*/
	WHERE 
		t.GUID IS NULL
		AND 
		cu.GUID NOT IN (SELECT [custGUID] FROM [#RESULT])

	--IF EXISTS(SELECT * FROM [GCCTaxTypes000] WHERE Type = 2 /*Exise Tax*/ AND IsUsed = 1)
	--BEGIN 
	--	INSERT INTO [#RESULT]
	--	SELECT 
	--		cu.GUID 
	--	FROM
	--		cu000 AS [cu] 
	--		LEFT JOIN [GCCCustomerTax000] t ON cu.GUID = t.[CustGUID] AND t.TaxType = 2 /*Exise Tax*/
	--	WHERE 
	--		t.GUID IS NULL
	--		AND 
	--		cu.GUID NOT IN (SELECT [custGUID] FROM [#RESULT])
	--END 

	DECLARE @lang [INT]
	SET @lang = [dbo].[fnConnections_getLanguage]() 

	SELECT -- DISTINCT 	
		[r].[custGUID] AS [custGuid],
		CASE @lang WHEN 0 THEN [cu].[CustomerName] ELSE CASE ISNULL([cu].[LatinName], '') WHEN '' THEN [cu].[CustomerName] ELSE [cu].[LatinName] END END AS [custName]
	FROM
		cu000 AS [cu] 
		INNER JOIN [#RESULT] r ON cu.GUID = r.[CustGUID]
	ORDER BY [cu].[Number]
#############################
#END
