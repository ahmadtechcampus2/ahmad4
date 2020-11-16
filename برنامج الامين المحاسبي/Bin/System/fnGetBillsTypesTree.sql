#########################################################
CREATE FUNCTION fnGetBillsTypesTree()
	RETURNS TABLE
AS
/*
icon ids:
	41. Bills Typs root.
	42. non standard bills
	43. standard bills
*/
	RETURN (
		SELECT [GUID], 0x0 AS [ParentGUID], '' AS [Code], [Name], [LatinName], 'bt000' AS [tableName], 0 AS [branchMask], 10 AS [SortNum], 41 AS [IconID], '.' AS [Path], 0 AS [Level]  FROM [brt] WHERE [tableName] = 'bt000'
		UNION ALL
		SELECT 
			[t].[GUID], 
			[b].[GUID],
			[t].[Abbrev],
			[t].[Name],
			[t].[LatinName],
			'bt000',
			[t].[branchMask],
			[t].[Type] * 64000 + [t].[SortNum], -- sortNum
			CASE [t].[Type] WHEN 1 THEN 42 ELSE 43 END, -- iconID
			'.' + CAST([Type] AS NVARCHAR(4)) + '.' + CAST([SortNum] AS NVARCHAR(10)) + '.' AS [Path], 
			1 AS [Level]
		FROM [bt000] AS [t] INNER JOIN [brt] AS [b] ON [b].[tableName] = 'bt000')

#########################################################
#END