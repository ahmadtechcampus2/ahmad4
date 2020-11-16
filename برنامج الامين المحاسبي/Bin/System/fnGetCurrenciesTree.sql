#########################################################
CREATE FUNCTION fnGetCurrenciesTree()
	RETURNS TABLE
AS
/*
icons ids:
	71. currencies types listt
	72. currency
*/
	RETURN (
		SELECT [GUID], 0x0 AS [ParentGUID], '' AS [Code], [Name], [LatinName], 'my000' AS [tableName], 0 AS [branchMask], 13 AS [SortNum], 71 AS [IconID], '.' AS [Path], 0 AS [Level] FROM [brt] WHERE [tableName] = 'my000'
		UNION ALL
		SELECT 
			[m].[GUID], 
			[b].[GUID],
			[m].[code], 
			[m].[Name],
			[m].[LatinName],
			'my000',
			[m].[branchMask],
			[m].[number], -- sortNum
			72, -- iconID
			'.' + CAST(Number AS NVARCHAR(100)) + '.' AS [Path], 
			1 AS [Level] 
		FROM [my000] AS [m] INNER JOIN [brt] AS [b] ON [b].[tableName] = 'my000') 

#########################################################
#END