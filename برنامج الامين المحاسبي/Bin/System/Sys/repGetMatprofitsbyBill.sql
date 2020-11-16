#########################################################
CREATE PROCEDURE repGetMatprofitsbyBill
	@StartDate		[DateTime],
    @EndDate		[DateTime],
    @SrcTypesGuid	[UNIQUEIDENTIFIER],
    @StoreGuid		[UNIQUEIDENTIFIER],
    @CurrPtr		[UNIQUEIDENTIFIER] ,
    @PostedValue	[int] = -1, -- 0, 1, -1
	@GroupGUID		[UNIQUEIDENTIFIER] = 0X00,
	@CostGUID		[UNIQUEIDENTIFIER] = 0X00,
	@PriceType		[INT] = 2,
	@PricePolicy	[INT] = 121,
	@CurVal			[FLOAT] = 1,
	@LANG			[BIT] = 0,
	@MatCond		UNIQUEIDENTIFIER = 0x00
AS 
	SET NOCOUNT ON  
	DECLARE @Type UNIQUEIDENTIFIER
 	CREATE TABLE [#SecViol] ([Type] [INT], [Cnt] [INTEGER]) 
	CREATE TABLE [#BillsTypesTbl] ([TypeGuid] [UNIQUEIDENTIFIER], [UserSecurity] [INTEGER], [UserReadPriceSecurity] [INT], [UnPostedSecurity] [INTEGER]) 
	CREATE TABLE [#StoreTbl] ([StoreGUID] [UNIQUEIDENTIFIER], [Security] [INT]) 
	CREATE TABLE [#MatTbl] ([MatGUID] [UNIQUEIDENTIFIER], [mtSecurity] [INT]) 
	CREATE TABLE [#CostTbl] ([CostGUID] [UNIQUEIDENTIFIER], [Security] [INT]) 	
	CREATE TABLE #QTYS
	(
		[Qty]						FLOAT,
		[Bonus]						FLOAT,
		[Price]						FLOAT,
		[MatGUID]					[UNIQUEIDENTIFIER],
		[stGUID]					[UNIQUEIDENTIFIER],					
		[TotalDiscountPercent]		FLOAT,
		[TotalExtraPercent]			FLOAT	
	) 
	CREATE TABLE #Bills([TypeGuid] [UNIQUEIDENTIFIER], [SortNum] INT, [Type] INT, [BillType] INT,
		[UserSecurity] INT, [UnPostedSecurity] INT, ReadSec INT)
	CREATE TABLE [#mt] ([MatGUID] [UNIQUEIDENTIFIER], [mtSecurity] INT, mtName NVARCHAR(256),
						mtCode NVARCHAR(256), mtUnit2Fact FLOAT, mtUnit3Fact FLOAT)

	INSERT INTO [#BillsTypesTbl]	EXEC  [prcGetBillsTypesList2] 	@SrcTypesguid 
	INSERT INTO [#StoreTbl]			EXEC [prcGetStoresList] 		@StoreGUID 
	INSERT INTO [#MatTbl]			EXEC [prcGetMatsList]			0X00, @GroupGUID, -1
	INSERT INTO [#CostTbl]			EXEC [prcGetCostsList] 			@CostGUID 

	IF (@CostGUID = 0X00)
		INSERT INTO [#CostTbl] VALUES(0X00,0)

	INSERT INTO #Bills 
	SELECT  b.[TypeGuid],
			[SortNum],
			bt.Type,
			[BillType],
			[UserSecurity],
			[UnPostedSecurity],
			CASE  WHEN [UserReadPriceSecurity] > 0 THEN 1 ELSE 0 END AS ReadSec
	FROM [#BillsTypesTbl] [b] INNER JOIN [bt000] bt ON b.[TypeGuid] = bt.Guid 

	INSERT INTO [#mt] SELECT [MatGUID], [mtSecurity], CASE @LANG WHEN 0 THEN [Name] ELSE CASE [LatinName] WHEN '' THEN [Name] ELSE [LatinName] END END mtName, [Code] mtCode,
		CASE Unit2Fact WHEN 0 THEN 1 ELSE Unit2Fact END mtUnit2Fact,
		CASE Unit3Fact WHEN 0 THEN 1 ELSE Unit3Fact END mtUnit3Fact
	FROM [#MatTbl] mt INNER JOIN [mt000] m ON m.Guid = [MatGUID]
	
	CREATE TABLE [#T_Result]
	(
		[MatGuid]		[UNIQUEIDENTIFIER],
		[mtCode]		[NVARCHAR](256) COLLATE ARABIC_CI_AI, 
		[mtName]		[NVARCHAR](256) COLLATE ARABIC_CI_AI, 
		[Price]			[FLOAT],
		[buBillType]	[int], 
		[Security]		[INT],
		[UserSecurity]	[INT],
		[stSecurity]	[INT],
		[MatSecurity] 	[INT],
		[buType]		[UNIQUEIDENTIFIER],
		[SortNum]		[INT]
	) 

	INSERT INTO [#T_Result]
	SELECT 
		biMatPtr, mtCode, mtName,
		ISNULL(SUM([FixedCurrencyFactor] * ReadSec * 
			((([biQty] + biBonusQnt) * ([biPrice]) / (CASE [biUnity] WHEN 1 THEN 1 WHEN 2 THEN mtUnit2Fact ELSE mtUnit3Fact END))
				+ [biExtra] - [biDiscount] - [biBonusDisc]
				)+ [FixedTotalExtraPercent] - [FixedTotalDiscountPercent]), 0),
		[buSecurity],
		CASE [buIsPosted] WHEN 1 THEN [Bt].[UserSecurity] ELSE [UnPostedSecurity] END,
		[btBillType], st.[Security], [mtSecurity], [buType], [SortNum]	
	FROM
		[fn_bubi_Fixed](@CurrpTr) as [bu]
		INNER JOIN [#Bills] [Bt] ON [bu].[buType] = [Bt].[TypeGuid]
		INNER JOIN [#CostTbl] [co] ON [co].[CostGUID] = [biCostPtr]
		INNER JOIN [#mt] m ON m.[MatGUID] = biMatPtr
		INNER JOIN  [#StoreTbl] st ON [StoreGUID] = biStorePtr
		LEFT JOIN (SELECT SUM([diExtra] - [diDiscount]) DISCEXTRA, [diParent] FROM [vwdi] GROUP BY [diParent]) AS [di] ON [di].[diParent] = [buGuid] 
	WHERE  
		[buDate] BETWEEN @StartDate AND @EndDate  
		AND ([bu].[buIsPosted] = @PostedValue OR @PostedValue = -1) 
	GROUP BY
		biMatPtr, mtCode, mtName, [buSecurity],
		CASE [buIsPosted] WHEN 1 THEN [Bt].[UserSecurity] ELSE [UnPostedSecurity] END,
		[btBillType], st.[Security], [mtSecurity], [buType], [SortNum]

	SELECT @Type = [TypeGuid] FROM #Bills WHERE Type = 2 AND [SortNum] = 2

	IF @Type IS NOT NULL
	BEGIN
		EXEC prcCalcEPBill @StartDate, @EndDate, @CurrPtr, @CostGUID, @StoreGuid, @PriceType, @PricePolicy, @PostedValue, @CurVal, 0	

		INSERT INTO #T_Result
		SELECT m.[MatGUID],	[mtCode], [mtName],	q.[Price] * (q.Qty + q.[Bonus]), 0, 0, 5, 0, 0, @Type, 2
		FROM #QTYS q INNER JOIN [#mt] M ON m.[MatGUID] = q.[MatGUID]
	END

	EXEC  [prcCheckSecurity] @Result = '#T_Result'

	CREATE TABLE #Types
	(
		ID			 INT IDENTITY(0,1),
		[TypeGuid]	 UNIQUEIDENTIFIER,
		[BillType]	 INT
	)

	INSERT INTO #Types ([TypeGuid], [BillType])
		SELECT a.[TypeGuid], a.[BillType]
		FROM #Bills a INNER JOIN (SELECT [buType] FROM #T_Result group by [buType]) b ON a.[TypeGuid] = [buType]
		ORDER BY a.[BillType], a.[SortNum], [TypeGuid]

	SELECT mt.GUID AS MatGuid, mt.Code AS [mtCode], mt.Name AS [mtName] -- DISTINCT a.[MatGuid], a.[mtCode], a.[mtName]
	FROM mt000 mt
	WHERE EXISTS(SELECT 1 FROM #T_Result a INNER JOIN #Types b ON a.buType = [TypeGuid] WHERE a.[MatGuid] = mt.GUID)
	ORDER BY [mt].[Code], [mt].[GUID]

	SELECT a.[MatGuid],	a.[mtCode],	a.[mtName],	SUM([Price]) Price,	[id]
	FROM #T_Result a INNER JOIN #Types b ON a.buType = [TypeGuid]
	GROUP BY [MatGuid], [mtCode], [mtName], [id] 
	ORDER BY [mtCode], [MatGuid], [id]


	SELECT ID, [TypeGuid], [BillType] FROM #Types ORDER BY ID 

	SELECT * FROM [#SecViol]
/*
EXEC repGetMatprofitsbyBill '1/1/2007','12/31/2007',0X00,0X00,'20689634-C035-43F9-8870-988CBD98EBA6'
*/
###################################################################################
#END 	
