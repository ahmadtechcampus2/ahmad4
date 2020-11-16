##################################################
CREATE PROCEDURE prcGetQntPriceForAllSrcs
	@StartDate 		[DATETIME], 
	@EndDate 		[DATETIME],
	@MatGUID 		[UNIQUEIDENTIFIER], -- 0 All Mat or MatNumber
	@GroupGUID 		[UNIQUEIDENTIFIER],
	@StoreGUID 		[UNIQUEIDENTIFIER], --0 all stores so don't check store or list of stores
	@CostGUID 		[UNIQUEIDENTIFIER], -- 0 all costs so don't Check cost or list of costs
	@CurrencyGUID 	[UNIQUEIDENTIFIER],
	@CurrencyVal 	[FLOAT],
	@Vendor 		[FLOAT], --0
	@SalesMan 		[FLOAT] --0
AS
SET NOCOUNT ON
-- Creating temporary tables
CREATE TABLE [#SecViol]( [Type] [INT], [Cnt] [INTEGER])
CREATE TABLE [#MatTbl]( [MatGUID] [UNIQUEIDENTIFIER], [mtSecurity] [INT])
CREATE TABLE [#BillsTypesTbl]( [TypeGuid] [UNIQUEIDENTIFIER], [UserSecurity] [INTEGER], [UserReadPriceSecurity] [INTEGER])
CREATE TABLE [#StoreTbl]( [StoreGUID] [UNIQUEIDENTIFIER], [Security] [INT])
CREATE TABLE [#CostTbl]( [CostGUID] [UNIQUEIDENTIFIER], [Security] [INT])
-- important dont change the place of these three lines
-- cause fnIsAllMats must called before delete conditions from mc000
--DECLARE @IsAllMats INT
--SET @IsAllMats = 0
--SET @IsAllMats = dbo.fnIsAllMats( @MatPtr, @GroupPtr)

--Filling temporary tables
INSERT INTO [#MatTbl]			EXEC [prcGetMatsList] 			@MatGUID, @GroupGUID
INSERT INTO [#BillsTypesTbl]	EXEC [prcGetBillsTypesList] 	0x0--'ALL'
INSERT INTO [#StoreTbl]			EXEC [prcGetStoresList] 		@StoreGUID
INSERT INTO [#CostTbl]			EXEC [prcGetCostsList] 			@CostGUID

EXEC [prcGetQntPrice] @StartDate, @EndDate, @MatGUID, @GroupGUID, @StoreGUID, @CostGUID, -1/*@MatType*/, @CurrencyGUID, @CurrencyVal, 0x0/*'ALL'*//*@SrcTypes*/, 2/*@PriceType*/, 121/*@PricePolicy*/, 0/*@ShowUnLinked*/, 3/*@UseUnit*/
/*
CREATE TABLE #t_Qtys
(
	mtNumber 	UNIQUEIDENTIFIER,
	Qnt 		FLOAT,
	Qnt2 		FLOAT,
	Qnt3 		FLOAT,
	StorePtr	UNIQUEIDENTIFIER
) --3100 upgard
CREATE TABLE #t_Prices
(
	mtNumber 	UNIQUEIDENTIFIER,
	APrice 		FLOAT
)
---- Get Qtys And Prices
CREATE TABLE #PricesQtys
(
	mtNumber	UNIQUEIDENTIFIER,
	APrice		FLOAT,
	Qnt			FLOAT,
	Qnt2		FLOAT,
	Qnt3		FLOAT,
	StorePtr	UNIQUEIDENTIFIER
)

CREATE TABLE #t_Qtys
(
	mtNumber 	UNIQUEIDENTIFIER,
	Qnt 		FLOAT,
	Qnt2 		FLOAT,
	Qnt3 		FLOAT,
	StorePtr	UNIQUEIDENTIFIER
) --3100 upgard
CREATE TABLE #t_Prices
(
	mtNumber 	UNIQUEIDENTIFIER,
	APrice 		FLOAT
)
---- Get Qtys And Prices
CREATE TABLE #PricesQtys
(
	mtNumber	UNIQUEIDENTIFIER,
	APrice		FLOAT,
	Qnt			FLOAT,
	Qnt2		FLOAT,
	Qnt3		FLOAT,
	StorePtr	UNIQUEIDENTIFIER
)

EXEC prcGetQntPriceForAllSrcs
'1/1/2003',	--@StartDate 		DATETIME, 
'1/1/2004',--	@EndDate 		DATETIME,
0x0,--	@MatGUID 		UNIQUEIDENTIFIER, -- 0 All Mat or MatNumber
0x0,--	@GroupGUID 		UNIQUEIDENTIFIER,
0x0,--	@StoreGUID 		UNIQUEIDENTIFIER, --0 all stores so don't check store or list of stores
0x0,--	@CostGUID 		UNIQUEIDENTIFIER, -- 0 all costs so don't Check cost or list of costs
0x0,--	@CurrencyGUID 	UNIQUEIDENTIFIER,
0,--	@CurrencyVal 	FLOAT,
0,--	@Vendor 		FLOAT, --0
0--	@SalesMan 		FLOAT --0

drop table #t_Qtys
drop table #t_Prices
drop table #PricesQtys

drop TABLE #t_Qtys
drop TABLE #t_Prices
drop TABLE #PricesQtys
*/
#####################################################
#END