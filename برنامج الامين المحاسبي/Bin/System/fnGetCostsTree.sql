#########################################################
CREATE FUNCTION fnGetCostsTree()
	RETURNS TABLE
AS
/*
icons ids
	11. costs root.
	12. cost
*/
	RETURN (
		SELECT [GUID], 0x0 AS [ParentGUID], '' AS [Code], [Name], [LatinName], 'co000' AS [tableName], 0 AS [branchMask],  3 AS [SortNum], 11 AS [IconID], '.' AS [Path], 0 AS [Level] FROM [brt] WHERE [tableName] = 'co000'
		UNION ALL
		SELECT 
			[c].[GUID], 
			CASE [c].[ParentGUID] WHEN 0x0 THEN [b].[GUID] ELSE [c].[ParentGUID] END,
			[c].[Code],
			[c].[Name],
			[c].[LatinName],
			'co000',
			[c].[branchMask],
			0, -- sortNum
			CASE [c].[Type] -- iconID 
				WHEN 1 THEN 5 
				WHEN 2 THEN 6 
				ELSE 12
			END,
			[fn].[Path] AS [Path],
			(fn.[Level]+1) AS [Level]
		FROM 
			[co000] AS [c] 
			INNER JOIN (
				SELECT [GUID], [Level], [Path] FROM [dbo].[fnGetCostsListSorted](0x0, 1) 
				UNION ALL 
				SELECT [GUID], 0, '2' FROM vbco WHERE TYPE = 1 OR TYPE = 2
				) AS [fn] ON [fn].[Guid] = [c].[Guid]
		INNER JOIN [brt] AS b ON [b].[tableName] = 'co000')
#########################################################
#END