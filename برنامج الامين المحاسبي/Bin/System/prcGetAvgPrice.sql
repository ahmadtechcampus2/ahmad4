###########################################################################
CREATE PROCEDURE prcGetAvgPrice
	@StartDate [DATETIME],
	@EndDate [DATETIME],
	@MatGUID [UNIQUEIDENTIFIER] = NULL,
	@GroupGUID [UNIQUEIDENTIFIER] = NULL,
	@StoreGUID [UNIQUEIDENTIFIER] = NULL,
	@CostGUID [UNIQUEIDENTIFIER] = NULL,
	@MatType [INT] = -1, -- 0 Store or 1 Service or -1 ALL
	@CurrencyGUID [UNIQUEIDENTIFIER] = NULL,
	@CurrencyVal [FLOAT] = 1,
	@SrcTypes [UNIQUEIDENTIFIER] = 0X00,
	@ShowUnLinked [INT] = 0, 
	@UseUnit [INT] = 0,
	@IsIncludeOpenedLC [BIT] = 0,
	@CalcTotalPrice [BIT] = 0
AS  
	SET NOCOUNT ON

	DECLARE @bNeg BIT
	
	DECLARE @AvgPriceReadPricePerm INT
	SET @AvgPriceReadPricePerm = [dbo].[fnGetUserSec]([dbo].fnGetCurrentUserGuid(),28,0x00,1,0)
	
	CREATE TABLE [#BillsTypesTbl_AVG]( [TypeGuid] [UNIQUEIDENTIFIER], [UserSecurity] [INTEGER], [UserReadPriceSecurity] [INTEGER], 
		[UnPostedSecurity] [INTEGER], [PriorityNum] [INTEGER], [SamePriorityOrder] INT, [SortNumber] INT) 
	INSERT INTO [#BillsTypesTbl_AVG] EXEC [prcGetBillsTypesList3] @SrcTypes, NULL, 1 /*@SortAffectCostType*/

	DECLARE @t_Result TABLE( 
		[GUID] [UNIQUEIDENTIFIER], 
		[Qnt] [FLOAT], 
		[AvgPrice] [FLOAT]) 
	---------------------------------------------------------------------- 
	DECLARE
		-- mt table variables declarations:
		@mtGUID [UNIQUEIDENTIFIER],
		@mtQnt [FLOAT], 
		@mtAvgPrice [FLOAT], 
		@mtValue [FLOAT], 
		-- bi cursor input variables declarations: 
		@buGUID				[UNIQUEIDENTIFIER],
		@buDate 			[DATETIME], 
		@buDirection 		[INT], 
		@biNumber 			[INT], 
		@biMatPtr 			[UNIQUEIDENTIFIER],
		@biQnt 				[FLOAT], 
		@biBonusQnt 		[FLOAT], 
		@biUnitPrice 		[FLOAT], 
		@biUnitDiscount 	[FLOAT], 
		@biDiscExtra		[FLOAT], 
		@biUnitExtra 		[FLOAT], 
		@biAffectsCostPrice [BIT], 
		@biDiscountAffectsCostPrice [BIT], 
		@biExtraAffectsCostPrice 	[BIT], 
		@biBaseBillType				[INT],
		@biLCDisc 					[FLOAT], 
		@biLCExtra					[FLOAT]
			 
	---------------------------------------------------------------------- 
	CREATE TABLE [#Result](
			[buGUID]					[UNIQUEIDENTIFIER],
			[buNumber]					[INT],
			[buDate] 					[DATETIME],
			[buDirection] 				[INT],
			[biNumber] 					[INT],
			[biMatPtr]					[UNIQUEIDENTIFIER],
			[biQnt]						[FLOAT],
			[biBonusQnt] 				[FLOAT],
			[biUnitPrice] 				[FLOAT],
			[biUnitDiscount] 			[FLOAT],
			[biUnitExtra] 				[FLOAT],
			[biDiscExtra] 				[FLOAT],
			[biAffectsCostPrice] 		[BIT],
			[biDiscountAffectsCostPrice][BIT],
			[biExtraAffectsCostPrice] 	[BIT],
			[biBaseBillType]			[INT],
			[Security]					[INT],
			[UserReadPriceSecurity]		[INT],
			[UserSecurity] 				[INT],
			[buSortFlag] 				[INT],
			[buSortFlag2]				[INT], --Used to reorder 'cost cards' first (cost card added in same bill date)
			[LCDisc]					[FLOAT],
			[LCExtra]					[FLOAT],
			[buLCGUID]					[UNIQUEIDENTIFIER],
			[biGUID]					[UNIQUEIDENTIFIER],
			[btGUID]					[UNIQUEIDENTIFIER]
		)
	---------------------------------------------------------------------- 
		
	INSERT INTO [#Result]
		SELECT
			[buGUID],
			[buNumber],
			[buDate],
			[buDirection],
			[biNumber],
			[biMatPtr],
			[biQty],
			[biBonusQnt],
			CASE WHEN [UserReadPriceSecurity] >= [BuSecurity] THEN [FixedbiUnitPrice] ELSE 0 END, -- CASE WHEN UserReadPriceSecurity >= BuSecurity THEN FixedBiPrice / (CASE mtUnitFact WHEN 0 THEN 1 ELSE mtUnitFact END) ELSE 0 END,
			CASE WHEN [UserReadPriceSecurity] >= [BuSecurity] THEN [FixedbiUnitDiscount] ELSE 0 END, -- CASE WHEN UserReadPriceSecurity >= BuSecurity THEN  ((CASE (buTotal * biQty) WHEN 0 THEN ((FixedbiDiscount / biQty) + biBonusDisc) ELSE ((CASE biQty WHEN 0 THEN 0 ELSE (FixedbiDiscount / biQty) END) + (ISNULL((SELECT SUM(diDiscount) FROM vwDi WHERE vwDi.diType = buType AND vwDi.diParent = buNumber),0) * FixedBiPrice / mtUnitFact) / buTotal) END) + biBonusDisc) * mcDiscountAffectsCostPrice ELSE 0 END,
			CASE WHEN [UserReadPriceSecurity] >= [BuSecurity] THEN [FixedbiUnitExtra] ELSE 0 END, -- CASE WHEN UserReadPriceSecurity >= BuSecurity THEN (CASE buTotal WHEN 0 THEN biExtra ELSE biExtra + buTotalExtra * FixedBiPrice / mtUnitFact / buTotal END) * mcExtraAffectsCostPrice ELSE 0 END,
			CASE WHEN [UserReadPriceSecurity] >= [BuSecurity] THEN ([FixedBiExtra] * [btExtraAffectCost]) - ([btDiscAffectCost] * [FixedBiDiscount]) ELSE 0 END,
			-----------------
			[btAffectCostPrice],
			[btDiscAffectCost],
			[btExtraAffectCost],
			[btBillType],
			[r].[buSecurity],
			[bt].[UserReadPriceSecurity],
			[bt].[UserSecurity],
			[buSortFlag],
			CASE [btBillType] WHEN 5 THEN -1 WHEN 4 THEN -1 ELSE 1 END,
			[r].biLCDisc,
			[r].biLCExtra,
			[r].buLCGUID,
			[r].biGUID,
			[bt].[TypeGUID]
		FROM
			[dbo].[fnExtended_Bi_Fixed](@CurrencyGUID) AS [r]
			INNER JOIN [#BillsTypesTbl_AVG] AS [bt] ON [r].[BuType] = [bt].[TypeGUID]
			INNER JOIN [#MatTbl] AS [mtTbl] ON [r].[biMatPtr] = [mtTbl].[MatGuid]
		WHERE
			[buIsPosted] > 0 AND [buDate] BETWEEN @StartDate AND @EndDate 
		AND [mtTbl].[mtSecurity] <= @AvgPriceReadPricePerm

	----------------------------------------------------------------------
	--Calc LC Extra And Disc If LC Is Open
	IF @IsIncludeOpenedLC = 1
	BEGIN
		UPDATE R
			SET 
				R.LCDisc = F.LCDisc,
				R.LCExtra = F.LCExtra
		FROM #Result AS R
			CROSS APPLY dbo.fnLCGetBillItemsDiscExtra(R.buLCGUID) AS F
				WHERE R.biGUID = F.biGUID
	END
	--CREATE CLUSTERED INDEX [ind] ON [#Result]([buNumber],[buDate],[buDirection],[biNumber],[biMatPtr])		 
	---------------------------------------------------------------------- 
	-- EXEC prcCheckSec2 1, 1, 0 
	---------------------------------------------------------------------- 
	-- declare cursors: 
	DECLARE @c_bi CURSOR 

	-- helpfull vars: 
	DECLARE @Tmp [FLOAT] 

	-- setup bi cursor: 
	SET @c_bi = CURSOR FAST_FORWARD FOR 
			SELECT  
				r.[buGUID],  
				r.[buDate],  
				r.[buDirection],
				r.[biNumber],  
				r.[biMatPtr],  
				r.[biQnt],  
				r.[biBonusQnt],  
				r.[biUnitPrice],  
				r.[biUnitDiscount],  
				r.[biUnitExtra], 
				r.[biDiscExtra],
				r.[biAffectsCostPrice], 
				r.[biDiscountAffectsCostPrice],  
				r.[biExtraAffectsCostPrice], 
				r.[biBaseBillType],
				r.[LCDisc],
				r.[LCExtra] 
			FROM 
				[#Result] r
				INNER JOIN [#BillsTypesTbl_AVG] bt ON [bt].[TypeGUID] = r.[btGUID]
			WHERE 
				r.[UserSecurity] >= r.[Security]
			ORDER BY 
				[biMatPtr],  
				[buDate],  
				[bt].[PriorityNum], [bt].[SortNumber], [r].[buNumber], [bt].[SamePriorityOrder], [biNumber]

	--------------------------------------------------------------------------------------- 
	OPEN @c_bi FETCH NEXT FROM @c_bi INTO
			@buGUID,
			@buDate,  
			@buDirection,
			@biNumber,  
			@biMatPtr,  
			@biQnt,  
			@biBonusQnt,  
			@biUnitPrice,  
			@biUnitDiscount,  
			@biUnitExtra,
			@biDiscExtra, 
			@biAffectsCostPrice, 
			@biDiscountAffectsCostPrice,  
			@biExtraAffectsCostPrice, 
			@biBaseBillType,
			@biLCDisc,
			@biLCExtra 

	-- get the first material 
	SET @mtGUID = @biMatPtr 
	-- reset variables: 
	SET @mtQnt = 0 
		
	SET @mtAvgPrice = 0 
	-- start @c_bi loop 
		
	WHILE @@FETCH_STATUS = 0 
	BEGIN 
		-- is this a new material ? 
		IF @mtGUID <> @biMatPtr
		BEGIN 
			-- insert the material record: 
			INSERT INTO @t_Result VALUES( 
				@mtGUID, 
				@mtQnt,   
				@mtAvgPrice) 
			-- reset mt variables: 
			SET @mtGUID = @biMatPtr 
			SET @mtQnt = 0 
			SET @bNeg = 0
			
			SET @mtAvgPrice = 0 
		END 
		-------------------------- 
		IF @biAffectsCostPrice = 0 
		BEGIN 
			SET @mtQnt = @mtQnt + @buDirection * (@biQnt + @biBonusQnt)  
		END
		ELSE 
		BEGIN
			IF @mtQnt >= 0
			BEGIN
				IF @biQnt > 0
					SET @mtValue = (@mtAvgPrice * @mtQnt) + (@buDirection * @biQnt * (@biUnitPrice + @biUnitExtra * @biExtraAffectsCostPrice - @biUnitDiscount * @biDiscountAffectsCostPrice))
				ELSE IF @biQnt = 0
					SET @mtValue = (@mtAvgPrice * @mtQnt) + (@buDirection * @biDiscExtra)
			END
			ELSE
				IF @buDirection = 1 
				BEGIN
					IF @biQnt > 0	
						SET @mtValue = @biQnt * (@biUnitPrice + @biUnitExtra * @biExtraAffectsCostPrice - @biUnitDiscount * @biDiscountAffectsCostPrice)
					ELSE IF @biQnt = 0
						SET @mtValue =  (@buDirection * @biDiscExtra)	
				END
			IF @mtQnt < 0
					set @bNeg = 1
			ELSE
				set @bNeg = 0
			SET @mtQnt = @mtQnt + @buDirection * (@biQnt + @biBonusQnt)
			SET @mtValue = @mtValue - @biLCDisc + @biLCExtra
			IF @mtValue > 0 
			BEGIN
				IF ( @mtQnt > 0) AND @bNeg = 0
					SET @mtAvgPrice = @mtValue / @mtQnt
				ELSE IF (@biQnt > 0) AND (@buDirection = 1) 
				BEGIN
				IF (@biQnt + @biBonusQnt) > 0
					SET @mtAvgPrice = @biQnt * (@biUnitPrice + @biUnitExtra * @biExtraAffectsCostPrice - @biUnitDiscount * @biDiscountAffectsCostPrice)/(@biQnt + @biBonusQnt)
				END
			END
			ELSE
			BEGIN
				IF (@biQnt + @biBonusQnt) > 0
					SET @mtAvgPrice = @biQnt * (@biUnitPrice + @biUnitExtra * @biExtraAffectsCostPrice - @biUnitDiscount * @biDiscountAffectsCostPrice)/(@biQnt + @biBonusQnt)
				
			END
			SET @mtValue = 0
		END 
		----------------------------------- 

		FETCH FROM @c_bi INTO 
			@buGUID,
			@buDate,  
			@buDirection, 
			@biNumber,  
			@biMatPtr,  
			@biQnt,  
			@biBonusQnt,  
			@biUnitPrice,  
			@biUnitDiscount,  
			@biUnitExtra,
			@biDiscExtra, 
			@biAffectsCostPrice, 
			@biDiscountAffectsCostPrice,  
			@biExtraAffectsCostPrice, 
			@biBaseBillType,
			@biLCDisc,
			@biLCExtra 
		 
	END -- @c_bi loop 		-- insert the last mt statistics:
	INSERT INTO @t_Result SELECT @mtGUID, @mtQnt, @mtAvgPrice

	CLOSE @c_bi DEALLOCATE @c_bi
	--return result Set
	INSERT INTO [#t_Prices]
	 	SELECT
			ISNULL( [r].[GUID],  [m].[mtGUID]), 
			ISNULL( [r].[AvgPrice], 0) * IIF(@CalcTotalPrice = 0 , 1 , ISNULL( [r].[Qnt], 0))
		FROM 
			@t_Result AS [r] INNER JOIN [vwMtGr] AS [m] ON [r].[GUID] = [m].[mtGUID]
		WHERE 
				((@MatType = -1) OR ([m].[mtType] = @MatType))
	RETURN @@ROWCOUNT 
	
/*
EXEC prcCallPricesProcs2 '4/1/2003', '4/10/2003', 0x0, 0x0, 0x0, 0x0, 0, '64aacb0d-530f-4c02-8cb7-4a2c33b468f9', 1.000000, 1, 0, 0x0, 2, 121, 0, 0, 0x0, 0x0, 0, 1, 3
*/
###########################################################################

#END