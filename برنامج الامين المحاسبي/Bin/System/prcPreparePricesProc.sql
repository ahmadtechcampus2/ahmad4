#########################################################
##---ãÚÇáÌÉ áÇÕáÇÍíÉ
##--íÌÈ ÅÍÖÇÑ ÌÏæá ÈÑÞã ÇáãÇÏÉ æÇáßãíÉ Ýí ÍÇá ÚÏã ÊÍÏíÏ ÊÝÕíá ÇáãÓÊæÏÚÇÊ
##--ÃãÇ Ýí ÍÇá ÊÍÏíÏ ÊÝÕíá ÇáãÓÊæÏÚÇÊ íÚíÏ ÑÞã ãÇÏÉ æßãíÉ æãÓÊæÏÚ
##--2- Úãá join ãÚ ÌÏæá ÇáÓÚÑ æÌÏæá ÇáßãíÇÊ æÌÏæá ÈÈÞíÉ ÍÞæá ÈØÇÞÉ ÇáãÇÏÉ
CREATE PROCEDURE prcPreparePricesProc
	@StartDate 				[DATETIME],
	@EndDate 				[DATETIME],
	@MatGUID 				[UNIQUEIDENTIFIER], -- 0 All Mat or MatNumber
	@GroupGUID 				[UNIQUEIDENTIFIER],
	@StoreGUID 				[UNIQUEIDENTIFIER], -- 0 all stores so don't check store or list of stores
	@CostGUID 				[UNIQUEIDENTIFIER], -- 0 all costs so don't Check cost or list of costs
	@MatType 				[INT],	     	-- 0 Store or 1 Service or -1 ALL
	@CurrencyGUID 			[UNIQUEIDENTIFIER],
	@CurrencyVal 			[FLOAT],
	@DetailsStores 			[INT], 			-- 1 show details 0 no details
	@ShowEmpty 				[INT], 			--1 Show Empty 0 don't Show Empty
	@SrcTypesguid			[UNIQUEIDENTIFIER],
	@PriceType 				[INT],
	@PricePolicy 			[INT],
	@SortType 				[INT] = 0, 		-- 0 Input Number, 1 matCode, 2MatName, 3Store
	@ShowUnLinked 			[INT] = 0,
	@ShowGroups 			[INT] = 0, 		-- if 1 add 3 new columns for groups
	@UseUnit 				[INT] = 0,
	@ShowMtFldsFlag			[BIGINT] = 0,
	@StLevel				[INT] = 0,
	@DetCostPrice			[INT] = 0,
	@Lang					[INT] = 0
AS
BEGIN
	SET NOCOUNT ON
