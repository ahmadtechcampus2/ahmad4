#########################################################
CREATE FUNCTION fnGetDiscountTypesTree()
	RETURNS TABLE
AS
/*
icon ids:
	111. Discount Types root.
	112. Discount Type
*/
	RETURN (
		SELECT	[GUID], 0x0 AS [ParentGUID], '' AS [Code], [Name], [LatinName], 'DiscountTypes000' AS [tableName], 
				0 AS [branchMask], 16 AS [SortNum], 111 AS [IconID], '.' AS [Path], 0 AS [Level]  
		FROM [brt] 
		WHERE [tableName] = 'DiscountTypes000'
		
		UNION ALL
		
		SELECT 
			[t].[GUID], 
			[b].[GUID],
			[t].[Abbrev],
			[t].[Name],
			[t].[LatinName],
			'DiscountTypes000',
			[t].[branchMask],
			0, -- sortNum
			112, -- iconID
			'.' AS [Path], 
			1 AS [Level]
		FROM	[DiscountTypes000] AS [t] 
					INNER JOIN 
				[brt] AS [b] 
					ON [b].[tableName] = 'DiscountTypes000')

#########################################################
#END