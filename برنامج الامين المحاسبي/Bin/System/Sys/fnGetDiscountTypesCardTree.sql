#########################################################
CREATE FUNCTION fnGetDiscountTypesCardTree()
	RETURNS TABLE
AS
/*
icon ids:
	141. Discount Types Card root.
	142. Discount Type Card
*/
	RETURN (
		SELECT	[GUID], 0x0 AS [ParentGUID], '' AS [Code], [Name], [LatinName], 'DiscountTypesCard000' AS [tableName], 
				0 AS [branchMask], 16 AS [SortNum], 141 AS [IconID], '.' AS [Path], 0 AS [Level]  
		FROM [brt] 
		WHERE [tableName] = 'DiscountTypesCard000'
		
		UNION ALL
		
		SELECT 
			[t].[GUID], 
			[b].[GUID],
			[t].[Name],
			[t].[Name],
			[t].[Name],
			'DiscountTypesCard000',
			[t].[branchMask],
			0, -- sortNum
			142, -- iconID
			'.' AS [Path], 
			1 AS [Level]
		FROM	[DiscountTypesCard000] AS [t] 
					INNER JOIN 
				[brt] AS [b] 
					ON [b].[tableName] = 'DiscountTypesCard000')

#########################################################
#END