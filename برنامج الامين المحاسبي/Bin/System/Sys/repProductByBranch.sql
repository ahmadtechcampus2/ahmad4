##########################################################################
CREATE PROCEDURE repProductByBranchs
	@StartDate 			[DateTime] ,
	@EndDate			[DateTime] ,
	@MatGUID 			[UNIQUEIDENTIFIER] ,
	@GroupGUID 			[UNIQUEIDENTIFIER] ,
	@StoreGUID  		[UNIQUEIDENTIFIER] ,
	@BranchGUID 		[UNIQUEIDENTIFIER] ,
	@CostGUID 			[UNIQUEIDENTIFIER] ,
	@SrcTypesguid		[UNIQUEIDENTIFIER] ,
	@CurrencyGUID 		[UNIQUEIDENTIFIER] ,
	@Poseted			[INT] = -1,
	@UseUnit 			[INT], --1 First 2 Seccound 3 Third 
	@HrAxe				[INT] =0,
	@VrtAxe				[INT] = 0,
	@InOutDet			[INT] = 0,
	@Sort				[INT] = 0,
	@PriceByPriceType	[INT] = 0,
	@PriceType			[INT] = 0 ,
	@PricePolicy		[INT] = 0,
	@CurrencyVal		[FLOAT] = 1,
	@Lang				[INT] = 0,
	@MatCondGuid		[UNIQUEIDENTIFIER] = 0X00,
	@CostCond			[UNIQUEIDENTIFIER] = 0X00
