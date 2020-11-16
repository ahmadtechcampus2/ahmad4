############################################################## 
CREATE PROCEDURE prcIE_CreateTmpSegments
AS
	IF EXISTS(SELECT NAME FROM SysObjects WHERE NAME = 'segments2')
		DROP TABLE [dbo].[segments2]
	CREATE TABLE [dbo].[segments2](
		[Id] [uniqueidentifier] NOT NULL DEFAULT (0x00),
		[Name] [nvarchar](250) NULL DEFAULT (''),
		[LatinName] [nvarchar](250) NULL DEFAULT (''),
		[CharactersCount] [int] NULL DEFAULT ((0)),
		[Number] [int] NULL DEFAULT ((0)),
		CONSTRAINT PK_TmpSegments_Id PRIMARY KEY (Id)
	)
############################################################## 
CREATE PROCEDURE prcIE_CreateTmpSegmentElements
	AS
	IF EXISTS(SELECT NAME FROM SysObjects WHERE NAME = 'segmentElements2')
		DROP TABLE [dbo].[segmentElements2]
	CREATE TABLE [dbo].[segmentElements2](
		[Id] [uniqueidentifier] NOT NULL DEFAULT (0x00),
		[Code] [nvarchar](100) NULL DEFAULT (''),
		[Name] [nvarchar](250) NULL DEFAULT (''),
		[LatinName] [nvarchar](250) NULL DEFAULT (''),
		[SegmentId] [uniqueidentifier] NULL DEFAULT (0x00),
		[Number] [int] NULL DEFAULT ((0)),
		CONSTRAINT PK_TmpSegmentElements_Id PRIMARY KEY (Id)
	) 
############################################################## 
CREATE PROCEDURE prcIE_CreateTmpMatElements
	AS
	IF EXISTS(SELECT NAME FROM SysObjects WHERE NAME = 'matElements2')
		DROP TABLE [dbo].[matElements2]
	CREATE TABLE [dbo].[matElements2](
		[Id] [uniqueidentifier] NOT NULL DEFAULT (0x00),
		[MaterialId] [uniqueidentifier] NULL DEFAULT (0x00),
		[ElementId] [uniqueidentifier] NULL DEFAULT (0x00),
		[Order] [int] NULL DEFAULT ((0)),
		CONSTRAINT PK_TmpMatElements_Id PRIMARY KEY (Id)
	)
############################################################## 
CREATE PROCEDURE prcIE_CreateTmpMatSegments
	AS
	IF EXISTS(SELECT NAME FROM SysObjects WHERE NAME = 'matSegments2')
		DROP TABLE [dbo].[matSegments2]
	CREATE TABLE [dbo].[matSegments2](
		[Id] [uniqueidentifier] NOT NULL DEFAULT (0x00),
		[MaterialId] [uniqueidentifier] NULL DEFAULT (0x00),
		[SegmentId] [uniqueidentifier] NULL DEFAULT (0x00),
		[Number] [int] NULL DEFAULT ((0)),
		CONSTRAINT PK_TmpMatSegments_Id PRIMARY KEY (Id)
	)
############################################################## 
CREATE PROCEDURE prcIE_CreateTmpMatSegmentElements
	AS
	IF EXISTS(SELECT NAME FROM SysObjects WHERE NAME = 'matSegmentElements2')
		DROP TABLE [dbo].[matSegmentElements2]
	CREATE TABLE [dbo].[matSegmentElements2](
		[MaterialSegmentId] [uniqueidentifier] NULL DEFAULT (0x00),
		[ElementId] [uniqueidentifier] NULL DEFAULT (0x00),
		[Number] [int] NULL DEFAULT ((0))
	)
############################################################## 
CREATE PROCEDURE prcIE_CreateTmpGroupSegments
	AS
	IF EXISTS(SELECT NAME FROM SysObjects WHERE NAME = 'groupSegments2')
		DROP TABLE [dbo].[groupSegments2]
	CREATE TABLE [dbo].[groupSegments2](
		[Id] [uniqueidentifier] NOT NULL DEFAULT (0x00),
		[GroupId] [uniqueidentifier] NULL DEFAULT (0x00),
		[SegmentId] [uniqueidentifier] NULL DEFAULT (0x00),
		[Number] [int] NULL DEFAULT ((0)),
		CONSTRAINT PK_TmpGroupSegments_Id PRIMARY KEY (Id)
	)
############################################################## 
CREATE PROCEDURE prcIE_CreateTmpGroupSegmentElements
	AS
	IF EXISTS(SELECT NAME FROM SysObjects WHERE NAME = 'groupSegmentElements2')
		DROP TABLE [dbo].[groupSegmentElements2]
	CREATE TABLE [dbo].[groupSegmentElements2](
		[GroupSegmentId] [uniqueidentifier] NULL DEFAULT (0x00),
		[ElementId] [uniqueidentifier] NULL DEFAULT (0x00),
		[Number] [int] NULL DEFAULT ((0))
	)
############################################################## 
CREATE PROCEDURE prcIE_CreateTmpGroups
	AS
	IF EXISTS(SELECT NAME FROM SysObjects WHERE NAME = 'groups2')
		DROP TABLE [dbo].[groups2]
	CREATE TABLE [dbo].[groups2](
		[GUID] [uniqueidentifier] NULL DEFAULT (0x00),
		[Code] [nvarchar](100) NULL DEFAULT ('')
	)
