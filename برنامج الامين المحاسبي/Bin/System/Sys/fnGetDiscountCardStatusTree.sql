#########################################################
CREATE FUNCTION fnGetDiscountCardStatusTree()
	RETURNS TABLE
AS
/*
icon ids:
	121. Discount Card Status root.
	122. Discount Card Status
*/
	RETURN (
		SELECT	[GUID], 0x0 AS [ParentGUID], '' AS [Code], [Name], [LatinName], 'DiscountCardStatus000' AS [tableName], 
				0 AS [branchMask], 16 AS [SortNum], 121 AS [IconID], '.' AS [Path], 0 AS [Level]  
		FROM [brt] 
		WHERE [tableName] = 'DiscountCardStatus000'
		
		UNION ALL
		
		SELECT 
			[t].[GUID], 
			[b].[GUID],
			[t].[Name],
			[t].[Name],
			[t].[Name],
			'DiscountCardStatus000',
			[t].[branchMask],
			0, -- sortNum
			122, -- iconID
			'.' AS [Path], 
			1 AS [Level]
		FROM	[DiscountCardStatus000] AS [t] 
					INNER JOIN 
				[brt] AS [b] 
					ON [b].[tableName] = 'DiscountCardStatus000')
#########################################################
#END