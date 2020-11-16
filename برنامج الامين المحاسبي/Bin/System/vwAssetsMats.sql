#############################################
CREATE VIEW vwAssetsMats
AS 
	SELECT 
		[mt].[GUID] AS [GUID],
		[mt].[Code] AS [Code],
		[mt].[Name] AS [Name],
		[mt].[Number] AS [Number],
		[mt].[Security] AS [Security]
	FROM
		[mt000] AS [mt]
	WHERE
		[Type] = 2
#############################################
#END