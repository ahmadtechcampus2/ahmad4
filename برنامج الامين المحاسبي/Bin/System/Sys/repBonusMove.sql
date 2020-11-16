############################################################################
CREATE PROCEDURE repBonusMove
	@SrcTypesguid		UNIQUEIDENTIFIER,
	@StartDate			DATETIME,
	@EndDate			DATETIME,
	@AccGuid			[UNIQUEIDENTIFIER],
	@CustGuid 			[UNIQUEIDENTIFIER],
	@MatGUID 			[UNIQUEIDENTIFIER],
	@GroupGUID 			[UNIQUEIDENTIFIER],
	@StoreGUID  		[UNIQUEIDENTIFIER],
	@CostGUID 			[UNIQUEIDENTIFIER],
	@ShowType			[BIT] = 0, -- 0 Summry 1 Details, 
	@CurrencyGUID 		[UNIQUEIDENTIFIER] ,
	@Poseted			[INT] = -1,
	@UseUnit 			[INT], --1 First 2 Seccound 3 Third 0 Def 4 Move Unit
	@PriceByPriceType	[INT] = 0,
	@PriceType			[INT] = 0 ,
	@PricePolicy		[INT] = 0,
	@PayType			[INT] = -1,
	@ChTypeGuid 		[UNIQUEIDENTIFIER] ,
	@CurrencyVal		[FLOAT] = 1,
	@MatCondGuid		[UNIQUEIDENTIFIER] = 0x0,
	@InS				BIT = 1,
	@OutS				BIT = 1
