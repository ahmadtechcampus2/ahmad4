##########################################################
CREATE PROCEDURE repStoreMoveAndCostCenter
	@StartDate 			[DATETIME],
	@EndDate			[DATETIME],
	@MatGUID 			[UNIQUEIDENTIFIER],
	@GroupGUID 			[UNIQUEIDENTIFIER],
	@StoreGUID  		[UNIQUEIDENTIFIER],
	@CostGUID 			[UNIQUEIDENTIFIER],
	@SrcTypesguid		[UNIQUEIDENTIFIER],
	@CurrencyGUID 		[UNIQUEIDENTIFIER],
	@UseUnit 			[INT],	-- 1 First 2 Seccound 3 Third 
	@InOutSign			[INT],	-- 0 IN + OUT + 1 IN + OUT - 2 IN - OUT +
	@StLevel			[INT] = 0,
	@CoLevel			[INT] = 0,
	@VrtAxe				[INT] = 0,
	@HrtAxe				[INT] = 0,
	@MainAxe			[INT] = 0, -- 0 None 
	@ShoeGroups			[INT] = 0,
	@PriceByPriceType	[INT] = 0,
	@PriceType			[INT] = 0 ,
	@PricePolicy		[INT] = 0,
	@CurrencyVal		[FLOAT] = 1,
	@ShowMat			[BIT] = 1,
	@GrpLevel			[INT] = 0,
	@Lang				[BIT] = 0,
	@shwEmptyMat		[BIT] = 0
