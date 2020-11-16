#########################################################
CREATE FUNCTION fnGetAccountsTree()
	RETURNS TABLE 
AS 
/* 
	icons ids: 
		1. accounts root. 
		2. normal account. 
		3. normal account with customer 
		4. final account. 
		5 collective account. 
		6. distributed account. 
*/  
	RETURN ( 
		SELECT [GUID], 0x0 AS [ParentGUID], '' AS [Code], [Name], [LatinName], 'ac000' tableName, 0 AS branchMask, 1 AS SortNum, 1 AS IconID, '.' AS [Path], 0 AS [Level] FROM [brt] WHERE [TableName] = 'ac000'
		UNION ALL
		SELECT 
			[a].[GUID],  
			CASE [a].[ParentGUID] WHEN 0x0 THEN [b].[GUID] ELSE [a].[ParentGUID] END, 
			[a].[Code], 
			[a].[Name], 
			[a].[LatinName],
			'ac000',
			[a].[branchMask],
			[a].[Type], -- sortnum 
			CASE [a].[Type] -- iconID 
				WHEN 1 THEN CASE ISNULL([c].[AccountGUID], 0x0) WHEN 0x0 THEN 2 ELSE 3 END 
				WHEN 2 THEN 4 
				WHEN 4 THEN 5 
				WHEN 8 THEN 6 
			END,
			[fn].[Path] AS [Path],
			([fn].[Level]+1) AS [Level]
		FROM 
			(	
			[ac000] AS [a] 
			INNER JOIN (
				SELECT [GUID], [Level], [Path] FROM [dbo].[fnGetAccountsList](0x0, 1) 
				UNION ALL 
				SELECT [GUID], 0, '2' FROM vbac WHERE TYPE = 4 OR TYPE = 8
				) AS [fn] ON [fn].[Guid] = [a].[Guid]
			INNER JOIN [brt] AS [b] ON [b].[tableName] = 'ac000'
			) 
			LEFT JOIN [cu000] AS [c] ON [a].[GUID] = [c].[AccountGUID]) 
#########################################################
#END