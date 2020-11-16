#################################################################################
CREATE PROCEDURE repMatSNBSheet
	@curGuid	[UNIQUEIDENTIFIER], 
	@CostGUID 		[UNIQUEIDENTIFIER] = 0x00,
	@StartDate		DATETIME = '1/1/1980',
	@EndDate		DATETIME = '1/1/2070'
AS
	SET NOCOUNT ON
	DECLARE @CNT INT
	CREATE TABLE [#SecViol]( [Type] [INT], [Cnt] [INTEGER])
	CREATE TABLE [#CostTbl2]( [CostGUID] UNIQUEIDENTIFIER, [Security] INT)
	CREATE TABLE [#sn](ID INT, cnt INT, [ParentGuid] UNIQUEIDENTIFIER)

	INSERT INTO [#CostTbl2] SELECT * FROM [#CostTbl]
	IF @CostGUID = 0X00
		INSERT INTO [#CostTbl2] VALUES(0X00,0)
	CREATE TABLE [#Result]
	(
		[Id]						[INT] IDENTITY(1,1),
		[MatPtr]					[UNIQUEIDENTIFIER] ,
		[biStorePtr]				[UNIQUEIDENTIFIER] ,
		[biPrice]					[FLOAT],
		[biGuid]				[UNIQUEIDENTIFIER],
		[Security]					[INT],
		[UserSecurity] 				[INT],
		[UserReadPriceSecurity]		[INT],
		[BillNumber]				[FLOAT],
		[MatSecurity] 				[INT],
		[buDirection]				[INT]
	)
	INSERT INTO [#Result]
	(
		[MatPtr],[biStorePtr],		
		[biPrice],[biGuid],[Security],[UserSecurity],			
		[UserReadPriceSecurity],[BillNumber],			
		[MatSecurity],[buDirection]			
	)
	SELECT
		--[sn].[SN],
		[mtTbl].[MatGuid],
		[bu].[biStorePtr],
		CASE WHEN [UserReadPriceSecurity] >= [bu].[BuSecurity] THEN 
		(([bu].[biPrice] * [biQty]) +
		(
			[FixedCurrencyFactor] *
			(
				(
					[biQty] * [BiPrice] / (CASE [BuTotal] WHEN 0 THEN 1 ELSE [BuTotal] END) * 
					( ([BuTotalExtra] - [BuItemsExtra])- ([BuTotalDisc]  - [BuItemsDisc]))
				)+ ([biExtra] - [biDiscount])
			)
		))/([biQty] + [biBonusQnt])
		 else 0 end,
		[biGuid],
		[buSecurity],
		[bt].[UserSecurity],
		[bt].[UserReadPriceSecurity],
		[buNumber],
		[mtTbl].[mtSecurity],[buDirection]
	FROM
		--[SN000] AS [sn] 
		fn_bubi_Fixed(@curGuid)AS [bu] --ON [bu].[biGUID] = [sn].[InGuid]
		INNER JOIN [#BillsTypesTbl] AS [bt] ON [bu].[buType] = [bt].[TypeGuid]
		INNER JOIN [#MatTbl2] AS [mtTbl] ON [bu].[biMatPtr] = [mtTbl].[MatGuid]
		INNER JOIN [#StoreTbl] AS [st] ON [st].[StoreGuid] = [bu].[biStorePtr]
		INNER JOIN  [#CostTbl2] AS [co] ON [co].[CostGUID] = [bu].[biCostPtr]
	WHERE
			[bu].[buIsPosted] != 0 AND
			[buDate] BETWEEN @StartDate	AND @EndDate	
		 
	ORDER BY
		[MatGuid],[buDate],[buSortFlag],[buNumber]
	---check sec
	CREATE CLUSTERED INDEX SERIN ON #RESULT(ID,[biGuid])
	EXEC [prcCheckSecurity]
	
	INSERT INTO [#sn] SELECT  MAX(CASE [buDirection] WHEN 1 THEN [Id] ELSE 0 END) AS ID ,SUM([buDirection]) AS cnt ,[sn].[ParentGuid] 
	FROM [snt000] AS [sn] INNER JOIN [#Result] [r] ON [sn].[biGuid] = [r].[biGuid] GROUP BY [sn].[ParentGuid],[stGuid] HAVING SUM(buDirection) > 0
	CREATE TABLE [#Isn2]
	(
		[SNID] [INT] IDENTITY(1,1),
		[id] [INT], 
		[cnt] [INT], 
		[Guid] UNIQUEIDENTIFIER,
		[SN] NVARCHAR(255) COLLATE ARABIC_CI_AI,
		[Length]	[INT]
	)
	CREATE TABLE [#Isn]
	(
		[SNID] [INT] ,
		[id] [INT], 
		[cnt] [INT], 
		[Guid] UNIQUEIDENTIFIER,
		[SN] NVARCHAR(255) COLLATE ARABIC_CI_AI,
		[Length]	[INT]
	)

	
	INSERT INTO [#Isn2] ([Guid],[id],[cnt],[SN],[Length]) SELECT   Guid,[ID] ,[cnt],[SN],LEN([SN])  FROM [#sn] INNER JOIN [snC000] ON [Guid] = [ParentGuid] ORDER BY SN
	INSERT INTO  #Isn SELECT *  FROM [#Isn2]
	IF EXISTS(SELECT * FROM [#Isn] WHERE [cnt] > 1)
	BEGIN
		SET @CNT = 1 
		WHILE (@CNT > 0)
		BEGIN
			INSERT INTO [#Isn] SELECT  SNID,MAX([R].[Id]),1,[I].[Guid]  ,[sn].[SN],[Length]  FROM [vcSNs] AS [sn] 
			INNER JOIN [#Result] [R] ON [sn].[biGuid] = [R].[biGuid] 
			INNER JOIN [#Isn] I ON [sn].[Guid] = [I].[Guid]  
			WHERE [R].[ID] NOT IN ( SELECT [ID] FROM [#Isn]) AND  [cnt] > 1
			GROUP BY [sn].[SN],[SNID],[Length],[I].[Guid]
			UPDATE [#Isn] SET [cnt] = [cnt] - 1 WHERE [cnt] > 1
			SET @CNT = @@ROWCOUNT
			
		END
	END
	DECLARE @Sql NVARCHAR(4000)
	--- Return first Result Set -- needed data
	SELECT
	[r].[MatPtr],[biStorePtr],1 AS [qty],SUM([r].[biPrice]) [biPrice]
	FROM
		[#Result] AS [r] INNER JOIN [#ISN] AS [SN] ON [sn].[Id] = [r].[Id] 
	 GROUP BY [r].[MatPtr],[biStorePtr]
#################################################################################
## Ì⁄ÿÌ‰« ‘Ã—… „‰ «·Õ”«»«  «· «»⁄… ·Õ”«» Œ «„Ì „⁄Ì‰ „— »…
CREATE PROCEDURE prcGetFinalAcc
	@StartDate 		DATETIME,  
	@EndDate 		DATETIME,     
	@CurPtr			UNIQUEIDENTIFIER,     
	@CurVal			FLOAT,    
	@CostGUID 		UNIQUEIDENTIFIER, -- 0 all costs so don't Check cost or list of costs  	
	@StGUID			UNIQUEIDENTIFIER, -- 0 all stores so don't check store or list of stores  	
	@Final			UNIQUEIDENTIFIER,    
	@DetailSubStores		INT,	 -- 1 show details 0 no details  for Stores 
	@PriceType				INT,	 
	@PricePolicy			INT,      
	@ShowDetails			INT,  -- 1= show Accounts Tree for the specific FinalAcc, 0 = show only balance for the specific FinalAcc     
	@ShowPosted				INT,
	@ShowUnPosted			INT,
	@RateType				INT = 0,
	@accLevel					INT = 1,
	@havePriceBySN			BIT = 0,
	@MatAccountGuid			UNIQUEIDENTIFIER = 0x0,
	@ShowProfitRatio		BIT = 0,
	@showAsT				BIT = 1
AS    
	--- 1s posted, 0 unposted -1 both       
	DECLARE @PostedType AS  INT
	DECLARE @TypeAccGuid1  [UNIQUEIDENTIFIER] 
	DECLARE @TypeAccGuid2  [UNIQUEIDENTIFIER] 
	DECLARE @Level INT, @MaxLevel INT   
	DECLARE @FinalType	BIT 

	IF( (@ShowPosted = 1) AND (@ShowUnPosted = 0) )		         
		SET @PostedType = 1      
	IF( (@ShowPosted = 0) AND (@ShowUnPosted = 1))         
		SET @PostedType = 0      
	IF( (@ShowPosted = 1) AND (@ShowUnPosted = 1))         
		SET @PostedType = -1      
	SET NOCOUNT ON	 
	DECLARE 
		@UserGUID [UNIQUEIDENTIFIER],
		@UserSec  [INT],
		@AccSec	  [INT],
		@RecCnt	  [INT]    
	IF @RateType = 1
		SELECT TOP 1 @CurPtr = [Guid] FROM [my000] WHERE CurrencyVal = 1
	SET @UserGUID = [dbo].[fnGetCurrentUserGUID]()    
	-- User Security on entries    
	SET @UserSec = [dbo].[fnGetUserEntrySec_Browse](@UserGUID, DEFAULT)    
	-- User Security on Browse Account
	SET @AccSec = dbo.fnGetUserAccountSec_Browse(@UserGUID)    
	
	-- Security Table ------------------------------------------------------------    
	CREATE TABLE #SecViol( Type INT, Cnt INTEGER)   
	
	--=================================================================
	--  AccList Sorted    
	--=================================================================
	CREATE TABLE [#AccountsList]    
	(    
		[guid]		[UNIQUEIDENTIFIER],     
		[level]		[INT],    
		[path]		[NVARCHAR](max) COLLATE ARABIC_CI_AI    
	)   
	--==================================================================== 
	CREATE TABLE [#FinalResult]
	(       
		[acGUID]			[UNIQUEIDENTIFIER],    
		[acCodeName]		[NVARCHAR](500) COLLATE ARABIC_CI_AI,    
		[acCodeLatinName]	[NVARCHAR](500) COLLATE ARABIC_CI_AI,    
		[acFinal]			[UNIQUEIDENTIFIER],    
		[acParent]			[UNIQUEIDENTIFIER],    
		[DebitOrCredit]		[INT]	DEFAULT 0,    
		[acCurPtr]			[UNIQUEIDENTIFIER],    
		[acCurVal]			[FLOAT] DEFAULT 0, 	   
		[acCurCode]			[NVARCHAR](500) COLLATE ARABIC_CI_AI,       
		[Debit] 			[FLOAT] DEFAULT 0,     
		[Credit] 			[FLOAT] DEFAULT 0,     
		[CurDebit] 			[FLOAT] DEFAULT 0,     
		[CurCredit] 		[FLOAT] DEFAULT 0,    
		[Level]				[INT]	DEFAULT 0,    
		[Path] 				[NVARCHAR](max) COLLATE ARABIC_CI_AI,   
		[RecType] 			[INT] DEFAULT 0,	-- = 0 Acc  =1 ParentAcc = 2 FinalAcc    
		[fn_AcLevel]		[INT],	-- OrderID for The FinalAcc
		[FLAG]				[INT],
		[Id]				[INT],
		[rank]				int
	) 
	
	CREATE TABLE [#TVFinalResult]
	(       
		[dacGUID]			[UNIQUEIDENTIFIER],    
		[dacCodeName]		[NVARCHAR](500) COLLATE ARABIC_CI_AI,    
		[dacCodeLatinName]	[NVARCHAR](500) COLLATE ARABIC_CI_AI,    
		[dacParent]			[UNIQUEIDENTIFIER],    
		[dDebitOrCredit]		[INT]	DEFAULT 0,    
		[dacCurPtr]			[UNIQUEIDENTIFIER],    
		[dacCurVal]			[FLOAT] DEFAULT 0, 	   
		[dacCurCode]			[NVARCHAR](500) COLLATE ARABIC_CI_AI,       
		dBalance			FLOAT,
		dCurBalance			FLOAT,
		dLevel				INT DEFAULT 0,

		[cacGUID]			[UNIQUEIDENTIFIER],    
		[cacCodeName]		[NVARCHAR](500) COLLATE ARABIC_CI_AI,    
		[cacCodeLatinName]	[NVARCHAR](500) COLLATE ARABIC_CI_AI,     
		[cacParent]			[UNIQUEIDENTIFIER],     
		[cDebitOrCredit]		[INT]	DEFAULT 0,    
		[cacCurPtr]			[UNIQUEIDENTIFIER],    
		[cacCurVal]			[FLOAT] DEFAULT 0, 	   
		[cacCurCode]			[NVARCHAR](500) COLLATE ARABIC_CI_AI,       
		cBalance			FLOAT,
		cCurBalance			FLOAT,
		cLevel				INT DEFAULT 0,

		[acFinal]			[UNIQUEIDENTIFIER],
		[Debit] 			[FLOAT] DEFAULT 0,     
		[Credit] 			[FLOAT] DEFAULT 0,     
		[CurDebit] 			[FLOAT] DEFAULT 0,     
		[CurCredit] 		[FLOAT] DEFAULT 0,    
		[Path] 				[NVARCHAR](max) COLLATE ARABIC_CI_AI,   
		[RecType] 			[INT] DEFAULT 0,	-- = 0 Acc  =1 ParentAcc = 2 FinalAcc    
		[fn_AcLevel]		[INT],	-- OrderID for The FinalAcc
		[FLAG]				[INT],
		[Id]				[INT],
		[rank]				int
	)     
	
	CREATE TABLE [#EResult]
	(       
		[acGUID]		[UNIQUEIDENTIFIER],    
		[acCodeName]		[NVARCHAR](500) COLLATE ARABIC_CI_AI,    
		[acCodeLatinName]	[NVARCHAR](500) COLLATE ARABIC_CI_AI,    
		[acFinal]			[UNIQUEIDENTIFIER],    
		[acParent]			[UNIQUEIDENTIFIER],    
		[DebitOrCredit]		[INT]	DEFAULT 0,    
		[acCurPtr]			[UNIQUEIDENTIFIER],    
		[acCurVal]			[FLOAT] DEFAULT 0, 	     
		[Debit] 			[FLOAT] DEFAULT 0,     
		[Credit] 			[FLOAT] DEFAULT 0,     
		[CurDebit] 			[FLOAT] DEFAULT 0,     
		[CurCredit] 		[FLOAT] DEFAULT 0,    
		[Level]				[INT]	DEFAULT 0,    
		[Path] 				[NVARCHAR](max) COLLATE ARABIC_CI_AI,   
		[RecType] 			[INT] DEFAULT 0,	-- = 0 Acc  =1 ParentAcc = 2 FinalAcc    
		[Security]			[INT],    
		[AccSecurity]		[INT],    
		[UserSecurity] 		[INT],
		[fn_AcLevel]		[INT],		-- OrderID for The FinalAcc
		[Flag]				[INT],
		[DFlag]				[INT],
		[ID]				[INT]
	)
	--=================================================================
	CREATE TABLE #FinalAccTbl
	( 
		[ID]				[INT] IDENTITY(1,1),
		[AcGuid]			[UNIQUEIDENTIFIER], 
		[AcCodeName]		[NVARCHAR](500) COLLATE ARABIC_CI_AI, 
		[AcCodeLatinName]	[NVARCHAR](500) COLLATE ARABIC_CI_AI, 
		[AcFinal]			[UNIQUEIDENTIFIER], 
		[AcParent]			[UNIQUEIDENTIFIER], 
		[DebitOrCredit]	[INT], 
		[AcCurPtr] 		[UNIQUEIDENTIFIER], 
		[AcCurVal]		[FLOAT],  
		[AccSecurity]	[INT], 
		[Level]			[INT]	 
	)      
	--==================================================================
	-- ·« Ì„ﬂ‰ «” Œœ«„ prcgetAccountslist    
	-- ·√‰Â ·« Ì√Œ– «·›—“    
	INSERT INTO #AccountsList    
	SELECT    
		[guid],    
		[level],    
		[path]    
	FROM     
		[fnGetAccountsList]( null, 1)
	
	--=================================================================
	--====================== Calc Acc Goods ===========================
	--=================================================================
	DECLARE @ShowUnLinked INT, @UseUnit INT, @DetailsStores	INT 
	DECLARE @MatGUID UNIQUEIDENTIFIER, @GroupPtr  UNIQUEIDENTIFIER, @SrcTypes UNIQUEIDENTIFIER 
	DECLARE @MatType INT
	DECLARE @FirstPeriodStGUID UNIQUEIDENTIFIER 
	
	SET @MatGUID = 0x0
	SET @GroupPtr = 0x0
	SET @SrcTypes = 0x0
	SET @MatType = 0
	SET @ShowUnLinked = 0 
	SET @UseUnit = 0 
	SET @DetailsStores = 1 
	
	-- Creating temporary tables  ---------------------------------------------------------- 
	CREATE TABLE [#MatTbl]( [MatGUID] [UNIQUEIDENTIFIER], [mtSecurity] [INT]) 
	CREATE TABLE [#MatTbl2]( [MatGUID] [UNIQUEIDENTIFIER], [mtSecurity] [INT]) 
	CREATE TABLE [#BillsTypesTbl]( [TypeGUID] [UNIQUEIDENTIFIER], [UserSecurity] [INTEGER], [UserReadPriceSecurity] [INTEGER])
	CREATE TABLE [#StoreTbl]([StoreGUID] UNIQUEIDENTIFIER, [Security] INT)  
	CREATE TABLE [#CostTbl]( [CostGUID] UNIQUEIDENTIFIER, [Security] INT)  
	
	--Filling temporary tables  
	INSERT INTO [#MatTbl]	EXEC [prcGetMatsList] @MatGUID, @GroupPtr,257 
	
	IF  @havePriceBySN > 0
	BEGIN
		INSERT INTO [#MatTbl2] SELECT *  from [#MatTbl]
		DELETE [#MatTbl] FROM [#MatTbl] mt INNER JOIN mt000 m ON m.Guid = mt.[MatGUID] WHERE  m.SnFlag > 0
		
	END
	INSERT INTO [#BillsTypesTbl] EXEC [prcGetBillsTypesList] @SrcTypes
	IF (@DetailSubStores = 1)
		INSERT INTO [#StoreTbl]	EXEC [prcGetStoresList] @StGUID
	ELSE
		INSERT INTO [#StoreTbl] SELECT [stGuid],[stSecurity] FROM vwSt WHERE ISNULL(@StGUID,0X00) = 0X00 OR  [stGuid] = @StGUID
	INSERT INTO [#CostTbl]	EXEC [prcGetCostsList] @CostGUID  
	
	--Get Qtys 
	CREATE TABLE [#t_Qtys] 
	( 
		[MatGUID] 	[UNIQUEIDENTIFIER], 
		[Qnt] 		[FLOAT], 
		[Qnt2] 		[FLOAT], 
		[Qnt3] 		[FLOAT], 
		[StoreGUID]	[UNIQUEIDENTIFIER] 
	) 
	
	CREATE TABLE #t_AccGoods  
	(  
		[acGUID]			[UNIQUEIDENTIFIER],  
		[acQty]				[FLOAT],
		[acPrice]			[FLOAT],	
		[StoreGUID]			[UNIQUEIDENTIFIER],
		[AccType]			[INT]		-- «·Õ”«»  «»⁄ ··„Ì“«‰Ì… √Ê «·„ «Ã—…	  
	)  
	
	CREATE TABLE [#t_Goods]  
	(  
		[acGUID]			[UNIQUEIDENTIFIER],  
		[acCodeName]		[NVARCHAR](500) COLLATE ARABIC_CI_AI,  
		[acCodeLatinName]	[NVARCHAR](500) COLLATE ARABIC_CI_AI,  
		[acFinal]			[UNIQUEIDENTIFIER],  
		[acParent]			[UNIQUEIDENTIFIER],  
		[acCurPtr]			[UNIQUEIDENTIFIER],  
		[acCurVal]			[FLOAT],  
		[Balance]			[FLOAT],
		[AccType]			[INT],-- «·Õ”«»  «»⁄ ··„Ì“«‰Ì… √Ê «·„ «Ã—…
		[acSecurity]		[INT]			  
	)  
	
	CREATE TABLE [#MatAccount]  
	(
		[MatGUID]	UNIQUEIDENTIFIER,	  
		[MatAccGUID] UNIQUEIDENTIFIER,
		[AccType]		INT
	)
	CREATE TABLE [#T_RESULT]
	(
		[acGUID] UNIQUEIDENTIFIER,
		[Flag] INT DEFAULT 0
	)
	CREATE TABLE [#t_Prices] 
	( 
		[MatGUID] 	[UNIQUEIDENTIFIER], 
		[Price] 	[FLOAT] 
	) 
	CREATE TABLE #PricesQtys 
	( 
		[MatGUID]	[UNIQUEIDENTIFIER], 
		[Price]		[FLOAT], 
		[Qnt]		[FLOAT], 
		[StoreGUID]	[UNIQUEIDENTIFIER]
	) 
	-- First Period
	DECLARE @DelPrice [BIT],@FBDate	DATETIME,@StDate DATETIME
	INSERT INTO [#FinalAccTbl] ([AcGuid],[AcCodeName],[AcCodeLatinName],[AcFinal],[AcParent],[DebitOrCredit],[AcCurPtr],[AcCurVal],[AccSecurity],[Level])
		SELECT 
			[acGUID], 
			[acCode] + '-'+ [acName], 
			[acCode] + '-'+ [acLatinName], 
			[acFinal],	 
			[acParent], 
			[acDebitOrCredit],  	 
			[acCurrencyPtr],   
			[acCurrencyVal], 
			[acSecurity], 
			[Level] 
		FROM 
			[fnGetAccountsList]( @Final,1) AS [al] INNER JOIN [vwAc] ON [al].[GUID] = [acGUID] 
		ORDER BY [path] 
	--========================================================================
	

	SELECT @FBDate = dbo.fnDate_Amn2Sql(value) FROM op000 WHERE NAME = 'AmnCfg_FPDate'
	IF (@FBDate < @StartDate)
	BEGIN
		IF NOT EXISTS( SELECT * FROM BT000 where TYPE = 2 AND SORTNUM = 2)
			SET @FinalType = 0
		ELSE
		BEGIN
			INSERT INTO #MatAccount([MatAccGUID]) SELECT DefBillAccGUID FROM BT000 where TYPE = 2 AND SORTNUM = 2 AND DefBillAccGUID <> 0x00
			INSERT INTO #MatAccount([MatAccGUID])
				SELECT [MatAccGUID] 	FROM [ma000] AS [ma] INNER JOIN [vwbt] ON [BillTypeGUID] = [btGUID]
						WHERE  	[ma].[Type] = 1  AND [btSortNum] = 2 AND [btType] = 2 AND  [MatAccGUID] <> 0X00
			
			IF NOT EXISTS( SELECT * FROM #MatAccount A inner join ac000 b on b.guid = [MatAccGUID] WHERE finalGuid = @Final )-- INNER JOIN [#FinalAccTbl] F ON f.acGuid = b.finalGuid)
				SET @FinalType = 1
			ELSE
				SET @FinalType = 0
			TRUNCATE TABLE #MatAccount
		END 
	END 
	ELSE 
		SET  @FinalType = 0
	SET @DelPrice = 1
	DECLARE		@FPStDate DATETIME
	SET @FPStDate = @StartDate
	IF @FinalType = 1
	BEGIN
		SET @FPStDate = '1/1/1980'
		SET @StDate = DATEADD(day,-1,@StartDate)
		EXEC [prcGetQnt] 
			'1/1/1980',@StDate,
			@MatGUID, @GroupPtr, 
			@StGUID, @CostGUID, 
			@MatType, @DetailsStores, 
			@SrcTypes, @ShowUnLinked 
		IF @PriceType = 2 AND @PricePolicy = 122 -- LastPrice 
			EXEC [prcGetLastPrice] '1/1/1980',@StDate, @MatGUID, @GroupPtr, @StGUID, @CostGUID, @MatType, @CurPtr, @SrcTypes, @ShowUnLinked, @UseUnit 
		ELSE IF @PriceType = 2 AND @PricePolicy = 120 -- MaxPrice 
			EXEC [prcGetMaxPrice] '1/1/1980',@StDate,  @MatGUID, @GroupPtr, @StGUID, @CostGUID, @MatType, @CurPtr, @CurVal, @SrcTypes, @ShowUnLinked, @UseUnit 
		ELSE IF @PriceType = 2 AND @PricePolicy = 121 -- COST And AvgPrice 
			EXEC [prcGetAvgPrice] '1/1/1980',@StDate,  @MatGUID, @GroupPtr, @StGUID, @CostGUID, @MatType, @CurPtr, @CurVal, @SrcTypes, @ShowUnLinked, @UseUnit 
		ELSE IF @PriceType = 2 AND @PricePolicy = 124 -- LastPrice with extra and discount
			EXEC [prcGetLastPrice] '1/1/1980',@StDate , @MatGUID, @GroupPtr, @StGUID, @CostGUID, @MatType,	@CurPtr, @SrcTypes, @ShowUnLinked, @UseUnit, 0 /*@CalcLastCost*/,	1 /*@ProcessExtra*/
		ELSE IF @PriceType = 2 AND @PricePolicy = 125
			EXEC [prcGetFirstInFirstOutPrise] '1/1/1980',@StDate,@CurPtr	
		ELSE
		BEGIN 
			EXEC prcGetMtPrice @MatGUID, @GroupPtr, @MatType, @CurPtr, @CurVal, @SrcTypes, @PriceType, @PricePolicy, @ShowUnLinked, 3
			SET @DelPrice = 0
		END 
		INSERT INTO [#PricesQtys]
		SELECT 
			[q].[MatGUID], 
			ISNULL([p].[Price],0), 
			ISNULL([q].[Qnt],0), 
			[q].[StoreGUID] 
		FROM 
			[#t_Qtys] AS [q] LEFT JOIN [#t_Prices] AS p ON [q].[MatGUID] = [p].[MatGUID] 
		IF  @havePriceBySN > 0
		BEGIN
			INSERT INTO [#PricesQtys] ([MatGUID],[StoreGUID],[Qnt],[Price]) 
				EXEC repMatSNBSheet @CurPtr, 0x00, '1/1/1980',@StDate
		END
		INSERT INTO #MatAccount		   		
			SELECT					   		
				[ObjGUID],			   
				[MatAccGUID],
				0
			FROM     
				[ma000] AS [ma] INNER JOIN [vwbt] ON [BillTypeGUID] = [btGUID]
			WHERE  
				[ma].[Type] = 1   
				AND [btSortNum] = 1		-- »÷«⁄… √Ê· „œ…
				AND [btType] = 2
		SELECT @TypeAccGuid2 = [bt].[btDefBillAcc]   FROM 	[vwbt] AS [bt] WHERE [bt].[btType] = 2 And [bt].[btSortNum] = 1 
		INSERT INTO #t_AccGoods
		SELECT  
			ISNULL([mAcc].[MatAccGUID], @TypeAccGuid2),
			[Pq].[Qnt],
			[Pq].[Price],
			0X00,
			-1	-- Ì»Ì‰ ﬁÌ„… »÷«⁄… ¬Œ— «·„œ… €Ì—  «»⁄… ·Õ”«»«  «·„Ê«œ Ê«·„Ã„Ê⁄« 
		FROM
			[#PricesQtys] AS [Pq] LEFT JOIN #MatAccount AS [mAcc] 
			ON [Pq].[MatGUID] = [mAcc].[MatGUID] 
		INSERT INTO [#t_Goods]  
		SELECT 
			ISNULL([tg].[acGUID],0x0),
			ISNULL([ac].[acCode]+'-'+[ac].[acName], ''),
			ISNULL([ac].[acCode]+'-'+[ac].[acLatinName], ''),
			ISNULL([acFinal],0x0),
			ISNULL([acParent],0x0),
			ISNULL([acCurrencyPtr],0x0),
			ISNULL([acCurrencyVal], 1)l,
			SUM(ISNULL(acQty * acPrice, 0)),
			0,
			[acSecurity]
		FROM 
			[#t_AccGoods] AS [tg] INNER JOIN [vwAc] AS [ac] ON [tg].[acGUID] = [ac].[acGUID]
		GROUP BY
			ISNULL([tg].[acGUID],0x00),
			ISNULL([ac].[acCode]+'-'+[ac].[acName], ''),
			ISNULL([ac].[acCode]+'-'+[ac].[acLatinName], ''),
			ISNULL([acFinal],0x00),
			[acParent],
			[acCurrencyPtr],
			[acCurrencyVal],
			[acSecurity]
		INSERT INTO #MatAccount([MatAccGUID]) SELECT @TypeAccGuid2
		
	------------------------------------------------------
		Exec [prcCheckSecurity] @UserGUID, 0, 0, [#t_Goods]

		--»÷«⁄… √Ê· «·„œ…
		INSERT INTO #EResult    
		SELECT      
			[t].[acGUID],    
			[t].[AcCodeName],    
			[t].[AcCodeLatinName],    
			[t].[acFinal],    
			[t].[acParent],
			0, 
			[t].[acCurPtr],     
			[t].[acCurVal],     
			CASE WHEN [Balance] > 0 THEN [Balance] ELSE 0 END, 
			CASE WHEN [Balance] < 0 THEN [Balance] * -1 ELSE 0 END, 
			0,0,
			[al].[level] + 1,    
			[al].[path],    
			0,    
			1,     
			1,     
			@UserSec,
			[f].[Level],    -- —ﬁ„ „” ÊÏ «·Õ”«» «·Œ «„Ì «·–Ì ”Ì »⁄ ·Â «·Õ”«»
			0,
			CASE WHEN ([t].[acFinal] = @Final) OR (@ShowDetails = 1)  THEN 1 ELSE 0 END,
			[f].[Id]
		FROM    
			[#t_Goods] AS [t]
			INNER JOIN [#AccountsList] AS [al]  ON [acGUID] = [al].[guid]
			INNER JOIN [#FinalAccTbl] AS [f] ON [f].[acGUID] = [t].[acFinal]
	
		IF @DelPrice > 0 
			TRUNCATE TABLE 	[#t_Prices] 
		TRUNCATE TABLE  [#t_Qtys]
		TRUNCATE TABLE  [#PricesQtys]
		TRUNCATE TABLE #t_AccGoods
		TRUNCATE TABLE [#t_Goods]
	END	
	
	EXEC [prcGetQnt] 
	@FPStDate,@EndDate,
	@MatGUID, @GroupPtr, 
	@StGUID, @CostGUID, 
	@MatType, @DetailsStores, 
	@SrcTypes, @ShowUnLinked 
	
	--8 Get last Prices 
	
	IF @PriceType = 2 AND @PricePolicy = 122 -- LastPrice 
		EXEC [prcGetLastPrice] @FPStDate,@EndDate, @MatGUID, @GroupPtr, @StGUID, @CostGUID, @MatType, @CurPtr, @SrcTypes, @ShowUnLinked, @UseUnit 
	ELSE IF @PriceType = 2 AND @PricePolicy = 120 -- MaxPrice 
		EXEC [prcGetMaxPrice] @FPStDate,@EndDate,  @MatGUID, @GroupPtr, @StGUID, @CostGUID, @MatType, @CurPtr, @CurVal, @SrcTypes, @ShowUnLinked, @UseUnit 
	ELSE IF @PriceType = 2 AND @PricePolicy = 121 -- COST And AvgPrice 
		EXEC [prcGetAvgPrice] @FPStDate,@EndDate,  @MatGUID, @GroupPtr, @StGUID, @CostGUID, @MatType, @CurPtr, @CurVal, @SrcTypes, @ShowUnLinked, @UseUnit 
	ELSE IF @PriceType = 2 AND @PricePolicy = 124 -- LastPrice with extra and discount
		EXEC [prcGetLastPrice] @FPStDate , @EndDate , @MatGUID, @GroupPtr, @StGUID, @CostGUID, @MatType,	@CurPtr, @SrcTypes, @ShowUnLinked, @UseUnit, 0 /*@CalcLastCost*/,	1 /*@ProcessExtra*/
	ELSE IF @PriceType = 2 AND @PricePolicy = 125
		EXEC [prcGetFirstInFirstOutPrise] @FPStDate , @EndDate,@CurPtr	
	ELSE 
	BEGIN
		IF @FinalType = 0
			EXEC prcGetMtPrice @MatGUID, @GroupPtr, @MatType, @CurPtr, @CurVal, @SrcTypes, @PriceType, @PricePolicy, @ShowUnLinked, 3 
	END
	
	---- Get Qtys And Prices 
	
	
	-- you must use left join cause if details stores you have more than one record for each mat 
	INSERT INTO [#PricesQtys]
	SELECT 
		[q].[MatGUID], 
		ISNULL([p].[Price],0), 
		ISNULL([q].[Qnt],0), 
		[q].[StoreGUID] 
	FROM 
		[#t_Qtys] AS [q] LEFT JOIN [#t_Prices] AS p ON [q].[MatGUID] = [p].[MatGUID] 
	IF  @havePriceBySN > 0
	BEGIN
		INSERT INTO [#PricesQtys] ([MatGUID],[StoreGUID],[Qnt],[Price])  
			EXEC repMatSNBSheet @CurPtr, 0x00, @FPStDate , @EndDate
	END
	
	-- Add MatAccount in ma 
	--------------------------------------------------
	-- »÷«⁄… ¬Œ— „œ… («·„Ì“«‰Ì…)
	--------------------------------------------------
	INSERT INTO #MatAccount
		SELECT 
			[ObjGUID],
			[MatAccGUID],
			1
		FROM     
			[ma000] AS [ma] INNER JOIN [vwbt] ON [BillTypeGUID] = [btGUID]
		WHERE  
			[ma].[Type] = 1   
			AND [btSortNum] = 2		-- »÷«⁄… ¬Œ— „œ…
			AND [btType] = 2
	
	--------------------------------------------------
	 -- »÷«⁄… ¬Œ— «·„œ… («·„ «Ã—…)
	--------------------------------------------------
	INSERT INTO [#MatAccount]
		SELECT 
			[ObjGUID],
			[DiscAccGUID],
			2		
		FROM     
			[ma000]  AS [ma]  INNER JOIN [vwbt] ON [BillTypeGUID] = [btGUID]
		WHERE  
			[ma].[Type] = 1   		-- Material Only
			AND [btSortNum] = 2	-- »÷«⁄… ¬Œ— „œ…
			AND [btType] = 2		-- »÷«⁄… ¬Œ— „œ…
	
	INSERT INTO #t_AccGoods
		SELECT  
			ISNULL([mAcc].[MatAccGUID], 0x0),
			[Pq].[Qnt],
			CASE ISNULL([AccType], 1) WHEN 1 THEN [Pq].[Price]
			WHEN 2 THEN [Pq].[Price] * -1 END,
			ISNULL([Pq].[StoreGUID], 0x0),
			ISNULL([AccType], 0)	-- Ì»Ì‰ ﬁÌ„… »÷«⁄… ¬Œ— «·„œ… €Ì—  «»⁄… ·Õ”«»«  «·„Ê«œ Ê«·„Ã„Ê⁄« 
		FROM
			[#PricesQtys] AS [Pq] LEFT JOIN #MatAccount AS [mAcc] 
			ON [Pq].[MatGUID] = [mAcc].[MatGUID] 
	
	
	-- ”Ì „  ﬂ—«— ﬁÌ„… »÷«⁄… ¬Œ— «·„œ… «·€Ì— „ÊÃÊœ… ›Ì Õ”«»«  «·„Ê«œ „‰ √Ã· «·„ «Ã—… 
	INSERT INTO [#t_AccGoods]
		SELECT  
			[acGUID],  
			[acQty],
			[acPrice],	
			[StoreGUID],
			-1
		FROM 
			[#t_AccGoods] ac
		WHERE [ac].[AccType] = 0
	
		
	--  ⁄œÌ· Õ”«» »÷«⁄… ¬Œ— «·„œ… «· «»⁄ ··„ «Ã—…
	IF (@DetailSubStores = 0 )-- AND (@StGUID <> 0X0)
	BEGIN
		UPDATE [t]
		SET  
			[AcGUID] = ISNULL([st].[AccountGuid],0x00),
			[acPrice] = -1 * [acPrice]
		FROM  [#t_AccGoods] AS [t] INNER JOIN [st000] AS [st] ON [st].[Guid] = [t].[StoreGUID]
		WHERE   
				[t].[AcGUID] = 0x00 AND [t].[AccType] = -1 AND ISNULL([st].[AccountGuid],0x00) <> 0x00
		
		
	END 
	SELECT @TypeAccGuid1 = [bt].[btDefDiscAcc]  FROM 	[vwbt] AS [bt] WHERE [bt].[btType] = 2 And [bt].[btSortNum] = 2 
	UPDATE [#t_AccGoods]
		SET  
			[AcGUID] = @TypeAccGuid1,  
			
			[acPrice] = -1 * [acPrice]
		WHERE   
			[#t_AccGoods].[AcGUID] = 0x0 AND [#t_AccGoods].[AccType] = -1
		SELECT @TypeAccGuid2 = [bt].[btDefBillAcc]   FROM 	[vwbt] AS [bt] WHERE [bt].[btType] = 2 And [bt].[btSortNum] = 2 
	--  ⁄œÌ· Õ”«» »÷«⁄… ¬Œ— «·„œ… «· «»⁄ ··„Ì“«‰Ì…
		UPDATE [#t_AccGoods]
		SET  
			[AcGUID] =  @TypeAccGuid2
			
		WHERE   
			[#t_AccGoods].[AcGUID] = 0x0
	--=================================================================
	--========================= END Calc AccGoods =====================
	--=================================================================
	INSERT INTO [#t_Goods]  
	SELECT 
		ISNULL([tg].[acGUID],0x0),
		ISNULL([ac].[acCode]+'-'+[ac].[acName], ''),
		ISNULL([ac].[acCode]+'-'+[ac].[acLatinName], ''),
		ISNULL([acFinal],0x0),
		ISNULL([acParent],0x0),
		ISNULL([acCurrencyPtr],0x0),
		ISNULL([acCurrencyVal], 1)l,
		SUM(ISNULL(acQty * acPrice, 0)),
		0,
		[acSecurity]
	FROM 
		[#t_AccGoods] AS [tg] INNER JOIN [vwAc] AS [ac] ON [tg].[acGUID] = [ac].[acGUID]
	GROUP BY
		[tg].[acGUID],
		ISNULL([ac].[acCode]+'-'+[ac].[acName], ''),
		ISNULL([ac].[acCode]+'-'+[ac].[acLatinName], ''),
		[acFinal],
		[acParent],
		[acCurrencyPtr],
		[acCurrencyVal],
		[acSecurity]
	------------------------------------------------------
	Exec [prcCheckSecurity] @UserGUID, 0, 0, [#t_Goods]
	--=================================================================
	--Get List of sorted final Accounts
	
	
	
	CREATE CLUSTERED INDEX [find] ON [#FinalAccTbl]([acGUID])
	--========================================================================
	Exec [prcCheckSecurity] @UserGUID, 0, 0, [#FinalAccTbl]	
	-- ÌÕÊÌ ‘Ã—… Õ”«»«  „— »…   «»⁄… ·Õ”«» ›—⁄Ì ÌŒ „ »«·Õ”«» «·Œ «„Ì «·„Õœœ    
	-- sotrted AccList contains parentAcc & SubAccount for a specific final Acc     
	
	DECLARE @MinLevel INT
	SELECT 	@MinLevel = MIN([level]) FROM   [#AccountsList]
	if 	@MinLevel > 0
		UPDATE [#AccountsList] SET [level] = [level] - @MinLevel

	CREATE TABLE [#AccountsTree]([GUID] [UNIQUEIDENTIFIER], [acCodeName] NVARCHAR(600), [acCodeLatinName] NVARCHAR(600),    
			[acFinal] [UNIQUEIDENTIFIER], [acParent] [UNIQUEIDENTIFIER], [acDebitOrCredit] INT, [acCurrencyPtr] [UNIQUEIDENTIFIER],    
			[acCurrencyVal] FLOAT, [acLevel] INT, [path] VARCHAR(8000), [acSecurity] INT, fLevel INT, [Id] INT)
	CREATE CLUSTERED INDEX InAccTree ON [#AccountsTree]([GUID])

	CREATE TABLE #RES2([ceSecurity] INT, [acCodeName] NVARCHAR(600), [acCodeLatinName] NVARCHAR(600), 
		[AccountGuid] [UNIQUEIDENTIFIER], EnDate DATETIME, [EnDebit] FLOAT, [EnCredit] FLOAT, [CurrencyGuid] [UNIQUEIDENTIFIER], 
		[CurrencyVal] FLOAT, [acFinal] [UNIQUEIDENTIFIER], [acParent] [UNIQUEIDENTIFIER], [acDebitOrCredit] INT,    
		[acCurrencyPtr] [UNIQUEIDENTIFIER], [acCurrencyVal] FLOAT, [acLevel] INT, [path] VARCHAR(8000), [fLevel] INT,
		[acSecurity] INT, [CurFact] FLOAT, [DebitCurAcc] FLOAT, [CreditCurAcc] FLOAT, [DFlag] INT, [ID] INT)

	INSERT INTO [#AccountsTree]
	SELECT      
			[al].[GUID],		    
			[ac].[acCode] + '-' + [ac].[acName] AS [acCodeName],    
			[ac].[acCode] + '-' + [ac].[acLatinName] AS [acCodeLatinName],    
			[ac].[acFinal],    
			[ac].[acParent], 
			[ac].[acDebitOrCredit],    
			[ac].[acCurrencyPtr],    
			[ac].[acCurrencyVal], 	    
			[al].[level] AS [acLevel],    
			[al].[path],    
			[ac].[acSecurity],    
			[f].[Level] AS fLevel,   -- —ﬁ„ „” ÊÏ «·Õ”«» «·Œ «„Ì «·–Ì ”Ì »⁄ ·Â «·Õ”«»									    
			[f].[Id]
		FROM
			[#AccountsList] AS [al]  
			INNER JOIN [vwAc] AS [ac] ON [al].[GUID] = [ac].[acGUID]
			INNER JOIN [#FinalAccTbl] AS [f] ON [f].[acGUID] = [ac].[acFinal]
	--================================================================
	INSERT INTO #RES2
	SELECT 
		[ce].[ceSecurity],
		[acCodeName],
		[acCodeLatinName], 
		[en].[AccountGuid], 
		[en].[Date] AS EnDate, 
		[en].[Debit] AS [EnDebit], 
		[en].[Credit]AS [EnCredit], 
		[en].[CurrencyGuid], 
		[en].[CurrencyVal],
		[al].[acFinal],    
		[al].[acParent], 
		[al].[acDebitOrCredit],    
		[al].[acCurrencyPtr],    
		[al].[acCurrencyVal], 	    
		[al].[acLevel],    
		[al].[path],    
		[al].[fLevel],
		[al].[acSecurity], 
		[dbo].[fnCurrency_fix](1, [en].[CurrencyGuid], [en].[CurrencyVal], @CurPtr, [en].[Date]) AS [CurFact],
		CASE [al].[acCurrencyPtr]     
				WHEN @CurPtr THEN 0     
				ELSE      
					CASE [en].[CurrencyGuid]      
						WHEN [al].[acCurrencyPtr] THEN [en].[Debit] / [en].[CurrencyVal]    	        
						ELSE 0      
					END        
		END AS [DebitCurAcc],     
		CASE [al].[acCurrencyPtr]     
			WHEN @CurPtr THEN 0    
			ELSE    
				CASE [en].[CurrencyGuid]      
					WHEN [al].[acCurrencyPtr]   THEN [en].[Credit] / [en].[CurrencyVal]     
					ELSE 0    
				END       
		END AS [CreditCurAcc],
		CASE WHEN ([acFinal] = @Final) OR (@ShowDetails = 1)  THEN 1 ELSE 0 END AS [DFlag],
		[ID]    
	FROM 
		[vwce] as [ce] 
		INNER JOIN [en000] AS en ON en.ParentGuid = ce.ceGuid
		INNER JOIN [#AccountsTree] AS [al] ON [al].[GUID] = [en].[AccountGuid]
	WHERE     
			[En].[Date] BETWEEN @StartDate AND @EndDate     
			AND ( (@CostGUID = 0x0) OR ([en].[CostGuid] IN (SELECT CostGUID FROM #CostTbl) ) )     			
			AND( (@PostedType = -1) OR ( @PostedType = 1 AND ceIsPosted = 1)       
				OR (@PostedType = 0 AND [ceIsPosted] = 0) )  

	--================================================================
	INSERT INTO [#EResult]    
		SELECT      
			[AccountGuid],    
			[acCodeName],    
			[acCodeLatinName],    
			[acfinal],    
			[acParent], 
			[acDebitOrCredit],    
			[acCurrencyPtr],     
			[acCurrencyVal],      
			SUM([EnDebit]*[CurFact]),    
			SUM([EnCredit]*[CurFact]),    
			SUM([DebitCurAcc]),     
			SUM([CreditCurAcc]),     
			[aclevel] + 1,    
			[path],    
			0,    
			[ceSecurity],     
			[acSecurity],     
			@UserSec,
			[fLevel],    -- —ﬁ„ „” ÊÏ «·Õ”«» «·Œ «„Ì «·–Ì ”Ì »⁄ ·Â «·Õ”«»
			0,
			[DFlag],
			[ID] 
		FROM    
			[#Res2]
		GROUP BY 
			[AccountGuid],    
			[acCodeName],    
			[acCodeLatinName],    
			[acfinal],    
			[acParent], 
			[acDebitOrCredit],    
			[acCurrencyPtr],     
			[acCurrencyVal],      
			[aclevel],    
			[path],    
			[ceSecurity],     
			[acSecurity],     
			[fLevel],
			[DFlag],
			[ID]   
	---------------------------------------------------------------
	-- ≈÷«›… »÷«⁄… ¬Œ— «·„œ…
	---------------------------------------------------------------
	INSERT INTO #EResult    
		SELECT      
			[t].[acGUID],    
			[t].[AcCodeName],    
			[t].[AcCodeLatinName],    
			[t].[acFinal],    
			[t].[acParent],
			0, 
			[t].[acCurPtr],     
			[t].[acCurVal],      
			CASE WHEN [Balance] > 0 THEN [Balance] ELSE 0 END, 
			CASE WHEN [Balance] < 0 THEN [Balance] * -1 ELSE 0 END, 
			0,0,
			[al].[level] + 1,    
			[al].[path],    
			0,    
			1,     
			1,     
			@UserSec,
			[f].[Level],    -- —ﬁ„ „” ÊÏ «·Õ”«» «·Œ «„Ì «·–Ì ”Ì »⁄ ·Â «·Õ”«»
			0,
			CASE WHEN ([t].[acFinal] = @Final) OR (@ShowDetails = 1)  THEN 1 ELSE 0 END,
			[f].[Id]
		FROM    
			[#t_Goods] AS [t]
			INNER JOIN [#AccountsList] AS [al]  ON [acGUID] = [al].[guid]
			INNER JOIN [#FinalAccTbl] AS [f] ON [f].[acGUID] = [t].[acFinal]
	
	--=======================================================================
	INSERT INTO [#FinalResult]		
	SELECT
		[AcGuid],
		[acCodeName],
		[acCodeLatinName],
		0x0,
		[acParent],
		[DebitOrCredit],
		[AcCurPtr],
		[AcCurVal],
		MY.myCode,
		0,0,0,0,		 
		0, 0, 2,
		[Level],    -- —ﬁ„ „” ÊÏ «·Õ”«» «·Œ «„Ì «·–Ì ”Ì »⁄ ·Â «·Õ”«»									    
		0,
		[id],0
	FROM [#FinalAccTbl]
	INNER JOIN vwMy MY ON acCurPtr = MY.myGUID 
	WHERE 
		[AcGuid] <> @Final

	SELECT @MaxLevel = MAX([Level]) FROM [#EResult] WHERE [DFlag] =1

	--Balnced Account
	INSERT INTO [#T_RESULT]
	SELECT [acGUID],CASE WHEN ABS(ISNULL(SUM([Debit]),0)- ISNULL(SUM(Credit),0))> dbo.fnGetZeroValuePrice() THEN 1 ELSE 0 END 
	FROM  [#EResult]
	WHERE [DFlag] =1
	GROUP BY [acGUID]
	
	UPDATE [#EResult] SET [Flag] = [t].[Flag]
	FROM [#EResult] AS [r] INNER JOIN [#T_Result] AS [t] ON [r].[acGUID] =[t].[acGUID]
	WHERE [r].[DFlag] =1 
	
	SET @Level = @MaxLevel 
	------------------------------------------------------------
	Exec [prcCheckSecurity] @Result = '#EResult'
	------------------------------------------------------------
	
	WHILE @Level >= 0
	BEGIN 
		INSERT INTO [#EResult]     
		SELECT      
			[r].[acParent],		    
			[ac].[acCodeName],    
			[ac].[acCodeLatinName],    
			[ac].[acFinal],    
			[ac].[acParent], 
			[ac].[acDebitOrCredit],    
			[ac].[acCurrencyPtr],    
			[ac].[acCurrencyVal], 	    
			SUM(IsNULL([Debit],0)),     
			SUM(IsNULL([Credit],0)),     
			SUM(IsNULL([CurDebit],0)),     
			SUM(IsNULL([CurCredit],0)),    
			[ac].[aclevel] + 1,    
			[ac].[path],    
			1,    
			1,	-- ’·«ÕÌ… «·”‰œ«     
			[ac].[acSecurity],    
			@UserSec,
			[ac].[fLevel],    -- —ﬁ„ „” ÊÏ «·Õ”«» «·Œ «„Ì «·–Ì ”Ì »⁄ ·Â «·Õ”«»									    
			SUM([Flag]),
			CASE WHEN ([ac].[acFinal] = @Final) OR (@ShowDetails = 1)  THEN 1 ELSE 0 END,
			[ac].[id]
		FROM
			[#EResult] AS [r] INNER JOIN [#AccountsTree] AS [ac] ON [r].[acParent] = [ac].[GUID] AND  [r].[acFinal] = [ac].[acFinal] 
		WHERE 
			[r].[Level] = @Level AND [r].[DFlag] = 1  
		GROUP BY
			[r].[acParent],
			[ac].[acCodeName],    
			[ac].[acCodeLatinName],    
			[ac].[acFinal],    
			[ac].[acParent], 
			[ac].[acDebitOrCredit],    
			[ac].[acCurrencyPtr],    
			[ac].[acCurrencyVal], 	    
			[ac].[aclevel],    
			[ac].[path],     
			[ac].[acSecurity],
			[ac].[fLevel],
			[ac].[id] 
		
		UPDATE [r]
			SET [Level] = @Level - 1,[acParent] = [ac].[acParent]
		FROM
			[#EResult] AS [r] INNER JOIN [#AccountsTree] AS [ac] ON [r].[acParent] = [ac].[GUID] AND  [r].[acFinal] <> [ac].[acFinal]
		WHERE 
			[r].[Level] = @Level AND [r].[DFlag] = 1 
			 
		SET @Level = @Level - 1   
	END	
	------------------------------------------------------------
	UPDATE [#EResult] SET [Level] = 1,[acParent] = 0X00 WHERE [acParent] <> 0X00 AND [acParent] NOT IN (SELECT  [GUID] FROM [#AccountsTree])
	SELECT @MaxLevel = ISNULL(MAX([ac].[Level]),0)
	FROM
			[#EResult] AS [r] INNER JOIN [#EResult] AS [ac] ON [r].[acParent] = [ac].[acGUID] AND  [r].[Level] <> [ac].[Level] + 1
		WHERE 
			[r].[DFlag] = 1   
	SET @Level = 0
	IF @MaxLevel > 0
	BEGIN
		WHILE @Level <= @MaxLevel
		BEGIN 
			UPDATE [r]
				SET [Level] = [ac].[Level] + 1
			FROM
				[#EResult] AS [r] INNER JOIN [#EResult] AS [ac] ON [r].[acParent] = [ac].[acGUID] AND  [r].[Level] <> [ac].[Level] + 1
			WHERE 
				[ac].[Level] = @Level AND [r].[DFlag] = 1   
			SET @Level = @Level + 1   
		END	
	END
	------------------------------------------------------------
	INSERT INTO [#FinalResult]
	SELECT    
		[acGUID],   
		[acCodeName],   
		[acCodeLatinName],   
		[acFinal],   
		[acParent], 
		[DebitOrCredit],    
		[acCurPtr],    
		[acCurVal],    
		MY.myCode,
		SUM( ISNULL([Debit],0) ),   
		SUM( ISNULL([Credit],0) ),   
		SUM( ISNULL([CurDebit],0) ),    
		SUM( ISNULL([CurCredit],0) ),   
		[Level] - 1 ,   
		[Path],
		[RecType],
		[fn_AcLevel]  ,
		SUM([Flag]),
		[id]  ,0
	FROM     
		[#EResult] 
		INNER JOIN vwMy MY ON [acCurPtr] = MY.myGUID
		WHERE [DFlag] = 1 AND [Level] <= @accLevel
	GROUP BY     
		[acGUID], 
		[acCodeName], 
		[acCodeLatinName], 
		[acFinal], 
		[acParent], 
		[DebitOrCredit], 
		[acCurPtr], 
		[acCurVal], 
		MY.myCode,
		[Level], 
		[Path],
		[RecType],   
		[fn_AcLevel],
		[id]
	-------------------------------------------------------------------------------------
	UPDATE [#FinalResult] SET Debit = fsum.Debit, Credit = fsum.Credit, CurDebit = fsum.CurDebit, CurCredit = fsum.CurCredit
	FROM
	(SELECT
		[f].[AcGuid],
		[f].[acCodeName],
		[f].[acCodeLatinName],
		[f].[acParent],
		[f].[DebitOrCredit],
		[f].[AcCurPtr],
		[f].[AcCurVal],
		SUM( ISNULL([Debit],0) ) Debit,   
		SUM( ISNULL([Credit],0) ) Credit,   
		SUM( ISNULL([CurDebit],0) ) CurDebit,    
		SUM( ISNULL([CurCredit],0) ) CurCredit,   
		[fn_AcLevel] ,
		SUM([FLAG]) flag,
		[f].[id] 
	FROM     
		[#EResult] AS [r]  INNER JOIN [#FinalAccTbl] AS [f] ON [r].[acFinal] = [f].[AcGuid]
	WHERE ABS(ISNULL([Debit],0) - ISNULL([Credit],0))> 0 AND [r].[DFlag] = 0
	GROUP BY 
		[f].[AcGuid],
		[f].[acCodeName],
		[f].[acCodeLatinName],
		[f].[acParent],
		[f].[DebitOrCredit],
		[f].[AcCurPtr],
		[f].[AcCurVal],
		[fn_AcLevel],
		[f].[id]) as fsum
	where [#FinalResult].AcGuid = fsum.acGUID   
	
	IF @RateType = 1
	BEGIN
		IF @CurVal = 0
			SET @CurVal = 1
		UPDATE	[#FinalResult] 
			SET [Debit] = [Debit] / @CurVal,[Credit] = [Credit] / @CurVal
	END
	-------------------------------------------------------------------------------------
	UPDATE [#FinalResult] SET Debit = fDebit, Credit = fCredit, CurDebit = fCurDebit, CurCredit = fCurCredit
	FROM 
	(SELECT acFinal, SUM(Debit) fDebit, SUM(Credit) fCredit, SUM(CurDebit) fCurDebit, SUM(CurCredit) fCurCredit
	 FROM [#FinalResult]
	 WHERE [Level] = 0  
	 GROUP BY  acFinal) fsum
	 WHERE RecType = 2 AND acGUID = fsum.acFinal
	------------------------------------------------------------
	SELECT @MaxLevel = ISNULL(MAX(fn_AcLevel), 0) FROM #FinalResult
	
	SET @Level = @MaxLevel - 1

	WHILE @Level >= 0
	BEGIN 
		UPDATE parent
			SET Debit = parent.Debit + sumchild.debit,
			Credit = parent.Credit + sumchild.credit,
			CurDebit = parent.CurDebit + sumchild.curDebit,
			CurCredit = parent.CurCredit + sumChild.curCredit
		FROM
			#FinalResult AS parent INNER JOIN 
			(SELECT acParent, SUM(ISNULL(debit, 0)) debit, SUM(ISNULL(credit, 0)) credit,
			SUM(ISNULL(curDebit, 0)) curDebit, SUM(ISNULL(CurCredit, 0)) curCredit
			 FROM #FinalResult WHERE recType = 2 AND fn_AcLevel = @Level + 1 GROUP BY acParent
			 )AS sumChild ON sumChild.[acParent] = [parent].[acGUID] 
		WHERE 
			parent.acGUID = sumChild.acParent and parent.fn_AcLevel = @Level and parent.RecType = 2

		SET @Level = @Level - 1   
	END	

	------------------------------------------------------------
	UPDATE #FinalResult SET id = id * CASE WHEN Debit - Credit < 0 THEN -1 ELSE 1 END
	WHERE RecType = 2 OR [level] = 0
	------------------------------------------------------------
	SELECT @MaxLevel = ISNULL(MAX([Level]), 0) FROM #FinalResult 
	
	SET @Level = 1
	IF @MaxLevel > 0
	BEGIN
		WHILE @Level <= @MaxLevel
		BEGIN 
			UPDATE child
				SET id = child.id * CASE WHEN parent.id < 0 THEN -1 ELSE 1 END
			FROM
				#FinalResult AS [child] INNER JOIN #FinalResult AS [parent] ON [child].[acParent] = [parent].[acGUID] 
			WHERE 
				[child].[Level] = @Level and child.RecType <> 2
			SET @Level = @Level + 1   
		END	
	END
	------------------------------------------------------------
	DELETE #FinalResult WHERE ABS(Debit) - ABS(Credit) = 0.0 AND level <> 0
	------------------------------------------------------------
	UPDATE #FinalResult SET [rank] = r.[Rank]
	FROM 
	(
	SELECT acGuid, RANK() OVER (PARTITION BY id ORDER BY [path] ) AS [Rank]
	FROM #FinalResult
	WHERE RecType <> 2
	) r
	WHERE #FinalResult.acGUID = r.acGUID
	-----------------------------------------------------------
	IF(@showAsT = 0)
	BEGIN
		UPDATE #FinalResult SET DebitOrCredit = CASE WHEN id >= 0 THEN 0 ELSE 1 END 
		SELECT *,abs(id) ABSID FROM [#FinalResult]  WHERE Debit - Credit <> 0 ORDER BY [fn_AcLevel],abs([id]), id DESC, [Path]
	END
	ELSE
	BEGIN
		INSERT INTO #TVFinalResult SELECT 
		CASE WHEN id >= 0 THEN   [acGUID]					ELSE 0x0 END,
		CASE WHEN id >= 0 THEN   [acCodeName]				ELSE ''	END,
		CASE WHEN id >= 0 THEN   [acCodeLatinName]			ELSE '' END,
		CASE WHEN id >= 0 THEN   [acParent]					ELSE 0x0 END,
		CASE WHEN id >= 0 THEN   [DebitOrCredit]			ELSE 0x0 END,
		CASE WHEN id >= 0 THEN   [acCurPtr]					ELSE 0x0 END,
		CASE WHEN id >= 0 THEN   [acCurVal]					ELSE 0 END,
		CASE WHEN id >= 0 THEN   [acCurCode]				ELSE '' END,
		CASE WHEN id >= 0 THEN   [Debit] - [Credit]			ELSE 0 END,
		CASE WHEN id >= 0 THEN   [CurDebit] - [CurCredit]	ELSE 0 END,
		CASE WHEN id >= 0 THEN   [Level]					ELSE 0 END,

		CASE WHEN id < 0 THEN   [acGUID]					ELSE 0x0 END,
		CASE WHEN id < 0 THEN   [acCodeName]				ELSE '' END,
		CASE WHEN id < 0 THEN   [acCodeLatinName]			ELSE '' END,
		CASE WHEN id < 0 THEN   [acParent]					ELSE 0x0 END,
		CASE WHEN id < 0 THEN   [DebitOrCredit]				ELSE 0x0 END,
		CASE WHEN id < 0 THEN   [acCurPtr]					ELSE 0x0 END,
		CASE WHEN id < 0 THEN   [acCurVal]					ELSE 0 END,
		CASE WHEN id < 0 THEN   [acCurCode]					ELSE '' END,
		CASE WHEN id < 0 THEN   [Credit] - [Debit]			ELSE 0 END,
		CASE WHEN id < 0 THEN   [CurCredit] - [CurDebit]	ELSE 0 END,
		CASE WHEN id < 0 THEN   [Level]					ELSE 0 END,

		[acFinal]	,
		[Debit],
		[Credit],
		[CurDebit] 	,
		[CurCredit] ,
		[Path] 		,
		[RecType] 	,
		[fn_AcLevel],
		[FLAG]		,
		[Id]		,
		[rank]		

		FROM #FinalResult
		-------------------------------------------------------------------- 
		UPDATE d SET cBalance = c.cBalance, cCurBalance = c.cCurBalance , cacCodeName = c.cacCodeName, cacCodeLatinName = c.cacCodeLatinName  , cacCurPtr = c.cacCurPtr, cacCurCode = c.cacCurCode, cLevel = c.cLevel
		FROM #TVFinalResult d INNER JOIN #TVFinalResult c ON d.Id = -1 * c.Id AND d.[rank] = c.[rank] AND c.cacCodeName <> '' AND d.RecType <> 2 AND c.RecType <> 2
		-------------------------------------------------------------------- 
		SELECT   dacCodeName, cacCodeName, dacCodeLatinName, cacCodeLatinName, dBalance dBalance, dCurBalance dCurBalance, dacCurPtr, dacCurCode, cBalance cBalance, cCurBalance cCurBalance, cacCurPtr, cacCurCode, acFinal, dLevel, cLevel, fn_AcLevel, id,  [rank], [Path], RecType from #TVFinalResult
		ORDER BY  abs(id), [rank], id DESC
		
	END
	--------------------------------------------------------------------
	SELECT ISNULL(SUM(CASE WHEN Debit - Credit >= 0 THEN Debit - Credit ELSE 0 END), 0) Debit,
		   ISNULL(SUM(CASE WHEN Debit - Credit < 0 THEN Credit - Debit ELSE 0 END), 0) Credit
	FROM [#FinalResult]
	WHERE (RecType = 2 AND fn_AcLevel = 1) OR (acFinal = @Final AND [level] = 0)
	--------------------------------------------------------------------
	IF @ShowProfitRatio = 1
	BEGIN
		SELECT
			isnull(ABS(SUM(isnull(en.FixedEnDebit - en.FixedEnCredit, 0))), 0) AS MatAccountBalance
		FROM
			[dbo].[fnExtended_En_Fixed](@CurPtr) en
		WHERE
			EXISTS(SELECT * FROM [dbo].[fnGetAccountsList](@MatAccountGuid, DEFAULT) WHERE [GUID] = en.enAccount)
			AND
			en.ceDate BETWEEN @StartDate AND @EndDate
			AND
			(@CostGUID = 0x0 OR (@CostGUID <> 0x0 AND en.enCostPoint = @CostGUID))
	END 
	--------------------------------------------------------------------
	SELECT * FROM [#SecViol]    
	-------------------------------------------------------------------- 
	SELECT 	Count(*) As [AccNull] FROM [vwbt] 
	WHERE  
		[btType] = 2 
		AND [btSortNum] = 2   
		AND ( (ISNULL([btDefDiscAcc], 0x0) = 0x0) OR ( ISNULL([btDefBillAcc], 0x0) = 0x0) ) 
/*    
prcConnections_add2 '„œÌ—'
EXEC   [prcGetFinalAcc] '1/1/2004 0:0:0.0', '12/31/2004 23:59:59.998', '04b7552d-3d32-47db-b041-50119e80dd52', 1.000000, '00000000-0000-0000-0000-000000000000', '00000000-0000-0000-0000-000000000000', 'f2da6efe-c1ca-4f69-97c6-dc765e751d86', 0, 2, 121, 0, 1, 0, 0, 1, 1
*/
############################################################
#END