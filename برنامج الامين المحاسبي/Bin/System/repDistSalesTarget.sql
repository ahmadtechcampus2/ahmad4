##############################################
CREATE PROC repDistSalesTarget
	@EndDate 		DATETIME,
	@GroupGuid 		UNIQUEIDENTIFIER = 0x00,
	@UseUnit 		INT,
	@PeriodGuid 	UNIQUEIDENTIFIER,
	@DistGuid		UNIQUEIDENTIFIER = 0x00,
	@HiGuid			UNIQUEIDENTIFIER = 0x00,
	@GroupByCost	BIT = 1,	-- 0 Total Result For All Costs		-- 1 Group Result By Cost
	@BonusAsSales	BIT = 0,	-- 0 Bonus Isnt Sales	-- 1 Bonus Is Sales
	@ShowMats		BIT = 1,	
	@ShowGroups		BIT = 0,
	@ShowDistHi		BIT = 0
AS 
	SET NOCOUNT ON
	DECLARE @PeriodStartDate	[DATETIME], 
			@PeriodEndDate		[DATETIME], 
			@PeriodDaysNum		[FLOAT],		
			@RepDaysNum			[FLOAT]
	
 
	SELECT @PeriodStartDate = [StartDate], @PeriodEndDate = [EndDate]  FROM [vwperiods] WHERE [Guid] = @PeriodGuid
	-- Total Days Of Report
	SET @RepDaysNum = DATEDIFF(d, @PeriodStartDate, @EndDate) + 1 - (SELECT COUNT(*) FROM [DistCalendar000] WHERE ([date] BETWEEN @PeriodStartDate AND @EndDate) AND ([State] = 1))
	-- Total Days Of Period
	SET @PeriodDaysNum = DATEDIFF(d, @PeriodStartDate, @PeriodEndDate) + 1  - (SELECT COUNT(*) FROM [DistCalendar000] WHERE ([date] BETWEEN @PeriodStartDate AND @PeriodEndDate) AND ([State] = 1))
	-----------------------------------------------------------------------------------
	CREATE TABLE [#SecViol]		( [Type]	[INT], [Cnt] [INTEGER] ) 
	-----------------------------------------------------------------------------------
	-- Dists Informations
	CREATE TABLE [#Dists]( [DistGuid] 	[UNIQUEIDENTIFIER], [Security] 	 [INT], [HIGuid] [UNIQUEIDENTIFIER], [SalesManGuid] [UNIQUEIDENTIFIER], [CostSalesManGuid] [UNIQUEIDENTIFIER], [SalesManSecrity] [INT])
	-- For Bills With CostGuid = 0x00
	INSERT INTO [#Dists] ( [DistGuid], [Security], [HIGuid], [SalesManGuid], [CostSalesManGuid], [SalesManSecrity] )
		VALUES (0x00, 1, 0x00, 0x00, 0x00, 0x00) 
	INSERT INTO [#Dists] ( [DistGuid], [Security]) EXEC [GetDistributionsList] @DistGuid, @HiGuid 
	UPDATE [d] SET	[HiGuid] = [HierarchyGUID], 
					[SalesManGuid] = CASE [CurrSaleMan] WHEN 1 THEN [PrimSalesmanGUID] ELSE [AssisSalesmanGUID] END,
					[CostSalesManGuid] = [sm].[CostGUID],
					[SalesManSecrity] = [sm].[Security]  
	FROM 
		[#Dists] AS [d] 
		INNER JOIN [Distributor000]	 AS [ds] ON [d].[DistGuid] = [ds].[GUID]
		INNER JOIN [DistSalesman000] AS [sm] ON [sm].[Guid] = CASE [CurrSaleMan] WHEN 1 THEN [PrimSalesmanGUID] ELSE [AssisSalesmanGUID] END
	---- Dists HierarchyList
	CREATE TABLE [#DistsList]( [Guid] [UNIQUEIDENTIFIER], [Type] [INT], [Level] [INT], [Path] [NVARCHAR](1000) COLLATE ARABIC_CI_AI)
	INSERT INTO #DistsList ([Guid], [Type], [Level], [Path]) VALUES (0x00, 0, 0, '1.00')
	INSERT INTO #DistsList ([Guid], [Type], [Level], [Path]) SELECT [Guid], [Type], [Level], [Path] FROM dbo.fnDistGetHierarchyList(0, 1) 
	-----------------------------------------------------------------------------------
	-- Mats For This Report
	CREATE TABLE [#Mat]	( [MatGUID] [UNIQUEIDENTIFIER], [mtSecurity] [INT] ) 
	INSERT INTO  [#Mat]	EXEC [prcGetMatsList] 0X00, @GroupGUID 

	-----------------------------------------------------------------------------------
	-- TABLE MatTargets  : Field /	Type = 1 Total Targets And Sales 
	--								Type = 2 Targets And Sales For Each Distributor
	CREATE TABLE #MatTargets( 
		[MatGuid] 	[UNIQUEIDENTIFIER], 
		[DistGuid] 	[UNIQUEIDENTIFIER], 
		[Target]	[Float], 
		[Sales]		[Float], 
		[Bonus]		[Float], 
		[CustsCnt]	[Float], 
		[BillsCnt]	[FLOAT], 
		[Type]		[Integer]
	)  
	-- Calc Total Target And Total Sales For Each Mat 
	IF @GroupByCost = 0
	BEGIN
		INSERT INTO #MatTargets(
			[MatGuid], [DistGuid], [Target], [Sales], [Bonus], [CustsCnt], [billsCnt], [Type])
		SELECT
			[mt].[MatGuid], [d].[DistGuid], 0, 0, 0, 0, 0, 1
		FROM 
			#Mat AS mt CROSS JOIN #Dists AS d
		WHERE [d].[DistGuid] = 0x00

		UPDATE #MatTargets 
		SET 
			[Target]	= [s].[TotalTarget], 
			[Sales]		= [s].[TotalSales],
			[Bonus]		= [s].[TotalBonus],
			[CustsCnt]	= [s].[TotalCustsCnt], 
			[billsCnt]	= [s].[TotalbillsCnt]
		FROM 
			#MatTargets AS mt
			INNER JOIN (SELECT	[mt].[MatGuid], ISNULL([tr].[Qty], 0) AS TotalTarget,
								ISNULL(SUM([biQty] * -[btDirection]), 0) AS TotalSales, 
								ISNULL(SUM([biBonusQnt] * -[btDirection]), 0) AS TotalBonus, 
								COUNT( DISTINCT CAST([bi].[buCustPtr] AS NVARCHAR(36))) AS TotalCustsCnt, 
								COUNT( DISTINCT CAST([bi].[buGuid] AS NVARCHAR(36))) AS TotalbillsCnt
						FROM #MatTargets AS mt
							 LEFT JOIN vwDisGeneralTarget AS tr ON [tr].[MatGuid] = [mt].[MatGuid] AND [tr].[PeriodGuid] = @PeriodGuid
							 LEFT JOIN vwbubi AS bi ON bi.biMatPtr = [mt].[MatGuid] AND [bi].[buDate] BETWEEN @PeriodStartDate AND @EndDate AND ([btBillType] = 1 OR [btBillType] = 3)
						WHERE [mt].[Type] = 1
						GROUP BY [mt].[MatGuid], [tr].[Qty]
					   ) AS S ON [s].[MatGuid] = [mt].[MatGuid]
		WHERE [Type] = 1
	END
	-- Calc Target For Each Mat Group By Distributor
	IF @GroupByCost = 1
	BEGIN
		INSERT INTO #MatTargets(
			[MatGuid], [DistGuid], [Target], [Sales], [Bonus], [CustsCnt], [billsCnt], [Type])
		SELECT
			[mt].[MatGuid], [d].[DistGuid], 0, 0, 0, 0, 0, 2
		FROM 
			#Mat AS mt CROSS JOIN #Dists AS d

		UPDATE #MatTargets 
		SET [Target] = [s].[TotalTarget] 
		FROM 
			#MatTargets AS mt
			INNER JOIN (SELECT 	[mt].[MatGuid], [mt].[DistGuid], SUM([ctr].[ExpectedCustTarget]) AS TotalTarget
						FROM #MatTargets AS mt
							 INNER JOIN DistDistributionLines000 AS dL On [dl].[DistGuid] = [mt].[DistGuid]
							 INNER JOIN vwDistCustMatTarget AS ctr ON [ctr].[MatGuid] = [mt].[MatGuid] AND [dl].[CustGuid] = [ctr].[CustGuid] AND [ctr].[PeriodGuid] = @PeriodGuid
						WHERE [mt].[Type] = 2
						GROUP BY [mt].[MatGuid], [mt].[DistGuid]
					   ) AS S ON [s].[MatGuid] = [mt].[MatGuid] AND [s].[DistGuid] = [mt].[DistGuid]
		WHERE [Type] = 2
		-- Calc Sales For Each Mat Group By Distributor
		CREATE TABLE #MatDistSales ( [MatGUID] 	[UNIQUEIDENTIFIER], [DistGUID] 	[UNIQUEIDENTIFIER], [Sales] [Float], [Bonus] [Float], [CustsCnt] [Float], [BillsCnt] [FLOAT])
		INSERT INTO #MatDistSales ([MatGUID], [DistGUID], [Sales], [Bonus], [CustsCnt], [BillsCnt])
			  SELECT
					[mt].[MatGuid], [mt].[DistGuid],
					SUM( [biQty] * -[btDirection])			AS Sales, 
					SUM( [biBonusQnt] * -[btDirection])		AS Bonus, 
					COUNT( DISTINCT CAST([bi].[buCustPtr] AS NVARCHAR(36)))	AS CustsCnt,
					COUNT( DISTINCT CAST([bi].[buGuid] AS NVARCHAR(36)))		AS billsCnt
			  FROM 	
				vwbubi AS bi
				INNER JOIN #Dists AS d ON [bi].[buCostPtr] = [d].[CostSalesManGuid] 
				INNER JOIN #MatTargets AS mt ON [bi].[biMatPtr] = [mt].[MatGuid] AND [mt].[DistGuid] = [d].[DistGuid]
			  WHERE [bi].[buDate] BETWEEN @PeriodStartDate AND @EndDate AND [mt].[Type] = 2
					AND ([btBillType] = 1 OR [btBillType] = 3)
			  GROUP BY [mt].[MatGuid], [mt].[DistGuid]
		UPDATE #MatTargets SET 
			[Sales] = [ms].[Sales], [Bonus] = [ms].[Bonus], [CustsCnt] = [ms].[CustsCnt], [billsCnt] = [ms].[billsCnt]
		FROM 
			#MatTargets AS mt
			INNER JOIN #MatDistSales AS ms ON [ms].[MatGuid] = [mt].[MatGuid] AND [ms].[DistGuid] = [mt].[DistGuid]
		WHERE [mt].[Type] = 2

		DROP TABLE #MatDistSales
	END
	-----------------------------------------------------------------------------------
	---------
	CREATE TABLE [#Result](
			[DistGuid]		[UNIQUEIDENTIFIER],
			[ParentGuid]	[UNIQUEIDENTIFIER],
			[Guid]			[UNIQUEIDENTIFIER],
			[Code]			[NVARCHAR](256) COLLATE ARABIC_CI_AI, 
			[Name]			[NVARCHAR](256) COLLATE ARABIC_CI_AI, 
			[LatinName]		[NVARCHAR](256) COLLATE ARABIC_CI_AI, 
			[Security]		[INT],
			[mtUnit]		[NVARCHAR](100) COLLATE ARABIC_CI_AI,
			[Target]		[FLOAT],
			[Sales]			[FLOAT],
			[Bonus]			[Float], 
			[CustsCnt]		[Float], 
			[BillsCnt]		[FLOAT], 
			[TargetPercent]	[FLOAT],
			[SalesExpected]	[FLOAT],
			[Path]			[NVARCHAR](2000) COLLATE ARABIC_CI_AI,
			[Level]			[INT],
			[Flag]			[INT]	-- 1 DistHi	-- 2 Dists	-- 3 Groups	-- 4 Mats
		)
	-----------------------------------------------------------------------------------
	------- Insert Mats Result	Flag = 4
	INSERT INTO  [#Result](
			[DistGuid],
			[ParentGuid],
			[Guid]		,
			[Code]		, 
			[Name]		, 
			[LatinName]	, 
			[Security]	,
			[mtUnit]	,
			[Target]	,
			[Sales]		,
			[Bonus]		, 
			[CustsCnt]	, 
			[BillsCnt]	, 
			[TargetPercent],
			[SalesExpected],
			[Path]			,
			[Level]			,
			[Flag]				-- 4 Mats
	)
	SELECT
		[mtg].[DistGuid],
		[mt].[mtGroup],
		[mt].[mtGuid],
		[mt].[mtCode],
		[mt].[mtName],
		[mt].[mtLatinName],
		[mt].[mtSecurity],
		mtUnit = (	CASE @UseUnit
						WHEN 1 THEN (CASE [mt].[mtUnit2Fact] WHEN 0 THEN [mt].[mtUnity] ELSE [mt].[mtUnit2] END) 
						WHEN 2 THEN (CASE [mt].[mtUnit3Fact] WHEN 0 THEN [mt].[mtUnity] ELSE [mt].[mtUnit3] END) 
						WHEN 3 THEN [mt].[mtDefUnitName] 
						ELSE [mt].[mtUnity] 
					END ),
		Target = [mtg].[Target] / 
				(	CASE @UseUnit	
						WHEN 1 THEN (CASE [mt].[mtUnit2Fact] WHEN 0 THEN 1 ELSE [mt].[mtUnit2Fact] END) 
						WHEN 2 THEN (CASE [mt].[mtUnit3Fact] WHEN 0 THEN 1 ELSE [mt].[mtUnit3Fact] END) 
						WHEN 3 THEN [mt].[mtDefUnitFact]
						ELSE 1 
					END ), 
		Sales = [mtg].[Sales] / 
				(	CASE @UseUnit	
						WHEN 1 THEN (CASE [mt].[mtUnit2Fact] WHEN 0 THEN 1 ELSE [mt].[mtUnit2Fact] END) 
						WHEN 2 THEN (CASE [mt].[mtUnit3Fact] WHEN 0 THEN 1 ELSE [mt].[mtUnit3Fact] END) 
						WHEN 3 THEN [mt].[mtDefUnitFact]
						ELSE 1 
					END ), 
		Bonus = [mtg].[Bonus] / 
				(	CASE @UseUnit	
						WHEN 1 THEN (CASE [mt].[mtUnit2Fact] WHEN 0 THEN 1 ELSE [mt].[mtUnit2Fact] END) 
						WHEN 2 THEN (CASE [mt].[mtUnit3Fact] WHEN 0 THEN 1 ELSE [mt].[mtUnit3Fact] END) 
						WHEN 3 THEN [mt].[mtDefUnitFact]
						ELSE 1 
					END ), 
		[mtg].[CustsCnt],
		[mtg].[BillsCnt],
		TargetPercent = ( CASE [mtg].[Target] WHEN 0 THEN 0 ELSE( ([mtg].[Sales] + [mtg].[Bonus] * @BonusAsSales) / [mtg].[Target] ) * 100 END ),
		SalesExpected = ([mtg].[Target] * @RepDaysNum) / @PeriodDaysNum,
		ISNULL([dl].[Path], '') + [fn].[Path] + '0.1',	-- Path 
		0,	-- Level
		4	-- Mats
			
	FROM 
		#MatTargets AS mtg
		INNER JOIN vwMt AS mt ON [mt].[mtGuid] = [mtg].[MatGuid]
		INNER JOIN [fnGetGroupsOfGroupSorted](0x00, 1) as fn on [fn].[Guid] = [mt].[mtGroup]
		INNER JOIN #DistsList AS dl ON [dl].[Guid] = [mtg].[DistGuid]
	-----------------------------------------------------------------------------------
	EXEC [prcCheckSecurity]
	-----------------------------------------------------------------------------------
	------- Insert Groups Result	Flag = 3
	--- Get Sales And Targets For Groups
	-- IF (@ShowGroups = 1)	-- Show Groups In Result
	BEGIN
		DECLARE @Level		INT
		SET @Level = 1
		WHILE (@Level <> 0)
		BEGIN
			INSERT INTO  [#Result](
					[DistGuid],
					[ParentGuid],
					[Guid],
					[Code], 
					[Name], 
					[LatinName], 
					[Security],
					[mtUnit],
					[Target],
					[Sales],
					[Bonus], 
					[CustsCnt], 
					[BillsCnt], 
					[TargetPercent],
					[SalesExpected],
					[Path],
					[Level],
					[Flag]				-- 3 Groups	
			)
			SELECT
				[R].[DistGuid],
				[gr].[grParent],
				[gr].[grGuid],
				[gr].[grCode],
				[gr].[grName],
				[gr].[grLatinName],
				[gr].[grSecurity],
				'', -- mtUnit
				SUM([R].[Target]),
				SUM([R].[Sales]),
				SUM([R].[Bonus]),
				0,	-- CustsCnt
				0,	-- BillsCnt
				TargetPercent = ( CASE SUM([Target]) WHEN 0 THEN 0 ELSE( (SUM([Sales]) + SUM([Bonus]) * @BonusAsSales) / SUM([Target]) ) * 100 END ),
				SalesExpected = (SUM([Target]) * @RepDaysNum) / @PeriodDaysNum,
				ISNULL([dl].[Path], '') + [fn].[Path],	-- Path
				@Level, --0,		-- Level			
				3	-- Flag    Groups			
			FROM 
				#Result AS R
				INNER JOIN vwGr AS Gr ON [R].[ParentGuid] = [gr].[grGuid]
				INNER JOIN [fnGetGroupsOfGroupSorted](0x00, 1) as fn on [fn].[Guid] = [gr].[grGuid] 
				INNER JOIN #DistsList AS dl ON [dl].[Guid] = [R].[DistGuid]
			WHERE 
				[R].[Level] = @Level - 1
			GROUP BY 
				[R].[DistGuid],	[gr].[grParent], [gr].[grGuid], [gr].[grCode], [gr].[grName], [gr].[grLatinName], [gr].[grSecurity], [fn].[Path], [dl].[Path]

			IF EXISTS (SELECT TOP 1 [ParentGuid] FROM #Result WHERE [Flag] = 3 AND [Level] = @Level AND [ParentGuid] <> 0x00)
				SET @Level = @Level + 1
			ELSE
				SET @Level = 0
		END	-- While @Level <> 0
		--- Get CustsCnt And BillsCnt For Each Groups
		DECLARE @C			CURSOR,
				@C_DistGuid	UNIQUEIDENTIFIER,
				@C_grGuid	UNIQUEIDENTIFIER,
				@coGuid		UNIQUEIDENTIFIER,
				@CustsCnt	INT,
				@BillsCnt	INT
		SET @C = CURSOR FAST_FORWARD FOR 
			SELECT [DistGuid], [Guid] FROM #Result WHERE [Flag] = 3 
		OPEN @C FETCH FROM @C INTO @C_DistGuid, @C_grGuid
		WHILE @@FETCH_STATUS = 0
		BEGIN
			SELECT @coGuid = [CostSalesManGuid] FROM #Dists WHERE [DistGuid] = @C_DistGuid
			SET @coGuid = ISNULL(@coGuid, 0x00)

			SELECT
				@CustsCnt = COUNT( DISTINCT CAST([bi].[buCustPtr] AS NVARCHAR(36))),
				@BillsCnt = COUNT( DISTINCT CAST([bi].[buGuid] AS NVARCHAR(36)))
			FROM
				dbo.fnGetGroupsOfGroup(@C_grGuid) AS gr
				INNER JOIN #Result AS R ON [R].[ParentGuid] = [gr].[GUID] AND [R].[DistGuid] = @C_DistGUID AND [R].[Flag] = 4 -- Mats
				INNER JOIN vwbubi AS bi ON [bi].[biMatPtr] = [R].[Guid] AND [bi].[buCostPtr] = @coGuid AND [bi].[buDate] BETWEEN @PeriodStartDate AND @EndDate AND ([btBillType] = 1 OR [btBillType] = 3)

			SET @CustsCnt = ISNULL(@CustsCnt, 0)				
			SET @BillsCnt = ISNULL(@BillsCnt, 0)				
			UPDATE #Result SET [CustsCnt] = @CustsCnt, [BillsCnt] = @BillsCnt WHERE [DistGuid] = @C_DistGuid AND [Guid] = @C_grGuid AND [Flag] = 3

			FETCH FROM @C INTO @C_DistGuid, @C_grGuid
		END
		CLOSE @C DEALLOCATE @C
	END -- If @ShowGroups = 1 
	-----------------------------------------------------------------------------------
	------- Insert Dists AND DistHi Result		Flag = 2 - Flag =  1
	IF @GroupByCost = 1
	BEGIN
	---- Insert Dists Result	Flag = 2
		INSERT INTO  [#Result](
				[DistGuid],
				[ParentGuid],
				[Guid],
				[Code], 
				[Name], 
				[LatinName], 
				[Security],
				[mtUnit],
				[Target],
				[Sales],
				[Bonus], 
				[CustsCnt], 
				[BillsCnt], 
				[TargetPercent],
				[SalesExpected],
				[Path],
				[Level],
				[Flag]				-- 3 Groups	
		)
		SELECT
			[R].[DistGuid],
			ISNULL([d].[HierarchyGuid], 0x00),
			ISNULL([d].[Guid], 0x00),
			ISNULL([d].[Code], '0'),
			ISNULL([d].[Name], '<»œÊ‰ „—ﬂ“ ﬂ·›…>'),
			ISNULL([d].[LatinName], '<No Cost>'),
			ISNULL([d].[Security], 0),
			'', -- mtUnit
			SUM([R].[Target]),
			SUM([R].[Sales]),
			SUM([R].[Bonus]),
			0,	-- CustsCnt
			0,	-- BillsCnt
			TargetPercent = ( CASE SUM([Target]) WHEN 0 THEN 0 ELSE( (SUM([Sales]) + SUM([Bonus]) * @BonusAsSales) / SUM([Target]) ) * 100 END ),
			SalesExpected = (SUM([Target]) * @RepDaysNum) / @PeriodDaysNum,
			[dl].[Path],		-- Path
			@Level, -- 0,	-- Level			
			2		-- Flag    Distributors			
		FROM 
			#Result AS R
			LEFT JOIN Distributor000 AS D ON [R].[DistGuid] = [D].[Guid]
			INNER JOIN #DistsList AS dl ON [dl].[Guid] = [R].[DistGuid]
		WHERE 
			[R].[Flag] = 3 AND [R].[ParentGUID] = 0x00 -- Groups Data 
		GROUP BY 
			[R].[DistGuid],	[d].[HierarchyGuid], [d].[Guid], [d].[Code], [d].[Name], [d].[LatinName], [d].[Security], [dl].[Path]

		--- Get CustsCnt And BillsCnt For Each Distributor
		SET @C = CURSOR FAST_FORWARD FOR 
			SELECT DISTINCT [DistGuid] FROM #Result WHERE [Flag] = 2 
		OPEN @C FETCH FROM @C INTO @C_DistGuid
		WHILE @@FETCH_STATUS = 0
		BEGIN
			SELECT @coGuid = [CostSalesManGuid] FROM #Dists WHERE [DistGuid] = @C_DistGuid
			SET @coGuid = ISNULL(@coGuid, 0x00)

			SELECT
				@CustsCnt = COUNT( DISTINCT CAST([bi].[buCustPtr] AS NVARCHAR(36))),
				@BillsCnt = COUNT( DISTINCT CAST([bi].[buGuid] AS NVARCHAR(36)))	   
			FROM
				#Result AS R
				INNER JOIN vwbubi AS bi ON [bi].[biMatPtr] = [R].[Guid] AND [bi].[buCostPtr] = @coGuid AND [bi].[buDate] BETWEEN @PeriodStartDate AND @EndDate AND ([btBillType] = 1 OR [btBillType] = 3)
			WHERE 
				[R].[DistGuid] = @C_DistGUID AND [R].[Flag] = 4 -- Mats

			SET @CustsCnt = ISNULL(@CustsCnt, 0)				
			SET @BillsCnt = ISNULL(@BillsCnt, 0)				
			UPDATE #Result SET [CustsCnt] = @CustsCnt, [BillsCnt] = @BillsCnt WHERE [DistGuid] = @C_DistGuid AND [Flag] = 2	
												
			FETCH FROM @C INTO @C_DistGuid
		END
		CLOSE @C DEALLOCATE @C
	
	---- Insert DistHi Result	Flag = 1
		IF @ShowDistHi = 1
		BEGIN
			SET @Level = 1
			WHILE (@Level <> 0)
			BEGIN
				INSERT INTO  [#Result](
						[DistGuid],
						[ParentGuid],
						[Guid],
						[Code], 
						[Name], 
						[LatinName], 
						[Security],
						[mtUnit],
						[Target],
						[Sales],
						[Bonus], 
						[CustsCnt], 
						[BillsCnt], 
						[TargetPercent],
						[SalesExpected],
						[Path],
						[Level],
						[Flag]				-- 3 Groups	
				)
				SELECT
					0x00, 
					[hi].[ParentGuid],
					[hi].[Guid],
					[hi].[Code],
					[hi].[Name],
					[hi].[LatinName],
					[hi].[Security],
					'', -- mtUnit
					SUM([R].[Target]),
					SUM([R].[Sales]),
					SUM([R].[Bonus]),
					0,	-- CustsCnt
					0,	-- BillsCnt
					TargetPercent = ( CASE SUM([Target]) WHEN 0 THEN 0 ELSE( (SUM([Sales]) + SUM([Bonus]) * @BonusAsSales) / SUM([Target]) ) * 100 END ),
					SalesExpected = (SUM([Target]) * @RepDaysNum) / @PeriodDaysNum,
					[dl].[Path],	-- Path
					@Level, --0,	-- Level			
					1	-- Flag    DistHi
				FROM 
					#Result AS R
					INNER JOIN DistHi000 AS Hi On [Hi].[Guid] = [R].[ParentGuid]
					INNER JOIN #DistsList AS dl ON [dl].[Guid] = [Hi].[Guid]
				WHERE 
					[R].[Level] = @Level - 1 AND ([R].[Flag] = 2 OR [R].[DistGuid] = 0x00)
				GROUP BY 
					[hi].[ParentGuid], [hi].[Guid], [hi].[Code], [hi].[Name], [hi].[LatinName], [hi].[Security], [dl].[Path]

				IF EXISTS (SELECT TOP 1 [ParentGuid] FROM #Result WHERE [Flag] = 1 AND [Level] = @Level AND [ParentGuid] <> 0x00)
					SET @Level = @Level + 1
				ELSE
					SET @Level = 0
			END	-- While @Level <> 0

			--- Get CustsCnt And BillsCnt For Each DistHi
			DECLARE @C_HiGuid UNIQUEIDENTIFIER
			SET @C = CURSOR FAST_FORWARD FOR 
				SELECT DISTINCT [Guid] FROM #Result WHERE [Flag] = 1
			OPEN @C FETCH FROM @C INTO @C_HiGuid
			WHILE @@FETCH_STATUS = 0
			BEGIN
				SELECT
					@CustsCnt = COUNT( DISTINCT CAST([bi].[buCustPtr] AS NVARCHAR(36))),
					@BillsCnt = COUNT( DISTINCT CAST([bi].[buGuid] AS NVARCHAR(36)))
				FROM
					dbo.fnGetHierarchiesList(@C_HiGuid, 0) AS Fn 
					INNER JOIN #Result AS R ON [R].[ParentGuid] = [Fn].[GUID] AND [R].[Flag] = 2 -- Dists
					INNER JOIN #Dists AS D ON [D].[DistGuid] = [R].[DistGuid]
					INNER JOIN vwbubi AS bi ON [bi].[buCostPtr] = [d].[CostSalesManGuid] AND [bi].[buDate] BETWEEN @PeriodStartDate AND @EndDate AND ([btBillType] = 1 OR [btBillType] = 3)

				SET @CustsCnt = ISNULL(@CustsCnt, 0)				
				SET @BillsCnt = ISNULL(@BillsCnt, 0)				
				UPDATE #Result SET [CustsCnt] = @CustsCnt, [BillsCnt] = @BillsCnt WHERE [Guid] = @C_HiGuid AND [Flag] = 1

				FETCH FROM @C INTO @C_HiGuid
			END
			CLOSE @C DEALLOCATE @C
		END -- IF ShowHi = 1 
	END	--	IF @GroupByCost = 1
	-----------------------------------------------------------------------------------
	-------- Get Results
	SELECT
		[Guid],
		[Code],
		[Name],
		[LatinName],
		[mtUnit],
		[Target],
		[Sales],
		[Bonus],
		[CustsCnt],
		[BillsCnt],
		[TargetPercent],
		[SalesExpected],
		[Flag]
	FROM 
		#Result
	WHERE
		([Target] <> 0 OR [Sales] <> 0) AND
		(	([Flag] = 2						/*Show Dists*/	)	OR
			([Flag] = 1 AND @ShowDistHi = 1	/*Show DistHi*/	)	OR
			([Flag] = 3 AND @ShowGroups = 1	/*Show Groups*/	)	OR
			([Flag] = 4 AND @ShowMats = 1	/*Show Mats*/	)
		)
	ORDER BY [Path], [Code]

	SELECT @RepDaysNum AS RepDaysNum, @PeriodDaysNum AS PeriodDaysNum, @RepDaysNum / @PeriodDaysNum * 100 AS TargetExpectedPercent

	SELECT * FROM #SecViol
	-----------------------------------------------------------------------------------

	DROP TABLE #SecViol
	DROP TABLE #Dists
	DROP TABLE #DistsList
	DROP TABLE #Mat
	DROP TABLE #MatTargets
	DROP TABLE #Result

/*
EXEC prcConnections_Add2 '„œÌ—'
EXEC [repDistSalesTarget] '12/25/2007  0:0:0:0', 0x00, 0, '41e483df-c437-4f07-9194-58d58cca2fd9', 0x00, 0x00, 1, 1, 1, 1, 1
*/
################################################################################
#END

