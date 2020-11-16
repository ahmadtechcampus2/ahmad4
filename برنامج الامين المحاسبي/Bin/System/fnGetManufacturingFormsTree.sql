#########################################################
CREATE FUNCTION fnGetManufacturingFormsTree()
	RETURNS TABLE
AS
/*
icon ids:
	71. manufacturing form root
	72. manufacturing form.
*/
	RETURN (
		SELECT [GUID], 0x0 AS [ParentGUID], '' AS [Code], [Name], [LatinName], 'fm000' AS [tableName], 0 AS [branchMask], 7 AS [SortNum], 71 AS [IconID] , '.' AS [Path], 0 AS [Level] FROM [brt] WHERE [tableName] = 'fm000'
		UNION ALL
		SELECT 
			[f].[GUID],
			[b].[GUID],
			[f].[Code],
			[f].[Name],
			[f].[LatinName],
			'fm000',
			[f].[branchMask],
			0, -- sortNum
			72, -- iconID
			'.' AS [Path], 
			1 AS [Level]

		FROM [fm000] AS [f] INNER JOIN [brt] AS [b] ON [b].[tableName] = 'fm000')

#########################################################
#END 