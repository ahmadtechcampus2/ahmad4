#########################################################
CREATE FUNCTION fnGetNotesTypesTree()
	RETURNS TABLE
AS
/*
icons ids:
	61. notes types listt
	62. note
*/
	RETURN (
		SELECT [GUID], 0x0 AS [ParentGUID], '' AS [Code], [Name],[LatinName], 'nt000' AS [tableName], 0 AS [branchMask], 12 AS [SortNum], 61 AS [IconID], '.' AS [Path], 0 AS [Level] FROM [brt] WHERE [tableName]= 'nt000'

		UNION ALL
		
		SELECT 
			[t].[GUID], 
			[b].[GUID],
			[t].[Abbrev],
			[t].[Name],
			[t].[LatinName],
			'nt000',
			[t].[branchMask],
			[t].[SortNum], 
			62,
			'.' AS [Path], -- Path
			1  AS [Level] -- Level	
		FROM [nt000] AS [t] INNER JOIN [brt] AS [b] ON [b].[tableName] = 'nt000')
		
#########################################################
#END