############################################################## 
CREATE PROCEDURE prcIE_CreateTmpMtOriginal
	AS
	IF EXISTS(SELECT NAME FROM SysObjects WHERE NAME = 'mtOriginal')
		DROP TABLE [dbo].[mtOriginal]
	SELECT GUID, Parent, HasSegments INTO [mtOriginal] FROM mt000
############################################################## 
CREATE PROCEDURE prcIE_ImportSegments
	@UpdateMatCard  [INT] = 0,
	@ReTrance		[BIT] = 0
AS 
	SET NOCOUNT ON
	IF NOT EXISTS(SELECT [NAME] FROM [SysObjects] WHERE [NAME] = 'segments2')
		RETURN
	SELECT * INTO [#segments] FROM [segments2]
	SELECT * INTO [#segmentManagement] FROM [segments2]

	-- update segments
	IF EXISTS(SELECT * FROM [#segments] AS [s2] INNER JOIN [Segments000] AS [s] ON ([s].[Id] = [s2].[Id] AND [s].[CharactersCount] != [s2].[CharactersCount]))
	BEGIN
		RAISERROR (N'AmnE1008', 16, 1);
		RETURN
	END
	IF @UpdateMatCard > 0 
	BEGIN
		UPDATE
			s
		SET
			s.Name = s2.Name,
			s.LatinName = s2.LatinName
		FROM
			Segments000 AS s
			INNER JOIN [#segments] AS s2 ON (s.Id = s2.Id AND s.CharactersCount = s2.CharactersCount)
	END

	--for same guid	
	DELETE [s2] FROM [#segments] AS [s2] INNER JOIN [Segments000] AS [s] ON [s].[Id] = [s2].[Id]
	
	--for different guid with the same name
	IF EXISTS(SELECT * FROM [#segments] AS [s2] INNER JOIN [Segments000] AS [s] ON [s].[Name] = [s2].[Name])
	BEGIN
		RAISERROR (N'AmnE1007', 16, 1);
		RETURN
	END

	DECLARE @MaxNum [INT]
	SELECT @MaxNum = ISNULL(MAX([NUMBER]),0) FROM [Segments000]

	--add segments
	INSERT INTO [Segments000]
		(
			[Id],
			[Name],
			[LatinName],
			[CharactersCount],
			[Number]		
		)
		SELECT 
			[s2].[Id],
			[s2].[Name],
			[s2].[LatinName],
			[s2].[CharactersCount],
			@MaxNum + (ROW_NUMBER() OVER(ORDER BY s2.Number ASC))
		FROM [#segments] as [s2]
	
	IF @ReTrance = 0
	BEGIN
		SELECT @MaxNum = ISNULL(MAX([NUMBER]),0) FROM [MaterialsSegmentsManagement000]
		DELETE [sm] FROM [#segmentManagement] AS [sm] INNER JOIN [MaterialsSegmentsManagement000] AS [sm2] ON [sm2].[SegmentId] = [sm].[Id]

		INSERT INTO [MaterialsSegmentsManagement000]
			(
				[Number],
				[SegmentId]
			)
			SELECT 
				@MaxNum + (ROW_NUMBER() OVER(ORDER BY s2.Number ASC)),
				[s2].[Id]
			FROM [#segmentManagement] as [s2]	
	END
############################################################## 
CREATE PROCEDURE prcIE_ImportMaterialsSegmentsManagement
AS 
	SET NOCOUNT ON
	IF NOT EXISTS(SELECT [NAME] FROM [SysObjects] WHERE [NAME] ='MaterialsSegmentsManagement2')
		RETURN
	SELECT * INTO [#segmentManagement] FROM [MaterialsSegmentsManagement2]
	DELETE [sm] FROM [#segmentManagement] AS [sm] INNER JOIN [MaterialsSegmentsManagement000] AS [sm2] ON [sm2].[SegmentId] = [sm].[SegmentId]
	DECLARE @MaxNum [INT]
	SELECT @MaxNum = ISNULL(MAX([NUMBER]),0) FROM [MaterialsSegmentsManagement000]
	INSERT INTO [MaterialsSegmentsManagement000]
		(
			[Number],
			[SegmentId]
		)
		SELECT 
			@MaxNum + (ROW_NUMBER() OVER(ORDER BY s2.Number ASC)),
			[s2].[SegmentId]
		FROM [#segmentManagement] as [s2]	
############################################################## 
CREATE PROCEDURE prcIE_ImportSegmentElements
	@UpdateMatCard  [INT] = 0
AS 
	SET NOCOUNT ON
	IF NOT EXISTS(SELECT [NAME] FROM [SysObjects] WHERE [NAME] ='segmentElements2')
		RETURN
	SELECT * 
	INTO [#segmentElements] 
	FROM [segmentElements2]
	
	SELECT * 
	INTO [#segments] 
	FROM [segments2]

	--for different code with the same name

	IF EXISTS(
		SELECT * FROM [#segmentElements] AS [se2] 
		INNER JOIN [SegmentElements000] AS [se] 
		ON [se].[Name] = [se2].[Name] 
		AND 
		([se].[Code] != [se2].[Code] COLLATE SQL_Latin1_General_CP1_CS_AS)
		INNER JOIN #segments AS s1 ON s1.Id = [se2].SegmentId
		INNER JOIN Segments000 AS s2 ON s2.Id = [se].SegmentId
		WHERE s1.Id = s2.Id
		)
	BEGIN
		RAISERROR (N'AmnE1009', 16, 1);
		RETURN
	END

	--for same code	
	DELETE [se2] FROM [#segmentElements] AS [se2] 
	INNER JOIN [SegmentElements000] AS [se] 
	ON 
	([se].[Code] = [se2].[Code] COLLATE SQL_Latin1_General_CP1_CS_AS) 
	AND 
	[se].[Name] = [se2].[Name]
	INNER JOIN #segments AS s1 ON s1.Id = [se2].SegmentId
	INNER JOIN Segments000 AS s2 ON s2.Id = [se].SegmentId
	WHERE s1.Id = s2.Id
	
	-- update elements
	IF @UpdateMatCard > 0 
	BEGIN
		UPDATE
			se
		SET
			se.Name = se2.Name,
			se.LatinName = se2.LatinName
		FROM
			[SegmentElements000] AS se
			INNER JOIN [#segmentElements] AS se2 ON ((se.Id = se2.Id) OR ((se.Code = se2.Code COLLATE SQL_Latin1_General_CP1_CS_AS) AND (se.Id != se2.Id))) AND (se.SegmentId = se2.SegmentId)
	END

	DELETE [se2] FROM [#segmentElements] AS [se2] 
	INNER JOIN [SegmentElements000] AS [se] 
	ON 
	(se.Id = se2.Id) 
	OR 
	([se].[Code] = [se2].[Code] COLLATE SQL_Latin1_General_CP1_CS_AS)
	INNER JOIN #segments AS s1 ON s1.Id = [se2].SegmentId
	INNER JOIN Segments000 AS s2 ON s2.Id = [se].SegmentId
	WHERE s1.Id = s2.Id

	DECLARE @MaxNum [INT]
	SELECT @MaxNum = ISNULL(MAX([NUMBER]),0) FROM [SegmentElements000]

	INSERT INTO [SegmentElements000]
		(
			[Id],
			[Code],
			[Name],
			[LatinName],
			[SegmentId],
			[Number]
		)
		SELECT 
			[se2].[Id],
			[se2].[Code],
			[se2].[Name],
			[se2].[LatinName],
			[se2].[SegmentId],
			@MaxNum + (ROW_NUMBER() OVER(ORDER BY [se2].[Number] ASC))
		FROM [#segmentElements] as [se2]
############################################################## 
CREATE PROCEDURE prcIE_ImportMatElements
AS 
	SET NOCOUNT ON
	IF NOT EXISTS(SELECT [NAME] FROM [SysObjects] WHERE [NAME] ='matElements2')
		RETURN
	SELECT * 
	INTO [#mt] 
	FROM [mt2]

	SELECT matElements2.*, [#mt].[Code], se2.Code AS elementCode, se2.SegmentId AS SegmentId 
	INTO [#matElements] 
	FROM matElements2
	LEFT JOIN [#mt] ON [#mt].[GUID] = [matElements2].[MaterialId]
	LEFT JOIN segmentElements2 as se2 ON se2.id = matElements2.ElementId
	
	DELETE me1 
	FROM [#matElements] AS me1 
	INNER JOIN (SELECT distinct(MaterialId), Code FROM MaterialElements000 
				LEFT JOIN [mt000] ON [mt000].[GUID] = [MaterialElements000].[MaterialId]) AS me2 
	ON (me1.MaterialId = me2.MaterialId OR (me1.Code = me2.Code COLLATE SQL_Latin1_General_CP1_CS_AS))

	INSERT INTO [MaterialElements000]
		(
			[Id],
			[MaterialId],
			[ElementId],
			[Order]
		)
		SELECT 
			[me2].[Id],
			[mt].[GUID],
			[se].[Id],
			[me2].[Order]
		FROM [#matElements] as [me2]
		INNER JOIN [mt000] AS [mt] ON (([mt].[GUID] = [me2].[MaterialId]) OR (([mt].[Code] = [me2].[Code] COLLATE SQL_Latin1_General_CP1_CS_AS) AND [mt].[GUID] != [me2].[MaterialId]))
		INNER JOIN [SegmentElements000] AS [se] ON ((([se].[Id] = [me2].[ElementId]) OR (([se].[Code] = [me2].[elementCode] COLLATE SQL_Latin1_General_CP1_CS_AS) AND [se].[Id] != [me2].[ElementId])) AND ([se].SegmentId = [me2].SegmentId))
############################################################## 
CREATE PROCEDURE prcIE_ImportMatSegments
	@ReTrance		[BIT] = 0
AS 
	SET NOCOUNT ON
	IF NOT EXISTS(SELECT [NAME] FROM [SysObjects] WHERE [NAME] ='matSegments2')
		RETURN
	
	SELECT * INTO [#mt] FROM [mt2]

	SELECT matSegments2.*, [#mt].[Code] 
	INTO [#matSegments] 
	FROM matSegments2
	LEFT JOIN [#mt] ON [#mt].[GUID] = [matSegments2].[MaterialId]
	
	CREATE TABLE #BasicResult
	(
		[NewMatId] [uniqueidentifier] NOT NULL DEFAULT (0x00),
		[NewSegmentsCount] [int] NULL DEFAULT ((0)),
		[OldMatId] [uniqueidentifier] NULL DEFAULT (0x00),
		[OldSegmentsCount] [int] NULL DEFAULT ((0)),
		[OldMatName] [nvarchar](255) NULL DEFAULT ('')
	)
	INSERT INTO #BasicResult
	(
		[NewMatId],
		[NewSegmentsCount],
		[OldMatId],
		[OldSegmentsCount],
		[OldMatName]
	)
	SELECT 
		matSegmentNew.MaterialId, 
		matSegmentNew.SegmentsCount, 
		matSegmentOriginal.MaterialId, 
		matSegmentOriginal.SegmentsCount, 
		matSegmentOriginal.Name
		FROM 
			(SELECT DISTINCT([#matSegments].MaterialId), (COUNT([#matSegments].MaterialId) OVER (PARTITION BY [#matSegments].MaterialId)) AS SegmentsCount, [#matSegments].Code
			FROM [#matSegments]) AS matSegmentNew
		INNER JOIN 
			(SELECT DISTINCT(MaterialSegments000.MaterialId), (COUNT(MaterialSegments000.MaterialId) OVER (PARTITION BY MaterialSegments000.MaterialId)) AS SegmentsCount, mt000.Code, mt000.Name
			FROM MaterialSegments000
			LEFT JOIN mt000 
			ON MaterialSegments000.MaterialId = mt000.GUID) AS matSegmentOriginal 
		ON (matSegmentNew.MaterialId = matSegmentOriginal.MaterialId OR ((matSegmentNew.Code = matSegmentOriginal.Code COLLATE SQL_Latin1_General_CP1_CS_AS) AND matSegmentNew.MaterialId != matSegmentOriginal.MaterialId))

	SELECT 
	mss.NewSegmentsCount AS NewSegmentsCount,
	mss.OldMatId AS OldMatId,
	mss.OldSegmentsCount AS OldSegmentsCount,
	mss.OldMatName AS OldMatName,
	SUM(mss.SimilarSegments) AS SimilarSegments
	INTO #Result
	FROM 
	(
		SELECT 
		ms.MaterialId AS NewMatId, 
		rms.NewSegmentsCount AS NewSegmentsCount, 
		rms.OldMatId AS OldMatId, 
		rms.OldSegmentsCount AS OldSegmentsCount,
		rms.OldMatName AS OldMatName,
		(CASE WHEN ms.MaterialId IS NULL THEN 0 ELSE 1 END) AS SimilarSegments
		FROM
			(SELECT 
			res.OldMatId AS OldMatId, 
			ms2.SegmentId AS NewSegmentId, 
			res.NewSegmentsCount AS NewSegmentsCount, 
			res.OldSegmentsCount AS OldSegmentsCount,
			res.OldMatName AS OldMatName 
			FROM #BasicResult AS res
			INNER JOIN #matSegments AS ms2 ON ms2.MaterialId = res.NewMatId) AS rms
		LEFT JOIN MaterialSegments000 AS ms ON ms.MaterialId = rms.OldMatId AND ms.SegmentId = rms.NewSegmentId
	) AS mss
	WHERE NewSegmentsCount != OldSegmentsCount OR NewSegmentsCount != SimilarSegments OR OldSegmentsCount != SimilarSegments
	GROUP BY
	NewSegmentsCount,
	OldMatId,
	OldSegmentsCount,
	OldMatName

	SELECT DISTINCT(mtParent.GUID) AS OldMatId, (CASE WHEN mtComponent.GUID IS NULL THEN 0 ELSE 1 END) AS HasComp 
	INTO #OldMatCompCount
	FROM [mtOriginal] AS mtParent 
	LEFT JOIN [mtOriginal] AS mtComponent ON mtComponent.Parent = mtParent.GUID
	WHERE mtParent.HasSegments = 1

	SELECT res.*, #OldMatCompCount.HasComp 
	INTO #DiffSegCompCount 
	FROM #RESULT res
	LEFT JOIN #OldMatCompCount 
	ON #OldMatCompCount.OldMatId = res.OldMatId
	 AND (res.NewSegmentsCount != res.OldSegmentsCount OR res.NewSegmentsCount != res.SimilarSegments OR res.OldSegmentsCount != res.SimilarSegments)

	SELECT * 
	INTO #DiffSegWithComp 
	FROM #DiffSegCompCount 
	WHERE HasComp != 0

	SELECT * 
	INTO #DiffSegZeroComp 
	FROM #DiffSegCompCount 
	WHERE HasComp = 0

	IF EXISTS (SELECT * FROM #DiffSegWithComp)
	BEGIN
		DECLARE @var1 [NVARCHAR](255);
		DECLARE @errStr [NVARCHAR](255);

		IF @ReTrance = 0
			SET @errStr = N'AmnE1000: '
		ELSE
			SET @errStr = N'AmnE1011: '

		SET @var1 = @errStr + (SELECT TOP(1) [OldMatName]	FROM #DiffSegWithComp)
		RAISERROR (@var1, 16, 1);
		RETURN
	END

	DELETE ms
	FROM MaterialSegments000 AS ms
	INNER JOIN #DiffSegZeroComp AS ds ON ds.OldMatId = ms.MaterialId

	DELETE ms1 
	FROM [#matSegments] AS ms1 
	INNER JOIN (SELECT distinct(MaterialId), Code 
				FROM MaterialSegments000 
				LEFT JOIN [mt000] ON [mt000].[GUID] = [MaterialSegments000].[MaterialId]) AS ms2 
	ON (ms1.MaterialId = ms2.MaterialId OR ms1.Code = ms2.Code)

	INSERT INTO [MaterialSegments000]
		(
			[Id],
			[MaterialId],
			[SegmentId],
			[Number]
		)
		SELECT 
			[ms2].[Id],
			[mt].[GUID],
			[s].[Id],
			[ms2].[Number]
		FROM [#matSegments] as [ms2]
		INNER JOIN [mt000] AS [mt] ON (([mt].[GUID] = [ms2].[MaterialId]) OR (([mt].[Code] = [ms2].[Code] COLLATE SQL_Latin1_General_CP1_CS_AS) AND [mt].[GUID] != [ms2].[MaterialId]))
		INNER JOIN [Segments000] AS [s] ON [s].[Id] = [ms2].[SegmentId]
############################################################## 
CREATE PROCEDURE prcIE_ImportMatSegmentElements
AS 
	SET NOCOUNT ON
	IF NOT EXISTS(SELECT [NAME] FROM [SysObjects] WHERE [NAME] ='matSegmentElements2')
		RETURN
	SELECT * INTO [#mt] FROM [mt2]

	SELECT [mse2].[MaterialSegmentId], [mse2].[ElementId], [se2].[Code] AS [elementCode], [mse2].[Number], [#mt].[GUID] AS GUID, [#mt].[Code] AS Code, [ms2].[SegmentId]
	INTO [#matSegmentElements] 
	FROM [matSegmentElements2] AS [mse2]
	LEFT JOIN [matSegments2] AS [ms2] ON [ms2].[Id] = [mse2].[MaterialSegmentId]
	LEFT JOIN [segmentElements2] AS [se2] ON [se2].[Id] = [mse2].[ElementId]
	LEFT JOIN [#mt] ON [#mt].GUID = [ms2].[MaterialId]

	DELETE mse FROM [#matSegmentElements] AS mse
	INNER JOIN (
		SELECT [mse2].[MaterialSegmentId], [mse2].[ElementId], [se2].[Code] AS [elementCode], [mse2].[Number], [mt].[GUID] , [mt].[Code], [ms2].[SegmentId]
		FROM [MaterialSegmentElements000] AS [mse2]
		LEFT JOIN [MaterialSegments000] AS [ms2] ON [ms2].[Id] = [mse2].[MaterialSegmentId]
		LEFT JOIN [SegmentElements000] AS [se2] ON [se2].[Id] = [mse2].[ElementId]
		LEFT JOIN [mt000] AS mt ON [mt].GUID = [ms2].[MaterialId]
	) AS mse3
	ON ((mse3.GUID = mse.GUID OR (mse3.Code = mse.Code COLLATE SQL_Latin1_General_CP1_CS_AS)) AND (mse3.SegmentId = mse.SegmentId) AND ((mse3.elementCode = mse.elementCode COLLATE SQL_Latin1_General_CP1_CS_AS) OR mse3.ElementId = mse.ElementId))
	
	INSERT INTO [MaterialSegmentElements000]
		(
			[MaterialSegmentId],
			[ElementId],
			[Number]
		)
		SELECT
			ms.[MaterialSegmentId], 
			se.Id,
			ROW_NUMBER() OVER (PARTITION BY ms.[MaterialSegmentId] ORDER BY mse2.[Number]) + ISNULL(ms.Number,0) as Number
		FROM [#matSegmentElements] AS mse2
		INNER JOIN 
			(SELECT 
				DISTINCT(MaterialSegments000.Id) AS [MaterialSegmentId], 
				MaterialSegments000.SegmentId AS SegmentId, 
				mt000.GUID AS MaterialId, 
				mt000.Code AS Code, 
				Max(MaterialSegmentElements000.Number) OVER (PARTITION BY MaterialSegmentElements000.MaterialSegmentId) AS Number
			FROM MaterialSegments000 
			INNER JOIN mt000 ON MaterialSegments000.MaterialId = mt000.GUID
			LEFT JOIN MaterialSegmentElements000 ON MaterialSegmentElements000.MaterialSegmentId = MaterialSegments000.Id) AS ms 
		ON ((ms.MaterialId = mse2.GUID OR (ms.MaterialId != mse2.GUID AND (ms.Code = mse2.Code COLLATE SQL_Latin1_General_CP1_CS_AS))) AND (mse2.SegmentId = ms.SegmentId))
		INNER JOIN SegmentElements000 AS se ON ((se.Id = mse2.ElementId OR (se.Id != mse2.ElementId AND (se.Code = mse2.elementCode COLLATE SQL_Latin1_General_CP1_CS_AS))) AND (se.SegmentId = ms.SegmentId))
############################################################## 
CREATE PROCEDURE prcIE_FilterImportedMaterials
	@UpdateMatCard  [INT] = 0,
	@ReTrance		[BIT] = 0
AS 
	SET NOCOUNT ON
	SELECT * INTO #mt2 FROM mt2

	SELECT #mt2.Name AS Name, #mt2.GUID AS GUID INTO [#segmentToNormalMatTbl] 
	FROM #mt2 
	INNER JOIN [mt000] AS [mt] ON (#mt2.GUID = [mt].GUID OR #mt2.Code = [mt].Code) 
	WHERE (#mt2.[HasSegments] = 1 AND [mt].[HasSegments] = 0 AND [mt].[Parent] = 0x00 AND dbo.[fnMaterial_IsUsed]([mt].[GUID]) != 0)

	SELECT mt3.Name AS Name, mt3.GUID AS GUID INTO #movedMaterials FROM #mt2 
	LEFT JOIN mt000 AS mt  ON (mt.GUID = #mt2.GUID OR (mt.Code = #mt2.Code COLLATE SQL_Latin1_General_CP1_CS_AS)) AND mt.HasSegments = 0 AND mt.Parent != 0x00 AND #mt2.HasSegments = 0 AND #mt2.Parent != 0x00
	LEFT JOIN #mt2  AS mt3 ON (mt3.GUID = #mt2.Parent)
	LEFT JOIN mt000 AS mt4 ON (mt4.GUID = mt3.GUID OR (mt4.Code = mt3.Code COLLATE SQL_Latin1_General_CP1_CS_AS)) AND mt4.Parent = 0x00 AND mt3.Parent = 0x00
	WHERE #mt2.MovedComposite = 1 AND mt.GUID IS NULL AND mt4.GUID IS NOT NULL
	
	SELECT #segmentToNormalMatTbl.* INTO #movedSegmentToNormalTbl FROM #segmentToNormalMatTbl
	INNER JOIN #movedMaterials ON #movedMaterials.GUID = #segmentToNormalMatTbl.GUID

	IF EXISTS (SELECT * FROM #movedSegmentToNormalTbl)
	BEGIN
		DECLARE @var1 [NVARCHAR](255);
		DECLARE @errStr [NVARCHAR](255);

		IF @ReTrance = 0
			SET @errStr = N'AmnE1002: '
		ELSE
			SET @errStr = N'AmnE1010: '

		SET @var1 = @errStr + (SELECT TOP(1) [Name] FROM #movedSegmentToNormalTbl)
		RAISERROR (@var1, 16, 1);
		RETURN
	END

	IF EXISTS (SELECT * FROM [#segmentToNormalMatTbl]) AND @UpdateMatCard = 1
	BEGIN
		DECLARE @var2 [NVARCHAR](255);
		SET @var2 = N'AmnE1002: ' + (SELECT TOP(1) [Name] FROM [#segmentToNormalMatTbl])
		RAISERROR (@var2, 16, 1);
		RETURN
	END

	IF @UpdateMatCard = 0
	BEGIN
		IF EXISTS (SELECT * FROM #movedMaterials)
		BEGIN
			DECLARE @var3 [NVARCHAR](255);
			SET @var3 = N'AmnE1003: ' + (SELECT TOP(1) Name	FROM #movedMaterials)
			RAISERROR (@var3, 18, 255);
			RETURN
		END

		SELECT #mt2.GUID AS matId INTO [#deletedSegmentedMats]
		FROM #mt2
		INNER JOIN mt000 AS mt ON (mt.GUID = #mt2.GUID OR (mt.Code = #mt2.Code COLLATE SQL_Latin1_General_CP1_CS_AS)) AND (mt.Parent = 0x00) AND (#mt2.Parent = 0x00)
	
		DELETE mt FROM #mt2 AS mt
		INNER JOIN [#deletedSegmentedMats] AS dsm ON dsm.matId = mt.GUID

		SELECT mt.GUID AS matId INTO [#deletedComponentMats]
		FROM #mt2 AS mt
		INNER JOIN [#deletedSegmentedMats] AS dsm ON dsm.matId = mt.Parent

		DELETE mt FROM #mt2 AS mt
		INNER JOIN [#deletedComponentMats] AS dcm ON dcm.matId = mt.GUID

		DROP TABLE mt2
		SELECT * INTO mt2 FROM #mt2

		DELETE me FROM matElements2 AS me
		INNER JOIN [#deletedComponentMats] AS dcm ON dcm.matId = me.MaterialId

		SELECT Id INTO [#deletedMatSegments]
		FROM matSegments2 AS ms
		INNER JOIN [#deletedSegmentedMats] AS dsm ON dsm.matId = ms.MaterialId

		DELETE ms FROM matSegments2 AS ms
		INNER JOIN [#deletedMatSegments] AS dms ON dms.Id = ms.Id

		DELETE mse FROM matSegmentElements2 AS mse
		INNER JOIN [#deletedMatSegments] AS dms ON dms.Id = mse.MaterialSegmentId

		SELECT DISTINCT(s.Id) AS SegmentId INTO #usedSegments
		FROM segments2 AS s
		LEFT JOIN matSegments2 AS ms2 ON ms2.SegmentId = s.Id
		LEFT JOIN (SELECT SegmentId FROM matElements2 AS me2 INNER JOIN segmentElements2 AS se2 ON se2.Id = me2.ElementId) AS me2 ON me2.SegmentId = s.Id
		LEFT JOIN groupSegments2 AS gs2 ON gs2.SegmentId = s.Id
		WHERE ms2.Id != 0x00 OR me2.SegmentId != 0x00 OR gs2.Id != 0x00

		SELECT DISTINCT(se2.Id) AS ElementId INTO #usedElements 
		FROM segmentElements2 AS se2
		LEFT JOIN matElements2 AS me2 ON me2.ElementId = se2.Id
		LEFT JOIN matSegmentElements2 AS mse2 ON mse2.ElementId = se2.Id
		LEFT JOIN groupSegmentElements2 AS gse2 ON gse2.ElementId = se2.Id
		WHERE me2.Id != 0x00 OR mse2.MaterialSegmentId != 0x00 OR gse2.GroupSegmentId != 0x00


		DELETE s2 FROM segments2 AS s2
		WHERE s2.Id NOT IN (SELECT SegmentId FROM #usedSegments)

		DELETE se2 FROM segmentElements2 AS se2
		WHERE se2.Id NOT IN (SELECT ElementId FROM #usedElements)
	END
############################################################## 
CREATE PROCEDURE prcIE_ImportGroupSegments
AS 
	SET NOCOUNT ON
	IF NOT EXISTS(SELECT [NAME] FROM [SysObjects] WHERE [NAME] ='groupSegments2')
		RETURN
	SELECT * INTO [#gr] FROM [groups2]

	SELECT groupSegments2.*, [#gr].[Code] INTO [#groupSegments] 
	FROM groupSegments2
	LEFT JOIN [#gr] ON [#gr].[GUID] = [groupSegments2].[GroupId]
	
	DELETE FROM GroupSegments000

	INSERT INTO [GroupSegments000]
		(
			[Id],
			[GroupId],
			[SegmentId],
			[Number]
		)
		SELECT 
			[gs2].[Id],
			[gr].[GUID],
			[s].[Id],
			[gs2].[Number]
		FROM [#groupSegments] as [gs2]
		INNER JOIN [gr000] AS [gr] ON (([gr].[GUID] = [gs2].[GroupId]) OR (([gr].[Code] = [gs2].[Code] COLLATE SQL_Latin1_General_CP1_CS_AS) AND [gr].[GUID] != [gs2].[GroupId]))
		INNER JOIN [Segments000] AS [s] ON [s].[Id] = [gs2].[SegmentId]
#################################################################
CREATE PROCEDURE prcIE_ImportGroupSegmentElements
AS 
	SET NOCOUNT ON
	IF NOT EXISTS(SELECT [NAME] FROM [SysObjects] WHERE [NAME] ='groupSegmentElements2')
		RETURN
	SELECT * INTO [#gr] FROM [groups2]
	SELECT * INTO [#groupsegments] FROM [groupSegments2]

	SELECT [gse2].[GroupSegmentId], [gse2].[ElementId], [gse2].[Number], [se2].[Code] AS [elementCode] INTO [#groupSegmentElements] 
	FROM groupSegmentElements2 AS [gse2]
	LEFT JOIN [segmentElements2] AS [se2] ON [se2].[Id] = [gse2].[ElementId]

	DELETE FROM GroupSegmentElements000

	INSERT INTO [GroupSegmentElements000]
		(
			[GroupSegmentId],
			[ElementId],
			[Number]
		)
		SELECT 
			[gse2].[GroupSegmentId],
			se.Id,
			[gse2].[Number]
		FROM [#groupSegmentElements] as [gse2]
		INNER JOIN [#groupsegments] AS [gs1] ON [gs1].[Id] = [gse2].[GroupSegmentId]
		INNER JOIN GroupSegments000 AS [gs] ON [gs].[Id] = [gse2].[GroupSegmentId]
		INNER JOIN SegmentElements000 AS se ON ((se.Id = gse2.ElementId OR (se.Id != gse2.ElementId AND (se.Code = gse2.elementCode COLLATE SQL_Latin1_General_CP1_CS_AS)))) AND (se.SegmentId = [gs1].SegmentId)
#################################################################
CREATE PROCEDURE prcIE_GetExportedSegments
AS 
	SET NOCOUNT ON
	CREATE TABLE #impMatSegments(Id UNIQUEIDENTIFIER, MaterialId UNIQUEIDENTIFIER, SegmentId UNIQUEIDENTIFIER, Number INT)
	CREATE TABLE #impGroupSegments(Id UNIQUEIDENTIFIER, GroupId UNIQUEIDENTIFIER, SegmentId UNIQUEIDENTIFIER, Number INT)

	INSERT INTO #impMatSegments EXEC prcIE_GetExportedMatSegments
	INSERT INTO #impGroupSegments EXEC prcIE_GetExportedGroupSegments

	SELECT s.CharactersCount,s.Id, s.LatinName, s.Name, s.Number
	FROM Segments000 AS s
	INNER JOIN (SELECT SegmentId FROM #impMatSegments 
				UNION 
				SELECT SegmentId FROM #impGroupSegments) AS usedSegments
	ON usedSegments.SegmentId = s.Id
#################################################################
CREATE PROCEDURE prcIE_GetExportedMatSegmentElements
AS 
	SET NOCOUNT ON
	SELECT * INTO [#mtbl] FROM [mtbl]
	CREATE TABLE #mse (id INT, ElementId UNIQUEIDENTIFIER, MaterialSegmentId UNIQUEIDENTIFIER, Number INT)
	INSERT INTO #mse (id, ElementId, MaterialSegmentId, Number) 
	SELECT ROW_NUMBER() OVER(ORDER BY mse.MaterialSegmentId), mse.ElementId, mse.MaterialSegmentId, mse.Number from MaterialSegmentElements000 AS mse

	SELECT #mse.MaterialSegmentId, #mse.ElementId, #mse.Number FROM #mse
	INNER JOIN(
	select DISTINCT(mse1.id) from #mse as mse1
	inner join materialsegments000 as ms1 on ms1.Id = mse1.MaterialSegmentId
	inner join [#mtbl] as m1 on m1.guid = ms1.MaterialId
	left join (select m2.guid as guid, m2.Parent as Parent, me1.ElementId as ElementId, m3.[type] AS [type] 
			   from mt000 as m2 
			   inner join [#mtbl] as m3 on m3.GUID = m2.GUID
			   inner join MaterialElements000 as me1 on me1.MaterialId = m2.GUID) as m4
	on m4.Parent = m1.guid and m4.ElementId = mse1.ElementId
	where m1.[type] = 2 or (m1.[type] = 1 and m4.guid != 0x00 and m4.[type] = 1)) AS mse2
	ON mse2.id = #mse.id
#################################################################
CREATE PROCEDURE prcIE_GetExportedGroupSegmentElements
AS 
	SET NOCOUNT ON
	SELECT * INTO [#mtbl] FROM [mtbl]
	SELECT * INTO [#gtbl] FROM [gtbl]
	CREATE TABLE #gse (id INT, ElementId UNIQUEIDENTIFIER, GroupSegmentId UNIQUEIDENTIFIER, Number INT)
	INSERT INTO #gse (id, ElementId, GroupSegmentId, Number) 
	SELECT ROW_NUMBER() OVER(ORDER BY gse.GroupSegmentId), gse.ElementId, gse.GroupSegmentId, gse.Number from GroupSegmentElements000 AS gse

	SELECT #gse.GroupSegmentId, #gse.ElementId, #gse.Number FROM #gse
	INNER JOIN(
	SELECT DISTINCT(gse1.id)
	FROM #gse AS gse1
	INNER JOIN GroupSegments000 AS gs1 ON gs1.Id = gse1.GroupSegmentId
	INNER JOIN gtbl AS g1 ON g1.guid = gs1.GroupId
	LEFT JOIN (SELECT m1.guid AS guid, m2.GroupGUID AS GroupGUID, se1.SegmentId AS SegmentId, m1.[type] AS [type]
			   FROM mtbl AS m1 
			   INNER JOIN mt000 AS m2 ON m2.GUID = m1.guid
			   INNER JOIN MaterialElements000 AS me1 ON me1.MaterialId = m1.guid
			   INNER JOIN SegmentElements000 AS se1 ON se1.Id = me1.ElementId) AS cm
			   ON cm.GroupGUID = g1.guid AND cm.SegmentId = gs1.SegmentId
	WHERE g1.[type] = 2 OR (g1.[type] = 1 AND cm.guid != 0x00 AND cm.[type] = 1)) AS gse2
	ON gse2.id = #gse.id
#################################################################
CREATE PROCEDURE prcIE_GetExportedSegmentElements
AS 
	SET NOCOUNT ON
	CREATE TABLE #impMatSegmentElements (MaterialSegmentId UNIQUEIDENTIFIER, ElementId UNIQUEIDENTIFIER, Number INT)
	CREATE TABLE #impGroupSegmentElements (GroupSegmentId UNIQUEIDENTIFIER, ElementId UNIQUEIDENTIFIER, Number INT)

	INSERT INTO #impMatSegmentElements EXEC prcIE_GetExportedMatSegmentElements
	INSERT INTO #impGroupSegmentElements EXEC prcIE_GetExportedGroupSegmentElements

	SELECT se.Code, se.Id, se.LatinName, se.Name, se.Number, se.SegmentId 
	FROM SegmentElements000 AS se
	INNER JOIN (SELECT ElementId FROM #impMatSegmentElements
				UNION
				SELECT ElementId FROM #impGroupSegmentElements) AS usedElements
	ON usedElements.ElementId = se.Id
#################################################################
CREATE PROCEDURE prcIE_GetExportedMatElements
AS 
	SET NOCOUNT ON
	SELECT * INTO [#mtbl] FROM [mtbl]
	SELECT ME.Id, ME.MaterialId, ME.ElementId, ME.[Order]
	FROM MaterialElements000 AS ME 
	INNER JOIN [#mtbl] AS mt2 ON mt2.Guid = me.MaterialId
#################################################################
CREATE PROCEDURE prcIE_GetExportedMatSegments
AS 
	SET NOCOUNT ON
	SELECT * INTO [#mtbl] FROM [mtbl]
	Select ms.Id, ms.MaterialId, ms.SegmentId , ms.Number
	FROM MaterialSegments000 AS ms
	INNER JOIN [#mtbl] AS mt2 ON mt2.GUID = ms.MaterialId
#################################################################
CREATE PROCEDURE prcIE_GetExportedGroupSegments
AS 
	SET NOCOUNT ON
	SELECT * INTO [#mtbl] FROM [mtbl]
	SELECT * INTO [#gtbl] FROM [gtbl]

	Select gs2.Id, gs2.GroupId, gs2.SegmentId, gs2.Number
	FROM GroupSegments000 AS gs2
	INNER JOIN(
	SELECT DISTINCT gs.Id AS Id
	FROM GroupSegments000 as gs 
	INNER JOIN [#gtbl] AS gt2 ON gt2.GUID = gs.GroupId
	LEFT JOIN (SELECT mt.GUID AS GUID, mt.GroupGUID AS GroupGUID, #mtbl.[type] AS [type], se.SegmentId AS GSegmentId
			   FROM #mtbl
			   INNER JOIN mt000 AS mt ON (mt.GUID = #mtbl.guid AND #mtbl.[type] = 1 AND mt.Parent != 0x00)
			   INNER JOIN MaterialElements000 AS me ON me.MaterialId = mt.GUID
			   INNER JOIN SegmentElements000 AS se ON se.Id = me.ElementId) AS ComponentMats 
	ON (ComponentMats.GroupGUID = gt2.GUID AND ComponentMats.GSegmentId = gs.SegmentId)
	WHERE gt2.[type] = 2 OR (gt2.[type] = 1 AND ComponentMats.[type] = 1 AND ComponentMats.GUID != 0x00)) AS gs3 ON gs3.Id = gs2.Id
#################################################################
#END