#########################################################
CREATE FUNCTION fnGetMaterialsTree() 
	RETURNS @Result TABLE([GUID] [UNIQUEIDENTIFIER], [ParentGUID] [UNIQUEIDENTIFIER], [Code] [NVARCHAR](255) COLLATE ARABIC_CI_AI, [Name] [NVARCHAR](255) COLLATE ARABIC_CI_AI, [LatinName] [NVARCHAR](255) COLLATE ARABIC_CI_AI,[tableName] [NVARCHAR](255) COLLATE ARABIC_CI_AI ,[branchMask] [BIGINT], [SortNum] [INT], [IconID] [INT], [Path] [NVARCHAR](max) COLLATE ARABIC_CI_AI, [Level] [INT])
BEGIN
/*  
icons ids  
	21. materials and groups root.  
	22. group. 
	23. material 
	 
*/ 
	DECLARE @brMask BIGINT,@ParenTGrp UNIQUEIDENTIFIER
	SET @brMask = -1
	IF EXISTS(SELECT * FROM [op000] where [Name] = 'EnableBranches' and [Value] = 1)
	SET @brMask = [dbo].[fnBranch_getCurrentUserReadMask_scalar](DEFAULT)
	declare  @Grp Table (
		[Guid] UNIQUEIDENTIFIER,
		[Level] SMALLINT,
		[Path] NVARCHAR(max)
	)
	INSERT INTO @Grp([Guid],[Level],[Path])
	SELECT [Guid],[Level],[Path] from [dbo].[fnGetGroupsOfGroupSorted]( 0x00, 1)
	
	SELECT @ParenTGrp = [GUID] 
	FROM [brt]  
		WHERE [tableName] = 'mt000' 
	INSERT INTO @Result SELECT * FROM 
	( 
		SELECT [GUID], 0x0 AS [ParentGUID], '' AS [Code], [Name], [LatinName], 'mt000' AS [tableName], @brMask AS [branchMask], 4 AS [SortNum], 21 AS [IconID] , '0.' AS [Path], 0 AS [Level] 
		
		FROM [brt]  
		WHERE [tableName] = 'mt000' 
		UNION ALL 
		SELECT   
			[g].[GUID],   
			CASE [g].[ParentGUID] WHEN 0x0 THEN @ParenTGrp ELSE [g].[ParentGUID] END,  
			[g].[Code],  
			[g].[Name],  
			[g].[LatinName],  
			'gr000', 
			[g].[branchMask], 
			0, -- sortNum  
			22, -- iconID  
			[fn].[Path] AS [Path], 
			(fn.[Level]+1) AS [Level]
		FROM  
			[gr000] AS [g]  
			INNER JOIN @Grp AS [fn] ON [g].[Guid] = [fn].[Guid] 
		UNION ALL 
		SELECT   
			[m].[GUID],   
			CASE [m].[groupGUID] WHEN 0x0 THEN @ParenTGrp ELSE [m].[groupGUID] END,  
			[m].[Code],  
			[m].[Name], 
			[m].[LatinName], 
			'mt000', 
			[m].[branchMask], 
			0, -- sortNum  
			23, -- iconID 
			[fn].[Path] + '0.1' AS [Path], 
			([fn].[Level]+2) AS [Level]
		FROM 
			[mt000] AS [m]  
			INNER JOIN @Grp AS [fn] ON [m].[groupGUID] = [fn].[Guid]
		WHERE [m].Parent = 0x0
		) AS [r] 
		WHERE @brMask = -1 OR (@brMask & branchMask) > 0
		ORDER BY [Path], [Level]
	RETURN
END
#########################################################
#END