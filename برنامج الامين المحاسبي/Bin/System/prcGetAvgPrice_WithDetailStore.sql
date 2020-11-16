CREATE PROCEDURE prcGetAvgPrice_WithDetailStore
	@StartDate [DATETIME],
	@EndDate [DATETIME],
	@MatGUID [UNIQUEIDENTIFIER] = NULL,
	@GroupGUID [UNIQUEIDENTIFIER] = NULL,
	@StoreGUID [UNIQUEIDENTIFIER] = NULL,
	@CostGUID [UNIQUEIDENTIFIER] = NULL,
	@MatType [INT] = -1, -- 0 Store or 1 Service or -1 ALL
	@CurrencyGUID [UNIQUEIDENTIFIER] = NULL,
	@CurrencyVal [FLOAT] = 1,
	@SrcTypes [NVARCHAR](2000) = '',
	@ShowUnLinked [INT] = 0, 
	@UseUnit [INT] = 0
AS  
	SET NOCOUNT ON

	DECLARE @CondStr [NVARCHAR](max)  
	DECLARE @Level [INT]
	
	DECLARE @t_Result TABLE( 
		[GUID] [UNIQUEIDENTIFIER], 
		[STGUID] [UNIQUEIDENTIFIER], 
		[Qnt] [FLOAT], 
		[Qnt2] [FLOAT], 
		[Qnt3] [FLOAT], 
		[AvgPrice] [FLOAT]) 
		---------------------------------------------------------------------- 
	DECLARE
		-- mt table variables declarations:
		@mtGUID						[UNIQUEIDENTIFIER],
		@stGUID						[UNIQUEIDENTIFIER],
		@mtQnt						[FLOAT], 
		@mtQnt2						[FLOAT], 
		@mtQnt3						[FLOAT], 
		@mtAvgPrice					[FLOAT], 
		@mtValue					[FLOAT], 
			-- bi cursor input variables declarations: 
		@buGUID						[UNIQUEIDENTIFIER],
		@buDate 					[DATETIME], 
		@buDirection 				[INT], 
		@biNumber 					[INT], 
		@biMatPtr 					[UNIQUEIDENTIFIER],
		@biStorePtr					[UNIQUEIDENTIFIER],
		@biQnt 						[FLOAT], 
		@biQnt2 					[FLOAT], 
		@biQnt3 					[FLOAT], 
		@biBonusQnt 				[FLOAT], 
		@biUnitPrice 				[FLOAT], 
		@biUnitDiscount 			[FLOAT], 
		@biUnitExtra 				[FLOAT], 
		@biAffectsCostPrice			[BIT], 
		@biDiscountAffectsCostPrice [BIT], 
		@biExtraAffectsCostPrice 	[BIT], 
		@biBaseBillType				[INT] 
			 
		---------------------------------------------------------------------- 
		CREATE TABLE [#Result](
			[buGUID]						[UNIQUEIDENTIFIER],
			[buNumber]						[INT],
			[buDate] 						[DATETIME],
			[buDirection] 					[INT],
			[biNumber] 						[INT],
			[biMatPtr] 						[UNIQUEIDENTIFIER],
			[biStorePtr] 					[UNIQUEIDENTIFIER],
			[biQnt] 						[FLOAT],
			[biQnt2] 						[FLOAT],
			[biQnt3]						[FLOAT],
			[biBonusQnt] 					[FLOAT],
			[biUnitPrice] 					[FLOAT],
			[biUnitDiscount] 				[FLOAT],
			[biUnitExtra] 					[FLOAT],
			[biAffectsCostPrice] 			[BIT],
			[biDiscountAffectsCostPrice]	[BIT],
			[biExtraAffectsCostPrice] 		[BIT],
			[biBaseBillType]				[INT],
			[Security]						[INT],
			[UserReadPriceSecurity]			[INT],
			[UserSecurity] 					[INT],
			[buSortFlag] 					[INT]
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
			[biStorePtr],
			[biQty],
			[biQty2],
			[biQty3],
			[biBonusQnt],
			CASE WHEN [UserReadPriceSecurity] >= [BuSecurity] THEN [FixedbiUnitPrice] ELSE 0 END, -- CASE WHEN UserReadPriceSecurity >= BuSecurity THEN FixedBiPrice / (CASE mtUnitFact WHEN 0 THEN 1 ELSE mtUnitFact END) ELSE 0 END,
			CASE WHEN [UserReadPriceSecurity] >= [BuSecurity] THEN [FixedbiUnitDiscount] ELSE 0 END, -- CASE WHEN UserReadPriceSecurity >= BuSecurity THEN  ((CASE (buTotal * biQty) WHEN 0 THEN ((FixedbiDiscount / biQty) + biBonusDisc) ELSE ((CASE biQty WHEN 0 THEN 0 ELSE (FixedbiDiscount / biQty) END) + (ISNULL((SELECT SUM(diDiscount) FROM vwDi WHERE vwDi.diType = buType AND vwDi.diParent = buNumber),0) * FixedBiPrice / mtUnitFact) / buTotal) END) + biBonusDisc) * mcDiscountAffectsCostPrice ELSE 0 END,
			CASE WHEN [UserReadPriceSecurity] >= [BuSecurity] THEN [FixedbiUnitExtra] ELSE 0 END, -- CASE WHEN UserReadPriceSecurity >= BuSecurity THEN (CASE buTotal WHEN 0 THEN biExtra ELSE biExtra + buTotalExtra * FixedBiPrice / mtUnitFact / buTotal END) * mcExtraAffectsCostPrice ELSE 0 END,
				-----------------
			[btAffectCostPrice],
			[btDiscAffectCost],
			[btExtraAffectCost],
			[btBillType],
			[r].[buSecurity],
			[bt].[UserReadPriceSecurity],
			[bt].[UserSecurity],

			[buSortFlag]
			FROM
			[dbo].[fnExtended_BiGr_Fixed](@CurrencyGUID) AS [r]
			INNER JOIN [#BillsTypesTbl] AS [bt] ON [r].[BuType] = [bt].[TypeGUID]
			INNER JOIN [#MatTbl] AS [mtTbl] ON [r].[biMatPtr] = [mtTbl].[MatGuid]
		WHERE
			[buIsPosted] > 0 AND [buDate] BETWEEN @StartDate AND @EndDate 

		---------------------------------------------------------------------- 
		-- EXEC prcCheckSec2 1, 1, 0 
		---------------------------------------------------------------------- 
		-- declare cursors: 
	-------------------------------------
	--Process Main Store
	SET @Level = (SELECT MAX([LEVEL]) FROM [fnGetStoresListByLevel](@StoreGUID,0 ) AS [f] INNER JOIN [#StoreTbl] ON [f].[Guid] = [StoreGuid] INNER JOIN [st000] AS [st] ON [st].[Guid] = [f].[Guid] )
	SELECT [f].[Guid] AS [stPtr],[ParentGuid], [LEVEL] INTO [#STL] FROM [fnGetStoresListByLevel](@StoreGUID,0 ) AS [f] INNER JOIN [#StoreTbl] ON [f].[Guid] = [StoreGuid] INNER JOIN [st000] AS [st] ON [st].[Guid] = [f].[Guid]
	WHILE @Level <> 1
	BEGIN
		INSERT INTO [#Result]
			SELECT 
				0X00,0,[buDate],[buDirection],[biNumber],	[biMatPtr],
				[ParentGuid],
				[biQnt], [biQnt2], [biQnt3], [biBonusQnt],
				[biUnitPrice], [biUnitDiscount], [biUnitExtra],
				[biAffectsCostPrice], [biDiscountAffectsCostPrice], [biExtraAffectsCostPrice],
				[biBaseBillType],	[Security],
				[UserReadPriceSecurity],
				[UserSecurity],
				[buSortFlag]
			FROM [#Result] INNER JOIN [#STL] ON [biStorePtr] = [stPtr] WHERE [ParentGuid] IS NOT NULL AND [LEVEL]= @Level
			SET @Level = @Level - 1
	END
	DECLARE @c_bi CURSOR 

	-- helpfull vars: 
	DECLARE @Tmp FLOAT 

	-- setup bi cursor: 
	SET @c_bi = CURSOR FAST_FORWARD FOR 
			SELECT  
				[buGUID],  
				[buDate],  
				[buDirection],
				[biNumber],  
				[biMatPtr],
				[biStorePtr],  
				[biQnt],  
				[biQnt2],  
				[biQnt3], 
				[biBonusQnt],  
				[biUnitPrice],  
				[biUnitDiscount],  
				[biUnitExtra], 
				[biAffectsCostPrice], 
				[biDiscountAffectsCostPrice],  
				[biExtraAffectsCostPrice], 
				[biBaseBillType] 
			FROM 
				[#Result] 
			WHERE 
				[UserSecurity] >= [Security]
			ORDER BY 
				[biMatPtr],
				[biStorePtr],  
				[buDate],  
				[buSortFlag],  
				[buNumber],
				[biNumber]

	--------------------------------------------------------------------------------------- 
	OPEN @c_bi FETCH NEXT FROM @c_bi INTO
			@buGUID,
			@buDate,  
			@buDirection,
			@biNumber,  
			@biMatPtr,
			@biStorePtr,   
			@biQnt,  
			@biQnt2,  
			@biQnt3, 
			@biBonusQnt,  
			@biUnitPrice,  
			@biUnitDiscount,  
			@biUnitExtra, 
			@biAffectsCostPrice, 
			@biDiscountAffectsCostPrice,  
			@biExtraAffectsCostPrice, 
			@biBaseBillType 

	-- get the first material 
	SET @mtGUID = @biMatPtr 
	SET @stGUID = @biStorePtr 
	-- reset variables: 
	SET @mtQnt = 0 
	SET @mtQnt2 = 0 
	SET @mtQnt3 = 0  
	SET @mtAvgPrice = 0 
	-- start @c_bi loop 
	 
	WHILE @@FETCH_STATUS = 0 
	BEGIN 
		-- is this a new material ? 
		IF @mtGUID <> @biMatPtr OR @stGUID <> @biStorePtr
		BEGIN 
			-- insert the material record: 
			INSERT INTO @t_Result VALUES( 
				@mtGUID, 
				@stGUID, 
				@mtQnt,   
				@mtQnt2, 
				@mtQnt3, 
				@mtAvgPrice) 
			-- reset mt variables: 
			SET @mtGUID = @biMatPtr 
			SET @stGUID = @biStorePtr 
			SET @mtQnt = 0 
			SET @mtQnt2 = 0  
			SET @mtQnt3 = 0 
			SET @mtAvgPrice = 0 
		END 

		-------------------------- 
		IF @biAffectsCostPrice = 0 
		BEGIN 
			SET @mtQnt = @mtQnt + @buDirection * (@biQnt + @biBonusQnt)  
			SET @mtQnt2 = @mtQnt2 + @buDirection * @biQnt2  
			SET @mtQnt3 = @mtQnt3 + @buDirection * @biQnt3 
		END
		ELSE 
		BEGIN
			IF @mtQnt > 0
			BEGIN
				IF @biBaseBillType <> 2 	-- ?CE??E ??E?? ?OE??CE 
					SET @mtValue = @mtAvgPrice * @mtQnt + @biQnt * (@biUnitPrice + @biUnitExtra * @biExtraAffectsCostPrice - @biUnitDiscount * @biDiscountAffectsCostPrice)
				SET @mtQnt = @mtQnt + @buDirection * (@biQnt + @biBonusQnt)
				IF @mtValue > 0 AND @mtQnt > 0 AND @biBaseBillType <> 2 	-- ?CE??E ??E?? ?OE??CE
					SET @mtAvgPrice = @mtValue / @mtQnt
			END
			ELSE BEGIN -- @mtQnt is <= 0:
				IF @biBaseBillType <> 2 	-- ?CE??E ??E?? ?OE??CE
					SET @mtValue = @biQnt * (@biUnitPrice + @biUnitExtra * @biExtraAffectsCostPrice - @biUnitDiscount * @biDiscountAffectsCostPrice)
				SET @Tmp = @buDirection * (@biQnt + @biBonusQnt) 
				IF @mtQnt = 0
					IF (@biQnt + @biBonusQnt) <> 0
						SET @mtAvgPrice = (@biQnt/(@biQnt + @biBonusQnt)) * (@biUnitPrice + @biUnitExtra * @biExtraAffectsCostPrice - @biUnitDiscount * @biDiscountAffectsCostPrice)
					ELSE
						SET @mtAvgPrice = @biUnitPrice + @biUnitExtra * @biExtraAffectsCostPrice - @biUnitDiscount * @biDiscountAffectsCostPrice
				ELSE
					IF @Tmp > 0 AND @mtValue > 0 AND @biBaseBillType <> 2
						SET @mtAvgPrice =  @mtValue / @Tmp
				SET @mtQnt = @mtQnt + @Tmp
			END 
			SET @mtQnt2 = @mtQnt2 + @buDirection * @biQnt2  
			SET @mtQnt3 = @mtQnt3 + @buDirection * @biQnt3
		END 
		----------------------------------- 

		FETCH FROM @c_bi INTO 
			@buGUID,
			@buDate,  
			@buDirection, 
			@biNumber,  
			@biMatPtr,
			@biStorePtr,     
			@biQnt,  
			@biQnt2,  
			@biQnt3, 
			@biBonusQnt,  
			@biUnitPrice,  
			@biUnitDiscount,  
			@biUnitExtra,
			@biAffectsCostPrice, 
			@biDiscountAffectsCostPrice,  
			@biExtraAffectsCostPrice, 
			@biBaseBillType 
	 
	END -- @c_bi loop 		-- insert the last mt statistics:
	INSERT INTO @t_Result SELECT @mtGUID, @stGUID, @mtQnt, @mtQnt2, @mtQnt3, @mtAvgPrice

	CLOSE @c_bi DEALLOCATE @c_bi
	--return result Set
	INSERT INTO [#t_Prices2]
 		SELECT
			ISNULL( [r].[GUID],  [m].[mtGUID]), 
			ISNULL( [r].[AvgPrice], 0),
			[r].[stGUID]
		FROM 
			@t_Result AS [r] INNER JOIN [vwMtGr] AS [m] ON [r].[GUID] = [m].[mtGUID]
			INNER JOIN [#MatTbl] AS [mtTbl] ON [r].[GUID] = [mtTbl].[MatGuid]
		WHERE 
			 ((@MatType = -1) OR ([m].[mtType] = @MatType))
	RETURN @@ROWCOUNT 
