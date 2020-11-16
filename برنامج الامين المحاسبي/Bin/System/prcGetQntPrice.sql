#########################################################
CREATE PROCEDURE prcGetQntPrice
	@StartDate 		[DATETIME],
	@EndDate 		[DATETIME],
	@MatGUID 		[UNIQUEIDENTIFIER], -- 0 All Mat or MatNumber
	@GroupGUID 		[UNIQUEIDENTIFIER],
	@StoreGUID 		[UNIQUEIDENTIFIER], -- 0 all stores so don't check store or list of stores
	@CostGUID 		[UNIQUEIDENTIFIER], -- 0 all costs so don't Check cost or list of costs
	@MatType 		[INT], -- 0 Store or 1 Service or -1 ALL
	@CurrencyGUID 	[UNIQUEIDENTIFIER],
	@CurrencyVal 	[FLOAT],
	@SrcTypesguid	[UNIQUEIDENTIFIER],
	@PriceType 		[INT],
	@PricePolicy 	[INT],
	@ShowUnLinked 	[INT] = 0,
	@UseUnit 		[INT]
AS
	SET NOCOUNT ON
	--- Get Qnt
	EXEC [prcGetQnt] @StartDate, @EndDate, @MatGUID, @GroupGUID, @StoreGUID, @CostGUID, @MatType, 0/*@DetailsStores*/, @SrcTypesguid, @ShowUnLinked
	---Get Price
	IF @PriceType = 2 AND @PricePolicy = 122 -- LastPrice
		EXEC [prcGetLastPrice] @StartDate , @EndDate , @MatGUID, @GroupGUID, @StoreGUID, @CostGUID, @MatType,	@CurrencyGUID, @SrcTypesguid, @ShowUnLinked, @UseUnit
	ELSE IF @PriceType = 2 AND @PricePolicy = 120 -- MaxPrice
		EXEC [prcGetMaxPrice] @StartDate , @EndDate , @MatGUID, @GroupGUID, @StoreGUID, @CostGUID, @MatType,	@CurrencyGUID, @CurrencyVal, @SrcTypesguid, @ShowUnLinked, @UseUnit
	ELSE IF @PriceType = 2 AND @PricePolicy = 121 -- COST And AvgPrice
		EXEC [prcGetAvgPrice]	@StartDate,	@EndDate, @MatGUID, @GroupGUID, @StoreGUID, @CostGUID, @MatType, @CurrencyGUID, @CurrencyVal, @SrcTypesguid, @ShowUnLinked, @UseUnit
	ELSE IF @PriceType = 2 AND @PricePolicy = 124 -- LastPrice with extra and discount
		EXEC [prcGetLastPrice] @StartDate , @EndDate , @MatGUID, @GroupGUID, @StoreGUID, @CostGUID, @MatType,	@CurrencyGUID, @SrcTypesguid, @ShowUnLinked, @UseUnit, 0 /*@CalcLastCost*/,	1 /*@ProcessExtra*/
	ELSE IF @PriceType = 2 AND @PricePolicy = 125
		EXEC [prcGetFirstInFirstOutPrise] @StartDate , @EndDate,@CurrencyGUID	
	ELSE IF @PriceType = -1
		INSERT INTO [#t_Prices] SELECT [MatGUID], 0 FROM [#MatTbl]
	ELSE
		EXEC [prcGetMtPrice] @MatGUID,	@GroupGUID, @MatType, @CurrencyGUID, @CurrencyVal, @SrcTypesguid, @PriceType, @PricePolicy, @ShowUnLinked, @UseUnit,@EndDate

	---- you must use left join cause if details stores you have more than one record for each mat
		INSERT INTO [#PricesQtys]
		SELECT
			[q].[mtNumber],
			ISNULL([p].[APrice], 0) AS [APrice],
			[q].[Qnt],
			[q].[Qnt2],
			[q].[Qnt3],
			[q].[StoreGUID]
		FROM
			[#t_Qtys] AS [q] LEFT JOIN [#t_Prices] AS [p] ON [q].[mtNumber] = [p].[mtNumber]

#########################################################
#END