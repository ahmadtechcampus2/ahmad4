####################################################
CREATE PROCEDURE prcCalcLastPrices
	@StartDate [DATETIME],
	@EndDate [DATETIME],
	@MatPtr [INT], -- 0 All Mat or MatNumber
	@GroupPtr [INT],
	@StorePtr [INT], -- 0 all stores so don't check store or list of stores
	@CostPtr [INT], -- 0 all costs so don't Check cost or list of costs
	@MatType [INT], -- 0 Store or 1 Service or -1 ALL
	@CurrencyPtr [INT],
	@CurrencyVal [FLOAT],
	@DetailsStores [INT], -- 1 show details 0 no details
	@ShowEmpty [INT], --1 Show Empty 0 don't Show Empty
	@SrcTypes [NVARCHAR](2000),-- bill types
	@SortType [INT] = 0, -- 0 NONE, 1 matCode, 2MatName, 3Store
	@ShowUnLinked [INT] = 0,
	@ShowGroups [INT] = 0, -- if 1 add 3 new  columns for groups
	@UseUnit [INT]
AS
BEGIN
	SET NOCOUNT ON
	
	CREATE TABLE [#SecViol]( [Type] [INT], [Cnt] [INTEGER])
--Get Qtys
	CREATE TABLE [#t_Qtys]
	(
		[mtNumber] 	[INT],
		[Qnt] 		[FLOAT],
		[Qnt2] 		[FLOAT],
		[Qnt3] 		[FLOAT],
		[StorePtr]	[INT]
	)
	EXEC [prcGetQnt] @StartDate, @EndDate, @MatPtr, @GroupPtr, @StorePtr, @CostPtr, @MatType, @DetailsStores, @SrcTypes, @ShowUnLinked
	--select * from #t_qtys
-- Get last Prices
	CREATE TABLE [#t_Prices]
	(
		[mtNumber] 	[INT],
		[APrice] 	[FLOAT]
	)
	EXEC [prcGetLastPrice] @StartDate , @EndDate , @MatPtr, @GroupPtr, @StorePtr, @CostPtr, @MatType,	@CurrencyPtr, @SrcTypes, @ShowUnLinked, @UseUnit
	--select * from #t_Prices
---- Get Qtys And Prices
	CREATE TABLE [#PricesQtys]
	(
		[mtNumber]	[INT],
		[APrice]	[FLOAT],
		[Qnt]		[FLOAT],
		[Qnt2]		[FLOAT],
		[Qnt3]		[FLOAT],
		[StorePtr]	[INT]
	)
---- you must use left join cause if details stores you have more than one record for each mat
	INSERT INTO [#PricesQtys] 
	SELECT 
		[q].[mtNumber],
		ISNULL([p].[APrice], 0) AS [APrice],
		[q].[Qnt],
		[q].[Qnt2],
		[q].[Qnt3],
		[q].[StorePtr]
	FROM
		[#t_Qtys] AS [q] LEFT JOIN [#t_Prices] AS [p] ON [q].[mtNumber] = [p].[mtNumber]
	--SELECT * FROM #PricesQtys 
	-- Creating temporary tables
	CREATE TABLE [#MatTbl]( [MatPtr] [INT], [mtSecurity] [INT])
	CREATE TABLE [#StoreTbl](	[StorePtr] [INTEGER], [Security] [INT])

	-- important dont change the place of these three lines
	-- cause fnIsAllMats must called before delete conditions from mc000
	DECLARE @IsAllMats [INT]
	SET @IsAllMats = 0
	SET @IsAllMats = [dbo].[fnIsAllMats]( @MatPtr, @GroupPtr)

	--Filling temporary tables
	INSERT INTO [#MatTbl]		EXEC [prcGetMatsList] 		@MatPtr, @GroupPtr, @MatType
	INSERT INTO [#StoreTbl]		EXEC [prcGetStoresList] 		@StorePtr

	CREATE TABLE [#R]
	(
		[StorePtr]		[INT],
		[mtNumber]		[INT],
		[mtQty]			[FLOAT],
		--Qnt			FLOAT,
		[mtPrice]		[FLOAT],
		[APrice]		[FLOAT],
		[MtUnity]		[NVARCHAR](255) COLLATE ARABIC_CI_AI,
		[MtUnit2]		[NVARCHAR](255) COLLATE ARABIC_CI_AI,
		[MtUnit3]		[NVARCHAR](255) COLLATE ARABIC_CI_AI,
		[mtDefUnitFact]	[FLOAT],
		[grName]		[NVARCHAR](255) COLLATE ARABIC_CI_AI,
		[mtName]		[NVARCHAR](255) COLLATE ARABIC_CI_AI,
		[mtCode]		[NVARCHAR](255) COLLATE ARABIC_CI_AI,
		[mtLatinName]	[NVARCHAR](255) COLLATE ARABIC_CI_AI,
		[mtUnit2Fact]	[FLOAT],
		[mtUnit3Fact]	[FLOAT],
		[mtBarCode]		[NVARCHAR](500) COLLATE ARABIC_CI_AI,
		[mtSpec]		[NVARCHAR](255) COLLATE ARABIC_CI_AI,
		[mtDim]			[NVARCHAR](255) COLLATE ARABIC_CI_AI,
		[mtOrigin]		[NVARCHAR](255) COLLATE ARABIC_CI_AI,
		[mtPos]			[NVARCHAR](255) COLLATE ARABIC_CI_AI,
		[mtCompany]		[NVARCHAR](255) COLLATE ARABIC_CI_AI,
		[mtType]		[INT],
		[mtDefUnitName]	[NVARCHAR](255) COLLATE ARABIC_CI_AI,
		[MtGroup]		[INT]--,
		--StName			NVARCHAR(255) COLLATE ARABIC_CI_AI
	)
	
	INSERT INTO [#R]
	SELECT
		--ISNULL(VMsSt.msStorePtr, 0) AS StorePtr,
		[pr].[StorePtr],
		[v_mt].[mtNumber],
		--v_mt.mtQty,
		[pr].[Qnt],
		--ISNULL(VMsSt.msQty, 0) AS Qnt,
		[mtPrice],
		ISNULL((CASE WHEN @CurrencyVal = 0 THEN [Pr].[APrice] ELSE [Pr].[APrice] / @CurrencyVal END), 0),
		[v_mt].[MtUnity],
		[v_mt].[MtUnit2],
		[v_mt].[MtUnit3],
		[v_mt].[mtDefUnitFact],
		[v_mt].[grName],
		[v_mt].[mtName],
		[v_mt].[mtCode],
		[v_mt].[mtLatinName],
		[v_mt].[mtUnit2Fact],
		[v_mt].[mtUnit3Fact],
		[v_mt].[mtBarCode],
		[v_mt].[mtSpec],
		[v_mt].[mtDim],
		[v_mt].[mtOrigin],
		[v_mt].[mtPos],
		[v_mt].[mtCompany],
		[v_mt].[mtType],
		[v_mt].[mtDefUnitName],
		[v_mt].[MtGroup]--,
		--VMsSt.StName
	FROM
		[dbo].[fnGetMtPricesWithSec]( 2 , 122, @UseUnit, 0x0, @EndDate) AS [v_mt]
		INNER JOIN [#PricesQtys] AS [Pr] ON [v_mt].[mtNumber] = [Pr].[mtNumber]
		--LEFT JOIN VwMsSt AS VMsSt ON v_mt.mtNumber = VMsSt.msMatPtr
	WHERE
		( (@MatType = -1) 						OR ([mtType] = @MatType))
		--AND( (@IsAllMats = 1) 					OR (v_mt.mtNumber IN( SELECT MatPtr FROM #MatTbl)))
		AND( @ShowEmpty = 1) OR ( [v_mt].[mtQty] > 0 AND( (@IsAllMats = 1) OR ([v_mt].[mtNumber] IN( SELECT [MatPtr] FROM [#MatTbl]))))
	
	SELECT
		[v_mt].[StorePtr],
		[v_mt].[mtNumber],
		[v_mt].[mtQty] AS [Qnt],
		[v_mt].[APrice],
		[v_mt].[MtUnity],
		[v_mt].[MtUnit2],
		[v_mt].[MtUnit3],
		[v_mt].[mtDefUnitFact],
		[v_mt].[grName],
		[v_mt].[mtName],
		[v_mt].[mtCode],
		[v_mt].[mtLatinName],
		[v_mt].[mtUnit2Fact],
		[v_mt].[mtUnit3Fact],
		[v_mt].[mtBarCode],
		[v_mt].[mtSpec],
		[v_mt].[mtDim],
		[v_mt].[mtOrigin],
		[v_mt].[mtPos],
		[v_mt].[mtCompany],
		[v_mt].[mtType],
		[v_mt].[mtDefUnitName],
		[v_mt].[MtGroup], 
		CASE WHEN @ShowGroups = 1 THEN 0 END AS [GroupParentPtr],
		(CASE WHEN @ShowGroups = 1 THEN 'm'END) AS [RecType],
		(CASE WHEN @ShowGroups = 1 THEN 0 END) AS [Level],
		(CASE WHEN @DetailsStores = 1 THEN [VMsSt].[StName] END) AS [StName]
	FROM
		[#R] AS [v_mt] LEFT JOIN [VwMsSt] AS [VMsSt] ON [v_mt].[mtNumber] = [VMsSt].[msMatPtr] AND [v_mt].[StorePtr] = [VMsSt].[msStorePtr]
	WHERE
		((@StorePtr = 0) OR ([VMsSt].[msStorePtr] IN( SELECT [StorePtr] FROM [#StoreTbl])))
	ORDER BY
		(CASE 	WHEN @SortType = 1 THEN [mtCode]
			 	WHEN @SortType = 2 THEN [mtName]
				WHEN @SortType = 3 AND @DetailsStores = 1 THEN [StName]
		END)
END
--to be moved to main proc prcCalPricesProc
--SELECT * FROM #SecViol
/*
prcConnections_add 2
EXEC prcCalcLastPrices
'1/1/2002'--	@StartDate DATETIME,
,'7/13/2002'--	@EndDate DATETIME,
,0--	@MatPtr INT, -- 0 All Mat or MatNumber   
,0--	@GroupPtr INT,
,0--	@StorePtr INT, -- 0 all stores so don't check store or list of stores
,1--	@CostPtr INT, -- 0 all costs so don't Check cost or list of costs
,0--	@MatType INT, -- 0 Store or 1 Service or -1 ALL
,1--	@CurrencyPtr INT,
,1--	@CurrencyVal FLOAT,
,0--	@DetailsStores INT, -- 1 show details 0 no details
,0--	@ShowEmpty INT, --1 Show Empty 0 don't Show Empty
,'1,2,3,4'--	@SrcTypes NVARCHAR(2000),-- bill types
,0--	@SortType INT = 0, -- 0 NONE, 1 matCode, 2MatName, 3Store 
,0--	@ShowUnLinked INT = 0,
,0--	@ShowGroups
,0--	@UseUnit INT
*/

###########################################################
#END