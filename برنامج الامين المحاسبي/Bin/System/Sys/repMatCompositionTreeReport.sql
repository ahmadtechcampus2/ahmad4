#########################################################################
CREATE PROC repMatCompositionTreeReport
AS
	SET NOCOUNT ON 
	
	CREATE TABLE #SecViol (Type INT, Cnt INT)  
	CREATE TABLE #Result(  
			[Guid]			UNIQUEIDENTIFIER,  -- Group , Mat , Compmosition  
			[ParentGuid] 	UNIQUEIDENTIFIER,  -- Group 
			[MatGuid]		UNIQUEIDENTIFIER,
			[Code]			NVARCHAR(250) COLLATE ARABIC_CI_AI,  
			[Name]			NVARCHAR(250) COLLATE ARABIC_CI_AI,  
			[LatinName]		NVARCHAR(250) COLLATE ARABIC_CI_AI,  
			[MatName]		NVARCHAR(250) COLLATE ARABIC_CI_AI, 
			[MatLatinName]	NVARCHAR(250) COLLATE ARABIC_CI_AI,   
			[Number]		INT,
			[Type]			INT,  -- 0 Group , 1 Mat , 2 Compmosition 
			[mtSecurity]	INT,
			[grSecurity]	INT,
			[Level]			INT,
			[EndLevel]		INT,
			[Path]			NVARCHAR(max) COLLATE ARABIC_CI_AI,
			[CompositionPath]	INT)  
	CREATE TABLE #Gr( Guid UNIQUEIDENTIFIER, Path NVARCHAR(max), [Level] INT)
	INSERT INTO #Gr SELECT Guid, Path, Level FROM dbo.fnGetGroupsOfGroupSorted( 0x0, 1) AS fn
		
	DECLARE @level INT 
	SET @level = 0
	DECLARE @row int 
	INSERT INTO #Result 
		SELECT  
			mtGUID, 
			mtGroup,
			0x0, 
			mtCode, 
			mt.mtName,
			mt.mtLatinName,
			mt.mtName,
			mt.mtLatinName,
			mtNumber,
			1, -- has segments
			mtSecurity,
			0,
			@Level,
			gr.Level + 1,
			gr.Path,
			ROW_NUMBER() OVER(ORDER BY mtNumber)
		FROM 
			vwmt as mt
			INNER JOIN #Gr AS gr 
			ON mt.mtGroup = gr.Guid
			WHERE mt.mtHasSegments = 1
			
	SET @row = @@ROWCOUNT
	WHILE  @row <> 0
	BEGIN
		SET @level = @level + 1
		INSERT INTO #Result 
			SELECT  
				grGUID, 
				grParent, 
				0x0,
				grCode, 
				gr.grName,
				gr.grLatinName,
				gr.grName,
				gr.grLatinName,
				grNumber,
				0, -- Group 
				0,
				grSecurity,
				@level,
				g.Level,
				g.Path,
				0
			FROM  
				vwGr AS gr inner join ( SELECT ParentGUID FROM #Result WHERE [Level] = @level - 1 GROUP BY ParentGUID)AS t
				ON gr.grGUID = t.ParentGUID 
				INNER JOIN #Gr AS g 
				ON gr.grGUID = g.Guid
		SET @row = @@ROWCOUNT	
	END

	INSERT INTO #Result 
		SELECT  
			[mt].mtGUID, 
			[mt].mtParent,
			[mt].mtGUID, 
			[mt].mtCode, 
			[mt].mtCompositionName,
			[mt].mtCompositionLatinName,
			[mt].mtName,
			[mt].mtLatinName,
			[mt].mtNumber,
			2, -- Compmosition Mat
			[mt].mtSecurity,
			0,
			@Level,
			r.Level + 1,
			r.Path,
			r.CompositionPath
		FROM 
			vwmt AS mt
			LEFT JOIN [#Result] AS r  ON r.Guid = mt.mtParent
		WHERE mt.mtParent <> 0x0
			

	EXEC prcCheckSecurity
	SELECT 
		[Guid],
		[ParentGuid],
		[MatGuid],
		[Code],
		[Name],
		[MatName],
		[MatLatinName],
		[LatinName],
		[Type],
		[mtSecurity],
		[grSecurity],
		[EndLevel] AS [Level],
		[Path],
		[CompositionPath]
	FROM 
		#Result 
	GROUP BY
		[Guid],
		[ParentGuid],
		[Code],
		[Name],
		[LatinName],
		[Type],
		[mtSecurity],
		[grSecurity],
		[EndLevel],
		[Path],
		[MatGuid],
		[Number],
		[MatName],
		[MatLatinName],
		[CompositionPath]
	ORDER BY 
		[Path],		
		[CompositionPath],
		[Type],
		[Number]

	SELECT * FROM #SecViol 
##########################################################################
#END