AS
	SET NOCOUNT ON 
	DECLARE @StGUID [UNIQUEIDENTIFIER]

	CREATE TABLE [#SecViol]( [Type] [INT], [Cnt] [INTEGER]) 
	CREATE TABLE [#MatTbl]( [MatGUID] [UNIQUEIDENTIFIER], [mtSecurity] [INT]) 
	CREATE TABLE [#BillsTypesTbl]( [TypeGuid] [UNIQUEIDENTIFIER], [UserSecurity] [INTEGER], [UserReadPriceSecurity] [INTEGER]) 
	CREATE TABLE [#StoreTbl]([StoreGUID] [UNIQUEIDENTIFIER], [Security] [INT]) 
	CREATE TABLE [#CostTbl]( [CostGUID] [UNIQUEIDENTIFIER], [Security] [INT]) 
	CREATE TABLE [#TCOST]([GUID] [UNIQUEIDENTIFIER], [Level] [INT], [Path] [NVARCHAR](max) COLLATE ARABIC_CI_AI) 
	--Filling temporary tables 
	INSERT INTO [#MatTbl]		EXEC [prcGetMatsList] 		@MatGUID, @GroupGUID ,-1 
	INSERT INTO [#BillsTypesTbl]EXEC [prcGetBillsTypesList]	@SrcTypesguid--, @UserGuid 
	INSERT INTO [#StoreTbl]		EXEC [prcGetStoresList]		@StoreGUID 
	INSERT INTO [#CostTbl]		EXEC [prcGetCostsList] 		@CostGUID 
	CREATE TABLE [#t_Prices]
	(
		[mtNumber] 	[UNIQUEIDENTIFIER],
		[APrice] 	[FLOAT]
	)
	CREATE TABLE [#GR] ([Guid] [UNIQUEIDENTIFIER])
	CREATE TABLE [#GRP] ([GUID] [UNIQUEIDENTIFIER], [Level] [INT], [Path] [NVARCHAR](max) COLLATE ARABIC_CI_AI, [Type] [INT])  
	CREATE TABLE [#TStore]([GUID]  UNIQUEIDENTIFIER, [Level] INT)

	DECLARE @Admin [INT],@UserGuid [UNIQUEIDENTIFIER],@cnt [INT]
	DECLARE @In [INT], @Out [INT]
	DECLARE @Sql [NVARCHAR](max)
	
	SET @UserGuid = [dbo].[fnGetCurrentUserGUID]()
	SET @Admin = [dbo].[fnIsAdmin](ISNULL(@userGUID,0x00) )
	
	IF @Admin = 0
	BEGIN
		INSERT INTO [#GR] SELECT [Guid] FROM [fnGetGroupsList](@GroupGUID)
		DELETE [r] FROM [#GR] AS [r] INNER JOIN fnGroup_HSecList() AS [f] ON [r].[gUID] = [f].[GUID] where [f].[Security] > [dbo].[fnGetUserGroupSec_Browse](@UserGuid)
		DELETE [m] FROM [#MatTbl] AS [m]
		INNER JOIN [mt000] AS [mt] ON [MatGUID] = [mt].[Guid] 
		WHERE [mtSecurity] > [dbo].[fnGetUserMaterialSec_Browse](@UserGuid) 
		OR [Groupguid] NOT IN (SELECT [Guid] FRoM [#Gr])
		SET @cnt = @@ROWCOUNT
		IF @cnt > 0
			INSERT INTO [#SecViol] values(7,@cnt)
		
	END
	IF (@CostGUID = 0X00)
		INSERT INTO [#CostTbl] VALUES(0x00,0)
		
	CREATE CLUSTERED INDEX [mtInd] ON [#MatTbl]([MatGUID])
	CREATE CLUSTERED INDEX [stInd] ON [#StoreTbl]([StoreGUID])
	CREATE CLUSTERED INDEX [btInd] ON [#BillsTypesTbl]([TypeGuid])
	CREATE CLUSTERED INDEX [coInd] ON [#CostTbl]([CostGUID])
	IF (@InOutSign =0)
	BEGIN
		SET @In =1
		SET @Out = 1
	END 
	ELSE IF (@InOutSign =1)
	BEGIN
		SET @In =1
		SET @Out = -1
	END 
	ELSE
	BEGIN
		SET @In =-1
		SET @Out = 1
	END 

	CREATE TABLE [#ENDRESULT] 
		(	
		[stGuid]		[UNIQUEIDENTIFIER],
		[matPtr]		[UNIQUEIDENTIFIER],
		[Qnt]			[FLOAT] DEFAULT 0,
		[BonusQnt]		[FLOAT] DEFAULT 0,
		[Qnt2]			[FLOAT],
		[Qnt3]			[FLOAT],
		[FixedBiPrice]	[FLOAT] DEFAULT 0,
		[FixedBiDiscount]	[FLOAT] DEFAULT 0,
		[FixedBiExtra]	[FLOAT] DEFAULT 0,
		[FixedBiVat]	[FLOAT] DEFAULT 0,
		[CostPtr]		[UNIQUEIDENTIFIER],
		[MatSecurity]	[INT],
		[Security]		[INT], 
		[UserSecurity]	[INT],
		[coSecurity]	[INT],
		[MatCode]		[NVARCHAR](256) COLLATE ARABIC_CI_AI,
		[MatName]		[NVARCHAR](256) COLLATE ARABIC_CI_AI,
		
		[stLevel]		[INT] DEFAULT 0,
		[coLevel]		[INT] DEFAULT 0,
		[grLevel]		[INT] DEFAULT 0,
		[grPath]		[NVARCHAR](1000),
		[FLAG]			[INT] DEFAULT 0,
		[IsGroup]       [INT] DEFAULT 0
	)
	
	INSERT INTO [#ENDRESULT] 
		SELECT 
			[bi].[biStorePtr],
			[bi].[biMatPtr],
			SUM(CASE @UseUnit 
				WHEN 0 THEN CASE [btIsinput] WHEN 1 THEN @In*[bi].[biQty]  ELSE @Out*[bi].[biQty] END
				WHEN 1 THEN CASE [btIsinput] WHEN 1 THEN @In*(([bi].[biQty] ) / CASE [mtUnit2Fact] WHEN 0 THEN 1 ELSE [mtUnit2Fact] END) ELSE  @Out*(([bi].[biQty]) / CASE [mtUnit2Fact] WHEN 0 THEN 1 ELSE [mtUnit2Fact] END) END
				WHEN 2 THEN CASE [btIsinput] WHEN 1 THEN @In*(([bi].[biQty]) / CASE [mtUnit3Fact] WHEN 0 THEN 1 ELSE [mtUnit3Fact] END) ELSE @Out*(([bi].[biQty]) / CASE [mtUnit3Fact] WHEN 0 THEN 1 ELSE [mtUnit3Fact] END) END
				ELSE CASE [btIsinput] WHEN 1 THEN @In*([bi].[biQty]) ELSE @Out*([bi].[biQty]) END  /
					CASE [bi].[mtDefUnit]
					WHEN 1 THEN 1
					WHEN 2 THEN [bi].[mtUnit2Fact]
					ELSE  [bi].[mtUnit3Fact]
					
				END
			END),
			SUM(CASE @UseUnit 
				WHEN 0 THEN CASE [btIsinput] WHEN 1 THEN @In*[bi].[biBonusQnt] ELSE @Out*[bi].[biBonusQnt] END
				WHEN 1 THEN CASE [btIsinput] WHEN 1 THEN @In*(([bi].[biBonusQnt]) / CASE [mtUnit2Fact] WHEN 0 THEN 1 ELSE [mtUnit2Fact] END) ELSE  @Out*(([bi].[biBonusQnt]) / CASE [mtUnit2Fact] WHEN 0 THEN 1 ELSE [mtUnit2Fact] END) END
				WHEN 2 THEN CASE [btIsinput] WHEN 1 THEN @In*(([bi].[biBonusQnt]) / CASE [mtUnit3Fact] WHEN 0 THEN 1 ELSE [mtUnit3Fact] END) ELSE @Out*(([bi].[biBonusQnt]) / CASE [mtUnit3Fact] WHEN 0 THEN 1 ELSE [mtUnit3Fact] END) END
				ELSE CASE [btIsinput] WHEN 1 THEN @In*([bi].[biBonusQnt]) ELSE @Out*([bi].[biBonusQnt]) END  /
					CASE [bi].[mtDefUnit]
					WHEN 1 THEN 1
					WHEN 2 THEN [bi].[mtUnit2Fact]
					ELSE  [bi].[mtUnit3Fact]
					
				END
			END),
			SUM([bi].[biCalculatedQty2] + CASE [mtUnit2Fact] WHEN 0 THEN 0 ELSE [bi].[biBonusQnt]/[mtUnit2Fact] END),
			SUM([bi].[biCalculatedQty3] + CASE [mtUnit3Fact] WHEN 0 THEN 0 ELSE [bi].[biBonusQnt]/[mtUnit3Fact] END),
			CASE WHEN [UserReadPriceSecurity] >= [bi].[buSecurity] THEN 1 ELSE 0 END * SUM(CASE [btIsinput] WHEN 1 THEN @In*([biUnitPrice] * [biQty] * [FixedCurrencyFactor]) ELSE @Out*([biUnitPrice] * [biQty] * [FixedCurrencyFactor]) END),
			CASE WHEN [UserReadPriceSecurity] >= [bi].[buSecurity] THEN 1 ELSE 0 END * SUM(CASE [btIsinput] WHEN 1 THEN @In*([biUnitDiscount] * [biQty] * [FixedCurrencyFactor]) ELSE @Out*([biUnitDiscount] * [biQty] * [FixedCurrencyFactor]) END),
			CASE WHEN [UserReadPriceSecurity] >= [bi].[buSecurity] THEN 1 ELSE 0 END * SUM(CASE [btIsinput] WHEN 1 THEN @In*((([biUnitExtra] * [biQty])) * [FixedCurrencyFactor]) ELSE @Out*((([biUnitExtra] * [biQty])) * [FixedCurrencyFactor]) END),
			CASE WHEN [UserReadPriceSecurity] >= [bi].[buSecurity] THEN 1 ELSE 0 END * SUM(CASE [btIsinput] WHEN 1 THEN @In*([biVat] * [FixedCurrencyFactor]) ELSE @Out*([biVat] * [FixedCurrencyFactor]) END),
			[bi].[biCostPtr],
			[mt].[mtSecurity],
			[bi].[buSecurity],
			[bt].[UserSecurity],
			[Co].[Security],
			[bi].[mtCode],
			CASE @Lang WHEN 0 THEN [bi].[mtName] ELSE CASE [bi].[mtLatinName] WHEN '' THEN [bi].[mtName] ELSE [bi].[mtLatinName] END END,
			0,0,0,'',
			0,0
			FROM [fnExtended_bi_Fixed](@CurrencyGUID) AS [bi]
				INNER JOIN [#MatTbl] AS [mt] ON [mt].[MatGUID] = [bi].[biMatPtr]
				INNER JOIN [#BillsTypesTbl] AS [bt] ON [bt].[TypeGuid] = [bi].[buType]
				INNER JOIN [#StoreTbl] AS [st] ON [st].[StoreGUID]=[bi].[biStorePtr]
				INNER JOIN [#CostTbl] AS [Co] ON [Co].[CostGUID] = [bi].[biCostPtr]
			WHERE 
				([buDate] BETWEEN @StartDate AND @EndDate )
				    	    AND [buIsPosted] = 1 
			GROUP BY 
				[bi].[biStorePtr],
				[bi].[biMatPtr],
				[bi].[biCostPtr],
				[mt].[mtSecurity],
				[bi].[buSecurity],
				[bt].[UserSecurity],
				[UserReadPriceSecurity],
				[Co].[Security],
				[bi].[mtCode],
				[bi].[mtName],
				[bi].[mtLatinName]	
	IF @shwEmptyMat > 0	
	BEGIN
		SELECT TOP 1 @StGUID = [stGuid] FROM [#ENDRESULT]
		INSERT INTO [#ENDRESULT] 
			([stGuid],[matPtr],[Qnt2],[Qnt3],[CostPtr],[MatSecurity],
			[Security],[UserSecurity],[coSecurity],[MatCode],[MatName])
			SELECT @StGUID,[mt].[MatGUID],0,0,0X00,[mtSecurity],0,0,0,CODE,[NAME]
			FROM [#MatTbl] AS [mt] 
			INNER JOIN MT000 [m] ON m.Guid= [mt].[MatGUID] 
			WHERE [mt].[MatGUID] NOT IN (SELECT [matPtr] FROM [#ENDRESULT] )
			
	END		   
	EXEC [prcCheckSecurity] @RESULT ='#ENDRESULT '
	DECLARE  @defCurr UNIQUEIDENTIFIER = (SELECT TOP 1 GUID FROM my000 WHERE CurrencyVal = 1);
	IF @PriceByPriceType > 0
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
			
			EXEC [prcGetAvgPrice]	@StartDate,	@EndDate, @MatGUID, @GroupGUID, @StoreGUID, @CostGUID, -1, @defCurr, 1, @SrcTypesguid,	0, 0
			
			UPDATE P
			SET APrice = (P.APrice/dbo.fnGetCurVal(@CurrencyGUID,@EndDate))
			FROM
				#t_Prices P

		END
		ELSE IF @PriceType = -1
			INSERT INTO [#t_Prices] SELECT [MatGUID], 0 FROM [#MatTbl]
		ELSE IF @PriceType = 2 AND @PricePolicy = 124 -- LastPrice with extra and discount
		BEGIN
			EXEC [prcGetLastPrice] @StartDate , @EndDate , @MatGUID, @GroupGUID, @StoreGUID, @CostGUID, -1,	@CurrencyGUID, @SrcTypesguid, 0, 0, 0 /*@CalcLastCost*/,	1 /*@ProcessExtra*/
		END
		ELSE
		BEGIN
			EXEC [prcGetMtPrice] @MatGUID,	@GroupGUID, -1, @CurrencyGUID, @CurrencyVal, @SrcTypesguid, @PriceType, @PricePolicy, 0, @UseUnit,@EndDate
	          
		END
		
		IF @UseUnit > 0
			UPDATE [t] SET [APrice] = [APrice] 
			* CASE @UseUnit 
				WHEN 1 THEN  CASE [Unit2Fact] WHEN 0 THEN 1 ELSE [Unit2Fact] END
				WHEN 2 THEN  CASE [Unit3Fact] WHEN 0 THEN 1 ELSE [Unit3Fact] END
				ELSE 
				CASE [DefUnit]
					WHEN 2 THEN  CASE [Unit2Fact] WHEN 0 THEN 1 ELSE [Unit2Fact] END
					WHEN 3 THEN  CASE [Unit3Fact] WHEN 0 THEN 1 ELSE [Unit3Fact] END
					ELSE 1 
				END 
			END 
			FROM [#t_Prices] AS [t] INNER JOIN [mt000] AS [MT] ON [mt].[Guid]= [mtNumber]
		UPDATE [r] SET [FixedbiPrice] = ([Qnt]+[BonusQnt]) *  [APrice],[FixedBiDiscount] = 0 ,[FixedBiExtra]	= 0, [FixedBiVat]	= 0 FROM [#EndRESULT] AS [r] INNER JOIN [#t_Prices] AS [t] ON [matPtr]= [mtNumber]
		

	END
	IF (@ShoeGroups >0)
	BEGIN
		INSERT INTO [#GRP] SELECT * FROM [dbo].[fnGetGroupsOfGroupSorted](@GroupGUID, 0)
		IF (@GrpLevel > 0)
			UPDATE [gr] SET [path] = [gr2].[path] FROM [#GRP] AS [GR] INNER JOIN (SELECT [path] FROM [#GRP] WHERE [Level] = (@GrpLevel - 1) ) AS [gr2] ON [gr].[path] LIKE [gr2].[path] + '%'  WHERE [Level] > (@GrpLevel - 1)		
		UPDATE [r] SET [grLevel] = [Level],[grPath]= [Path] 
		FROM [#ENDRESULT] AS [r]
		INNER JOIN [mt000] AS [mt] ON [mt].[Guid] = [matPtr]
		INNER JOIN [#GRP] AS [gr] ON [mt].[groupGuid] = [gr].[Guid]
		
		INSERT INTO [#ENDRESULT]
		SELECT 
			[stGuid],
			[gr].[GUID],
			SUM([Qnt]),
			SUM([BonusQnt]),
			SUM([Qnt2]),
			SUM([Qnt3]),
			SUM([FixedBiPrice]),
			SUM([FixedBiDiscount]),
			SUM([FixedBiExtra]),	
			SUM([FixedBiVat]),
			[CostPtr],
			0,
			0,
			0,
			[coSecurity],
			[gr1].[Code],
			CASE @Lang WHEN 0 THEN [gr1].[Name] ELSE CASE [gr1].[LatinName] WHEN '' THEN [gr1].[Name] ELSE [gr1].[LatinName] END END ,
			0,
			0,
			[gr].[Level],
			[gr].[Path],
			0,1
		FROM ([#ENDRESULT] AS [r]
		INNER JOIN [mt000] AS [mt] ON [mt].[Guid] = [matPtr]
		INNER JOIN [#GRP] AS [gr] ON [mt].[groupGuid] = [gr].[Guid])
		INNER JOIN [gr000] AS [gr1] ON [gr].[GUID] = [gr1].[GUID]
		GROUP BY 
			[stGuid],
			[gr].[GUID],
			[CostPtr],
			[gr1].[Security],
			[coSecurity],
			[gr1].[Code],
			[gr1].[Name],
			[gr1].[LatinName],
			[gr].[Level],
			[gr].[Path]
		SELECT @Cnt = MAX([LEVEL]) FROM [#GRP]
		WHILE @Cnt > 0
		BEGIN
			INSERT INTO [#ENDRESULT]
			SELECT 
				[stGuid],
				[gr].[GUID],
				SUM([Qnt]),
				SUM([BonusQnt]),
				SUM([Qnt2]),
				SUM([Qnt3]),
				SUM([FixedBiPrice]),
				SUM([FixedBiDiscount]),
				SUM([FixedBiExtra]),	
				SUM([FixedBiVat]),	
				[CostPtr],
				0,
				0, 
				0,
				[coSecurity],
				[gr1].[Code],
				CASE @Lang WHEN 0 THEN [gr1].[Name] ELSE CASE [gr1].[LatinName] WHEN '' THEN [gr1].[Name] ELSE [gr1].[LatinName] END END ,
				0,
				0,
				[gr].[Level],
				[gr].[Path],
				0,1
			FROM ([#ENDRESULT] AS [r]
			INNER JOIN [gr000] AS [mt] ON [mt].[Guid] = [matPtr]
			INNER JOIN [#GRP] AS [gr] ON [mt].[ParentGuid] = [gr].[Guid])
			INNER JOIN [gr000] AS [gr1] ON [gr].[GUID] = [gr1].[GUID]
			WHERE [r].[grLevel] = @cnt AND [IsGroup] = 1
			GROUP BY 
				[stGuid],
				[gr].[GUID],
				[CostPtr],
				[coSecurity],
				[gr1].[Code],
				[gr1].[Name],
				[gr1].[LatinName],
				[gr].[Level],
				[gr].[Path]
			
			SET @Cnt = @Cnt - 1
		END
		IF @ShowMat = 0
			DELETE [#ENDRESULT] WHERE [IsGroup] = 0
		IF (@GrpLevel > 0)
			DELETE [#ENDRESULT] WHERE [IsGroup] = 1 AND [grLevel] > (@GrpLevel - 1)
	
	END

	IF (@StLevel <> 0)
	BEGIN
		SELECT @Cnt = MAX([LEVEL]) - 1 FROM [fnGetStoresListByLevel](@StoreGUID,0 ) 
		
		INSERT INTO [#TStore] SELECT * FROM [fnGetStoresListByLevel](@StoreGUID, 0)
		UPDATE [r] SET [stLevel] = [st].[Level]
		FROM [#ENDRESULT] AS [r] INNER JOIN [#TStore]AS [st] ON [st].[Guid] = [r].[stGuid]
		WHILE @Cnt > 0
		BEGIN
			INSERT INTO  [#ENDRESULT] ([stGuid],[matPtr],[Qnt],[BonusQnt],[Qnt2],[Qnt3],[FixedBiPrice],[FixedBiDiscount],[FixedBiExtra],[FixedBiVat],[CostPtr],[MatCode],[matName],[stLevel],[grLevel],[grPath],[IsGroup])
				SELECT [s].[Guid],[matPtr],SUM([Qnt]),SUM([BonusQnt]),SUM([Qnt2]),SUM([Qnt3]),SUM([FixedBiPrice]),SUM([FixedBiDiscount]),SUM([FixedBiExtra]),SUM([FixedBiVat])
				,[CostPtr],[MatCode],[matName],@Cnt ,[grLevel],[grPath],[IsGroup]
				FROM ([#ENDRESULT] AS [r] 
				INNER JOIN [vwSt] [st] ON [st].[stGuid] = [r].[stGuid])
				INNER JOIN [#TStore] AS [s] ON [s].[Guid] = [st].[stParent]
				WHERE [s].[Level] = @Cnt
				GROUP BY [matPtr], [CostPtr] ,[MatCode],[MatName],[s].[Guid],[grLevel],[grPath],[IsGroup]
			SET @Cnt = @Cnt - 1 
		END
	END
	--DECLARE @coSorted [INT]
	--SET @coSorted = @Sorted + 1
	IF (@CoLevel <> 0)
	BEGIN
		INSERT INTO [#TCOST] SELECT * FROM [fnGetCostsListWithLevel](@CostGUID,1) --WHERE [LEVEL] <= @CoLevel -1
		SET @Cnt = (SELECT MAX([LEVEL]) FROM [#TCOST]) 
		UPDATE [r] SET [coLevel] = [co].[Level]
		FROM [#ENDRESULT] AS [r] INNER JOIN [#TCOST]AS [co] ON [co].[Guid] = [CostPtr]
		
		WHILE @Cnt >= 0
		BEGIN
			INSERT INTO  [#ENDRESULT] ([stGuid],[stLevel]	,[matPtr],[Qnt],[BonusQnt],[Qnt2],[Qnt3],[FixedBiPrice],[FixedBiDiscount],[FixedBiExtra],[FixedBiVat],[CostPtr],[MatName],[MatCode],[grLevel],[coLevel],[grPath],[IsGroup])
				SELECT [stGuid],[stLevel],[matPtr],SUM([Qnt]),SUM([BonusQnt]),SUM([Qnt2]),SUM([Qnt3]),SUM([FixedBiPrice]),SUM([FixedBiDiscount]),SUM([FixedBiExtra]),SUM([FixedBiVat]),[c].[Guid],[matName],[matCode],[grLevel],@Cnt   ,[grPath],[IsGroup] 
				FROM ([#ENDRESULT] AS [r] 
				INNER JOIN [vwCo] [co] ON [co].[CoGuid] = [r].[CostPtr])
				INNER JOIN  [#TCOST] AS [c] ON [Co].[coParent] = [c].[Guid]
				WHERE [c].[Level] = @Cnt 
				GROUP BY [matPtr], [stGuid],[stLevel],[c].[Guid],[matName],[matCode],[grLevel],[grPath],[IsGroup]
			SET @Cnt = @Cnt -1 
		END
	END
	--DECLARE @Count INT
	--SELECT @Count = COUNT(*) FROM [#ENDRESULT] HAVING COUNT(*)> 0
	--IF (@HrtAxe = 0) 
	--	INSERT INTO [#ENDRESULT] ([stGuid],[FLAG],[Qnt]) SELECT [st].[stGuid], -1,@Count from [vwSt] AS [st] INNER JOIN [#ENDRESULT] [r] ON [r].[stGuid] = [st].[stGuid] WHERE @StLevel = 0 OR [stLevel] <= @StLevel
	--ELSE IF (@HrtAxe = 1) 
	--BEGIN
	--	SELECT TOP 1 @StGUID = [stGuid] FROM [#ENDRESULT]
	--	INSERT INTO [#ENDRESULT] ([stGuid],[CostPtr],[FLAG],[Qnt]) SELECT @StGuid,ISNULL([co].[coGuid],0X00),-1,@Count from [vwCo] AS [co] RIGHT JOIN [#ENDRESULT] [r] ON [r].[CostPtr] = [co].[coGuid] WHERE @coLevel = 0 OR [coLevel] <= @coLevel - 1
	--END
	--ELSE
	--IF (@HrtAxe != 0) AND  (@HrtAxe != 1)
	--BEGIN 
	--	SELECT TOP 1 @StGUID = [stGuid] FROM [#ENDRESULT]
	--	INSERT INTO [#ENDRESULT] ([stGuid],[matPtr],[MatCode],[MatName],[FLAG],[Qnt]) SELECT @StGUID,[mt].[Guid],[Code],[Name], -1,@Count FROM [mt000] AS [mt] INNER JOIN [#ENDRESULT] AS [r] ON [r].[matPtr] = [Guid]
	--	IF (@ShoeGroups = 1)
	--		INSERT INTO [#ENDRESULT] ([stGuid],[matPtr],[MatCode],[MatName],[FLAG],[Qnt],[isGroup]) SELECT @StGUID,[mt].[Guid],[Code],[Name], -1,@Count,1 FROM [gr000] AS [mt] INNER JOIN [#ENDRESULT] AS [r] ON [r].[matPtr] = [Guid]
	--END
	
	IF (@VrtAxe = 0)
		SET @Sql = ' SELECT [st].[stGuid], [st].[stName], [st].[stCode], [st].[stLatinName] '
	ELSE IF (@VrtAxe = 1)
		SET @Sql = ' SELECT ISNULL([co].[coGuid],0X00) AS [coGuid], [co].[coName], [co].[coCode], [co].[coLatinName] '
	ELSE 
		SET @Sql = ' SELECT [MatPtr], [MatName], [MatCode] '
	
	IF (@MainAxe = 1)
			SET @Sql = @Sql + ' ,[st].[stGuid], [st].[stName], [st].[stCode], [st].[stLatinName] '
	ELSE IF (@MainAxe = 2)
		SET @Sql = @Sql +  ' ,ISNULL([co].[coGuid],0X00) AS [coGuid], [co].[coName], [co].[coCode], [co].[coLatinName] '
	ELSE IF (@MainAxe = 3)
		SET @Sql = @Sql + ' ,[MatPtr], [matName], [matCode] '
	
	IF (@HrtAxe = 0)
		SET @Sql = @Sql + ',[st].[stGuid], [st].[stName], [st].[stCode], [st].[stLatinName] '
	ELSE IF (@HrtAxe = 1)
		SET @Sql = @Sql + ',ISNULL([co].[coGuid],0X00) AS [coGuid], [co].[coName], [co].[coCode], [co].[coLatinName] '
	ELSE 
		SET @Sql = @Sql + ',[MatPtr], [matName], [matCode] '
	
	IF ((@StLevel <> 0 ) AND ((@HrtAxe = 0) OR (@MainAxe = 1) OR (@VrtAxe = 0)))
		SET @Sql =@Sql + ' ,[fst].[PATH] AS stPATH'  
	IF ((@CoLevel <> 0) AND ((@CoLevel <> 0) AND ((@HrtAxe = 1) OR (@MainAxe = 2) OR (@VrtAxe = 1))))
		SET @Sql =@Sql + ' ,[fco].[PATH] AS coPATH' 
	
	IF (@VrtAxe = 0) AND (@StLevel <> 0 )
		SET @Sql = @Sql + ',ISNULL([fst].[LEVEL],0) AS [VLEVEL] '
	ELSE IF (@VrtAxe = 1) AND (@CoLevel <> 0 )
		SET @Sql = @Sql + ',ISNULL([fco].[LEVEL],0) AS [VLEVEL] '
	ELSE
		SET @Sql = @Sql + ',0 AS [VLEVEL]'
	IF (@MainAxe <> 0)
	BEGIN
		IF (@MainAxe = 1) AND (@StLevel <> 0 )
			SET @Sql = @Sql + ',ISNULL([fst].[LEVEL],0) AS [MLEVEL] '
		ELSE IF (@MainAxe = 2) AND (@CoLevel <> 0 )
			SET @Sql = @Sql + ',ISNULL([fco].[LEVEL],0) AS [MLEVEL] '
		ELSE
		BEGIN
			IF (@ShoeGroups > 0) AND @ShowMat = 0
				SET @Sql = @Sql + ',CASE [IsGroup] WHEN 1 THEN [grLevel] ELSE 0 END AS [MLEVEL]'  
			ELSE 
				SET @Sql = @Sql + ',0 AS [MLEVEL]'
		END
	END	
	
	IF (@HrtAxe = 0) AND (@StLevel <> 0 )
		SET @Sql = @Sql + ',ISNULL([fst].[LEVEL],0) AS [HLEVEL] '
	ELSE IF (@HrtAxe = 1) AND (@CoLevel <> 0 )
		SET @Sql = @Sql + ',ISNULL([fco].[LEVEL],0) AS [HLEVEL] '
	ELSE
	BEGIN
		IF (@ShoeGroups > 0) AND @ShowMat = 0
			SET @Sql = @Sql + ',CASE [IsGroup] WHEN 1 THEN [grLevel] ELSE 0 END AS [HLEVEL]'  
		ELSE 
			SET @Sql = @Sql + ',0 AS [HLEVEL]'
	END
	SET @Sql =@Sql + ',SUM([Qnt]) AS [Qty],SUM([BonusQnt]) AS [BonusQnt] ,SUM([FixedBiPrice]) AS [APrice],SUM([FixedBiDiscount]) AS [Discount],SUM([FixedBiExtra]) AS [Extra],SUM([FixedBiVat]) AS [Vat] '
	SET @Sql = @Sql + ',[r].[FLAG]'
	IF  (@ShoeGroups = 1) AND( (@HrtAxe = 2) OR (@MainAxe = 3) OR (@VrtAxe = 2) )
		SET @Sql = @Sql + ',[IsGroup] AS [IsGroup], [grLevel] AS [GroupLevel]'
	ELSE 
		SET @Sql = @Sql + ',0 AS [IsGroup], 0 AS [GroupLevel]'
	SET @Sql = @Sql + '  FROM [#ENDRESULT] AS [r]'
	IF (@HrtAxe = 0) OR (@MainAxe = 1) OR (@VrtAxe = 0)
		SET @Sql = @Sql + '  INNER JOIN [vwSt] AS [st] ON [st].[stGuid] = [r].[stGuid] '
	IF (@HrtAxe = 1) OR (@MainAxe = 2) OR (@VrtAxe = 1)
		SET @Sql = @Sql + '  LEFT JOIN [vwCo] AS [Co] ON [Co].[CoGuid] = [r].[CostPtr] '
	IF ((@StLevel <> 0 ) AND ((@HrtAxe = 0) OR (@MainAxe = 1) OR (@VrtAxe = 0)))
			SET @Sql = @Sql + 'INNER JOIN [fnGetStoresListTree] (' + '''' +  CONVERT( [NVARCHAR](2000), @StoreGUID)+ ''',0) AS [fst] ON [fst].[Guid] = [r].[stGuid] '
	IF ((@CoLevel <> 0) AND ((@HrtAxe = 1) OR (@MainAxe = 2) OR (@VrtAxe = 1)))
		SET @Sql = @Sql + 'LEFT  JOIN [#TCOST] AS [fco] ON [fco].[Guid] = [r].[CostPtr] '
	IF  (@stLevel > 0) OR (@coLevel > 0)
		SET @Sql = @Sql + '		WHERE '
	IF (@coLevel > 0)
		SET @Sql = @Sql + '	[coLevel] <= ' +CAST (@coLevel AS NVARCHAR(256)) + '-1'
	IF  (@stLevel > 0) AND (@coLevel > 0)
		SET @Sql = @Sql + ' AND '
	IF  (@stLevel > 0) 
		SET @Sql = @Sql + '	[stLevel] <= ' +CAST (@stLevel AS NVARCHAR(256))
	SET @Sql = @Sql + ' GROUP BY [r].[FLAG],'
	
	IF (@VrtAxe = 0)
		SET @Sql = @Sql +  '[st].[stGuid], [st].[stName], [st].[stCode], [st].[stLatinName] '
	ELSE IF (@VrtAxe = 1)
		SET @Sql = @Sql + '[co].[coGuid], [co].[coName], [co].[coCode], [co].[coLatinName] '
	ELSE 
		SET @Sql = @Sql + '[MatPtr], [matName], [matCode] '
	IF  (@ShoeGroups = 1) AND( (@HrtAxe = 2) OR (@MainAxe = 3) OR (@VrtAxe = 2) )
		SET @Sql = @Sql + ',[IsGroup], [grLevel]'
	IF (@MainAxe = 1)
			SET @Sql = @Sql + ' ,[st].[stGuid], [st].[stName], [st].[stCode], [st].[stLatinName] '
	ELSE IF (@MainAxe = 2)
		SET @Sql = @Sql + ' ,[co].[coGuid], [co].[coName], [co].[coCode], [co].[coLatinName] '
	ELSE IF (@MainAxe = 3)
		SET @Sql = @Sql + ' ,[MatPtr], [matName], [matCode] '
	
	IF (@HrtAxe = 0)
		SET @Sql = @Sql + ',[st].[stGuid], [st].[stName], [st].[stCode], [st].[stLatinName] '
	ELSE IF (@HrtAxe = 1)
		SET @Sql = @Sql + ',[co].[coGuid], [co].[coName], [co].[coCode], [co].[coLatinName] '
	ELSE 
		SET @Sql = @Sql + ',[MatPtr], [matName], [matCode] '
		
	IF  ((@StLevel <> 0 ) AND ((@HrtAxe = 0) OR (@MainAxe = 1) OR (@VrtAxe = 0)))
		SET @Sql =@Sql + ' ,[fst].[PATH]'
	IF ((@CoLevel <> 0) AND ((@CoLevel <> 0) AND ((@HrtAxe = 1) OR (@MainAxe = 2) OR (@VrtAxe = 1))))
		SET @Sql =@Sql + ' ,[fco].[PATH]'
	
	IF (@VrtAxe = 0) AND (@StLevel <> 0 )
		SET @Sql = @Sql + ',[fst].[LEVEL] '
	ELSE IF (@VrtAxe = 1) AND (@CoLevel <> 0 )
		SET @Sql = @Sql + ',[fco].[LEVEL]  '
	IF (@MainAxe <> 0)
	BEGIN
		IF (@MainAxe = 1) AND (@StLevel <> 0 )
			SET @Sql = @Sql + ',[fst].[LEVEL]  '
		ELSE IF (@MainAxe = 2) AND (@CoLevel <> 0 )
			SET @Sql = @Sql + ',[fco].[LEVEL]'
		ELSE
		BEGIN
			IF (@ShoeGroups > 0) AND @ShowMat = 0
				SET @Sql = @Sql + ',CASE [IsGroup] WHEN 1 THEN [grLevel] ELSE 0 END'
		END
	END	
	IF (@HrtAxe = 0) AND (@StLevel <> 0 )
		SET @Sql = @Sql + ',[fst].[LEVEL]  '
	ELSE IF (@HrtAxe = 1) AND (@CoLevel <> 0 )
		SET @Sql = @Sql + ',[fco].[LEVEL] '
	ELSE
	BEGIN
		IF (@ShoeGroups > 0) AND @ShowMat = 0
			SET @Sql = @Sql + ',CASE [IsGroup] WHEN 1 THEN [grLevel] ELSE 0 END '  
	END	
	IF  (@ShoeGroups = 1) AND( (@HrtAxe = 2) OR (@MainAxe = 3) OR (@VrtAxe = 2) )
		SET @Sql = @Sql + ',[grPath]'
	SET @Sql = @Sql + ' ORDER BY [r].[FLAG],'
	IF (@VrtAxe = 0)
	BEGIN
		IF (@StLevel = 0 )
		BEGIN
			SET @Sql = @Sql +'[st].[stCode],'
		END
		ELSE
			SET @Sql = @Sql + '[fst].[PATH],'
	END
	ELSE IF (@VrtAxe = 1)
	BEGIN
		IF (@CoLevel = 0 )
		BEGIN
			SET @Sql = @Sql +'[co].[coCode],'
		END
		ELSE
			SET @Sql = @Sql + '[fco].[PATH],'
	END
	ELSE 
	BEGIN
		IF @ShoeGroups = 0 
		BEGIN
			SET @Sql = @Sql +' [matCode],'
		END
		ELSE
		BEGIN
			SET @Sql = @Sql + '[grPath],[isGroup] DESC,'
			SET @Sql = @Sql + ' [matCode],'
		END
	END
	
	IF (@MainAxe = 1)
	BEGIN
		IF (@StLevel = 0 )
		BEGIN
			SET @Sql = @Sql + '[st].[stCode],'
		END
		ELSE
			SET @Sql = @Sql + '[fst].[PATH],'
	END
	ELSE IF (@MainAxe = 2)
	BEGIN
		IF (@CoLevel = 0 )
		BEGIN
			SET @Sql = @Sql +'[co].[coCode],'
		END 
		ELSE
			SET @Sql = @Sql + '[fco].[PATH],'
	END 
	ELSE IF (@MainAxe = 3)
	BEGIN
		IF @ShoeGroups = 0 
		BEGIN
			SET @Sql = @Sql + ' [matCode],'
		END
		ELSE
		BEGIN
			SET @Sql = @Sql + '[grPath],[isGroup] DESC,'
			SET @Sql = @Sql + ' [matCode],'
		END
	END
	
	IF (@HrtAxe = 0)
	BEGIN
		IF (@StLevel = 0 )
		BEGIN
			SET @Sql = @Sql + '[st].[stCode]'
		END
		ELSE
			SET @Sql = @Sql + '[fst].[PATH]'
	END
	ELSE IF (@HrtAxe = 1)
	BEGIN
		IF (@CoLevel = 0 )
		BEGIN
			SET @Sql = @Sql + '[co].[coCode]'
		END
		ELSE
			SET @Sql = @Sql + '[fco].[PATH]'
	END
	ELSE 
	BEGIN
		IF @ShoeGroups = 0 
		BEGIN
			SET @Sql = @Sql + ' [matCode]'
		END
		ELSE
		BEGIN
			SET @Sql = @Sql + '[grPath],[isGroup] DESC,'
			SET @Sql = @Sql + ' [matCode]'
		END
	END
	EXEC (@Sql)
	SELECT * FROM [#SecViol]			
#########################################################
#END