AS
	SET NOCOUNT ON 
	CREATE TABLE [#SecViol]( [Type] [INT], [Cnt] [INTEGER]) 
	CREATE TABLE [#MatTbl]( [MatGUID] [UNIQUEIDENTIFIER] , [mtSecurity] [INT]) 
	CREATE TABLE [#BillsTypesTbl]( [TypeGuid] [UNIQUEIDENTIFIER] , [UserSecurity] [INTEGER], [UserReadPriceSecurity] [INTEGER],[UnPostedSecurity] [INTEGER]) 
	CREATE TABLE [#StoreTbl](	[StoreGUID] [UNIQUEIDENTIFIER] , [Security] [INT]) 
	CREATE TABLE [#CostTbl]( [CostGUID] [UNIQUEIDENTIFIER] , [Security] [INT]) 
	CREATE TABLE [#BranchTbl]( [GUID] [UNIQUEIDENTIFIER] , [Security] [INT]) 
	CREATE TABLE [#t_Prices]
	(
		[mtNumber] 	[UNIQUEIDENTIFIER],
		[APrice] 	[FLOAT]
	)
	DECLARE @Str [NVARCHAR] (max)
	DECLARE @MaxLevel [INT]
	
	--Filling temporary tables 
	INSERT INTO [#MatTbl]			EXEC [prcGetMatsList] 		@MatGUID, @GroupGUID ,-1,@MatCondGuid
	INSERT INTO [#BillsTypesTbl]	EXEC [prcGetBillsTypesList2] @SrcTypesguid--, @UserGuid 
	INSERT INTO [#StoreTbl]			EXEC [prcGetStoresList] 	@StoreGUID 
	INSERT INTO [#CostTbl]			EXEC [prcGetCostsList] 		@CostGUID, @CostCond
	INSERT INTO [#BranchTbl]		SELECT [f].[Guid],[Security] FROM [fnGetBranchesList](@BranchGUID) [f] INNER JOIN [br000] [br] on [f].[guid] = [Br].[Guid]
	IF (@CostGUID = 0X00)
		INSERT INTO [#CostTbl]	VALUES (0X00,0)
	CREATE CLUSTERED INDEX [rmtBrMt] ON  [#MatTbl]( [MatGUID])
	CREATE CLUSTERED INDEX [rmtBrBt ] ON [#BillsTypesTbl]  ( [TypeGuid]) 
	CREATE CLUSTERED INDEX  [rmtBrSt] ON [#StoreTbl] ([StoreGUID]) 
	CREATE TABLE [#EndRESULT] 
		(	
		[stGuid]			[UNIQUEIDENTIFIER] ,
		[matPtr]			[UNIQUEIDENTIFIER] ,
		[BranchPtr]			[UNIQUEIDENTIFIER] ,
		[Qnt]				[FLOAT] DEFAULT 0,
		[Qnt2]				[FLOAT],
		[Qnt3]				[FLOAT],
		[BonusQnt]			[FLOAT],
		[FixedbiPrice]		[FLOAT] DEFAULT 0,
		[FixedbiDiscount]	[FLOAT] DEFAULT 0,
		[FixedBiExtra]		[FLOAT] DEFAULT 0,
		[CostPtr]			[UNIQUEIDENTIFIER] ,
		[MatSecurity]		[INT],
		[Security]			[INT], 
		[UserSecurity]		[INT],
		[brSecurity]		[INT],
		[FLAG]				[INT] DEFAULT 0,
		[Path] 				[NVARCHAR] (255) DEFAULT '',
		[biQnt]				[FLOAT] DEFAULT 0,
		[Direction]			[INT]
		)
		INSERT INTO [#EndRESULT] 
			SELECT 
				[bi].[biStorePtr],
				[bi].[biMatPtr],
				[bi].[buBranch],
				SUM([bi].[btDirection]  * CASE @UseUnit 
					WHEN 0 THEN [bi].[biQty]
					WHEN 1 THEN [bi].[biQty]/CASE ISNULL([mtunit2Fact], 0) WHEN 0 THEN 1 ELSE [mtunit2Fact] END
					WHEN 2 THEN [bi].[biQty]/CASE ISNULL([mtunit3Fact], 0) WHEN 0 THEN 1 ELSE [mtunit3Fact] END
					ELSE [bi].[biQty] / CASE ISNULL([mtDefUnitFact], 0) WHEN 0 THEN 1 ELSE [mtDefUnitFact] END
				END),
				SUM([bi].[btDirection]  *([bi].[biCalculatedQty2] + CASE ISNULL([mtunit2Fact], 0) WHEN 0 THEN 0 ELSE [bi].[biBonusQnt]/[mtunit2Fact] END)),
				SUM([bi].[btDirection]  *([bi].[biCalculatedQty3] + CASE ISNULL([mtunit3Fact], 0) WHEN 0 THEN 0 ELSE [bi].[biBonusQnt]/[mtunit3Fact] END)),
				SUM([bi].[btDirection]  * CASE @UseUnit 
					WHEN 0 THEN [bi].[biBonusQnt]
					WHEN 1 THEN [bi].[biBonusQnt]/CASE ISNULL([mtunit2Fact], 0) WHEN 0 THEN 1 ELSE [mtunit2Fact] END
					WHEN 2 THEN [bi].[biBonusQnt]/CASE ISNULL([mtunit3Fact], 0) WHEN 0 THEN 1 ELSE [mtunit3Fact] END
					ELSE [bi].[biBonusQnt] / CASE ISNULL([mtDefUnitFact], 0) WHEN 0 THEN 1 ELSE [mtDefUnitFact] END
				END),
				SUM([bi].[btDirection]  *[bi].[FixedbiPrice] * [bi].[biQty] / CASE ISNULL([MtUnitFact], 0) WHEN 0 THEN 1 ELSE [MtUnitFact] END),
				SUM([bi].[btDirection]  * ([bi].[FixedBuTotalDisc] -  [FixedBuItemsDisc]) * [FixedbiPrice]* [bi].[biQty] / (CASE ISNULL([FixedBuTotal], 0) WHEN 0 THEN 1 ELSE [FixedBuTotal] END) / CASE ISNULL([MtUnitFact], 0) WHEN 0 THEN 1 ELSE [MtUnitFact] END + [bi].[btDirection]  *[FixedbiDiscount]), 
				SUM([bi].[btDirection]  *[FixedBuTotalExtra] * [FixedbiPrice]* [bi].[biQty] / (CASE ISNULL([FixedBuTotal], 0) WHEN 0 THEN 1 ELSE [FixedBuTotal] END) / CASE ISNULL([MtUnitFact], 0) WHEN 0 THEN 1 ELSE [MtUnitFact] END) ,
				[bi].[biCostPtr],
				[mt].[mtSecurity],
				[bi].[buSecurity],
				CASE [buIsposted] WHEN  1 THEN [bt].[UserSecurity] ELSE [UnPostedSecurity] END,
				[Br].[Security],
				0,
				'',
				SUM(CASE  WHEN @PriceByPriceType = 0 THEN  0 ELSE [bi].[btDirection]  * ([bi].[biQty] + [bi].[biBonusQnt]) END),
				[bi].[btDirection]
		FROM 
					[fnExtended_bi_Fixed](@CurrencyGUID) AS [bi]
					INNER JOIN [#MatTbl] AS [mt] ON [mt].[MatGUID] = [bi].[biMatPtr]
					INNER JOIN [#BillsTypesTbl] AS [bt] ON [bt].[TypeGuid] = [bi].[buType]
					INNER JOIN [#StoreTbl] AS [st] ON [st].[StoreGUID] = [bi].[biStorePtr]
					INNER JOIN [#BranchTbl] AS [br] ON [bi].[buBranch] = [br].[Guid]
					INNER JOIN [#CostTbl] AS [co] ON [co].[CostGUID] = [bi].[biCostPtr]
				WHERE 
			[buDate] BETWEEN @StartDate AND @EndDate
			AND (@Poseted = -1 OR [buIsposted] = @Poseted)
		GROUP BY
			[bi].[biStorePtr],
			[bi].[biMatPtr],
			[bi].[buBranch],
			[bi].[biCostPtr],
			[mt].[mtSecurity],
			[bi].[buSecurity],
			[buIsposted],
			[bt].[UserSecurity],
			[UnPostedSecurity],
			[Br].[Security],
			[bi].[btDirection]
	EXEC [prcCheckSecurity] @Result = '#EndRESULT'
	IF @PriceByPriceType = 1
	BEGIN
		
		IF @PriceType = 2 AND @PricePolicy = 122 -- LastPrice
		BEGIN
			EXEC [prcGetLastPrice] @StartDate , @EndDate , @MatGUID, @GroupGUID, @StoreGUID, @CostGUID, -1,	@CurrencyGUID, @SrcTypesguid, 0, 0
		END
		ELSE IF @PriceType = 2 AND @PricePolicy = 120 -- MaxPrice
		BEGIN
			EXEC [prcGetMaxPrice] @StartDate , @EndDate , @MatGUID, @GroupGUID, @StoreGUID, @CostGUID, -1,	@CurrencyGUID, @CurrencyVal, @SrcTypesguid, 0, 0
		END
		ELSE IF @PriceType = 2 AND @PricePolicy = 121  -- COST And AvgPrice NO STORE DETAILS
		BEGIN
			EXEC [prcGetAvgPrice]	@StartDate,	@EndDate, @MatGUID, @GroupGUID, @StoreGUID, @CostGUID, -1, @CurrencyGUID, @CurrencyVal, @SrcTypesguid,	0, 0
		END
		ELSE IF @PriceType = -1
			INSERT INTO [#t_Prices] SELECT [MatGUID], 0 FROM [#MatTbl]
			ELSE IF @PriceType = 2 AND @PricePolicy = 124 -- LastPrice with extra and discount
		BEGIN
			EXEC [prcGetLastPrice] @StartDate , @EndDate , @MatGUID, @GroupGUID, @StoreGUID, @CostGUID, -1,	@CurrencyGUID, @SrcTypesguid, 0, 0, 0 /*@CalcLastCost*/,	1 /*@ProcessExtra*/
		END
		ELSE
		BEGIN
			EXEC [prcGetMtPrice] @MatGUID,	@GroupGUID, -1, @CurrencyGUID, @CurrencyVal, @SrcTypesguid, @PriceType, @PricePolicy, 0, @UseUnit
		END
		UPDATE [r] SET [FixedbiPrice] =  [biQnt] * [APrice],[FixedbiDiscount]= 0,[FixedBiExtra] = 0 FROM [#EndRESULT] AS [r] INNER JOIN [#t_Prices] AS [t] ON [matPtr]= [mtNumber] 
	END
	
	IF (@VrtAxe = 3) OR (@HrAxe =3) -- one of axes is Group:
	BEGIN
		UPDATE [#EndRESULT] SET [Security] = 0

		DECLARE @Sort2 [INT]
		SET @Sort2 = @Sort + 1

		SELECT
		DISTINCT
		[f].[GUID],
		[f].[Path],
		[Level],
		[gr].[ParentGuid]
		INTO [#GR2]
		FROM [fnGetGroupsOfGroupSorted]( @GroupGUID, @Sort2 ) AS [f]
		INNER JOIN [gr000] AS [gr] ON [gr].[Guid] = [f].[Guid]

		--CREATE CLUSTERED INDEX [GRIND] ON [#GR2]([GUID],[Path])
		
		SELECT @MaxLevel = MAX([Level]) FROM [#GR2]
		INSERT INTO [#EndRESULT] ([matPtr],[BranchPtr],[Qnt],[Qnt2],[Qnt3],[BonusQnt],[FixedbiPrice],[FixedbiDiscount],[FixedBiExtra],[Path],[Security],[Direction])
			SELECT [GroupGuid],[r].[BranchPtr],SUM([r].[Qnt]),SUM([r].[Qnt2]),SUM([r].[Qnt3]),SUM([r].[BonusQnt]),SUM([r].[FixedbiPrice]),SUM([r].[FixedbiDiscount]),SUM([r].[FixedBiExtra]),[gr].[Path],CASE [gr].[Level] WHEN 0 THEN 1 ELSE 0 END,[Direction]
			FROM [#EndRESULT] AS [r]  
			INNER JOIN [mt000] AS [mt] ON [mt].[Guid] = [matPtr] 
			INNER JOIN [#GR2] AS [gr] ON [gr].[GUID] = [GroupGuid]
			GROUP BY 
				 [GroupGuid],[r].[BranchPtr],[gr].[Path],[gr].[Level] ,[Direction]		
		
		WHILE @MaxLevel > 0
		BEGIN
			INSERT INTO [#EndRESULT] ([matPtr],[BranchPtr],[Qnt],[Qnt2],[Qnt3],[BonusQnt],[FixedbiPrice],[FixedbiDiscount],[FixedBiExtra],[Path],[Security],[Direction])
			SELECT [gr].[ParentGuid],[r].[BranchPtr],SUM([r].[Qnt]),SUM([r].[Qnt2]),SUM([r].[Qnt3]),SUM([r].[BonusQnt]),SUM([r].[FixedbiPrice]),SUM([r].[FixedbiDiscount]),SUM([r].[FixedBiExtra]),[gr].[Path],CASE (@MaxLevel - 1) WHEN 0 THEN 1 ELSE 0 END,[Direction]
			FROM [#EndRESULT] AS [r] 
			INNER JOIN [#GR2] AS [gr] ON [gr].[GUID] = [matPtr] 
			WHERE [gr].[Level] = @MaxLevel
			GROUP BY 
				 [gr].[ParentGuid],[r].[BranchPtr],[gr].[Path],[gr].[Level] ,[Direction]	
			SET @MaxLevel = @MaxLevel - 1
		
		END 
		
		
	END
	IF @HrAxe = 0 
 		 SELECT
		 DISTINCT
		 [br].[Guid] AS [brGuid] ,
		 [br].[Code] + '-' + CASE @Lang WHEN 0 THEN [br].[Name] ELSE CASE [br].[LatinName] WHEN '' THEN [br].[Name] ELSE [br].[LatinName] END END AS [brName],
		 CASE @Sort WHEN 0 THEN [br].[Code] ELSE CASE @Lang WHEN 0 THEN [br].[Name] ELSE CASE [br].[LatinName] WHEN '' THEN [br].[Name] ELSE [br].[LatinName] END END END
		 FROM [#EndRESULT] AS [r]
		 INNER JOIN [br000] AS [br] ON [br].[GUID] = [r].[BranchPtr]
		 ORDER BY
		 CASE @Sort WHEN 0 THEN [br].[Code] ELSE  CASE @Lang WHEN 0 THEN [br].[Name] ELSE CASE [br].[LatinName] WHEN '' THEN [br].[Name] ELSE [br].[LatinName] END END END

	IF @HrAxe = 1 
		SELECT DISTINCT [mt].[Guid] AS [mtGuid], [mt].[Name] AS [mtName]  FROM [#EndRESULT] AS [r] INNER JOIN [Mt000] AS [mt] ON [mt].[Guid] = [r].[matPtr] ORDER BY [mt].[Name] 
	IF @HrAxe = 2 
		SELECT DISTINCT  [LatinName]  AS [mtLatinName] FROM [#EndRESULT] AS [r]  INNER JOIN [Mt000] AS [mt] ON [mt].[Guid] = [r].[matPtr] ORDER BY  [LatinName] 
		
	IF @HrAxe = 3 
		SELECT
		DISTINCT
		[gr].[grGuid],
		[gr].[grCode] + '-' +[gr].[grName] AS [grName],
		[r].[Path]
		FROM [#EndRESULT] AS [r]
		INNER JOIN [vwGr] AS [gr] ON [r].[matPtr] = [gr].[grGuid]  ORDER BY [r].[Path]
	IF @HrAxe = 4 
		SELECT DISTINCT [mt].[Spec] AS [mtSpec]  FROM [#EndRESULT] AS [r] INNER JOIN [Mt000] AS [mt] ON [mt].[Guid] = [r].[matPtr] ORDER BY [mt].[Spec]
	IF @HrAxe = 5 
		SELECT DISTINCT [mt].[Dim] AS [mtDim]  FROM [#EndRESULT] AS [r] INNER JOIN [Mt000] AS [mt] ON [mt].[Guid] = [r].[matPtr] ORDER BY [mt].[Dim]
	IF @HrAxe = 6 
		SELECT DISTINCT [mt].[Pos] AS [mtPos]  FROM [#EndRESULT] AS [r] INNER JOIN [Mt000] AS [mt] ON [mt].[Guid] = [r].[matPtr] ORDER BY [mt].[Pos] 
	IF @HrAxe = 7 
		SELECT DISTINCT [mt].[Origin] AS [mtOrigin]  FROM [#EndRESULT] AS [r] INNER JOIN [Mt000] AS [mt] ON [mt].[Guid] = [r].[matPtr] ORDER BY [mt].[Origin] 
	IF @HrAxe = 8 
		SELECT DISTINCT [mt].[Company] AS [mtCompany]  FROM [#EndRESULT] AS [r] INNER JOIN [Mt000] AS [mt] ON [mt].[Guid] = [r].[matPtr] ORDER BY [mt].[Company] 
	IF @HrAxe = 9 
		SELECT DISTINCT [mt].[Color] AS [mtColor]  FROM [#EndRESULT] AS [r] INNER JOIN [Mt000] AS [mt] ON [mt].[Guid] = [r].[matPtr] ORDER BY [mt].[Color] 
	IF @HrAxe = 10
		SELECT DISTINCT [mt].[Model] AS [mtModel]  FROM [#EndRESULT] AS [r] INNER JOIN [Mt000] AS [mt] ON [mt].[Guid] = [r].[matPtr] ORDER BY [mt].[Model]  
	DECLARE @DuolicateMat [INT]
	IF @VrtAxe = 1 OR @HrAxe = 1
	BEGIN
		SELECT @DuolicateMat = CAST([Value] AS [INT]) FROM [op000] WHERE [Name] =  'AmnCfg_CanDuplicateMatName'
		IF @@ROWCOUNT = 0
			SET @DuolicateMat = 0
	END
	SET @Str = ' SELECT [br].[Guid] AS [brGuid] ,[BR].[Code] + ' + '''' + '-' + '''' +' +  CASE  ' + CAST (@Lang AS [NVARCHAR](1))+' WHEN 0 THEN [br].[Name] ELSE CASE [br].[LatinName] WHEN '+ ''''+'''' +' THEN [br].[Name] ELSE [br].[LatinName] END END AS [brName]'
	IF @VrtAxe = 1 
	BEGIN
		IF @DuolicateMat = 0
			SET @Str = @Str  + ',[mt].[mtGuid]'
		SET @Str = @Str  +' , [mt].[mtName] '
	END
	IF @VrtAxe = 2 
		SET @Str = @Str  +' ,  [mt].[mtLatinName]  '
	
	IF @VrtAxe = 3 
		SET @Str = @Str  +' ,[gr].[grGuid],[gr].[grCode] +' + '''' + '''' +  '+ [gr].[grName] AS [grName], [r].[Security] '
	IF @VrtAxe = 4 
		SET @Str = @Str + '	,[mt].[mtSpec] '
	IF @VrtAxe = 5 
		SET @Str = @Str + '	,[mt].[mtDim] ' 
	IF @VrtAxe = 6 
		SET @Str = @Str + '	,[mt].[mtPos] ' 
	IF @VrtAxe = 7 
		SET @Str = @Str + ',[mt].[mtOrigin] ' 
	IF @VrtAxe = 8 
		SET @Str = @Str + '	,[mt].[mtCompany] ' 
	IF @VrtAxe = 9 
		SET @Str = @Str + '	,[mt].[mtColor] ' 
	IF @VrtAxe = 10 
		SET @Str = @Str + ',[mt].[mtModel] '
	IF @HrAxe = 1 
	BEGIN
		IF @DuolicateMat = 0
			SET @Str = @Str  + ',[mt].[mtGuid]'
		SET @Str = @Str  +' , [mt].[mtName] '
		
	END
	IF @HrAxe = 2 
		SET @Str = @Str  +' , [mt].[mtLatinName] '
	IF @HrAxe = 3 
		SET @Str = @Str  +' ,[gr].[grGuid], [gr].[grName], [r].[Security] '
	IF @HrAxe = 4 
		SET @Str = @Str + '	,[mt].[mtSpec] '
	IF @HrAxe = 5 
		SET @Str = @Str + '	,[mt].[mtDim] ' 
	IF @HrAxe = 6 
		SET @Str = @Str + '	,[mt].[mtPos] ' 
	IF @HrAxe = 7 
		SET @Str = @Str + ',[mt].[mtOrigin] ' 
	IF @HrAxe = 8 
		SET @Str = @Str + '	,[mt].[mtCompany] ' 
	IF @HrAxe = 9 
		SET @Str = @Str + '	,[mt].[mtColor] ' 
	IF @HrAxe = 10 
		SET @Str = @Str + ',[mt].[mtModel] '
	SET @Str = @Str + ' ,SUM ([r].[Qnt]) AS [Qty], SUM ([r].[Qnt2]) AS [Qnt2], SUM ([r].[Qnt3]) AS [Qnt3], SUM ([r].[FixedbiPrice]) AS [FixedbiPrice], ISNULL(SUM ([r].[FixedbiDiscount]), 0) AS [FixedbiDiscount] ,SUM ([r].[FixedBiExtra]) AS [FixedBiExtra], SUM([BonusQnt]) AS [BonusQnt] '
	IF @InOutDet > 0
		SET @Str = @Str + ',[r].[Direction] '
	SET @Str = @Str + ' FROM [#EndRESULT] AS [r]  INNER JOIN [br000] AS [br] ON [br].[GUID] = [r].[BranchPtr]'
	
	IF @VrtAxe <> 3 AND @HrAxe <> 3
		SET @Str = @Str + ' INNER JOIN [vwMt] AS [mt] ON [mt].[mtGuid] = [r].[matPtr]  '
	IF @VrtAxe = 3 OR @HrAxe = 3
		SET @Str = @Str + ' INNER JOIN [vwGr] AS [gr] ON [r].[matPtr] = [gr].[grGuid] '
	SET @Str = @Str + ' GROUP BY '
	IF @VrtAxe = 3 OR @HrAxe = 3
		SET @Str = @Str  + '[r].[Path], '
	SET @Str = @Str  +' [br].[Guid], [br].[Name],[br].[LatinName],[BR].[Code] '
	IF @VrtAxe = 1 
	BEGIN
		IF @DuolicateMat = 0
			SET @Str = @Str  + ',[mt].[mtGuid]'
		SET @Str = @Str  +' , [mt].[mtName] '
	END
	IF @VrtAxe = 2 
		SET @Str = @Str  +' ,  [mt].[mtLatinName]  '
	IF @VrtAxe = 3 
		SET @Str = @Str  +' ,[gr].[grGuid],[gr].[grCode], [gr].[grName], [r].[Security] '
	IF @VrtAxe = 4 
		SET @Str = @Str + '	,[mt].[mtSpec] '
	IF @VrtAxe = 5 
		SET @Str = @Str + '	,[mt].[mtDim] ' 
	IF @VrtAxe = 6 
		SET @Str = @Str + '	,[mt].[mtPos] ' 
	IF @VrtAxe = 7 
		SET @Str = @Str + ',[mt].[mtOrigin] ' 
	IF @VrtAxe = 8 
		SET @Str = @Str + '	,[mt].[mtCompany] ' 
	IF @VrtAxe = 9 
		SET @Str = @Str + '	,[mt].[mtColor] ' 
	IF @VrtAxe = 10 
		SET @Str = @Str + ',[mt].[mtModel] '
	IF @HrAxe = 1
	BEGIN 
		IF @DuolicateMat = 0
			SET @Str = @Str  + ',[mt].[mtGuid]'
		SET @Str = @Str  +' ,[mt].[mtName] '
	END
	IF @HrAxe = 2 
		SET @Str = @Str  +' ,[mt].[mtLatinName] '
	IF @HrAxe = 3 
		SET @Str = @Str  +' ,[gr].[grGuid],[gr].[grName],[r].[Security] '
	IF @HrAxe = 4 
		SET @Str = @Str + '	,[mt].[mtSpec] '
	IF @HrAxe = 5 
		SET @Str = @Str + '	,[mt].[mtDim] ' 
	IF @HrAxe = 6 
		SET @Str = @Str + '	,[mt].[mtPos] ' 
	IF @HrAxe = 7 
		SET @Str = @Str + ',[mt].[mtOrigin] ' 
	IF @HrAxe = 8 
		SET @Str = @Str + '	,[mt].[mtCompany] ' 
	IF @HrAxe = 9 
		SET @Str = @Str + '	,[mt].[mtColor] '
	IF @HrAxe = 10 
		SET @Str = @Str + ',[mt].[mtModel] '
		
	IF @InOutDet > 0
		SET @Str = @Str + ',[r].[Direction] '
	SET @Str = @Str + '	ORDER BY  '
	IF @VrtAxe = 0 	
	BEGIN
		IF (@Sort = 0)
			SET @Str = @Str  +' [BR].[Code], CASE '+ CAST (@Lang AS [NVARCHAR](1)) + ' WHEN 0 THEN [br].[Name] ELSE CASE [br].[LatinName] WHEN '+ ''''+'''' +' THEN [br].[Name] ELSE [br].[LatinName] END END,[br].[Guid] '
		ELSE
			SET @Str = @Str  +'  CASE ' + CAST (@Lang AS [NVARCHAR](1)) + ' WHEN 0 THEN [br].[Name] ELSE CASE [br].[LatinName] WHEN '+ ''''+'''' +' THEN [br].[Name] ELSE [br].[LatinName] END END,[BR].[Code],[br].[Guid] '
	END
	IF @VrtAxe = 1
		SET @Str = @Str  +'[mt].[mtName] '
	IF @VrtAxe = 2 
		SET @Str = @Str  +'  [mt].[mtLatinName] '
	IF @VrtAxe = 3 
		SET @Str = @Str  +' [r].[path] '
	IF @VrtAxe = 4 
		SET @Str = @Str + '	[mt].[mtSpec] '
	IF @VrtAxe = 5 
		SET @Str = @Str + '	[mt].[mtDim] ' 
	IF @VrtAxe = 6 
		SET @Str = @Str + '	[mt].[mtPos] ' 
	IF @VrtAxe = 7 
		SET @Str = @Str + ' [mt].[mtOrigin] ' 
	IF @VrtAxe = 8 
		SET @Str = @Str + '	[mt].[mtCompany] ' 
	IF @VrtAxe = 9 
		SET @Str = @Str + '	[mt].[mtColor] ' 
	IF @VrtAxe = 10 
		SET @Str = @Str + ' [mt].[mtModel] '
	
	IF @HrAxe = 0 
	BEGIN
		IF (@Sort = 0)
			SET @Str = @Str  +' ,[BR].[Code], CASE ' + CAST (@Lang AS [NVARCHAR](1)) + ' WHEN 0 THEN [br].[Name] ELSE CASE [br].[LatinName] WHEN '+ ''''+'''' +' THEN [br].[Name] ELSE [br].[LatinName] END END,[br].[Guid] '
		ELSE
			SET @Str = @Str  +' , CASE ' + CAST (@Lang AS [NVARCHAR](1))+ ' WHEN 0 THEN [br].[Name] ELSE CASE [br].[LatinName] WHEN '+ ''''+'''' +' THEN [br].[Name] ELSE [br].[LatinName] END END,[BR].[Code],[br].[Guid] '	
	END
	IF @HrAxe = 1 
	BEGIN
		SET @Str = @Str  +' ,[mt].[mtName] '
	END
	IF @HrAxe = 2 
		SET @Str = @Str  +' ,[mt].[mtLatinName] '
	IF @HrAxe = 3 
		SET @Str = @Str  +' ,[r].[path] '
	IF @HrAxe = 4 
		SET @Str = @Str + '	,[mt].[mtSpec] '
	IF @HrAxe = 5 
		SET @Str = @Str + '	,[mt].[mtDim] ' 
	IF @HrAxe = 6 
		SET @Str = @Str + '	,[mt].[mtPos] ' 
	IF @HrAxe = 7 
		SET @Str = @Str + ',[mt].[mtOrigin] ' 
	IF @HrAxe = 8 
		SET @Str = @Str + '	,[mt].[mtCompany] ' 
	IF @HrAxe = 9 
		SET @Str = @Str + '	,[mt].[mtColor] '
	IF @HrAxe = 10 
		SET @Str = @Str + ',[mt].[mtModel] '
	EXEC (@Str)
	
	IF @InOutDet > 0
	BEGIN -- calc total result:
		DECLARE @StrTotal [NVARCHAR] (max)
		SET @StrTotal = 'SELECT SUM([Qnt]) AS [Qty], SUM([Qnt2]) [Qnt2], SUM([Qnt3]) [Qnt3], SUM(FixedbiPrice) FixedbiPrice, ISNULL(SUM(FixedbiDiscount), 0) FixedbiDiscount, SUM(FixedBiExtra) FixedBiExtra, SUM(BonusQnt) BonusQnt '
		IF @HrAxe = 0	SET @StrTotal = @StrTotal + ' ,[r].[BranchPtr] AS [brGuid], [br].[Name] AS [brName], [br].[LatinName], [br].[Code] '
		IF @HrAxe = 1	SET @StrTotal = @StrTotal + ' ,[r].[matPtr] AS [mtGuid], [mt].[Name] AS [mtName] '
		IF @HrAxe = 2	SET @StrTotal = @StrTotal + ' ,[mt].[LatinName] AS [mtLatinName] '
		IF @HrAxe = 3	SET @StrTotal = @StrTotal + ' ,[gr].[grGuid], [gr].[grCode] +' + '''' + '''' +  '+ [gr].[grName] AS [grName] '
		IF @HrAxe = 4	SET @StrTotal = @StrTotal + ' ,[mt].[Spec] AS [mtSpec] '
		IF @HrAxe = 5	SET @StrTotal = @StrTotal + ' ,[mt].[Dim] AS [mtDim] '
		IF @HrAxe = 6	SET @StrTotal = @StrTotal + ' ,[mt].[Pos] AS [mtPos] '
		IF @HrAxe = 7	SET @StrTotal = @StrTotal + ' ,[mt].[Origin] AS [mtOrigin] '
		IF @HrAxe = 8	SET @StrTotal = @StrTotal + ' ,[mt].[Company] AS [mtCompany] '
		IF @HrAxe = 9	SET @StrTotal = @StrTotal + ' ,[mt].[Color] AS [mtColor] '
		IF @HrAxe = 10	SET @StrTotal = @StrTotal + ' ,[mt].[Model] AS [mtModel] '
		IF @VrtAxe = 0 SET @StrTotal = @StrTotal + ' ,[r].[BranchPtr] AS [brGuid], [br].[Name] AS [brName], [br].[LatinName], [BR].[Code]'
		IF @VrtAxe = 1 SET @StrTotal = @StrTotal + ' ,[r].[matPtr] AS [mtGuid], [mt].[Name] AS [mtName] '
		IF @VrtAxe = 2 SET @StrTotal = @StrTotal + ' ,[mt].[LatinName] AS [mtLatinName] '
		IF @VrtAxe = 3 SET @StrTotal = @StrTotal + ' ,[gr].[grGuid], [gr].[grCode] +' + '''' + '''' +  '+ [gr].[grName] AS [grName] '
		IF @VrtAxe = 4 SET @StrTotal = @StrTotal + ' ,[mt].[Spec] AS [mtSpec] '
		IF @VrtAxe = 5 SET @StrTotal = @StrTotal + ' ,[mt].[Dim] AS [mtDim] '
		IF @VrtAxe = 6 SET @StrTotal = @StrTotal + ' ,[mt].[Pos] AS [mtPos] '
		IF @VrtAxe = 7 SET @StrTotal = @StrTotal + ' ,[mt].[Origin] AS [mtOrigin] '
		IF @VrtAxe = 8 SET @StrTotal = @StrTotal + ' ,[mt].[Company] AS [mtCompany] '
		IF @VrtAxe = 9 SET @StrTotal = @StrTotal + ' ,[mt].[Color] AS [mtColor] '
		IF @VrtAxe = 10 SET @StrTotal = @StrTotal + ' ,[mt].[Model] AS mtModel'
		SET @StrTotal = @StrTotal + ' FROM [#EndRESULT] AS [r] '
		SET @StrTotal = @StrTotal + ' INNER JOIN [br000] AS [br] ON [br].[GUID] = [r].[BranchPtr] '
		IF @VrtAxe <> 3 AND @HrAxe <> 3
		SET @StrTotal = @StrTotal + ' INNER JOIN [Mt000] AS [mt] ON [mt].[Guid] = [r].[matPtr] '
		IF @VrtAxe = 3 OR @HrAxe = 3
		SET @StrTotal = @StrTotal + ' INNER JOIN [vwGr] AS [gr] ON [r].[matPtr] = [gr].[grGuid] '
		SET @StrTotal = @StrTotal + ' GROUP BY '
		IF @HrAxe = 0	SET @StrTotal = @StrTotal + ' [r].[BranchPtr], [br].[Name],[br].[LatinName],[br].[Code] '
		IF @HrAxe = 1	SET @StrTotal = @StrTotal + ' [r].[matPtr], [mt].[Name] '
		IF @HrAxe = 2	SET @StrTotal = @StrTotal + ' [mt].[LatinName] '
		IF @HrAxe = 3	SET @StrTotal = @StrTotal + ' [gr].[grGuid], [gr].[grCode] +' + '''' + '''' +  '+ [gr].[grName] '
		IF @HrAxe = 4	SET @StrTotal = @StrTotal + ' [mt].[Spec] '
		IF @HrAxe = 5	SET @StrTotal = @StrTotal + ' [mt].[Dim] '
		IF @HrAxe = 6	SET @StrTotal = @StrTotal + ' [mt].[Pos] '
		IF @HrAxe = 7	SET @StrTotal = @StrTotal + ' [mt].[Origin] '
		IF @HrAxe = 8	SET @StrTotal = @StrTotal + ' [mt].[Company] '
		IF @HrAxe = 9	SET @StrTotal = @StrTotal + ' [mt].[Color] '
		IF @HrAxe = 10	SET @StrTotal = @StrTotal + ' [mt].[Model] '
		IF @VrtAxe = 0 SET @StrTotal = @StrTotal + ' ,[r].[BranchPtr], [br].[Name],[br].[LatinName],[br].[Code] '
		IF @VrtAxe = 1 SET @StrTotal = @StrTotal + ' ,[r].[matPtr], [mt].[Name] '
		IF @VrtAxe = 2 SET @StrTotal = @StrTotal + ' ,[mt].[LatinName] '
		IF @VrtAxe = 3 SET @StrTotal = @StrTotal + ' ,[gr].[grGuid], [gr].[grCode] +' + '''' + '''' +  '+ [gr].[grName] '
		IF @VrtAxe = 4 SET @StrTotal = @StrTotal + ' ,[mt].[Spec] '
		IF @VrtAxe = 5 SET @StrTotal = @StrTotal + ' ,[mt].[Dim] '
		IF @VrtAxe = 6 SET @StrTotal = @StrTotal + ' ,[mt].[Pos] '
		IF @VrtAxe = 7 SET @StrTotal = @StrTotal + ' ,[mt].[Origin] '
		IF @VrtAxe = 8 SET @StrTotal = @StrTotal + ' ,[mt].[Company] '
		IF @VrtAxe = 9 SET @StrTotal = @StrTotal + ' ,[mt].[Color] '
		IF @VrtAxe = 10 SET @StrTotal = @StrTotal + ' ,[mt].[Model] '
		
		EXEC (@StrTotal)
	END
	SELECT * FROM [#SecViol]
/*
PrcConnections_add2 '„œÌ—'

exec  [repProductByBranchs] '1/1/2004', '6/2/2005', '00000000-0000-0000-0000-000000000000', '00000000-0000-0000-0000-000000000000', '00000000-0000-0000-0000-000000000000', '00000000-0000-0000-0000-000000000000', '00000000-0000-0000-0000-000000000000', '5b2676e9-e6c2-483f-9446-21ccc186bf3e', 'ca1f70c1-45aa-47b7-8e65-c8570c11016a', 1, 3, 0, 1, 0, 1, 1, 2, 120, 30.000000,
*/
###############################################################################
#END