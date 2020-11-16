################################################################################
CREATE PROCEDURE prc_EPGoods
	@StartDate 		DATETIME,  
	@EndDate 		DATETIME,     
	@CurPtr			UNIQUEIDENTIFIER,     
	@CostGUID 		UNIQUEIDENTIFIER, -- 0 all costs so don't Check cost or list of costs  	
	@StGUID			UNIQUEIDENTIFIER, -- 0 all stores so don't check store or list of stores  	
	@Final			UNIQUEIDENTIFIER,
	@DetailSubStores	INT,	 -- 1 show details 0 no details  for Stores 
	@PriceType			INT,	 
	@PricePolicy		INT,      
	@Posted				INT,
	@UserSec			INT,
	@CurVal				FLOAT,
	@UserGuid			UNIQUEIDENTIFIER,
	@Admin				BIT,
	@SrcGuid		    [UNIQUEIDENTIFIER] = 0X0
AS 
	DECLARE @StDate DATETIME
	SET @StDate = DATEADD(day,-1,@StartDate)
		
	CREATE TABLE [#MatTbl]( [MatGUID] [UNIQUEIDENTIFIER], [mtSecurity] [INT])  
	CREATE TABLE [#StoreTbl]([StoreGUID] UNIQUEIDENTIFIER, [Security] INT)  

	--Filling temporary tables  
	INSERT INTO [#MatTbl]	EXEC [prcGetMatsList] 0X00, 0X00,257  
	IF (@DetailSubStores = 1)
		INSERT INTO [#StoreTbl]	EXEC [prcGetStoresList] @StGUID
	ELSE
		INSERT INTO [#StoreTbl] SELECT [stGuid],[stSecurity] FROM vwSt WHERE ISNULL(@StGUID,0X00) = 0X00 OR  [stGuid] = @StGUID
	
	CREATE TABLE [#t_Prices] 
	( 
		[MatGUID] 	[UNIQUEIDENTIFIER], 
		[Price] 	[FLOAT] 
	)
	CREATE TABLE [#ma2]
	(
		[ObjGUID]		UNIQUEIDENTIFIER,
		[AccGUID]		UNIQUEIDENTIFIER,
		[DiscAccGUID]	UNIQUEIDENTIFIER
	)
	--FirstPeriod Price
	INSERT INTO [#ma2]([ObjGUID],[AccGUID],[DiscAccGUID])		
	SELECT 
		[ObjGUID],[MatAccGUID],[DiscAccGUID]
	FROM     
		[ma000]  AS [ma]  INNER JOIN [vwbt] ON [BillTypeGUID] = [btGUID]
	WHERE  
		[ma].[Type] = 1   		-- Material Only
		AND [btSortNum] = 1	-- »÷«⁄… ¬Œ— „œ…
		AND [btType] = 2 AND ([DiscAccGUID] <> 0X00 OR [MatAccGUID] <> 0X00)
	---
	IF @PriceType = 2 AND @PricePolicy = 122 -- LastPrice 
		EXEC [prcGetLastPrice] '1/1/1980',@StDate, 0X00, 0X00, @StGUID, @CostGUID, -1, @CurPtr, @SrcGuid, 0, 0 
	ELSE IF @PriceType = 2 AND @PricePolicy = 120 -- MaxPrice 
		EXEC [prcGetMaxPrice] '1/1/1980',@StDate,  0X00, 0X00, @StGUID, @CostGUID, -1, @CurPtr, @CurVal, @SrcGuid, 0, 0 
	ELSE IF @PriceType = 2 AND @PricePolicy = 121 -- COST And AvgPrice 
		EXEC [prcGetAvgPrice] '1/1/1980',@StDate,  0X00, 0X00, @StGUID, @CostGUID, -1, @CurPtr, @CurVal, @SrcGuid, 0, 0 
	ELSE IF @PriceType = 2 AND @PricePolicy = 124 -- LastPrice with extra and discount
		EXEC [prcGetLastPrice] '1/1/1980' , @StDate , 0X00, 0X00, @StGUID, @CostGUID, -1,	@CurPtr, @SrcGuid, 0, 0, 0 /*@CalcLastCost*/,	1 /*@ProcessExtra*/
	ELSE IF @PriceType = 2 AND @PricePolicy = 125
		EXEC [prcGetFirstInFirstOutPrise] '1/1/1980' , @StDate,@CurPtr	
	ELSE 
		EXEC prcGetMtPrice 0X00, 0X00, 0X00, @CurPtr, @CurVal, 0X00, @PriceType, @PricePolicy, 0, 0 
	SELECT SUM([buDirection]*([biQty] + [biBonusQnt])) as [Qty],[biMatPtr],[buSecurity],[mtSecurity],[buType]
	INTO #Qnts
	FROM [vwbubi] [bi] 
	INNER JOIN [vwmt] [mt] ON [mtGuid] = [biMatPtr]
	INNER JOIN [#StoreTbl] AS [st] ON [StoreGUID] = [biStorePtr]
	INNER JOIN [#CostTbl] AS [co] ON [CostGUID] = [biCostPtr]
	WHERE [buDate] BETWEEN '1/1/1980' AND @StDate 
	GROUP BY [biMatPtr],[buSecurity],[mtSecurity],[buType]
	IF (@Admin = 0)
	BEGIN
		UPDATE [#Qnts] SET [buSecurity] = 0 WHERE [mtSecurity] <= dbo.fnGetUserReadMatBalSec(@UserGuid)
		DELETE [#Qnts] WHERE [mtSecurity] > dbo.fnGetUserMaterialSec_Browse(@UserGuid)
		INSERT INTO [#SecViol] VALUES( @@ROWCOUNT ,7)
		DELETE [#Qnts] WHERE [buSecurity] > dbo.fnGetUserBillSec_Browse(@UserGuid,[buType])
		INSERT INTO [#SecViol] VALUES( @@ROWCOUNT ,1)
	END
	
	SELECT [Qty]*ISNULL([Price],0)  [Price],[biMatPtr] INTO #Prices	FROM [#Qnts] INNER JOIN [#t_Prices] AS [p] ON [MatGUID] = [biMatPtr]
	------- Income Coods
	SELECT SUM([Price]) AS [Price],ISNULL ([DiscAccGUID],0X00) AS [AccGUID]
	INTO [#Goods]	
	FROM #Prices
	LEFT JOIN (SELECT * FROM [#ma2] WHERE [DiscAccGUID] <> 0X00) [ma] ON [ObjGUID] = [biMatPtr] 
	GROUP BY [DiscAccGUID]
	UPDATE [#Goods] SET [AccGUID] = [btDefDiscAcc]
			FROM [vwbt]	WHERE [btSortNum] = 1	-- »÷«⁄… ¬Œ— „œ…
			AND [btType] = 1		-- »÷«⁄… ¬Œ— „œ…
			AND [AccGUID] = 0X00
	INSERT INTO #FPACC2 SELECT [AccGUID],SUM(-[Price]),0
	FROM [#Goods] GROUP BY [AccGUID]
	------ Cashflow Goods
	SELECT SUM([Price]) AS [Price],ISNULL ([AccGUID],0X00) AS [AccGUID]
	INTO [#Goods2]	
	FROM #Prices
	LEFT JOIN (SELECT * FROM [#ma2] WHERE [AccGUID] <> 0X00) [ma] ON [ObjGUID] = [biMatPtr]
	GROUP BY [AccGUID]
	UPDATE [#Goods2] SET [AccGUID] = btDefBillAcc
			FROM [vwbt]	WHERE [btSortNum] = 1	-- »÷«⁄… ¬Œ— „œ…
			AND [btType] = 1		-- »÷«⁄… ¬Œ— „œ…
			AND [AccGUID] = 0X00
	INSERT INTO #FPACC2 SELECT [AccGUID],SUM(-[Price]),0
	FROM [#Goods2] GROUP BY [AccGUID]
	------
	TRUNCATE TABLE [#ma2]
	TRUNCATE TABLE [#t_Prices]
	TRUNCATE TABLE  [#Goods]
	TRUNCATE TABLE #Qnts
	-- Last period goods
	INSERT INTO [#ma2]		
	SELECT 
		[ObjGUID],[MatAccGUID],
		[DiscAccGUID]
	
	FROM     
		[ma000]  AS [ma]  INNER JOIN [vwbt] ON [BillTypeGUID] = [btGUID]
	WHERE  
		[ma].[Type] = 1   		-- Material Only
		AND [btSortNum] = 2	-- »÷«⁄… ¬Œ— „œ…
		AND [btType] = 2		-- »÷«⁄… ¬Œ— „œ…
		AND ([MatAccGUID] <> 0X00 OR [DiscAccGUID] <> 0X00)
	IF @PriceType = 2 AND @PricePolicy = 122 -- LastPrice 
		EXEC [prcGetLastPrice] '1/1/1980',@EndDate, 0X00, 0X00, @StGUID, @CostGUID, -1, @CurPtr, @SrcGuid, 0, 0 
	ELSE IF @PriceType = 2 AND @PricePolicy = 120 -- MaxPrice 
		EXEC [prcGetMaxPrice] '1/1/1980',@EndDate,  0X00, 0X00, @StGUID, @CostGUID, -1, @CurPtr, @CurVal, @SrcGuid, 0, 0 
	ELSE IF @PriceType = 2 AND @PricePolicy = 121 -- COST And AvgPrice 
		EXEC [prcGetAvgPrice] '1/1/1980',@EndDate,  0X00, 0X00, @StGUID, @CostGUID, -1, @CurPtr, @CurVal, @SrcGuid, 0, 0 
	ELSE IF @PriceType = 2 AND @PricePolicy = 124 -- LastPrice with extra and discount
		EXEC [prcGetLastPrice] '1/1/1980' , @EndDate , 0X00, 0X00, @StGUID, @CostGUID, -1,	@CurPtr, @SrcGuid, 0, 0, 0 /*@CalcLastCost*/,	1 /*@ProcessExtra*/
	ELSE IF @PriceType = 2 AND @PricePolicy = 125
		EXEC [prcGetFirstInFirstOutPrise] '1/1/1980' , @EndDate,@CurPtr	
	ELSE 
		EXEC prcGetMtPrice 0X00, 0X00, 0X00, @CurPtr, @CurVal, 0X00, @PriceType, @PricePolicy, 0, 0 
	INSERT INTO #Qnts
	SELECT SUM([buDirection]*([biQty] + [biBonusQnt])) as [Qty],[biMatPtr],[buSecurity],[mtSecurity],[buType]
	
	FROM [vwbubi] [bi] 
	INNER JOIN [vwmt] [mt] ON [mtGuid] = [biMatPtr]
	INNER JOIN [#StoreTbl] AS [st] ON [StoreGUID] = [biStorePtr]
	INNER JOIN [#CostTbl] AS [co] ON [CostGUID] = [biCostPtr]
	WHERE [buDate] BETWEEN '1/1/1980' AND @EndDate 
	GROUP BY [biMatPtr],[buSecurity],[mtSecurity],[buType]
	IF (@Admin = 0)
	BEGIN
		UPDATE [#Qnts] SET [buSecurity] = 0 WHERE [mtSecurity] <= dbo.fnGetUserReadMatBalSec(@UserGuid)
		DELETE [#Qnts] WHERE [mtSecurity] > dbo.fnGetUserMaterialSec_Browse(@UserGuid)
		INSERT INTO [#SecViol] VALUES( @@ROWCOUNT ,7)
		DELETE [#Qnts] WHERE [buSecurity] > dbo.fnGetUserBillSec_Browse(@UserGuid,[buType])
		INSERT INTO [#SecViol] VALUES( @@ROWCOUNT ,1)
	END
	TRUNCATE TABLE #Prices
	INSERT INTO #Prices SELECT [Qty]*ISNULL([Price],0)  [Price],[biMatPtr] 	FROM [#Qnts] INNER JOIN [#t_Prices] AS [p] ON [MatGUID] = [biMatPtr]
	----
	INSERT INTO [#Goods]	
	SELECT SUM([Price]) AS [Price],ISNULL ([DiscAccGUID],0X00) AS [AccGUID]
	FROM #Prices
	LEFT JOIN  (SELECT * FROM [#ma2] WHERE [DiscAccGUID] <> 0X00) [ma] ON [ObjGUID] = [biMatPtr]
	GROUP BY [DiscAccGUID]
	UPDATE [#Goods] SET [AccGUID] = [btDefDiscAcc]
			FROM [vwbt]	WHERE [btSortNum] = 2	-- »÷«⁄… ¬Œ— „œ…
			AND [btType] = 2		-- »÷«⁄… ¬Œ— „œ…
			AND ([AccGUID] = 0X00 OR [AccGUID] IS NULL)
	---
	INSERT INTO [#Goods2]	
	SELECT SUM([Price]) AS [Price],ISNULL ([AccGUID],0X00) AS [AccGUID]
	FROM #Prices
	LEFT JOIN  (SELECT * FROM [#ma2] WHERE [AccGUID] <> 0X00) [ma] ON [ObjGUID] = [biMatPtr]
	GROUP BY [AccGUID]
	UPDATE [#Goods2] SET [AccGUID] = btDefBillAcc
			FROM [vwbt]	WHERE [btSortNum] = 2	-- »÷«⁄… ¬Œ— „œ…
			AND [btType] = 2		-- »÷«⁄… ¬Œ— „œ…
			AND ([AccGUID] = 0X00 OR [AccGUID] IS NULL)
	---
	INSERT INTO #FPACC2 SELECT [AccGUID],SUM([Price]),0
	FROM [#Goods] GROUP BY [AccGUID]
	
	INSERT INTO #FPACC2 SELECT [AccGUID],SUM([Price]),1
	FROM [#Goods2] GROUP BY [AccGUID]
################################################################################
CREATE PROCEDURE prc_getIncome 
	@StartDate 			DATETIME,   
	@EndDate 			DATETIME,      
	@CurPtr				UNIQUEIDENTIFIER,      
	@CostGUID 			UNIQUEIDENTIFIER, -- 0 all costs so don't Check cost or list of costs  	 
	@StGUID				UNIQUEIDENTIFIER, -- 0 all stores so don't check store or list of stores  	 
	@Final				UNIQUEIDENTIFIER, 
	@DetailSubStores		INT,	 -- 1 show details 0 no details  for Stores  
	@PriceType			INT,	  
	@PricePolicy			INT,       
	@Posted				INT, 
	@UserSec			INT, 
	@CurVal				FLOAT, 
	@SrcGuid			[UNIQUEIDENTIFIER] = 0X0 
AS  
	DECLARE @UserGuid [UNIQUEIDENTIFIER] ,@Admin [BIT] 
	SET @UserGuid = [dbo].[fnGetCurrentUserGUID]() 
	SELECT @Admin = [bAdmin] FROM [Us000] WHERE [Guid] =@UserGuid 
	CREATE TABLE [#FRAccTbl]( [Guid] [UNIQUEIDENTIFIER], [Security] [INT], [Lvl] [INT])   
	INSERT INTO [#FRAccTbl] EXEC [prcGetAccountsList] @Final 
	SELECT  [acc].[Guid],CASE WHEN [acc].[Security] > [f].[Security] THEN [acc].[Security] ELSE [f].[Security] END AS [Security] ,[BalSheetGuid]
	INTO [#LsAcc] 
	FROM [#AccTbl2] AS [acc]  
	INNER JOIN [#FRAccTbl] AS [f] ON [acc].[Final] = [f].[Guid] 
	 
	-- Last period goods 
	SELECT  
		[ObjGUID], 
		[DiscAccGUID] 
	INTO [#MA]		 
	FROM      
		[ma000]  AS [ma]  INNER JOIN [vwbt] ON [BillTypeGUID] = [btGUID] 
	WHERE   
		[ma].[Type] = 1   		-- Material Only 
		AND [btSortNum] = 2	-- »÷«⁄… ¬Œ— „œ… 
		AND [btType] = 2		-- »÷«⁄… ¬Œ— „œ… 
	--EXEC prc_EPGoods @StartDate ,@EndDate,@CurPtr,@CostGUID ,@StGUID,@Final,@DetailSubStores,@PriceType,@PricePolicy,@Posted,@UserSec,@CurVal,1,@UserGuid,@Admin		 
	CREATE TABLE #FPACC2
	( 
		[AccGUID]		UNIQUEIDENTIFIER, 
		[Price]			[FLOAT] ,
		[Type]			TINYINT
	) 
	EXEC prc_EPGoods @StartDate ,@EndDate,@CurPtr,@CostGUID ,@StGUID,@Final,@DetailSubStores,@PriceType,@PricePolicy,@Posted,@UserSec,@CurVal,@UserGuid,@Admin				 
	INSERT INTO [#T_RESULT] 
	( [Debit],[Credit],[BalsheetIsCash],[CashFlowType],[Security],[AccSecurity],[UserSecurity],[InTime])  
	SELECT 0,SUM([Price]),ISNULL([bs].[IsCash],-1),0,0,[Security],@UserSec,1 
	FROM [#FPACC2] fp
	INNER JOIN [#LsAcc] ON [AccGUID] = [Guid] 
	LEFT JOIN [BalSheet000] [bs] ON [bs].[Guid] = [#LsAcc].[BalSheetGuid]
	WHERE fp.Type = 0
	GROUP BY [Security] ,[bs].[IsCash]
	
	INSERT INTO [#T_RESULT] 
	( [Debit],[Credit],[BalsheetIsCash],[CashFlowType],[Security],[AccSecurity],[UserSecurity],[InTime],[BalSheetNumber],[BalSheetParent],[BalSheetName])  
	SELECT SUM([Price]),0,ISNULL([bs].[IsCash],-1),0,0,[Security],@UserSec,1,[bs].[Name],[bs].[Parent],[bs].[Number]
	FROM [#FPACC2] fp
	INNER JOIN [#LsAcc] ON [AccGUID] = [Guid] 
	INNER  JOIN [BalSheet000] [bs] ON [bs].[Guid] = [#LsAcc].[BalSheetGuid]
	WHERE fp.Type = 1
	GROUP BY [Security] ,[bs].[IsCash],[bs].[Name],[bs].[Parent],[bs].[Number]
 
	--INSERT INTO [#T_RESULT] 
	--( [Debit],[Credit],[BalsheetIsCash],[CashFlowType],[Security],[AccSecurity],[UserSecurity])  
	--SELECT SUM([FixedenDebit]),SUM([FixedenCredit]),-1,0,[ceSecurity],[Security],@UserSec  
	--FROM [dbo].[fnCeEn_Fixed](@CurPtr) [en] INNER JOIN [#LsAcc] [ac] ON [enAccount] = [ac].[Guid] 
	--WHERE  [enDate] BETWEEN @StartDate AND @EndDate  AND (@Posted = -1 OR [ceIsPosted] = @Posted) 
	--GROUP BY [ceSecurity],[Security] 
	--IF @@ROWCOUNT = 0 
	--	INSERT INTO [#T_RESULT] 
	--	( [Credit],[Debit],[BalsheetIsCash],[CashFlowType],[Security],[AccSecurity],[UserSecurity])  
	--	VALUES(0,0,-1,0,0,0,0) 

	INSERT INTO [#T_RESULT] 
	( [Debit],[Credit],[BalsheetIsCash],[CashFlowType],ac.[Security],[AccSecurity],[UserSecurity])  
	SELECT SUM([FixedenDebit]),SUM([FixedenCredit]),-1,0,[ceSecurity],ac.[Security],@UserSec  
	FROM [dbo].[fnCeEn_Fixed](@CurPtr) [en] INNER JOIN ac000 [ac] ON [enAccount] = [ac].[Guid] 
	Inner join ac000 as [fa] on [ac].FinalGUID = [fa].GUID
	WHERE  fa.[incometype] = 1 and [enDate] BETWEEN @StartDate AND @EndDate  AND (@Posted = -1 OR [ceIsPosted] = @Posted) 
	GROUP BY [ceSecurity],ac.[Security] 
	IF @@ROWCOUNT = 0 
		INSERT INTO [#T_RESULT] 
		( [Credit],[Debit],[BalsheetIsCash],[CashFlowType],ac.[Security],[AccSecurity],[UserSecurity])  
		VALUES(0,0,-1,0,0,0,0) 
################################################################################
CREATE PROCEDURE repCashFlow 
	@StartDate 		DATETIME,   
	@EndDate 		DATETIME,      
	@CostGUID 		UNIQUEIDENTIFIER, -- 0 all costs so don't Check cost or list of costs  	 
	@StGUID			UNIQUEIDENTIFIER, -- 0 all stores so don't check store or list of stores  	 
	@lpFinal		UNIQUEIDENTIFIER, 
	@Final			UNIQUEIDENTIFIER, 
	@DetailSubStores		INT,	 -- 1 show details 0 no etails  for Stores  
	@PriceType				INT,	  
	@PricePolicy			INT,       
	@Posted					INT, 
	@Details				BIT = 0, 
	@Level					INT	= 0, 
	@AccDetails				BIT = 0, 
	@SrcGuid		    [UNIQUEIDENTIFIER] = 0X0, 
	@PrevBalFE			[BIT] = 0,
	@OrderAsc			BIT = 0,
	@hasperiods			BIT = 0,   
	@CurPtr				UNIQUEIDENTIFIER,     
	@CurVal				FLOAT

AS 
	SET NOCOUNT ON  
	DECLARE @OpeningEntryType UNIQUEIDENTIFIER   
	SET @OpeningEntryType = (SELECT [Value] FROM op000 WHERE [Name] ='FSCfg_OpeningEntryType')   
	DECLARE  @FPDate DATETIME 
	SET @FPDate = (SELECT CONVERT(DATETIME, value , 105) FROM op000 WHERE Name = 'AmnCfg_FPDate')

	CREATE TABLE [#SecViol]( [Type] [INT], [Cnt] [INT])   
	CREATE TABLE [#CostTbl]( [CostGUID] UNIQUEIDENTIFIER, [Security] INT)  

	CREATE TABLE [#RESULT] 
	(          
		[FBalance] 			[FLOAT],
		[EBalance]			[FLOAT],      
		[Type] 				[INT],   
		[CashFlowType]		[INT],
		[IncomeType]		[INT],   
		[AccountGuid]		[UNIQUEIDENTIFIER],
		[AccountName]		NVARCHAR(255) COLLATE ARABIC_CI_AI 
	)
	
	-------------------------------------------------------------------------------------------
	INSERT INTO [#CostTbl]		EXEC [prcGetCostsList] 		@CostGUID 
	IF @CostGUID = 0X0
		INSERT INTO [#CostTbl] VALUES(0X0,0) 
	-------------------------------------------------------------------------------------------
	DECLARE @netIncome FLOAT
	SET @netIncome = 
	(SELECT 
		SUM([EnCredit] - [EnDebit]) / @CurVal
	FROM [dbo].[vwCeEn] [FIXEN] 
		INNER JOIN ac000 AS [AC] ON [AC].GUID = [FIXEN].enAccount
		INNER JOIN ac000 AS [FA] ON [FA].GUID = [AC].FinalGUID
		INNER JOIN en000 AS [EN] ON EN.GUID = FIXEN.enGUID
		INNER JOIN #CostTbl [CO] ON EN.CostGUID = CO.CostGUID
	WHERE [enDate] BETWEEN  @StartDate   AND @EndDate
		AND [AC].[IncomeType] > 0
		AND [FA].[IncomeType] = 1
		AND (@Posted = -1 OR [ceIsPosted] = @Posted)
		AND [FIXEN].ceTypeGUID <> @OpeningEntryType
	)
	
	INSERT INTO [#RESULT]([CashFlowType], [Type], [FBalance]) VALUES (0, 0, @netIncome)
	-------------------------------------------------------------------------------------------
	INSERT INTO [#RESULT]([CashFlowType], [IncomeType], [TYPE],[FBalance], [EBalance]) VALUES (1,14,1,0,0),(1,15,1,0,0),(1,18,1,0,0),(2,13,1,0,0),(3,8,1,0,0),(3,9,1,0,0),(3,10,1,0,0),(3,11,1,0,0),(3,12,1,0,0),(3,17,1,0,0),(4,16,4,0,0)
	-------------------------------------------------------------------------------------------
	UPDATE [#RESULT] SET [FBalance] = ISNULL(G.BALANCE, 0)
	FROM
	(SELECT SUM(EnDebit - EnCredit) / @CurVal BALANCE,[AC].CashFlowType, [AC].IncomeType
	FROM [dbo].[vwCeEn] [FIXEN] 
		INNER JOIN ac000 AS [AC] ON [AC].GUID = [FIXEN].enAccount
		INNER JOIN ac000 AS [FA] ON [FA].GUID = [AC].FinalGUID
		INNER JOIN en000 AS [EN] ON EN.GUID = FIXEN.enGUID
		INNER JOIN #CostTbl [CO] ON EN.CostGUID = CO.CostGUID
	WHERE 
		([FA].IncomeType = 2 or [FA].IncomeType = 3)
		AND ([FIXEN].enDate < @StartDate OR [FIXEN].ceTypeGUID = @OpeningEntryType)
		AND (@Posted = -1 OR [ceIsPosted] = @Posted)
	GROUP BY [AC].CashFlowType, [AC].IncomeType) AS G
	WHERE G.CashFlowType = #RESULT.CashFlowType AND G.IncomeType = #RESULT.IncomeType
	-------------------------------------------------------------------------------------------
	UPDATE [#RESULT] SET [EBalance] = ISNULL(G.BALANCE,0)
						
	FROM
	(SELECT SUM(EnDebit - EnCredit) / @CurVal BALANCE,[AC].CashFlowType, [AC].IncomeType
	FROM [dbo].[vwCeEn] [FIXEN] 
		INNER JOIN ac000 AS [AC] ON [AC].GUID = [FIXEN].enAccount
		INNER JOIN ac000 AS [FA] ON [FA].GUID = [AC].FinalGUID
		INNER JOIN en000 AS [EN] ON EN.GUID = FIXEN.enGUID
		INNER JOIN #CostTbl [CO] ON EN.CostGUID = CO.CostGUID
	WHERE 
		([FA].IncomeType = 2 or [FA].IncomeType = 3)
		AND [FIXEN].enDate <= @EndDate
		AND (@Posted = -1 OR [ceIsPosted] = @Posted)
	GROUP BY [AC].CashFlowType, [AC].IncomeType) AS G
	WHERE G.CashFlowType = [#RESULT].CashFlowType AND G.IncomeType = [#RESULT].IncomeType
	-------------------------------------------------------------------------------------------
	
	DECLARE @Corrective TABLE 
	(
		AccountGuid			[UNIQUEIDENTIFIER],
		OperationalAffect	INT,
		Destination			INT,
		Balance				FLOAT
	)
	
	-------------------------------------------------------------------------------------------
	DECLARE @correctiveaccount	UNIQUEIDENTIFIER
	DECLARE @OperationalAffect	INT
	DECLARE @Destination		INT

	DECLARE corrective_cursor CURSOR FOR 
	SELECT AccountGuid, OperationalAffect, Destination
	FROM correctiveaccount000

	OPEN corrective_cursor

	FETCH NEXT FROM corrective_cursor 
	INTO @correctiveaccount, @OperationalAffect, @Destination

	WHILE @@FETCH_STATUS = 0
	BEGIN
		
		INSERT INTO @Corrective
		SELECT [CA].GUID, @OperationalAffect, @Destination, SUM(ABS(EnDebit - EnCredit)) / @CurVal
		FROM [dbo].[vwCeEn] [FIXEN] 
		INNER JOIN fnGetAccountsList(@correctiveaccount, 0) [CA] ON [CA].[GUID] = [FIXEN].[enAccount] 
		INNER JOIN ac000 [AC] ON [AC].GUID = [CA].GUID
		INNER JOIN en000 AS [EN] ON EN.GUID = FIXEN.enGUID
		INNER JOIN #CostTbl [CO] ON EN.CostGUID = CO.CostGUID
		WHERE 
			[FIXEN].enDate BETWEEN @StartDate AND @EndDate
			AND [FIXEN].ceTypeGUID <> @OpeningEntryType
			AND (@Posted = -1 OR [ceIsPosted] = @Posted)
		GROUP BY [CA].GUID
   
		FETCH NEXT FROM corrective_cursor
		INTO @correctiveaccount, @OperationalAffect, @Destination
	END 
	CLOSE corrective_cursor
	DEALLOCATE corrective_cursor
	-------------------------------------------------------------------------------------------
	
	INSERT INTO [#RESULT]
	SELECT 
		CASE operationalAffect WHEN 0 THEN Balance
							   WHEN 1 THEN -1 * Balance END,
		0,
		3,
		CASE Destination WHEN 0 THEN 2
						 WHEN 1 THEN 3 END,
		100,
		[AC].GUID,
		[AC].Name
	FROM @Corrective AS [CA]
	INNER JOIN ac000 [AC] ON [AC].GUID = [CA].[AccountGuid]
	
	INSERT INTO [#RESULT]
	SELECT 
		CASE operationalAffect WHEN 0 THEN -1 * Balance
							   WHEN 1 THEN Balance END,
		0,
		3,
		1,
		100,
		[AC].GUID,
		[AC].Name
	FROM @Corrective AS [CA]
	INNER JOIN ac000 [AC] ON [AC].GUID = [CA].[AccountGuid]
	-------------------------------------------------------------------------------------------
	IF(@Details = 1)
	BEGIN
		INSERT INTO [#RESULT]
		SELECT DISTINCT  0, 0, 2, [AC].CashFlowType, [AC].IncomeType, [BS].GUID, [BS].Name
		FROM ac000 [AC]  
			INNER JOIN ac000 [FA] on [FA].[GUID] = [AC].[FinalGUID] 
			INNER JOIN BalSheet000 [BS] ON [BS].GUID = AC.BalsheetGuid
		WHERE 
			([FA].IncomeType = 2 or [FA].IncomeType = 3) AND [AC].IncomeType <> 16
		-----------------------------------------------------------------------------------------
		UPDATE [#RESULT] SET [FBalance] = ISNULL(G.BALANCE,0)						
		FROM
		(SELECT SUM(EnDebit - EnCredit) / @CurVal AS BALANCE, [AC].CashFlowType, [AC].IncomeType, [BS].GUID [AccountGuid], [BS].Name
		FROM [dbo].[vwCeEn] [FIXEN] 
		INNER JOIN ac000 [AC] ON [AC].[GUID] = [FIXEN].[enAccount] 
		INNER JOIN ac000 [FA] on [FA].[GUID] = [AC].[FinalGUID] 
		INNER JOIN BalSheet000 [BS] ON [BS].GUID = AC.BalsheetGuid
		INNER JOIN en000 AS [EN] ON EN.GUID = FIXEN.enGUID
		INNER JOIN #CostTbl [CO] ON EN.CostGUID = CO.CostGUID
		WHERE 
			([FA].IncomeType = 2 or [FA].IncomeType = 3)
			AND ([FIXEN].enDate < @StartDate OR [FIXEN].ceTypeGUID = @OpeningEntryType)
			AND [AC].IncomeType <> 16
			AND (@Posted = -1 OR [ceIsPosted] = @Posted)
		GROUP BY [AC].CashFlowType, [AC].IncomeType, [BS].GUID, [BS].Name) AS G
		WHERE G.[AccountGuid] = [#RESULT].[AccountGuid] AND G.CashFlowType = #RESULT.CashFlowType AND G.IncomeType = #RESULT.IncomeType
		-------------------------------------------------------------------------------------------
		UPDATE [#RESULT] SET [EBalance] = ISNULL(G.BALANCE,0)
		FROM
		(SELECT SUM(EnDebit - EnCredit) / @CurVal AS BALANCE, [AC].CashFlowType, [AC].IncomeType, [BS].GUID [AccountGuid], [BS].Name
		FROM [dbo].[vwCeEn] [FIXEN] 
		INNER JOIN ac000 [AC] ON [AC].[GUID] = [FIXEN].[enAccount] 
		INNER JOIN ac000 [FA] on [FA].[GUID] = [AC].[FinalGUID] 
		INNER JOIN BalSheet000 [BS] ON [BS].GUID = AC.BalsheetGuid
		INNER JOIN en000 AS [EN] ON EN.GUID = FIXEN.enGUID
		INNER JOIN #CostTbl [CO] ON EN.CostGUID = CO.CostGUID
		WHERE 
			([FA].IncomeType = 2 or [FA].IncomeType = 3)
			AND [FIXEN].enDate <= @EndDate
			AND [AC].IncomeType <> 16
			AND (@Posted = -1 OR [ceIsPosted] = @Posted)
		GROUP BY [AC].CashFlowType, [AC].IncomeType, [BS].GUID, [BS].Name) AS G
		WHERE G.[AccountGuid] = [#RESULT].[AccountGuid] AND G.CashFlowType = #RESULT.CashFlowType AND G.IncomeType = #RESULT.IncomeType
	END
	-------------------------------------------------------------------------------------------
	UPDATE [#RESULT] SET [FBalance] = ABS(ISNULL(G.BALANCE, 0))
	FROM
	(SELECT SUM(EnDebit - EnCredit) / @CurVal AS BALANCE, [AC].IncomeType
	FROM [vwCeEn] [FIXEN] 
		INNER JOIN ac000 AS [AC] ON [AC].GUID = [FIXEN].enAccount
		INNER JOIN ac000 AS [FA] ON [FA].GUID = [AC].FinalGUID
		INNER JOIN en000 AS [EN] ON EN.GUID = FIXEN.enGUID
		INNER JOIN #CostTbl [CO] ON EN.CostGUID = CO.CostGUID
	WHERE 
		([FA].IncomeType = 3)
		AND AC.IncomeType = 16
		AND [FIXEN].ceTypeGUID = @OpeningEntryType
		AND (@Posted = -1 OR [ceIsPosted] = @Posted)
	GROUP BY [AC].IncomeType) AS G
	WHERE G.IncomeType = #RESULT.IncomeType
	-------------------------------------------------------------------------------------------
	Exec [prcCheckSecurity]	 
	
	SELECT 
		ISNULL([FBalance], 0.0) AS [FBalance],
		ISNULL([EBalance], 0.0) AS [EBalance],
		ISNULL([Type], 0) AS [Type],
		ISNULL([CashFlowType], 0) AS [CashFlowType],
		ISNULL([IncomeType], 0) AS [IncomeType],
		ISNULL([AccountGuid], 0x00) AS [AccountGuid],
		ISNULL([AccountName], '') AS [AccountName] 
	FROM #RESULT ORDER BY CashFlowType , IncomeType , Type
	-------------------------------------------------------------------------------------------
	SELECT COUNT(*) COUNT
	FROM ac000 [AC] INNER JOIN ac000 [FAC] ON [AC].FinalGUID = [FAC].GUID
	WHERE [FAC].IncomeType <= 3 AND [AC].IncomeType = 0 AND [AC].NSons = 0
	SELECT * FROM [#SecViol] 
###################################################################################
CREATE  PROCEDURE repBalSheet
	@FAccGuid	UNIQUEIDENTIFIER,
	@CostGuid	UNIQUEIDENTIFIER,
	@StartDate	DATETIME,
	@EndDate	DATETIME,
	@SrcGuid	UNIQUEIDENTIFIER,
	@CurPtr		UNIQUEIDENTIFIER,
	@IsPosted	BIT
AS
	
	SET NOCOUNT ON 
	DECLARE @Admin [INT],@UserGuid [UNIQUEIDENTIFIER],@CNT INT  
	SET @UserGuid = [dbo].[fnGetCurrentUserGUID]()  
	SET @Admin = [dbo].[fnIsAdmin](ISNULL(@userGUID,0x00) ) 
	CREATE TABLE [#AccTbl]( [Guid] [UNIQUEIDENTIFIER] , [BalSheetGuid] [UNIQUEIDENTIFIER] , Debit [FLOAT] , Credit[FLOAT] , [Sec] [INT])
	CREATE TABLE [#CostTbl]( [CostGUID] UNIQUEIDENTIFIER, [Security] INT)
	CREATE TABLE [#SecViol]( [Type] [INT], [Cnt] [INT])
	CREATE TABLE [#EntryTbl]( [Type] [UNIQUEIDENTIFIER], [Security] [INT])     
	CREATE TABLE [#BillsTypesTbl]( [TypeGUID] [UNIQUEIDENTIFIER], [UserSecurity] [INTEGER], [UserReadPriceSecurity] [INTEGER]) 

	INSERT INTO [#CostTbl]	EXEC [prcGetCostsList] 		@CostGUID  
	IF @CostGUID = 0X00 
		INSERT INTO [#CostTbl] VALUES(0X00,0) 
	
	INSERT INTO [#BillsTypesTbl] EXEC [prcGetBillsTypesList] @SrcGuid     
	
	INSERT INTO [#EntryTbl] EXEC [prcGetEntriesTypesList] @SrcGuid 
	INSERT INTO [#EntryTbl] SELECT [TypeGUID] , [UserSecurity]  FROM [#BillsTypesTbl] 
	
	INSERT INTO [#AccTbl] 
		SELECT GUID , BalSheetGuid , Debit , Credit , Security 
		FROM ac000 ac
		WHERE (FinalGUID = @FAccGuid AND ISNULL(@FAccGuid, 0x0) <> 0x0) OR (ISNULL(@FAccGuid, 0x0) = 0x0)

	CREATE TABLE [#RESULT]
	(
		Debit				FLOAT,
		Credit				FLOAT,
		BalsheetGuid		UNIQUEIDENTIFIER,
		BalSheetName		NVARCHAR(225) COLLATE ARABIC_CI_AI,
		BalSheetParent		INT,  
		acSecurity			INT , 
		[ceSecurity]			INT
	)
	
	INSERT INTO [#RESULT]  SELECT [FixedenDebit],[FixedenCredit],[BalSheetGuid],[bs].[Name],[bs].[Parent],[ac].[Sec],[en].[ceSecurity]
	FROM [dbo].[fnCeEn_Fixed](@CurPtr) [en]  
	INNER JOIN [#AccTbl] [ac] ON [enAccount] = [ac].[Guid] 
	INNER JOIN [#CostTbl] [co] ON [en].[enCostPoint] = [co].[CostGUID] 
	INNER JOIN [BalSheet000] AS [bs] ON [bs].[Guid] = [ac].[BalsheetGuid]
	INNER JOIN [#EntryTbl] AS [t]  ON [en].[ceTypeGuid] = [t].[Type]    
	WHERE  
	([enDate] BETWEEN @StartDate AND @EndDate ) AND  (@IsPosted = -1 OR [ceIsPosted] = @IsPosted)
	
	DECLARE @SecBalPrice [INT]   
	IF @Admin = 0  
	BEGIN  
		SET @SecBalPrice = [dbo].[fnGetUserAccountSec_readBalance]([dbo].[fnGetCurrentUserGuid]())  
		IF @SecBalPrice > 0  
			UPDATE [#Result] SET [ceSecurity] = -10 WHERE [AcSecurity] <= @SecBalPrice  
	END 
	
	Exec [prcCheckSecurity] @RESULT = '#RESULT' 
		
	SELECT SUM(Debit), SUM(Credit), SUM(Debit) - SUM(Credit) Bal, BalsheetGuid , BalSheetName , BalSheetParent
	FROM [#RESULT]
	GROUP BY BalSheetName, BalSheetParent, BalsheetGuid
	ORDER BY BalSheetParent
	
	SELECT * FROM [#SecViol]
###################################################################################
#END 	
