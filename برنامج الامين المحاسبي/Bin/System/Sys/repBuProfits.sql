#############################################
CREATE PROCEDURE repBuProfits
	@StartDate 		[DATETIME],
	@EndDate 		[DATETIME],
	@SrcTypesguid	[UNIQUEIDENTIFIER],
	@CustGUID 		[UNIQUEIDENTIFIER],
	@CostGUID 		[UNIQUEIDENTIFIER], -- 0 all costs so don't Check cost or list of costs
	@CurrencyGUID 	[UNIQUEIDENTIFIER],
	@CurrencyVal 	[FLOAT],
	@Vendor 		[FLOAT],
	@SalesMan 		[FLOAT],
	@SortType		[INT],
	@AccPtr			AS [UNIQUEIDENTIFIER]=0X0,
	@PayType		[INT] = -1,
	@CheckGuid		[UNIQUEIDENTIFIER] = 0X0,
	@CustCond		[UNIQUEIDENTIFIER] = 0X0,
	@Lang			[INT] = 0,
	@CollectByCust	[BIT] = 0,
	@InOutNeg		[INT] = 0,
	@ShwMainAcc		[BIT] = 0,
	@profitWithTax  [BIT] = 0
AS
	SET NOCOUNT ON
	
	CREATE TABLE [#Cust]( [CustGUID] [UNIQUEIDENTIFIER], [Security] [INT])
	CREATE TABLE [#CustTbl]([CustGUID] [UNIQUEIDENTIFIER], [Security] [INT], [AccountGuid] [UNIQUEIDENTIFIER])
	CREATE TABLE [#Acc] ([Guid] [UNIQUEIDENTIFIER], [Level] INT ,[Path] VARCHAR(8000))
	INSERT INTO [#Cust]			EXEC [prcGetCustsList] 		@CustGUID,@AccPtr,@CustCond
	IF ((@CustGUID = 0x0) AND (@AccPtr =0X0) AND ( @CustCond = 0x00))
		INSERT INTO [#Cust] VALUES (0X00,0)
	INSERT INTO [#CustTbl] SELECT [cu].*, ISNULL([AccountGuid],0X00) AS [AccountGuid] FROM [#Cust] AS [cu] LEFT JOIN [Cu000] AS [c] ON [cu].[CustGUID] = [c].[Guid]
	IF @ShwMainAcc > 0
		INSERT INTO [#Acc] SELECT [f].[Guid],[f].[Level],[f].[Path] FROM [dbo].[fnGetAccountsList](@AccPtr,1) [f]
	EXEC [repGetBuProfits]	@StartDate, @EndDate, @SrcTypesguid,  @CurrencyGUID, @CostGUID, @CurrencyVal, @Vendor, @SalesMan, @SortType,@PayType,@CheckGuid,@Lang,@CollectByCust,@InOutNeg,@ShwMainAcc,@profitWithTax
/*
	prcConnections_add2  'ãÏíÑ'
	EXEC  [repBuProfits] '1/1/2006', '11/16/2006', 'bdbb0c28-0fb6-4992-9029-af83913f447e', '00000000-0000-0000-0000-000000000000', '00000000-0000-0000-0000-000000000000', '789a6cfb-dd4d-4242-ba6b-857d36d699ad', 1.000000, 0, 0, 0, '00000000-0000-0000-0000-000000000000', -1, '00000000-0000-0000-0000-000000000000', '00000000-0000-0000-0000-000000000000', 0, 0, 0 
*/
######################################################## 
CREATE PROCEDURE repGetBuProfits
	@StartDate 		[DATETIME],
	@EndDate 		[DATETIME],
	@SrcTypesGUID	[UNIQUEIDENTIFIER],
	@CurrencyGUID 	[UNIQUEIDENTIFIER],
	@CostGUID		[UNIQUEIDENTIFIER] = 0X0,
	@CurrencyVal 	[FLOAT],
	@Vendor 		[FLOAT],
	@SalesMan 		[FLOAT],
	@SortType		[INT],
	@PayType		[INT] = -1,
	@CheckGuid		[UNIQUEIDENTIFIER] = 0X0,
	@Lang			[INT] = 0,
	@CollectByCust	[BIT] = 0,
	@InOutNeg		[INT] = 0,
	@ShwMainAcc		[BIT] = 0,
	@profitWithTax  [BIT] = 0

AS
	SET NOCOUNT ON
	DECLARE @Level [INT]
	-- Creating temporary tables
	CREATE TABLE [#SecViol]( [Type] [INT], [Cnt] [INTEGER])
	CREATE TABLE [#BillsTypesTbl]( [TypeGuid] [UNIQUEIDENTIFIER], [UserSecurity] [INTEGER], [UserReadPriceSecurity] [INTEGER], [UnpstedSecurity] 
	[INTEGER])
	CREATE TABLE [#CostTbl]( [CostGUID] [UNIQUEIDENTIFIER], [Security] [INT])
	INSERT INTO [#CostTbl]		EXEC [prcGetCostsList] 		@CostGUID
	-- Filling temporary tables
	INSERT INTO [#BillsTypesTbl]	EXEC [prcGetBillsTypesList2] 	@SrcTypesguid--, @UserGuid
	CREATE TABLE [#Result]  
	(
		[BuType] 				[UNIQUEIDENTIFIER],
		[BuNumber] 				[UNIQUEIDENTIFIER] ,
		[buNum]					[FLOAT],-- bu number for sort
		[buDirection]			[INT],
		[buNotes] 				[NVARCHAR](1000) COLLATE ARABIC_CI_AI,
		[buDate] 				[DATETIME] NOT NULL DEFAULT '1/1/1980',
		[buCustPtr] 			[UNIQUEIDENTIFIER],
		[buTotal]				[FLOAT],
		[buTotalDisc]			[FLOAT], 
		[buTotalExtra]			[FLOAT],
		[buProfits]				[FLOAT],
		[Security]				[INT] DEFAULT 0,
		[UserSecurity] 			[INT] DEFAULT 0,
		[UserReadPriceSecurity]	[INT],
		[buVat]					[FLOAT],
		[AffectDisc]			[BIT],
		[AffectExtra]			[BIT],
		[AccountGuid]			[UNIQUEIDENTIFIER],
		[Path]					[NVARCHAR](4000) COLLATE ARABIC_CI_AI,
		[Level]					[INT],
		[PayType]				[INT],
		[CheckTypeGuid]			[UNIQUEIDENTIFIER],
		[bHasTTC]				BIT,
		BuFirstPay				[FLOAT],
		[btType]				[INT],
		[btBillType]		    [INT],
	)

	CREATE TABLE #Profit
	(
		BiGUID [UNIQUEIDENTIFIER] PRIMARY KEY, 
		BuGUID [UNIQUEIDENTIFIER],
		Cost [FLOAT], 
		Profit [FLOAT]
	)

	CREATE NONCLUSTERED INDEX IX_BUGUID ON #Profit(BuGuid);

	DECLARE @DefCurr UNIQUEIDENTIFIER = (SELECT dbo.fnGetDefaultCurr())


	IF @DefCurr = @CurrencyGUID
		INSERT INTO #Profit 
		SELECT biGUID, buGUID, biUnitCostPrice, biProfits 
		FROM vwbubi
		WHERE [buDate] BETWEEN @StartDate AND @EndDate
	ELSE
		INSERT INTO #Profit 
		SELECT BiGuid, BuGuid, Cost, Profit 
		FROM dbo.fnGetBillMaterialsCost(0x0, 0x0, @CurrencyGUID, @EndDate) t

	INSERT INTO [#Result]
	SELECT
		[r].[buType],
		[r].[buGUID],
		[r].[buNumber],
		[r].[buDirection],
		[r].[buNotes],
		[r].[buDate],
		[r].[buCustPtr],
		CASE WHEN [UserReadPriceSecurity] >= [BuSecurity] THEN ISNULL([r].[FixedBuTotal], 0) END AS [buTotal],
		CASE WHEN [UserReadPriceSecurity] >= [BuSecurity] THEN ISNULL([r].[FixedBuTotalDisc], 0) ELSE 0 END AS [buTotalDisc],
		CASE WHEN [UserReadPriceSecurity] >= [BuSecurity] THEN ISNULL([r].[FixedBuTotalExtra], 0)  ELSE 0 END AS [buTotalExtra],
		CASE WHEN [UserReadPriceSecurity] >= [BuSecurity] THEN ISNULL([prf].Profit, 0) ELSE 0 END AS [buProfits],
		[r].[buSecurity],
		CASE [r].[buIsPosted] WHEN 1 THEN [bt].[UserSecurity] ELSE [bt].[UnpstedSecurity] END,
		[bt].[UserReadPriceSecurity],
		[r].FixedbuVAT,
		[btDiscAffectProfit]|[btDiscAffectCost],[btExtraAffectProfit]|[btExtraAffectCost],[AccountGuid],'',0,
		[buPayType],[buCheckTypeGuid],
		CASE btVatSystem WHEN 2 THEN 1 ELSE 0 END,
		R.[FixedbuFirstPay],
		[r].[btType],
		[r].[btBillType]
	FROM
		[fnBu_Fixed](@CurrencyGUID) AS [r]
		INNER JOIN ( SELECT BuGuid, SUM(Profit) AS Profit
					 FROM #Profit [prf] GROUP BY BuGuid 
				   ) [prf] ON [prf].BuGuid = [r].buGUID
		INNER JOIN [#BillsTypesTbl] AS [bt] ON [r].[buType] = [bt].[TypeGuid]
		INNER JOIN [#CustTbl] AS [cu] ON [cu].[CustGuid] = [r].[buCustPtr]
	WHERE
		[buDate] BETWEEN @StartDate AND @EndDate
		AND( ([BuVendor] = @Vendor) 	OR (@Vendor = 0 ))	
		AND( ([BuSalesManPtr] = @SalesMan) 		OR (@SalesMan = 0))
		AND ((@PayType = -1)	OR ([buPayType] = @PayType))
		AND ((@CheckGuid = 0X0)	OR ([buCheckTypeGuid] = @CheckGuid))
		AND( (@CostGUID = 0x0)     OR EXISTS ( SELECT [CostGUID] FROM [#CostTbl] WHERE [CostGUID] = [buCostPtr] ) ) 
	---check sec

	EXEC [prcCheckSecurity]

	IF @ShwMainAcc > 0
	BEGIN
		SELECT @Level = MAX([Level]) FROM [#Acc]
		UPDATE [r] SET [Path] = [ac].[Path],[Level] = [AC].[Level] FROM [#Result] [r] INNER JOIN [#Acc] ac ON [ac].[Guid] = [AccountGuid]
		WHILE @Level > 0
		BEGIN
			INSERT INTO [#Result]
			(
				[buDirection],
				[buCustPtr],
				[buTotal],
				[buTotalDisc], 
				[buTotalExtra],			
				[buProfits],	
				[buVat],					
				[AffectDisc],			
				[AffectExtra],			
				[AccountGuid],			
				[Path],					
				[Level]					
			)
			SELECT 
				[buDirection],
				[ac].[Guid],
				ISNULL(SUM([buTotal]), 0),
				ISNULL(SUM([buTotalDisc]*[AffectDisc]), 0), 
				ISNULL(SUM([buTotalExtra]*[AffectExtra]), 0),			
				ISNULL(SUM([buProfits]), 0),
				ISNULL(SUM([buVat]), 0),
				1,
				1,
				[ac].[Guid],
				[ac].[Path],
				[ac].[Level]
			FROM 	[#Result] AS [r] INNER JOIN [ac000] AS [c] ON [r].[AccountGuid] = [c].[Guid] INNER JOIN [#Acc] ac ON [c].[ParentGuid] = [ac].[Guid]
			WHERE [r].[Level] = @Level
			GROUP BY
				[buDirection],
				[ac].[Guid],
				[ac].[Path],
				[ac].[Level]
			SET @Level = @Level - 1
					
		END
	END
	---return result set
	IF @CollectByCust = 0
	BEGIN
		SELECT 
			[BuType], 
			nt.Name as NoteName, 
			nt.LatinName  as NoteLatinName, 
			cu.CustomerName CustomerName, 
			cu.LatinName CustomerLatinName,
			bt.[Abbrev], 
			bt.[LatinAbbrev], [bDiscAffectCost], [bDiscAffectProfit], [bExtraAffectCost], [bExtraAffectProfit], [BuNumber],[buNum],[buDirection],[buNotes],[buDate],
			[buCustPtr],[buTotal],[buTotalDisc],[buTotalExtra],[buProfits],[buVat],[PayType],[CheckTypeGuid], 
			ISNULL(CASE @Lang WHEN 0 THEN [CustomerName] ELSE CASE [cu].[LatinName] WHEN '' THEN [CustomerName] ELSE [cu].[LatinName] END END,'') AS [Name],
			0 AS [DiscAffected], 
			0 AS [ExtraAffected],
			BuFirstPay
		FROM 
			[#Result] result 
			INNER JOIN [bt000] bt ON bt.GUID = result.BuType
			LEFT JOIN [nt000] nt ON nt.GUID = result.[CheckTypeGuid]
			LEFT JOIN [cu000] cu ON result.[buCustPtr] = cu.GUID
		WHERE [UserSecurity] >= result.[Security] 
		ORDER BY [budate], [btType], [btBillType], [buNum] ASC
	END
	ELSE
		SELECT 
			0x0 AS [BuType], 
			'' AS NoteName, 
			'' AS NoteLatinName, 
			'' AS CustomerName, 
			'' AS CustomerLatinName,
			'' AS [Abbrev], 
			'' AS [LatinAbbrev], 0 AS [bDiscAffectCost], 0 AS [bDiscAffectProfit], 0 AS [bExtraAffectCost], 0 AS [bExtraAffectProfit], 
			0 AS [BuNumber], 0 AS [buNum], 0 AS [buDirection],'' AS [buNotes], GETDATE() AS [buDate],

			[buCustPtr],
			ISNULL(CASE @Lang WHEN 0 THEN [CustomerName] ELSE CASE [LatinName] WHEN '' THEN [CustomerName] ELSE [LatinName] END END,'') AS [Name],
			SUM([buTotal] * CASE @InOutNeg WHEN 0 THEN [buDirection] WHEN 1 THEN 1 ELSE -1 END * [buDirection]) AS [buTotal] ,
			SUM([buTotalDisc] * CASE @InOutNeg WHEN 0 THEN [buDirection] WHEN 1 THEN 1 ELSE -1 END * [buDirection]) AS [buTotalDisc],
			SUM([buTotalExtra]* CASE @InOutNeg WHEN 0 THEN [buDirection] WHEN 1 THEN 1 ELSE -1 END * [buDirection]) AS [buTotalExtra],
			SUM((CASE @profitWithTax WHEN 1 THEN [buProfits] + [buVat] 
			                         ELSE [buProfits] END)* CASE @InOutNeg WHEN 0 THEN [buDirection] WHEN 1 THEN 1 ELSE -1 END * [buDirection]) AS [buProfits],
			SUM([buVat]* CASE @InOutNeg WHEN 0 THEN [buDirection] WHEN 1 THEN 1 ELSE -1 END * [buDirection]) AS [buVat],
			0 AS [PayType], 
			0x0 AS [CheckTypeGuid],
			SUM([buTotalDisc] * CASE @InOutNeg WHEN 0 THEN [buDirection] WHEN 1 THEN 1 ELSE -1 END * [buDirection] * [AffectDisc] ) AS [DiscAffected],
			SUM([buTotalExtra]* CASE @InOutNeg WHEN 0 THEN [buDirection] WHEN 1 THEN 1 ELSE -1 END * [buDirection] * [AffectExtra]) AS [ExtraAffected]
		FROM [#Result] AS [r] LEFT JOIN [Cu000] AS [cu] ON [cu].[Guid] = [buCustPtr]
		WHERE [UserSecurity] >= [r].[Security]	AND [buCustPtr] IS NOT NULL
		GROUP BY [buCustPtr],ISNULL(CASE @Lang WHEN 0 THEN [CustomerName] ELSE CASE [LatinName] WHEN '' THEN [CustomerName] ELSE [LatinName] END END,''),[Path]
		ORDER BY [Path],ISNULL(CASE @Lang WHEN 0 THEN [CustomerName] ELSE CASE [LatinName] WHEN '' THEN [CustomerName] ELSE [LatinName] END END,'')

	IF @CollectByCust = 0
	BEGIN
		 --Bill Mat Details
		 SELECT [a].[buGUID] AS [BillGUID],
		 [a].[mtName] AS [MatName],
		 [a].[biBillQty] + [a].[biBonusQnt] AS [Quantity],
		 [a].[mtUnityName] AS [Unity],
		 [a].FixedBiVAT AS [Vat],
		 [a].[biMatPtr] AS [MatGUID],
		 [a].[biGUID] AS [BiGUID],
		 [a].FixedbiUnitExtra * [a].[biBillQty] * [a].[mtUnitFact]  AS [biExtra],
		 [a].FixedbiUnitDiscount * [a].[biBillQty] * [a].[mtUnitFact] AS [biDiscount],
		 ([a].FixedBiPrice * [a].[biBillQty]) AS [biTotal],
		 [prf].Cost *  ( [a].[biBonusQnt] + [a].[biQty] )  + [prf].Profit + (@profitWithTax * [a].FixedBiVAT) AS [Value],
		 [prf].Cost * ( [a].[biBonusQnt] + [a].[biQty] )  AS [Cost] ,		 
		 [prf].Profit  AS [Profit],   -- [Value]-[Cost] without Vat 
		 ([prf].Profit + [a].FixedBiVAT) AS [ProfitWithVat],
		 ([a].FixedBuTotal + [a].[FixedBuVAT]) AS [buNetProfit],
		 CASE 
			WHEN R.buProfits = 0 THEN 0
			ELSE ([prf].Profit/ R.buProfits) 
		 END AS [NetTotalProfit], 
		 CASE 
			WHEN (R.buProfits + [a].[FixedBuVAT]) = 0 THEN 0
			ELSE (([prf].Profit + [a].FixedBiVAT)  / (R.buProfits + [a].[FixedBuVAT]))
		 END AS [NetTotalProfitWithVat] 
		 From 
			[fnExtended_bi_Fixed](@CurrencyGUID) AS [a]
			INNER JOIN #Profit AS [prf] ON [prf].BiGuid = [a].biGUID
			INNER JOIN #Result AS R ON a.buGUID = R.BuNumber
	END

	IF @ShwMainAcc = 0	
		SELECT [Guid],CASE @Lang WHEN 0 THEN [CustomerName] ELSE CASE [LatinName] WHEN '' THEN [CustomerName] ELSE [LatinName] END END AS [Name], 1 [IsCustomer] FROM [cu000] AS [cu] INNER JOIN (SELECT DISTINCT [buCustPtr] FROM [#Result]) AS [r] ON [cu].[Guid] = [r].[buCustPtr] 
	ELSE
		SELECT [Guid],CASE @Lang WHEN 0 THEN [CustomerName] ELSE CASE [LatinName] WHEN '' THEN [CustomerName] ELSE [LatinName] END END AS [Name], 1 [IsCustomer] FROM [cu000] AS [cu] INNER JOIN (SELECT DISTINCT [buCustPtr] FROM [#Result]) AS [r] ON [cu].[Guid] = [r].[buCustPtr] 
		UNION ALL
		SELECT [Guid],[Code] + '-' + CASE @Lang WHEN 0 THEN [Name] ELSE CASE [LatinName] WHEN '' THEN [Name] ELSE [LatinName] END END AS [Name], 0 [IsCustomer] FROM [ac000] AS [ac] INNER JOIN (SELECT DISTINCT [AccountGuid] FROM [#Result]) AS [r] ON [ac].[Guid] = [r].[AccountGuid] 
	
	SELECT * FROM [#SecViol]
###############################################################
#END