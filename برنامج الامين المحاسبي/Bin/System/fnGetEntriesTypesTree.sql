#########################################################
CREATE FUNCTION fnGetEntriesTypesTree()
	RETURNS TABLE
AS
/*
icons ids:
	51. entries types root
	52. entry
*/
	RETURN (
		SELECT [GUID], 0x0 AS [ParentGUID], '' AS [Code], [Name], [LatinName], 'et000' AS [tableName], 0 AS [branchMask], 11 AS [SortNum], 51 AS [IconID], '.' AS [Path], 0 AS [Level]  FROM [brt] WHERE [tableName] = 'et000'
		UNION ALL
		SELECT 
			[t].[GUID], 
			[b].[GUID],
			[t].[Abbrev],
			[t].[Name],
			[t].[LatinName],
			'et000',
			[t].[branchMask],
			[t].[SortNum],
			52, -- iconID
			'.' + CAST( EntryType AS VARCHAR(3)) + '.' + CAST( SortNum AS VARCHAR(3)) + '.'   AS [Path], 
			1 AS [Level] 
		FROM [et000] AS [t] INNER JOIN [brt] AS [b] ON [b].[tableName] = 'et000')
 
#########################################################
#END