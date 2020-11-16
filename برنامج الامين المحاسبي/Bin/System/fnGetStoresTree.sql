#########################################################
CREATE FUNCTION fnGetStoresTree()
	RETURNS TABLE
AS
/*
icons ids:
	31. stors root.
	32. store
*/
	RETURN (
		SELECT [GUID], 0x0 AS [ParentGUID], '' AS [Code], [Name], [LatinName], 'st000' AS [tableName], 0 AS [branchMask], 6 AS [SortNum], 31 AS [IconID], '.' AS [Path], 0 AS [Level] FROM [brt] WHERE [tableName] = 'st000'
		UNION ALL
		SELECT 
			[s].[GUID], 
			CASE [s].[ParentGUID] WHEN 0x0 THEN [b].[GUID] ELSE [s].[ParentGUID] END,
			[s].[Code],
			[s].[Name],
			[s].[LatinName],
			'st000',
			[s].[branchMask],
			0, -- sortNum
			32, -- iconID
			[fn].[Path] AS [Path], --Path
			(fn.[Level]+1) AS [Level]
		FROM 
			[st000] AS [s] 
		INNER JOIN [dbo].[fnGetStoresListTree]( 0x0, 0) AS [fn] ON [s].[Guid] = [fn].[Guid]
		INNER JOIN [brt] AS [b] ON [b].[tableName] = 'st000')
#########################################################
#END