########################################
CREATE PROCEDURE repGCCMaterialTool
AS
	Set NOCOUNT ON

	DECLARE @lang [INT]
	SET @lang = [dbo].[fnConnections_getLanguage]() 

	SELECT	
		[mt].[GUID] AS [mtGuid],
		[mt].[Code] AS [mtCode],
		CASE @lang WHEN 0 THEN [mt].[Name] ELSE CASE ISNULL([mt].[LatinName], '') WHEN '' THEN [mt].[Name] ELSE [mt].[LatinName] END END AS [mtName],
		[gr].[GUID] AS [grGuid],
		[gr].[Code] AS [grCode],
		CASE @lang WHEN 0 THEN [gr].[Name] ELSE CASE ISNULL([gr].[LatinName], '') WHEN '' THEN [gr].[Name] ELSE [gr].[LatinName] END END AS [grName]
	FROM	
		mt000 AS [mt]
		INNER JOIN gr000 AS [gr] ON [gr].[GUID] = [mt].[GroupGUID]
		LEFT JOIN [GCCMaterialTax000] t ON mt.GUID = t.[MatGUID] AND t.TaxType = 1 /*VAT*/
	WHERE 
		t.GUID IS NULL
	ORDER BY [mt].[Code] 
#############################
#END
