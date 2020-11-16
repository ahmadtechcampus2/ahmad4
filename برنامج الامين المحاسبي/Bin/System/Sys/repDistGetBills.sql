########################################
## repDistGetBills
CREATE PROCEDURE repDistGetBills
	@EndDate 	DATETIME,
	@GroupGuid 	UNIQUEIDENTIFIER = 0x00,
	@bUnitType 	INT = 0,
	@UseUnit 	INT,
	@PeriodGuid 	UNIQUEIDENTIFIER,
	@DistGuid	UNIQUEIDENTIFIER = 0x00,
	@HiGuid		UNIQUEIDENTIFIER = 0x00,
	@ByCost		INT = 1
AS 
	SET NOCOUNT ON

	DECLARE @StartDate		[DATETIME]
	DECLARE @DistDaysNum		[INT] 
	DECLARE @RealDaysNum		[INT] 
	DECLARE @EDate			[DATETIME] 
	DECLARE @ExpectFact		[FLOAT]
	DECLARE @MaxLevel 		[INT]
 
	SELECT @StartDate = [StartDate] FROM [vwperiods] WHERE [Guid] = @PeriodGuid
	SELECT @EDate = EndDate FROM [vwperiods] WHERE [guid] = @PeriodGuid

	SET @DistDaysNum = DATEDIFF(d, @StartDate, @EndDate) + 1 - (SELECT COUNT(*) FROM DISTCalendar000 WHERE ([date] BETWEEN @StartDate AND @EndDate) AND (STATE = 1))
	SET @RealDaysNum = DATEDIFF(d, @StartDate, @EDate) + 1  - (SELECT COUNT(*) FROM DISTCalendar000 WHERE ([date] BETWEEN @StartDate AND @EDate) AND (STATE = 1))
	IF @DistDaysNum <> 0
		SET @ExpectFact = CAST(@RealDaysNum AS [FLOAT])/ @DistDaysNum
	ELSE
		SET @ExpectFact = CAST(@RealDaysNum AS [FLOAT])
	 
	CREATE TABLE [#BillsTypesTbl]	( [TypeGuid] 	[UNIQUEIDENTIFIER], [btSecurity] [INTEGER], [UserReadPriceSecurity] [INTEGER], [UnPostedSecurity] [INTEGER])
	CREATE TABLE [#SecViol]		( [Type]	[INT], [Cnt] [INTEGER] ) 
	CREATE TABLE [#MatTbl]		( [MatGUID] 	[UNIQUEIDENTIFIER], [mtSecurity] [INT] ) 
	CREATE TABLE [#Cust] 		( [Number] 	[UNIQUEIDENTIFIER], [Security] 	 [INT] ) 
	CREATE TABLE [#DistTble]	( [DistGuid] 	[UNIQUEIDENTIFIER], [Security] 	 [INT], [HIGuid] [UNIQUEIDENTIFIER], [SalesManGuid] [UNIQUEIDENTIFIER], [CostSalesManGuid] [UNIQUEIDENTIFIER], [SalesManSecrity] [INT])
	CREATE TABLE [#mt2]
	(
		[mtGuid]		[UNIQUEIDENTIFIER],
		[mtCode]		[NVARCHAR](256) COLLATE ARABIC_CI_AI, 
		[mtName]		[NVARCHAR](256) COLLATE ARABIC_CI_AI, 
		[mtLatinName]		[NVARCHAR](256) COLLATE ARABIC_CI_AI, 
		[mtSecurity]		[INT],
		[mtUnitFact]		[FLOAT] DEFAULT 1,
		[mtUnitName]		[NVARCHAR](256) COLLATE ARABIC_CI_AI,
		[GroupGuid]		[UNIQUEIDENTIFIER]
	
	)
	CREATE TABLE [#Result]
		(
			[mtGuid]		[UNIQUEIDENTIFIER],
			[mtCode]		[NVARCHAR](256) COLLATE ARABIC_CI_AI, 
			[mtName]		[NVARCHAR](256) COLLATE ARABIC_CI_AI, 
			[mtLatinName]		[NVARCHAR](256) COLLATE ARABIC_CI_AI, 
			[mtSecurity]		[INT],
			[mtUnitName]		[NVARCHAR](256) COLLATE ARABIC_CI_AI,
			[btSecurity]		[INT],
			[Qty]			[FLOAT],
			[mtTargetQty]		[FLOAT],
			[Security]		[INT],
			[GroupGuid]		[UNIQUEIDENTIFIER],
			[ExpSaleQty]		[FLOAT],
			[Level]			[INT],
			[Flag]			[INT],
			[DistPtr]		[UNIQUEIDENTIFIER],
			[hiGuid]		[UNIQUEIDENTIFIER],
			[HiLevel]		[INT] DEFAULT 0

		)
	
	IF (ISNULL(@DistGuid,0X00) <> 0X00) OR (ISNULL(@HiGuid,0X00) <> 0X00)
	BEGIN
		INSERT INTO [#DistTble] ([DistGuid], [Security]) EXEC [GetDistributionsList] @DistGuid, @HiGuid 
		UPDATE [d] SET [HIGuid] = [HierarchyGUID], [SalesManGuid] = CASE [CurrSaleMan] WHEN 1 THEN [PrimSalesmanGUID] ELSE [AssisSalesmanGUID] END 
		FROM [#DistTble] AS [d] INNER JOIN [Distributor000] AS [d2] ON [d].[DistGuid] = [d2].[GUID]
		UPDATE [d] SET  [CostSalesManGuid] = [d2].[CostGUID] ,[SalesManSecrity] = [d2].[Security] 
		FROM [#DistTble] AS [d] INNER JOIN [DistSalesman000] AS [d2] ON [d].[SalesManGuid] = [d2].[Guid]
		INSERT INTO [#Cust] EXEC [prcGetCustsList] 0X0,0X0
		SELECT DISTINCT CASE @ByCost WHEN 1 THEN 0X00 ELSE [c].[Number] END AS [Number], 
				CASE @ByCost WHEN 1 THEN 0 ELSE [c].[Security] END AS [CustSecurity], 
				[d].[DistGuid], [d].[Security] AS [DistSecurity], [hiGuid], [CostSalesManGuid], [SalesManSecrity]
		INTO [#Cust2] 
		FROM  [#CUST]  AS c
		INNER JOIN [DistCe000] 			AS ce ON ce.CustomerGuid = c.Number
		INNER JOIN DistDistributionLines000 	AS Dl ON Dl.CustGuid = ce.CustomerGuid 
		INNER JOIN [#DistTble] 			AS d  ON d.DistGuid = Dl.DistGUID 

		EXEC [prcCheckSecurity] @Result = '#Cust2' 

		CREATE CLUSTERED INDEX [custiNE] ON [#Cust2] ( [Number], [DistGuid])
	END
	INSERT INTO [#BillsTypesTbl]	EXEC [prcGetBillsTypesList2] 	0X0--, @UserGuid 
	INSERT INTO [#MatTbl]			EXEC [prcGetMatsList] 0X00, @GroupGUID 

	INSERT INTO [#mt2]
		SELECT [mt].[MatGUID],[Code],[Name],[LatinName],[mtSecurity],
			(CASE @bUnitType 
			WHEN 0 THEN 
					(CASE @UseUnit	
						WHEN 1 THEN (CASE [Unit2Fact] WHEN 0 THEN 1 ELSE [Unit2Fact] END) 
						WHEN 2 THEN (CASE [Unit3Fact] WHEN 0 THEN 1 ELSE [Unit3Fact] END) 
						WHEN 3 THEN (CASE [DefUnit] WHEN  0 THEN 1 WHEN 1 THEN CASE [Unit2Fact] WHEN 0 THEN 1 ELSE [Unit2Fact] END ELSE CASE [Unit3Fact] WHEN 0 THEN 1 ELSE [Unit3Fact] END END) 
						ELSE 1 END )
			ELSE 
			
					(CASE @UseUnit	
					WHEN 0 THEN (CASE ISNULL([me].[SalesFactor1], 0) WHEN 0 THEN 0 ELSE 1/[me].[SalesFactor1] END) 
					ELSE (CASE ISNULL([me].[SalesFactor2], 0) WHEN 0 THEN 0 ELSE 1/[me].[SalesFactor2] END)END)
			END), 
			(CASE @bUnitType 
			WHEN 0 THEN 
					(CASE @UseUnit	
						WHEN 1 THEN (CASE [Unit2Fact] WHEN 0 THEN [Unity] ELSE [Unit2] END) 
						WHEN 2 THEN (CASE [Unit3Fact] WHEN 0 THEN [Unity] ELSE [Unit3] END) 
						WHEN 3 THEN (CASE [DefUnit] WHEN  0 THEN [Unity] WHEN 1 THEN CASE [Unit2Fact] WHEN 0 THEN [Unity] ELSE [Unit2] END ELSE CASE [Unit3Fact] WHEN 0 THEN [Unity] ELSE [Unit3] END END) 
						ELSE [Unity] END )
			ELSE 
				''
			END),
			[mt2].[GroupGuid]
		FROM [#MatTbl] AS [mt] INNER JOIN [mt000] AS [mt2] ON [mt].[MatGUID] = [mt2].[Guid]
			LEFT JOIN [Distme000] AS [me] ON [me].[MtGUID] = [mt2].[Guid]
	IF (ISNULL(@DistGuid,0X00) <> 0X00) OR (ISNULL(@HiGuid,0X00) <> 0X00)
	BEGIN
		INSERT INTO [#Result]
			SELECT [mtGuid], [mtCode], mt.[mtName], [mtLatinName], [mtSecurity], [mtUnitName],
				CASE [buIsPosted] WHEN 1 THEN  [btSecurity] ELSE [UnPostedSecurity] END,
				SUM( ([biQty] + [biBonusQnt])/[mtUnitFact] * -[btDirection]),
				ISNULL([ta].[CustTarget],0)/[mtUnitFact]
				,[Security]
				,[GroupGuid]
				,0
				,0
				,3
				,c.[DistGuid]
				,[hiGuid]
				,0
			FROM 	[vwBuBi] AS [bi] 
				INNER JOIN [#mt2] 		 AS [mt] ON [bi].[biMatPtr] = [mt].[mtGuid]
				INNER JOIN [#Cust2] 		 AS [c]  ON (@ByCost = 0 AND [c].[Number] = [bi].[buCustPtr]) OR (@ByCost = 1 AND [c].[CostSalesManGuid] = [bi].[biCostPtr])
				LEFT JOIN [vwDistCustMatTarget] AS [ta] ON [ta].[MatGuid] = [mt].[mtGuid] AND [ta].[CustGuid] =  [bi].[buCustPtr]
				INNER JOIN  [#BillsTypesTbl] 	 AS [bt] ON [bt].[TypeGuid] = [bi].[buType]
			WHERE 
				([buDate] BETWEEN  @StartDate AND @EndDate)
				AND ([btBillType] = 1 OR [btBillType] = 3)
				AND (ISNULL([ta].[PeriodGuid], @PeriodGuid) = @PeriodGuid)
			GROUP BY
				[mtGuid], [mtCode], mt.[mtName], [mtLatinName], [mtSecurity], [mtUnitName],
				[btSecurity], [Security], [GroupGuid], [ta].[CustTarget], [mtUnitFact],
				c.[DistGuid], [hiGuid], [buIsPosted], [UnPostedSecurity]

	END
	ELSE
	BEGIN
		SELECT [MatGuid], SUM([Qty]) AS [Qty] INTO [#Target] FROM [vwDisGeneralTarget]  WHERE [PeriodGuid] = @PeriodGuid GROUP BY [MatGuid]
		INSERT INTO [#Result]
			SELECT [mtGuid], [mtCode], [mtName], [mtLatinName], [mtSecurity], [mtUnitName],
				CASE [buIsPosted] WHEN 1 THEN  [btSecurity] ELSE [UnPostedSecurity] END,
				SUM(([biQty] + [biBonusQnt] )/[mtUnitFact] * -[btDirection]),
				ISNULL([ta].[Qty],0)/[mtUnitFact]
				,[buSecurity]
				,[GroupGuid]
				,0
				,0
				,3
				,0X00
				,0X00
				,0
			
				
			FROM [vwBuBi] AS [bi] INNER JOIN [#mt2] AS [mt] ON [bi].[biMatPtr] = [mt].[mtGuid]
				INNER JOIN   [#Target] AS [ta] ON [ta].[MatGuid] = [mt].[mtGuid]
				INNER JOIN  [#BillsTypesTbl] AS [bt] ON [bt].[TypeGuid] = [bi].[buType]
			WHERE 
				([buDate] BETWEEN  @StartDate AND @EndDate)
				AND ([btBillType] = 1 OR [btBillType] = 3)
			GROUP BY
				[mtGuid], [mtCode], [mtName], [mtLatinName], [mtSecurity], [mtUnitName],
				[btSecurity], [buSecurity], [GroupGuid], [ta].[Qty], [mtUnitFact], [buIsPosted], [UnPostedSecurity]
	END 
	UPDATE [#Result] SET [ExpSaleQty] = [Qty] * @ExpectFact		
	EXEC [prcCheckSecurity]
	IF ISNULL(@HiGuid,0X00)  <> 0X00
	BEGIN
		SELECT [f].[Guid], [f].[Level], [ParentGuid] INTO [#Hi] FROM fnGetHierarchyList(@HiGuid,0)AS [f] INNER JOIN [DistHi000] AS [hi] ON [f].[Guid] = [hi].[guid]
		SELECT @MaxLevel = MAX([Level]) FROM [#Hi]
		IF (@MaxLevel > 0)
		BEGIN
			CREATE CLUSTERED INDEX [hiInd] ON [#Hi]([Guid])
			INSERT INTO #RESULT ([mtGuid], [mtCode], [mtName], [mtLatinName], [mtUnitName], [Qty], [mtTargetQty], [GroupGuid], [ExpSaleQty], [Flag], [DistPtr], [HiGuid], [HiLevel], [Level])
				SELECT [mtGuid],[mtCode],[mtName],[mtLatinName],[mtUnitName],SUM([Qty]),SUM([mtTargetQty]),[GroupGuid],SUM([ExpSaleQty]),[Flag],[Hi].[Guid],[ParentGuid],[Hi].[Level],[r].[Level]
				FROM [#RESULT] AS [r] INNER JOIN [#HI] AS [hi] ON [r].[HiGuid] = [Hi].[Guid]
				GROUP BY [mtGuid],[mtCode],[mtName],[mtLatinName],[mtUnitName],[GroupGuid],[Flag],[Hi].[Guid],[ParentGuid],[Hi].[Level],[r].[Level]
			UPDATE [#RESULT] SET [HiLevel] = 1 WHERE [hiGuid] = @HiGuid AND  [HiLevel] = 0
			WHILE (@MaxLevel > 0)
			BEGIN
				INSERT INTO #RESULT ([mtGuid],[mtCode],[mtName],[mtLatinName],[mtUnitName],[Qty],[mtTargetQty],[GroupGuid],[ExpSaleQty],[Flag],[DistPtr],[HiGuid],[HiLevel],[Level])
				SELECT [mtGuid],[mtCode],[mtName],[mtLatinName],[mtUnitName],SUM([Qty]),SUM([mtTargetQty]),[GroupGuid],SUM([ExpSaleQty]),[Flag],[Hi].[Guid],[ParentGuid],[Hi].[Level],[r].[Level]
				FROM [#RESULT] AS [r] INNER JOIN [#HI] AS [hi] ON [r].[HiGuid] = [Hi].[Guid]
				WHERE [HiLevel] = @MaxLevel
				GROUP BY [mtGuid],[mtCode],[mtName],[mtLatinName],[mtUnitName],[GroupGuid],[Flag],[Hi].[Guid],[ParentGuid],[Hi].[Level],[r].[Level]
				SET @MaxLevel = @MaxLevel -1
			END
			DELETE #RESULT WHERE [HiLevel] <> 1
		END
	END
	INSERT INTO [#Result]	([mtGuid],[mtCode],[mtName],[mtLatinName],[mtUnitName],[Qty],[mtTargetQty],[GroupGuid],[ExpSaleQty],[Level],[Flag],[DistPtr])
		SELECT [mtGuid],[mtCode],[mtName],[mtLatinName],[mtUnitName],SUM([Qty]),[mtTargetQty],[GroupGuid],SUM([ExpSaleQty]),[Level],0,[DistPtr]
		FROM [#Result]
		GROUP BY [mtGuid],[mtCode],[mtName],[mtLatinName],[mtUnitName],[mtTargetQty],[GroupGuid],[Level],[DistPtr]
	DELETE [#Result] WHERE [FLAG] = 3
	SELECT [gr].[GUID],[Code] AS [grCode],[Name] AS [grName],CASE [LatinName] WHEN '' THEN [Name] ELSE [LatinName] END AS [grLatinName],[f].[Level],[gr].[ParentGuid] INTO [#GrpTBL]  FROM [fnGetGroupsListByLevel](@GroupGuid,0) AS [f] INNER JOIN [gr000] AS [gr] ON [gr].[Guid] = [f].[Guid]
	CREATE CLUSTERED INDEX [grpInd] ON [#GrpTBL]([GUID])
	
	SELECT @MaxLevel = MAX([Level]) FROM [#GrpTBL]
	INSERT INTO [#Result]([mtGuid],[mtCode],[mtName],[mtLatinName],[Qty],[mtTargetQty],[GroupGuid],[ExpSaleQty],[Level],[Flag],[DistPtr],[hiGuid])
	SELECT [gr].[Guid],[grCode],[grName],[grLatinName],
		SUM([Qty]),
		SUM([mtTargetQty])
		,[ParentGuid]
		,SUM([ExpSaleQty])
		,[gr].[Level]
		,1
		,[DistPtr],[hiGuid]
	FROM [#Result] AS [r] INNER JOIN [#GrpTBL] AS [gr] ON [gr].[Guid] = [r].[GroupGuid]
	GROUP BY 
		[gr].[Guid],[grCode],[grName],[grLatinName]
		,[ParentGuid]
		,[gr].[Level]
		,[DistPtr],[hiGuid]
	WHILE (@MaxLevel > 0)
	BEGIN
		INSERT INTO [#Result]([mtGuid],[mtCode],[mtName],[mtLatinName],[Qty],[mtTargetQty],[GroupGuid],[ExpSaleQty],[Level],[Flag],[DistPtr],[hiGuid])
			SELECT [gr].[Guid],[grCode],[grName],[grLatinName],
				SUM([Qty]),
				SUM([mtTargetQty])
				,[ParentGuid]
				,SUM([ExpSaleQty])
				,[gr].[Level]
				,1
				,[DistPtr],[hiGuid]
			FROM [#Result] AS [r] INNER JOIN [#GrpTBL] AS [gr] ON [gr].[Guid] = [r].[GroupGuid]
			WHERE [r].[Level] = @MaxLevel
			GROUP BY 
				[gr].[Guid],[grCode],[grName],[grLatinName]
				,[ParentGuid],[gr].[Level]
				,[DistPtr],[hiGuid]
		SET @MaxLevel = @MaxLevel - 1
	
	END
	IF (ISNULL(@DistGuid,0X00) <> 0X00) OR (ISNULL(@HiGuid,0X00) <> 0X00)
	BEGIN
		IF ISNULL(@HiGuid,0X00) <> 0X00
			INSERT INTO [#Result] ([mtGuid],[mtCode],[mtName],[mtLatinName],[Flag],[DistPtr])
				SELECT [Guid],'------' + [Code],[Name],[LatinName],-9,[r].[DistPtr] FROM  [distHi000] AS [Hi] INNER JOIN [#Result] AS [r] ON [Hi].[guid] = [r].[DistPtr]
		INSERT INTO [#Result] ([mtGuid],[mtCode],[mtName],[mtLatinName],[Flag],[DistPtr])
			SELECT [Guid],'---' + [Code],[Name],[LatinName],-9,[r].[DistPtr] FROM  [Distributor000] AS [Hi] INNER JOIN [#Result] AS [r] ON [Hi].[guid] = [r].[DistPtr]
		
	END
	SELECT 
			[mtGuid],
			[mtCode], 
			[mtName], 
			[mtLatinName],
			ISNULL([mtUnitName],'') AS [mtUnitName], 
			SUM([Qty])	AS [mtQty],
			SUM([mtTargetQty])	AS 	[targ],
			[GroupGuid],
			SUM([ExpSaleQty]) AS [ExpSaleQty],
			[Level],
			[Flag],[DistPtr]
	FROM 
		[#Result] 
	GROUP BY
		[mtGuid],
		[mtCode], 
		[mtName], 
		[mtLatinName],
		[mtUnitName], 
		[GroupGuid],
		[Level],
		[Flag]
		,[DistPtr]
	ORDER BY
		[Flag],
		[Level] DESC,
		[mtCode],
		[mtGuid],
		[DistPtr]
	SELECT @DistDaysNum AS DistDaysNum , @RealDaysNum AS RealDaysNum
	SELECT * FROM [#SecViol]
/*
prcConnections_add2 '„œÌ—'
Exec   [repDistGetBills] '3/13/2006', 0x00, 0, 0, '3E8EB127-6D23-4B1D-8B54-DDA7F245A709', '94AADC7B-2F84-42A2-ABF3-7B9A99C9D6AB', 0x00, 0 
*/
#############################
#END
