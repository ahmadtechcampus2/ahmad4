#########################################################
CREATE PROCEDURE prcCalcEPBill
	@StartDate 		DATETIME,  
	@EndDate 		DATETIME,     
	@CurPtr			UNIQUEIDENTIFIER,     
	@CostGUID 		UNIQUEIDENTIFIER, -- 0 all costs so don't Check cost or list of costs  	
	@StGUID			UNIQUEIDENTIFIER, -- 0 all stores so don't check store or list of stores  	
	@PriceType				INT,	 
	@PricePolicy			INT,      
	@Posted					INT,
	@CurVal					FLOAT,
	@UseUnit				[INT]
AS 
	DECLARE @UserGuid	UNIQUEIDENTIFIER,@Admin [BIT]
	SELECT @Admin = bAdmin FROM [US000] WHERE Guid = @UserGuid
	SET @UserGuid = dbo.fnGetCurrentUserGUID()
	CREATE TABLE [#t_Prices] 
	( 
		[MatGUID] 	[UNIQUEIDENTIFIER],
		[Price] 	[FLOAT] 
	) 
	CREATE TABLE #Qnts ([Qty] FLOAT, [Bonus] FLOAT, [biMatPtr] UNIQUEIDENTIFIER, [buSecurity] INT,
						[mtSecurity] INT , [buType] UNIQUEIDENTIFIER, [biStorePtr] UNIQUEIDENTIFIER ,[FixedTotalDiscountPercent] FLOAT ,[FixedTotalExtraPercent] FLOAT)
	IF @PriceType = 2 AND @PricePolicy = 122 -- LastPrice 
		EXEC [prcGetLastPrice] @StartDate,@EndDate, 0X00, 0X00, @StGUID, @CostGUID, -1, @CurPtr, 0X00, 0, 0 
	ELSE IF @PriceType = 2 AND @PricePolicy = 120 -- MaxPrice 
		EXEC [prcGetMaxPrice] @StartDate,@EndDate,  0X00, 0X00, @StGUID, @CostGUID, -1, @CurPtr, @CurVal, 0X00, 0, 0 
	ELSE IF @PriceType = 2 AND @PricePolicy = 121 -- COST And AvgPrice 
		EXEC [prcGetAvgPrice] @StartDate,@EndDate,  0X00, 0X00, @StGUID, @CostGUID, -1, @CurPtr, @CurVal, 0X00, 0, 0 
	ELSE IF @PriceType = 2 AND @PricePolicy = 124 -- LastPrice with extra and discount
		EXEC [prcGetLastPrice] @StartDate , @EndDate , 0X00, 0X00, @StGUID, @CostGUID, -1,	@CurPtr, 0X00, 0, 0, 0 /*@CalcLastCost*/,	1 /*@ProcessExtra*/
	ELSE IF @PriceType = 2 AND @PricePolicy = 125
		EXEC [prcGetFirstInFirstOutPrise] @StartDate , @EndDate,@CurPtr	
	ELSE 
		EXEC prcGetMtPrice 0X00, 0X00, 0X00, @CurPtr, @CurVal, 0X00, @PriceType, @PricePolicy, 0, @UseUnit 
	INSERT INTO #Qnts SELECT SUM([buDirection] * [biQty]) AS [Qty] ,SUM([buDirection] * [biBonusQnt]) AS [Bonus] ,[biMatPtr],[buSecurity],[mtSecurity],[buType],[biStorePtr], SUM(bi.TotalDiscountPercent) AS FixedTotalDiscountPercent , SUM(bi.TotalExtraPercent) AS FixedTotalExtraPercent
	FROM [vwbubi] [bi] 
	INNER JOIN [#BillsTypesTbl] [Bt] ON [bI].[buType]=[Bt].[TypeGuid]
	INNER JOIN [vwmt] [mt] ON [mtGuid] = [biMatPtr]
	INNER JOIN [#StoreTbl] AS [st] ON [StoreGUID] = [biStorePtr]
	INNER JOIN [#CostTbl] AS [co] ON [CostGUID] = [biCostPtr]
	WHERE [buDate] BETWEEN @StartDate AND @EndDate 
	AND (@Posted = -1 OR [buIsPosted] = @Posted)
	GROUP BY [biMatPtr],[buSecurity],[mtSecurity],[buType],[biStorePtr]
	IF (@Admin = 0)
	BEGIN
		UPDATE [#Qnts] SET [buSecurity] = 0 WHERE [mtSecurity] <= dbo.fnGetUserReadMatBalSec(@UserGuid)
		DELETE [#Qnts] WHERE [mtSecurity] > dbo.fnGetUserMaterialSec_Browse(@UserGuid)
		INSERT INTO [#SecViol] VALUES( @@ROWCOUNT ,7)
		DELETE [#Qnts] WHERE [buSecurity] > dbo.fnGetUserBillSec_Browse(@UserGuid,[buType])
		INSERT INTO [#SecViol] VALUES( @@ROWCOUNT ,1)
	END
	INSERT INTO #QTYS
	SELECT SUM([Qty]),SUM([Bonus]),[Price],[biMatPtr],[biStorePtr], SUM([FixedTotalDiscountPercent]),SUM(FixedTotalExtraPercent)
	FROM [#Qnts] LEFT JOIN [#t_Prices] AS [p] ON [MatGUID] = [biMatPtr]
	GROUP BY [Price],[biMatPtr],[biStorePtr]
###################################################################################
#END