-- Get Qtys
	DECLARE @c CURSOR
	DECLARE @cnt [INT], @Guid [UNIQUEIDENTIFIER], @stName [NVARCHAR](255)
	CREATE TABLE [#t_Qtys]
	(
		[mtNumber] 	[UNIQUEIDENTIFIER],
		[Qnt] 		[FLOAT],
		[Qnt2] 		[FLOAT],
		[Qnt3] 		[FLOAT],
		[StoreGUID]	[UNIQUEIDENTIFIER]
	)
	CREATE TABLE [#t_QtysWithEmpty]
	(
		[mtNumber] 	[UNIQUEIDENTIFIER],
		[Qnt] 		[FLOAT],
		[Qnt2] 		[FLOAT],
		[Qnt3] 		[FLOAT],
		[StoreGUID]	[UNIQUEIDENTIFIER],
		[StName]	[NVARCHAR](255) COLLATE ARABIC_CI_AI
	)
	
	CREATE TABLE [#R1]
	(
		[StoreGUID]		[UNIQUEIDENTIFIER],
		[mtNumber]		[UNIQUEIDENTIFIER],
		[mtQty]			[FLOAT],
		[Qnt2]			[FLOAT],
		[Qnt3]			[FLOAT],
		--Qnt			FLOAT,
		[mtPrice]		[FLOAT],
		[APrice]		[FLOAT],
		[StName]		[NVARCHAR](255) COLLATE ARABIC_CI_AI
	)
	CREATE TABLE [#t_Prices2]
	(
		[mtNumber] 	[UNIQUEIDENTIFIER],
		[APrice] 	[FLOAT],
		[stNumber]	[UNIQUEIDENTIFIER]
	)
	
	

	

	CREATE TABLE [#t_Prices]
	(
		[mtNumber] 	[UNIQUEIDENTIFIER],
		[APrice] 	[FLOAT]
	)

	CREATE TABLE [#PricesQtys]
	(
		[mtNumber]	[UNIQUEIDENTIFIER],
		[APrice]	[FLOAT],
		[Qnt]		[FLOAT],
		[Qnt2]		[FLOAT],
		[Qnt3]		[FLOAT],
		[StoreGUID]	[UNIQUEIDENTIFIER],
		[StName]	[NVARCHAR](255) COLLATE ARABIC_CI_AI
	)
	EXEC [prcGetQnt] @StartDate, @EndDate, @MatGUID, @GroupGUID, @StoreGUID, @CostGUID, @MatType, @DetailsStores, @SrcTypesguid, @ShowUnLinked, @ShowGroups, @UseUnit

	-- RETURN 8 sec
	IF @ShowEmpty = 0
		INSERT INTO [#t_QtysWithEmpty]
			SELECT
				[q].[mtNumber],
				ISNULL([q].[Qnt], 0),
				ISNULL([q].[Qnt2],0),
				ISNULL([q].[Qnt3],0),
				[q].[StoreGUID],
				ISNULL( CASE @Lang WHEN 0 THEN [st].[StName] ELSE CASE [st].[StLatinName] WHEN '' THEN [st].[StName] ELSE [st].[StLatinName] END END , '')
			FROM
				[#t_Qtys] AS [q] LEFT JOIN [vwSt] AS [st] ON  [q].[StoreGUID] = [st].[stGuid]
	ELSE
		INSERT INTO [#t_QtysWithEmpty]
			SELECT
				[mt].[mtGUID],
				ISNULL([q].[Qnt], 0),
				ISNULL([q].[Qnt2],0),
				ISNULL([q].[Qnt3],0),
				[q].[StoreGUID],
				ISNULL([StName],'')
			FROM
				[vwmt] AS [mt] INNER JOIN [#MatTbl] AS [mtTbl] ON [mt].[mtGUID] = [mtTbl].[MatGUID]
				LEFT JOIN (SELECT [Qnt] ,[Qnt2],[Qnt3],[StoreGUID],[mtNumber],ISNULL( CASE @Lang WHEN 0 THEN [st].[StName] ELSE CASE [st].[StLatinName] WHEN '' THEN [st].[StName] ELSE [st].[StLatinName] END END , '') AS [StName] FROM [#t_Qtys] AS [q1] 
				LEFT JOIN [vwSt] AS [st] ON  [q1].[StoreGUID] = [st].[stGuid]
				) AS [q] ON [mt].[mtGUID] = [q].[mtNumber]
			--WHERE
			--	( (@MatType = -1) 						OR (mtType = @MatType))
				--AND( (@IsAllMats = 1) OR (mt.mtNumber IN( SELECT MatGUID FROM #MatTbl)))

	-- RETURN 9 -10 sec
-- Get last Prices

	IF @PriceType = 2 AND @PricePolicy = 122 -- LastPrice
	BEGIN
		EXEC [prcGetLastPrice] @StartDate , @EndDate , @MatGUID, @GroupGUID, @StoreGUID, @CostGUID, @MatType,	@CurrencyGUID, @SrcTypesguid, @ShowUnLinked, 0
	END
	ELSE IF @PriceType = 2 AND @PricePolicy = 120 -- MaxPrice
	BEGIN
		EXEC [prcGetMaxPrice] @StartDate , @EndDate , @MatGUID, @GroupGUID, @StoreGUID, @CostGUID, @MatType,	@CurrencyGUID, @CurrencyVal, @SrcTypesguid, @ShowUnLinked, 0
	END
	ELSE IF @PriceType = 2 AND @PricePolicy = 121 AND @DetCostPrice = 0 -- COST And AvgPrice NO STORE DETAILS
	BEGIN
		EXEC [prcGetAvgPrice]	@StartDate,	@EndDate, @MatGUID, @GroupGUID, @StoreGUID, @CostGUID, @MatType, @CurrencyGUID, @CurrencyVal, @SrcTypesguid,	@ShowUnLinked, 0
	END
	ELSE IF @PriceType = 2 AND @PricePolicy = 121 AND @DetCostPrice = 1 -- COST And AvgPrice  STORE DETAILS
	BEGIN
		EXEC [prcGetAvgPrice_WithDetailStore]	@StartDate,	@EndDate, @MatGUID, @GroupGUID, @StoreGUID, @CostGUID, @MatType, @CurrencyGUID, @CurrencyVal, @SrcTypesguid,	@ShowUnLinked, 0
	END
	ELSE IF @PriceType = -1
		INSERT INTO [#t_Prices] SELECT [MatGUID], 0 FROM [#MatTbl]
	
	ELSE IF @PriceType = 2 AND @PricePolicy = 124 -- LastPrice with extra and discount
	BEGIN
		EXEC [prcGetLastPrice] @StartDate , @EndDate , @MatGUID, @GroupGUID, @StoreGUID, @CostGUID, @MatType,	@CurrencyGUID, @SrcTypesguid, @ShowUnLinked, 0, 0 /*@CalcLastCost*/,	1 /*@ProcessExtra*/
	END
	ELSE
	BEGIN
		print 'ex4'
		EXEC [prcGetMtPrice] @MatGUID,	@GroupGUID, @MatType, @CurrencyGUID, @CurrencyVal, @SrcTypesguid, @PriceType, @PricePolicy, @ShowUnLinked, @UseUnit,@EndDate
	END

---- Get Qtys And Prices
---- you must use left join cause if details stores you have more than one record for each mat
	IF @DetCostPrice = 0
	BEGIN
		INSERT INTO [#PricesQtys]
		SELECT
			[q].[mtNumber],
			ISNULL([p].[APrice], 0) AS [APrice],
			[q].[Qnt],
			[q].[Qnt2],
			[q].[Qnt3],
			[q].[StoreGUID],
			[q].[StName]
		FROM
			[#t_QtysWithEmpty] AS [q] LEFT JOIN [#t_Prices] AS [p] ON [q].[mtNumber] = [p].[mtNumber]
	END
	ELSE
	BEGIN
		INSERT INTO [#PricesQtys]
			SELECT
				[q].[mtNumber],
				ISNULL([p].[APrice], 0) AS [APrice],
				[q].[Qnt],
				[q].[Qnt2],
				[q].[Qnt3],
				[q].[StoreGUID],
				[q].[StName]
			FROM
				[#t_QtysWithEmpty] AS [q] LEFT JOIN [#t_Prices2] AS [p] ON [q].[mtNumber] = [p].[mtNumber] AND q.[StoreGUID] = p.[StNumber]
	END
	-- RETURN 13 sec
	INSERT INTO [#R]
		SELECT
			[pr].[StoreGUID],
			[mtTbl].[MatGUID],
			--v_mt.mtQty,
			[pr].[Qnt],
			[pr].[Qnt2],
			[pr].[Qnt3],
			0 AS [mtPrice],
			ISNULL([Pr].[APrice], 0),
			[Pr].[StName]
		FROM
			[#PricesQtys] AS [Pr] --ON v_mt.mtNumber = Pr.mtNumber
			LEFT JOIN [#MatTbl] AS [mtTbl] ON [Pr].[mtNumber] = [mtTbl].[MatGUID]

	IF (@StLevel > 0)
	BEGIN
		SET @Cnt = (SELECT MAX([LEVEL]) FROM [fnGetStoresListByLevel](@StoreGUID,0 )) 
		
		SELECT [f].[Guid], [Level], [Name] INTO [#TStore] FROM [fnGetStoresListByLevel](@StoreGUID, @stLevel) AS [f] INNER JOIN [st000] AS [st] ON [st].[GUID] = [f].[Guid]
		
		WHILE @Cnt != 0
		BEGIN
			UPDATE [#R]	SET [StoreGUID] = [st].[ParentGuid], [StName] = ''
			FROM [#R] AS [T] INNER JOIN [st000] AS [st] ON [st].[Guid] = [T].[StoreGuid]
			
			WHERE [StoreGUID] NOT IN (SELECT [GUID] FROM [#TStore])
			SET @Cnt = @Cnt -1 
		END
		UPDATE [#R]	SET [StName] = [st].[Name]
		FROM [#R] AS [T] INNER JOIN [st000] AS [st] ON [st].[Guid] = [T].[StoreGuid]
		WHERE [T].[StName] = ''
		
		SET @c=CURSOR FAST_FORWARD FOR  SELECT [GUID], [Name] FROM [#TStore] WHERE [LEVEL] < @stLevel ORDER BY [LEVEL] DESC
		OPEN @c
		FETCH @c INTO @Guid,@stName
		WHILE @@FETCH_STATUS = 0  
		BEGIN
			INSERT INTO [#R] 
				SELECT
					@Guid,
					[mtNumber],
					SUM([mtQty]),
					SUM([Qnt2]),
					SUM([Qnt3]),
					[mtPrice],
					[APrice],
					@stName
				FROM [#R] JOIN [vwSt] [st] ON [st].[stGuid] = [StoreGUID]
				WHERE [st].[stParent] = @Guid
				GROUP BY 
					[mtNumber],
					[mtPrice],
					[APrice]  
			FETCH @c INTO @Guid,@stName
		END
		CLOSE @c
		DEALLOCATE @c
		
		INSERT INTO [#R1]
		SELECT 
	 		[StoreGUID],
			[mtNumber],
			SUM([mtQty]) ,
			SUM([Qnt2]) ,
			SUM([Qnt3]) ,
			[mtPrice],
			[APrice],
			[StName]
		FROM [#R]
		GROUP BY
			[StoreGUID],
			[mtNumber],
			[mtPrice],
			[APrice],
			[StName]
			
		DELETE [#R]
		INSERT INTO [#R] SELECT * FROM [#R1]
		
	END
---- delete empty mats
	IF @ShowEmpty = 0 AND @StLevel >=0 AND @DetailsStores = 0
		DELETE FROM [#R] WHERE ABS( [mtQty]) < [dbo].[fnGetZeroValueQTY]()
							
	CREATE INDEX [R_mt_Number] ON [#R] ([mtNumber])
	---return result set
		DECLARE @strg [NVARCHAR](3000) 
		SET @strg = '
		SELECT 
	 		[r].[StoreGUID],
			[r].[mtNumber],
			[r].[mtQty],
			[r].[Qnt2],
			[r].[Qnt3],
			[r].[mtPrice],
			[r].[APrice],
			[r].[StName]
		FROM [#R] AS [r] INNER JOIN [vwmtgr] AS [v_mt] ON [r].[mtNumber] = [v_mt].[mtGUID] '
		
		
		SET @strg = @strg + ' ORDER BY '
		IF @SortType = 3 AND @DetailsStores = 1 
			SET @strg = @strg + ' [StName]' 
		ELSE IF @SortType = 2 
			SET @strg = @strg + ' [mtName]' 
		ELSE IF @SortType = 1 
			SET @strg = @strg + ' [mtCode]' 
		ELSE IF  @SortType = 0 -- By Mat Input 
			SET @strg = @strg + ' [v_mt].[mtNumber]' 
		ELSE IF  @SortType = 4 -- By Mat Latin Name 
			SET @strg = @strg + ' [v_mt].[mtLatinName]' 
		ELSE IF  @SortType = 5 -- By Mat Type 
			SET @strg = @strg + ' [v_mt].[mtType]'
		ELSE IF  @SortType = 6 -- By Mat Specification  
			SET @strg = @strg + ' [v_mt].[mtSpec]'
		ELSE IF  @SortType = 7 -- By Mat Color 
			SET @strg = @strg + ' [v_mt].[mtColor]'
		ELSE IF  @SortType = 8 -- By Mat Orign
			SET @strg = @strg + ' [v_mt].[mtOrigin]'
		ELSE IF  @SortType = 9 -- By Mat Magerment
			SET @strg = @strg + ' [v_mt].[mtDim]'
		ELSE IF @SortType = 10-- By Mat COMPANY
			SET @strg = @strg + ' [v_mt].[mtCompany]'
		ELSE  -- By Mat BARCOD
			SET @strg = @strg + ' [v_mt].[mtBarCode]'
END



-- To be moved to main proc prcCalPricesProc
-- SELECT * FROM #SecViol
/*
prcConnectioins_add2  'ãÏíÑ'

EXEC prcPreparePricesProc
'1/1/2002'	--	@StartDate DATETIME,
,'7/31/2005'--	@EndDate DATETIME,
,0x0		--	@MatGUID UNIQUEIDENTIFIER, -- 0 All Mat or MatNumber
,0x0		--	@GroupGUID UNIQUEIDENTIFIER,
,0x0		--	@StoreGUID UNIQUEIDENTIFIER, -- 0 all stores so don't check store or list of stores
,0x0		--	@CostGUID UNIQUEIDENTIFIER, -- 0 all costs so don't Check cost or list of costs
,0			--	@MatType UNIQUEIDENTIFIER, -- 0 Store or 1 Service or -1 ALL
,0x0		--	@CurrencyGUID UNIQUEIDENTIFIER,
,1			--	@CurrencyVal FLOAT,
,0			--	@DetailsStores INT, -- 1 show details 0 no details
,0			--	@ShowEmpty INT, --1 Show Empty 0 don't Show Empty
,0x0		--	@SrcTypesGUID UNIQUEIDENTIFIER,-- bill types
,2			--  @PriceType INT,
,121		--  @PricePolicy INT,
,1			--	@SortType INT = 0, -- 0 NONE, 1 matCode, 2MatName, 3Store
,0			--	@ShowUnLinked INT = 0,
,1			--	@ShowGroups
,3			--	@UseUnit INT


*/

#########################################################
#END