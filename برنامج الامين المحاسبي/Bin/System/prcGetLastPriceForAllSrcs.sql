#########################################################
CREATE PROCEDURE prcGetLastPriceForAllSrcs
	@StartDate 		[DATETIME],
	@EndDate 		[DATETIME],
	@MatGUID 		[UNIQUEIDENTIFIER], -- 0 All Mat or MatNumber
	@GroupGUID 		[UNIQUEIDENTIFIER],
	@StoreGUID 		[UNIQUEIDENTIFIER], --0 all stores so don't check store or list of stores
	@CostGUID 		[UNIQUEIDENTIFIER], -- 0 all costs so don't Check cost or list of costs
	@CurrencyGUID 	[UNIQUEIDENTIFIER],
	@CurrencyVal 	[FLOAT],
	@Vendor 		[FLOAT],
	@SalesMan 		[FLOAT]
AS

	SET NOCOUNT ON
	-- Creating temporary tables
	CREATE TABLE [#SecViol]( [Type] [INT], [Cnt] [INTEGER])
	CREATE TABLE [#MatTbl]( [MatGUID] [UNIQUEIDENTIFIER], [mtSecurity] [INT])
	CREATE TABLE [#BillsTypesTbl]( [TypeGuid] [UNIQUEIDENTIFIER], [UserSecurity] [INTEGER], [UserReadPriceSecurity] [INTEGER])
	CREATE TABLE [#StoreTbl]( [StoreGUID] [UNIQUEIDENTIFIER], [Security] [INT])
	CREATE TABLE [#CostTbl]( [CostGUID] [UNIQUEIDENTIFIER], [Security] [INT])

	--Filling temporary tables
	INSERT INTO [#MatTbl]			EXEC [prcGetMatsList] 			@MatGUID, @GroupGUID
	INSERT INTO [#BillsTypesTbl]	EXEC [prcGetBillsTypesList] 	0x0--'ALL'
	INSERT INTO [#StoreTbl]			EXEC [prcGetStoresList] 		@StoreGUID
	INSERT INTO [#CostTbl]			EXEC [prcGetCostsList]	 		@CostGUID

	CREATE TABLE [#t_Prices2]
	(
		[mtNumber] 	[UNIQUEIDENTIFIER],
		[APrice] 	[FLOAT]
	)

	---get last price by Currency
	EXEC [prcGetLastPrice] @StartDate , @EndDate , @MatGUID, @GroupGUID, @StoreGUID, @CostGUID, -1/*@MatType*/, @CurrencyGUID, 0x0/*@SrcTypesguid*/, 0/*@ShowUnLinked*/, 3/*@UseUnit*/, 0/*@CalcLastCost*/

	INSERT INTO [#t_Prices2] SELECT * FROM [#t_Prices]
	DELETE FROM [#t_Prices]

	EXEC [prcGetLastPrice] @StartDate , @EndDate , @MatGUID, @GroupGUID, @StoreGUID, @CostGUID, -1/*@MatType*/, @CurrencyGUID, 0x0/*@SrcTypesguid*/, 0/*@ShowUnLinked*/, 3/*@UseUnit*/, 1/*@CalcLastCost*/

	INSERT INTO [#t_ALLPrices] SELECT [a].[mtNumber], [b].[APrice], [a].[APrice] FROM [#t_Prices] AS [a] INNER JOIN [#t_Prices2] AS [b] ON [a].[mtNumber] = [b].[mtNumber]

#########################################################
#END