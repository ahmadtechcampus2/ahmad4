################################################################################
CREATE PROCEDURE repMatHasSegmentsTree
		@Lang INT =0 
AS 
	SET NOCOUNT ON
	CREATE TABLE #SecViol (Type INT, Cnt INT)  
	CREATE TABLE #Result(  
			Guid		UNIQUEIDENTIFIER,  -- Group , Mat , Asset , AssetDetail 
			ParentGuid 	UNIQUEIDENTIFIER,  -- Group 
			Code		NVARCHAR(250) COLLATE ARABIC_CI_AI,  
			[Name]		NVARCHAR(250) COLLATE ARABIC_CI_AI,  
			Number		INT,
			Type		INT,  -- 0 Group , 1 Asset 
			mtSecurity INT,
			grSecurity INT,
			[Level] INT,
			EndLevel INT,
			Path NVARCHAR(max) COLLATE ARABIC_CI_AI)  
	CREATE TABLE #Gr( Guid UNIQUEIDENTIFIER, Path NVARCHAR(max), [Level] INT)
	INSERT INTO #Gr SELECT Guid, Path, Level FROM dbo.fnGetGroupsOfGroupSorted( 0x0, 1) AS fn
		
	declare @level INT 
	SET @level = 0
	declare @row int 
	INSERT INTO #Result 
		SELECT  
			mtGUID, 
			mtGroup,
			mtCode, 
			CASE WHEN (@Lang = 1)AND(mt.mtLatinName <> '') THEN  mt.mtLatinName ELSE mt.mtName END AS mtName,
			mtNumber,
			1, -- has segments
			mtSecurity,
			0,
			@Level,
			gr.Level + 1,
			gr.Path
		FROM 
			vwmt as mt
			INNER JOIN #Gr AS gr 
			ON mt.mtGroup = gr.Guid

			WHERE mt.mtHasSegments = 1
			
	set @row = @@ROWCOUNT
	while  @row <> 0
	begin
		set @level = @level + 1
		INSERT INTO #Result 
			SELECT  
				grGUID, 
				grParent, 
				grCode, 
				CASE WHEN (@Lang = 1)AND(gr.grLatinName <> '') THEN  gr.grLatinName ELSE gr.grName END AS grName,
				grNumber,
				0, -- Group 
				0,
				grSecurity,
				@level,
				g.Level,
				g.Path
			FROM  
				vwGr as gr inner join ( SELECT ParentGUID FROM #Result WHERE [Level] = @level - 1 GROUP BY ParentGUID)AS t
				on gr.grGUID = t.ParentGUID 
				INNER JOIN #Gr AS g 
				ON gr.grGUID = g.Guid
		set @row = @@ROWCOUNT	
	end
	exec prcCheckSecurity
	
	SELECT 
		Guid,
		ParentGuid,
		Code,
		[Name],
		Number,
		Type,
		mtSecurity,
		grSecurity,
		EndLevel AS [Level],
		[Path]
	FROM 
		#Result 
	GROUP BY
		[Guid],
		[ParentGuid],
		[Code],
		[Name],
		[Number],
		[Type],
		[mtSecurity],
		[grSecurity],
		[EndLevel],
		[Path]
	ORDER BY 
		[Path],
		[Type],
		[Number]
	SELECT * FROM #SecViol
	SET NOCOUNT OFF
################################################################################
CREATE   PROCEDURE repGetMatHasSegmnetsList
	@Lang		INT = 0,					-- Language	(0=Arabic; 1=English)
	@MatParentGuid		[UNIQUEIDENTIFIER] = NULL
AS
	SET NOCOUNT ON
		
	CREATE TABLE [#SecViol] ([Type] [INT], [Cnt] [INT])
	CREATE TABLE [#Mats] ([MatGUID] [UNIQUEIDENTIFIER], [Security] [INT])
	INSERT INTO [#Mats] EXEC [prcGetMatsList] @MatParentGuid, Null, -1, NULL
	
	CREATE TABLE [#Result](
			[Guid]		[UNIQUEIDENTIFIER],
			[GroupGuid] 	[UNIQUEIDENTIFIER],
			[Code]		[NVARCHAR](250) COLLATE ARABIC_CI_AI,
			[Name]		[NVARCHAR](250) COLLATE ARABIC_CI_AI,
			[Number]		[FLOAT],
			[MatSecurity] [INT]
		   	)
	
	INSERT INTO [#Result] 
	SELECT 
			[mt].[mtGUID], 
			[mt].[mtGroup],
			[mt].[mtCode], 
			CASE WHEN (@Lang = 1) AND ([mt].[mtCompositionName] <> '') THEN  [mt].[mtCompositionLatinName] ELSE [mt].[mtCompositionName] END AS [mtName],
			[mt].[mtNumber],
			[mt].[mtSecurity]
	FROM
			[vwmt] AS [mt]
	WHERE 
			[mt].[mtParent] = @MatParentGuid
	
	EXEC [prcCheckSecurity]
	
	SELECT * 
	FROM [#Result] 
	ORDER BY [Number]

	SELECT * FROM [#SecViol]
###################################################################################
#END
