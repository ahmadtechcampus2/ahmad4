########################################
CREATE  FUNCTION fnDistGetDistributionTree() 
	RETURNS @Result TABLE ( [GUID] [UNIQUEIDENTIFIER], [ParentGUID] [UNIQUEIDENTIFIER], [Code] [NVARCHAR](255) COLLATE ARABIC_CI_AI, [Name] [NVARCHAR](255) COLLATE ARABIC_CI_AI, [LatinName] [NVARCHAR](255) COLLATE ARABIC_CI_AI, [tableName] [NVARCHAR](100) COLLATE ARABIC_CI_AI, [branchMask] [BIGINT], [SortNum] [INT], [IconID] [INT], [Path] [NVARCHAR](max) COLLATE ARABIC_CI_AI, [Level] [INT] ) 
AS 
BEGIN
/*   
icons ids   
	21. Distributors And Hierarchies Root.   
	22. Distributors And Hierarchies :  	23. Distributors .		22. Hierarchies . 
	22. Sales Mans .   
	22. Van Cards.   
*/
	DECLARE @RootGuid UNIQUEIDENTIFIER
	SELECT @RootGuid = Guid From [brt] WHERE [tableName] = 'Distributor000'  
	INSERT INTO @Result SELECT * FROM 
		(  
		-- «· Ê“Ì⁄
		SELECT [GUID], 0x0 AS [ParentGUID], '' AS [Code], [Name], [LatinName], 'Distributor000' AS [tableName], 3 AS [branchMask], 4 AS [SortNum], 21 AS [IconID] , '001.0.' AS [Path], 0 AS [Level]  
		FROM [brt]   
		WHERE [tableName] = 'Distributor000'  
		-- «·„Ã„Ê⁄«  Ê»ÿ«ﬁ«  «·„Ê“⁄Ì‰
		UNION ALL  	
		SELECT [GUID], @RootGuid AS [ParentGUID], '' AS [Code], [Name], [LatinName], [tableName], 0 AS [branchMask], 4 AS [SortNum], 22 AS [IconID] , '002.0.' AS [Path], 1 AS [Level]  
		FROM [brt]   
		WHERE [tableName] = 'DistHi000'  
		UNION ALL  -- «·„Ã„Ê⁄« 
		SELECT    
			[hi].[GUID],    
			CASE [hi].[ParentGUID] WHEN 0x0 THEN [b].[GUID] ELSE [hi].[ParentGUID] END,   
			[hi].[Code],   
			[hi].[Name],   
			[hi].[LatinName],   
			[b].[TableName],   
			[hi].[branchMask],  
			0, -- sortNum   
			22, -- iconID   
			'002.' + [fn].[Path] AS [Path],  
			(fn.[Level]+2) AS [Level]  
		FROM   
			[DistHi000] AS [hi]   
			INNER JOIN [dbo].[fnGetHierarchyList]( 0x0, 1) AS [fn] ON [hi].[Guid] = [fn].[Guid]  
			INNER JOIN [brt] AS [b] ON [b].[tableName] = 'DistHi000' -- this will preserve the parent  
		UNION ALL  -- »ÿ«ﬁ«  «·„Ê“⁄Ì‰
		SELECT    
			[di].[GUID],    
			-- CASE [di].[HierarchyGuid] WHEN 0x0 THEN [b].[GUID] ELSE [di].[HierarchyGuid] END,   
			CASE [di].[HierarchyGuid] WHEN 0x0 THEN [b].[GUID] ELSE [di].[HierarchyGuid] END,   
			[di].[Code],   
			[di].[Name],  
			[di].[LatinName],  
			[b].[TableName],  -- 'Distributor000',  
			[di].[branchMask],  
			0, -- sortNum   
			23, -- iconID  
			'002.' + [fn].[Path] + '0.1' AS [Path],  
			([fn].[Level]+3) AS [Level]  
		FROM [Distributor000] AS [di]   
		INNER JOIN [brt] AS [b] ON [tableName] = 'Distributor000' -- 'DistHi000'  
		INNER JOIN [dbo].[fnGetHierarchyList]( 0x0, 1) AS [fn] ON [di].[HierarchyGuid] = [fn].[Guid] 
		-- «·„‰œÊ»Ì‰
		UNION ALL  	
		SELECT [GUID], @RootGuid AS [ParentGUID], '' AS [Code], [Name], [LatinName], [tableName], 0 AS [branchMask], 4 AS [SortNum], 22 AS [IconID] , '003.0.' AS [Path], 1 AS [Level]  
		FROM [brt]   
		WHERE [tableName] = 'DistSalesMan000' 
		UNION ALL
		SELECT 
			sm.Guid,
			b.Guid,
			sm.Code,
			sm.Name,
			sm.LatinName,
			b.TableName,
			sm.branchMask,
			0, -- sortNum
			22, -- iconId
			'003.0.000000' + CAST(sm.Number AS NVARCHAR(10))	AS Path,
			2 -- Level
		FROM 
			DistSalesMan000 AS sm 
			INNER JOIN brt AS b ON tableName = 'DistSalesMan000'
		-- ”Ì«—«  «· Ê“Ì⁄
		UNION ALL  	
		SELECT [GUID], @RootGuid AS [ParentGUID], '' AS [Code], [Name], [LatinName], [tableName], 0	AS [branchMask], 4 AS [SortNum], 22 AS [IconID] , '004.0.' AS [Path], 1 AS [Level]  
		FROM [brt]   
		WHERE [tableName] = 'DistVan000'  
		UNION ALL
		SELECT 
			vn.Guid,
			b.Guid,
			vn.Code,
			vn.Name,
			vn.LatinName,
			b.TableName,
			vn.branchMask,
			0, -- sortNum
			22, -- iconId
			'004.0.000000' + CAST(vn.Number AS NVARCHAR(10))	AS Path,
			2 -- Level
		FROM 
			DistVan000 AS vn 
			INNER JOIN brt AS b ON tableName = 'DistVan000'

		) AS [r] ORDER BY [Path], [Level] 

	RETURN 
END 
-- Select * from fnDistGetDistributionTree()
#############################
#END