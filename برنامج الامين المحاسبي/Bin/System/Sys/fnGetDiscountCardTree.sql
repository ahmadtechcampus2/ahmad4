#########################################################
CREATE FUNCTION fnGetDiscountCardTree()
	RETURNS TABLE
AS
/*
icon ids:
	131. Discount Card root.
	132. Discount Card
*/
	RETURN (
		SELECT	[GUID], 0x0 AS [ParentGUID], '' AS [Code], [Name], [LatinName], 'DiscountCard000' AS [tableName], 
				0 AS [branchMask], 16 AS [SortNum], 131 AS [IconID], '.' AS [Path], 0 AS [Level]  
		FROM [brt] 
		WHERE [tableName] = 'DiscountCard000'
		
		UNION ALL
		
		SELECT 
			[t].[GUID], 
			[b].[GUID],
			[t].[Code],
			[t].[Code],
			[t].[Code],
			'DiscountCard000',
			[t].[branchMask],
			0, -- sortNum
			132, -- iconID
			'.' AS [Path], 
			1 AS [Level]
		FROM	[DiscountCard000] AS [t] 
					INNER JOIN 
				[brt] AS [b] 
					ON [b].[tableName] = 'DiscountCard000')

#########################################################
#END