AS
	SET NOCOUNT ON 
	
	DECLARE @Lang INT 
	SET @Lang = [dbo].[fnConnections_GetLanguage]()

	DECLARE @Sql [NVARCHAR](max)
	CREATE TABLE [#SecViol]( [Type] [INT], [Cnt] [INTEGER]) 
	CREATE TABLE [#MatTbl]( [MatGUID] [UNIQUEIDENTIFIER] , [mtSecurity] [INT]) 
	CREATE TABLE [#BillsTypesTbl]( [TypeGuid] [UNIQUEIDENTIFIER] , [UserSecurity] [INTEGER], [UserReadPriceSecurity] [INTEGER],[UnPostedSecurity] [INTEGER]) 
	CREATE TABLE [#StoreTbl](	[StoreGUID] [UNIQUEIDENTIFIER] , [Security] [INT]) 
	CREATE TABLE [#CostTbl]( [CostGUID] [UNIQUEIDENTIFIER] , [Security] [INT]) 
	CREATE TABLE [#CustTbl]( [CustGuid] [UNIQUEIDENTIFIER], [Security] [INT])
	CREATE TABLE [#MatTbl2]	([MatGUID] [UNIQUEIDENTIFIER], [mtSecurity] INT,  UnitFact FLOAT,
			Unit2Fact FLOAT, Unit3Fact FLOAT, UnitName NVARCHAR(256), [mtName] NVARCHAR(256),
			[mtCode] NVARCHAR(256), GroupGuid [UNIQUEIDENTIFIER]
			)
	CREATE TABLE [#CustTbl2] ([CustGuid] [UNIQUEIDENTIFIER], [Security] INT, [cuName] NVARCHAR(256))	
	CREATE TABLE [#t_Prices]
	(
		[mtNumber] 	[UNIQUEIDENTIFIER],
		[APrice] 	[FLOAT]
	)
	INSERT INTO [#MatTbl]			EXEC [prcGetMatsList] 		@MatGUID, @GroupGUID ,-1,@MatCondGuid
	INSERT INTO [#BillsTypesTbl]	EXEC [prcGetBillsTypesList2] @SrcTypesguid--, @UserGuid 
	INSERT INTO [#StoreTbl]			EXEC [prcGetStoresList] 	@StoreGUID 
	INSERT INTO [#CostTbl]			EXEC [prcGetCostsList] 		@CostGUID
	IF (@CostGUID = 0X00)
		INSERT INTO [#CostTbl] VALUES(0X00,0)
	INSERT INTO [#MatTbl2]	
	SELECT [MatGUID]  , [mtSecurity],  
		CASE @UseUnit 
		WHEN 0 THEN 1 
		WHEN 1 THEN CASE Unit2Fact WHEN 0 THEN 1 ELSE Unit2Fact END
		WHEN 2 THEN CASE Unit3Fact WHEN 0 THEN 1 ELSE Unit3Fact END 
			ELSE CASE defunit 
				WHEN 1 THEN 1 
				WHEN 2 THEN CASE Unit2Fact WHEN 0 THEN 1 ELSE Unit2Fact END
				ELSE CASE Unit3Fact WHEN 0 THEN 1 ELSE Unit3Fact END 
			END END AS UnitFact,
			CASE Unit2Fact WHEN 0 THEN 1 ELSE Unit2Fact END Unit2Fact, CASE Unit3Fact WHEN 0 THEN 1 ELSE Unit3Fact END Unit3Fact,
		CASE @UseUnit 
			WHEN 0 THEN Unity 
			WHEN 1 THEN CASE Unit2Fact WHEN 0 THEN Unity ELSE Unit2 END
			WHEN 2 THEN CASE Unit3Fact WHEN 0 THEN Unity ELSE Unit3 END
			ELSE 
			CASE defunit 
				WHEN 1 THEN Unity 
				WHEN 2 THEN CASE Unit2Fact WHEN 0 THEN Unity ELSE Unit2 END
				ELSE CASE Unit3Fact WHEN 0 THEN Unity ELSE Unit3 END
			END
		END AS UnitName,
		CASE @Lang WHEN 0 THEN [Name] ELSE CASE [LatinName] WHEN '' THEN [Name] ELSE [LatinName] END END[mtName],[Code] [mtCode],b.GroupGuid
	FROM [#MatTbl] a INNER JOIN [mt000] b ON a.[MatGUID] = b.[Guid]

	INSERT INTO [#CustTbl]			EXEC [prcGetCustsList] 		@CustGuid, @AccGuid
	IF @CustGuid = 0X00 AND  @AccGuid = 0X00
		INSERT INTO [#CustTbl] VALUES(0X00,0)	
	INSERT INTO [#CustTbl2]SELECT [CustGuid] , b.[Security] ,ISNULL( CASE @Lang WHEN 0 THEN [CustomerName] ELSE CASE [LatinName] WHEN '' THEN [CustomerName] ELSE [LatinName] END END,'') [cuName]
	FROM cu000 a RIGHT JOIN [#CustTbl] b ON a.[Guid] = [CustGuid]
	
	CREATE TABLE [#EndRESULT] 
	(
		[id]				INT IDENTITY(1,1),
		[buGuid]			[UNIQUEIDENTIFIER],
		[btGuid]			[UNIQUEIDENTIFIER],	
		[stGuid]			[UNIQUEIDENTIFIER] ,
		[cuGuid]			[UNIQUEIDENTIFIER] ,
		[matPtr]			[UNIQUEIDENTIFIER] ,
		[buDate]			DATETIME,
		[buNumber]			INT,
		[mtCode]			[NVARCHAR](256) COLLATE ARABIC_CI_AI,
		[mtName]			[NVARCHAR](256) COLLATE ARABIC_CI_AI,
		[cuName]			[NVARCHAR](256) COLLATE ARABIC_CI_AI,
		[Unit]			[NVARCHAR](256) COLLATE ARABIC_CI_AI,
		[BonusQnt]			[FLOAT],
		[FixedbiPrice]		[FLOAT] DEFAULT 0,
		[PayType]			[INT],
		[CheckType]			[UNIQUEIDENTIFIER],
		[CostPtr]			[UNIQUEIDENTIFIER] ,
		[MatSecurity]		[INT],
		[Security]			[INT], 
		[UserSecurity]		[INT],
		[UnitFact]			[FLOAT],
		[Branch]			[UNIQUEIDENTIFIER],
		[GroupGuid]			UNIQUEIDENTIFIER,
		[Dir]				INT,
		[Path]				NVARCHAR(max),
		[buFormatedNumber]	NVARCHAR(max)
	)
	INSERT INTO [#EndRESULT] ([buGuid],[btGuid],[stGuid],[matPtr],[buDate],[buNumber],[mtCode],[mtName],[cuName],[Unit],[BonusQnt],[FixedbiPrice],[PayType],[CheckType],[CostPtr],[MatSecurity],[Security],[UserSecurity],[cuGuid],[UnitFact],[Branch],[GroupGuid],[Dir], [buFormatedNumber])
	SELECT 
			[bi].[buGuid],[bi].[buType],[bi].[biStorePtr],[bi].[biMatPtr],[buDate],[buNumber],[mtCode],[mtName],
			CASE [buCustPtr] WHEN 0X00 THEN [buCust_Name] ELSE [cuName] END,
			UnitName ,
			[bi].[biBonusQnt] / [UnitFact],
			CASE WHEN [UserReadPriceSecurity] >= [bi].[buSecurity] THEN 1 ELSE 0 END * 
			CASE  WHEN @PriceType = 0xfff AND (ABS([FixedbiProfits]) > 0.0001 OR [btAffectCostPrice] = 0)
			THEN 
				(
				(([bi].[FixedbiPrice] * [bi].[biQty]) * CASE [biUnity]	WHEN 1 THEN 1 WHEN 2 THEN Unit2Fact ELSE Unit3Fact END) + (CASE [bi].[FixedbuTotal] WHEN 0 THEN 0 ELSE 
				((([FixedBuTotalExtra] * [btExtraAffectProfit]) -([bi].[FixedBuTotalDisc] * [btDiscAffectProfit]))*(([bi].[FixedbiPrice] * [bi].[biQty]) / CASE [biUnity]	WHEN 1 THEN 1 WHEN 2 THEN Unit2Fact ELSE Unit3Fact END)/[FixedbuTotal]) END)
				- [FixedbiProfits])/([biBonusQnt] + [biQty])
			ELSE
			([bi].[FixedbiPrice] )
				+ CASE [bi].[FixedbuTotal] WHEN 0 THEN 0 ELSE (([FixedBuTotalExtra] -[bi].[FixedBuTotalDisc])*(([bi].[FixedbiPrice] * [bi].[biQty]) / CASE [biUnity]	WHEN 1 THEN 1 WHEN 2 THEN Unit2Fact ELSE Unit3Fact END)/[FixedbuTotal]) END
			END,
			[buPayType],[buCheckTypeGuid],
			[bi].[biCostPtr],
			[mt].[mtSecurity],
			[bi].[buSecurity],
			CASE [buIsposted] WHEN  1 THEN [bt].[UserSecurity] ELSE [UnPostedSecurity] END,
			[bi].[buCustPtr],
			CASE WHEN @PriceByPriceType = 0 OR @PriceType = 2 OR @PriceType = 0xfff THEN UnitFact ELSE 1 END,
			[buBranch],[GroupGuid],
			CASE [btDirection]
				WHEN 1 THEN CASE @InS WHEN 1 THEN 1 ELSE -1 END 
				ELSE CASE @OutS WHEN 1 THEN 1 ELSE -1 END 
			END,
			CASE @lang 
				WHEN 0 THEN [buFormatedNumber] 
				ELSE CASE btLatinAbbrev WHEN '' THEN [buFormatedNumber] ELSE [buLatinFormatedNumber] END 
			END 
	FROM 
		[fn_bubi_Fixed](@CurrencyGUID) AS [bi]
		INNER JOIN [#MatTbl2] AS [mt] ON [mt].[MatGUID] = [bi].[biMatPtr]
		INNER JOIN [#CustTbl2] AS [cu] ON [cu].[CustGuid] = [bi].[buCustPtr]
		INNER JOIN [#BillsTypesTbl] AS [bt] ON [bt].[TypeGuid] = [bi].[buType]
		INNER JOIN [#StoreTbl] AS [st] ON [st].[StoreGUID] = [bi].[biStorePtr]
		INNER JOIN [#CostTbl] AS [co] ON [co].[CostGUID] = [bi].[biCostPtr]
	WHERE 
		[buDate] BETWEEN @StartDate AND @EndDate AND [biBonusQnt] > 0
		AND (@Poseted = -1 OR [buIsposted] = @Poseted)
		AND ( @PayType = -1 OR [buPayType] = @PayType)
		AND (@ChTypeGuid = 0X00 OR [buCheckTypeGuid] = @ChTypeGuid)
	ORDER BY [buDate],[buSortFlag],[buNumber],[buGuid],[biNumber]

	EXEC [prcCheckSecurity] @Result = '#EndRESULT'
	
	DECLARE  @defCurr UNIQUEIDENTIFIER = (SELECT TOP 1 GUID FROM my000 WHERE CurrencyVal = 1);

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
			EXEC [prcGetAvgPrice]	@StartDate,	@EndDate, @MatGUID, @GroupGUID, @StoreGUID, @CostGUID, -1, @defcurr, 1, @SrcTypesguid,	0, 0
			UPDATE P
				SET APrice =P.APrice/dbo.fnGetCurVal(@CurrencyGUID,@EndDate)
				FROM
					#t_Prices P
					INNER JOIN mt000 mt on  mt.GUID= p.mtNumber
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
		UPDATE [r] 
		
				SET [FixedbiPrice] =  
							(CASE @pricetype 
								WHEN  0x8000  THEN dbo.fnGetOutbalanceAveragePrice(matptr,[buDate])/dbo.fnGetCurVal(@CurrencyGUID,@EndDate) 
								ELSE APrice end 
							)
				FROM [#EndRESULT] AS [r] INNER JOIN [#t_Prices] AS [t] ON [matPtr]= [mtNumber] 
	END

	IF @ShowType > 0 
	BEGIN 
		SELECT 
			[buGuid], [btGuid], [stGuid], [buDate], [buNumber], [cuName], [Unit], [cuGuid],
			ISNULL([br].[Name], '') AS [brName],
			ISNULL(CASE [br].[LatinName] WHEN '' THEN [br].[Name] ELSE [br].[LatinName] END, '') AS [brLatinName],
			[mtCode] AS matCode, [mtName] AS matName, [matPtr], [Dir] * ISNULL(ABS([BonusQnt]), 0) AS BonusQnt, ISNULL(ABS([FixedbiPrice]), 0) * [UnitFact] [FixedbiPrice],
			[buFormatedNumber]
		FROM 
			[#EndRESULT]
			LEFT JOIN [br000] [br] ON [br].[Guid] = [Branch]
		ORDER BY
			[Id]
	END ELSE BEGIN 
		SELECT 
			[buGuid], [btGuid], [stGuid], [buDate], [buNumber], [cuName], [Unit], [cuGuid],
			ISNULL([br].[Name], '') AS [brName],
			ISNULL(CASE [br].[LatinName] WHEN '' THEN [br].[Name] ELSE [br].[LatinName] END, '') AS [brLatinName],
			SUM([Dir] * ISNULL(ABS([BonusQnt]), 0)) AS BonusQnt, 
			SUM(ISNULL(ABS([FixedbiPrice]), 0) * [UnitFact] * ISNULL(ABS([BonusQnt]), 0))/SUM(ISNULL(ABS([BonusQnt]), 1)) [FixedbiPrice],
			[buFormatedNumber]
		FROM 
			[#EndRESULT]
			LEFT JOIN [br000] [br] ON [br].[Guid] = [Branch]
		GROUP BY 
			[buGuid], [btGuid], [stGuid], [buDate], [buNumber], [cuName], [Unit], [cuGuid],
			[br].[Name], [br].[LatinName], [buFormatedNumber]
		ORDER BY
			MIN([Id])
	END 

	SELECT * FROM #SecViol
###################################################################################
#END
