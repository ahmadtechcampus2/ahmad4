#####################################################################
CREATE PROCEDURE prcGetAvgPriceByBranch
	@StartDate 		[DATETIME],
	@EndDate 		[DATETIME],
	@MatGUID 		[UNIQUEIDENTIFIER] = 0x00,
	@GroupGUID 		[UNIQUEIDENTIFIER] = 0x00,
	@StoreGUID 		[UNIQUEIDENTIFIER] = 0x00,
	@CostGUID 		[UNIQUEIDENTIFIER] = 0x00,
	--@BranchGUID 	UNIQUEIDENTIFIER = NULL,
	@MatType 		[INT] = -1, -- 0 Store or 1 Service or -1 ALL
	@CurrencyGUID 	[UNIQUEIDENTIFIER] = 0x00,
	@CurrencyVal 	[FLOAT] = 1,
	@SrcTypes 		[UNIQUEIDENTIFIER] = 0x00,
	@ShowUnLinked 	[INT] = 0, 
	@UseUnit 		[INT] = 0,
	@ByStore		[INT] = 0
AS
	SET NOCOUNT ON	 

	DECLARE @CondStr [NVARCHAR](max)

	DECLARE @t_Result TABLE
	(
		[GUID] 			[UNIQUEIDENTIFIER],
		[StGUID]		[UNIQUEIDENTIFIER],
		[BranchGUID]	[UNIQUEIDENTIFIER],
		[Qnt] 			[FLOAT],
		[AvgPrice] 		[FLOAT]
	)
	---------------------------------------------------------------------- 
	DECLARE
		-- mt table variables declarations:
		@mtGUID 						[UNIQUEIDENTIFIER],
		@stGUID 						[UNIQUEIDENTIFIER],
		@BranchGUID						[UNIQUEIDENTIFIER],
		@mtQnt 							[FLOAT],
		@mtQnt2 						[FLOAT],
		@mtQnt3 						[FLOAT],
		@mtAvgPrice 					[FLOAT],
		@mtValue 						[FLOAT],
		-- bi cursor input variables declarations:
		@buGUID							[UNIQUEIDENTIFIER],
		@buDate 						[DATETIME],
		@buDirection 					[INT],
		@biNumber 						[INT],
		@biMatPtr 						[UNIQUEIDENTIFIER],
		@biStorePtr 					[UNIQUEIDENTIFIER],
		@buBranch						[UNIQUEIDENTIFIER],
		@biQnt 							[FLOAT],
		@biBonusQnt 					[FLOAT], 
		@biUnitPrice 					[FLOAT], 
		@biUnitDiscount 				[FLOAT], 
		@biUnitExtra 					[FLOAT], 
		@biAffectsCostPrice 			[BIT], 
		@biDiscountAffectsCostPrice 	[BIT], 
		@biExtraAffectsCostPrice 		[BIT], 
		@biBaseBillType					[INT] 
		 
	---------------------------------------------------------------------- 
	CREATE TABLE [#Result](
			[buGUID]						[UNIQUEIDENTIFIER],
			[buNumber]						[INT],
			[buDate] 						[DATETIME],
			[buDirection] 					[INT],
			[buBranch]						[UNIQUEIDENTIFIER],
			[biNumber] 						[INT],
			[biMatPtr] 						[UNIQUEIDENTIFIER],
			[biStorePtr] 						[UNIQUEIDENTIFIER],
			[biQnt]							[FLOAT],
			[biBonusQnt] 					[FLOAT],
			[biUnitPrice] 					[FLOAT],
			[biUnitDiscount] 				[FLOAT],
			[biUnitExtra] 					[FLOAT],
			[biAffectsCostPrice] 			[BIT],
			[biDiscountAffectsCostPrice]	[BIT],
			[biExtraAffectsCostPrice]		[BIT],
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
			[buBranch],
			[biNumber],
			[biMatPtr],
			[biStorePtr],
			[biQty],
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
			[dbo].[fnExtended_BiGr_Fixed]( @CurrencyGUID) AS [r]
			INNER JOIN [#BillsTypesTbl] AS [bt] ON [r].[BuType] = [bt].[TypeGUID]
			INNER JOIN [#MatTbl] AS [mtTbl] ON [r].[biMatPtr] = [mtTbl].[MatGuid]
		WHERE
			[buIsPosted] <> 0 AND [buDate] BETWEEN @StartDate AND @EndDate

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
			[buGUID],
			[buDate],
			[buDirection],
			[buBranch],
			[biNumber],
			[biMatPtr], 
			[biStorePtr],  
			[biQnt],  
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
			CASE @ByStore WHEN 0 THEN 0X00 ELSE [biStorePtr] END,
			[buBranch],
			[buDate],  
			[buSortFlag],  
			[buNumber],
			[biNumber]

	--------------------------------------------------------------------------------------- 
	OPEN @c_bi FETCH NEXT FROM @c_bi INTO
			@buGUID,
			@buDate,  
			@buDirection,
			@buBranch,
			@biNumber,  
			@biMatPtr, 
			@biStorePtr,  
			@biQnt,  
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
	IF (@ByStore = 0)
		SET @stGUID = 0X0
	ELSE
		SET @stGUID = @biStorePtr 
	SET @BranchGUID = @buBranch 
	-- reset variables: 
	SET @mtQnt = 0 
	
	SET @mtAvgPrice = 0 
	-- start @c_bi loop 
	 
	WHILE @@FETCH_STATUS = 0 
	BEGIN 
		-- is this a new material ? 
		IF (@mtGUID <> @biMatPtr) AND (@stGUID <> @biStorePtr)
		BEGIN
			-- insert the material record: 
			INSERT INTO @t_Result VALUES( 
				@mtGUID,
				@stGUID, 
				@BranchGUID,
				@mtQnt,   
				@mtAvgPrice) 
			-- reset mt variables: 
			SET @mtGUID = @biMatPtr 
			IF (@ByStore = 0)
				SET @stGUID = 0X0
			ELSE
				SET @stGUID = @biStorePtr
			SET @BranchGUID = @BuBranch
			SET @mtQnt = 0 
			SET @mtQnt2 = 0  
			SET @mtQnt3 = 0 
			SET @mtAvgPrice = 0 
		END 
		-------------------------- 
		--- is this a new branch
		IF @BuBranch <> @BranchGUID 
		BEGIN
			-- insert the material record: 
			INSERT INTO @t_Result VALUES( 
				@mtGUID,
				@stGUID,
				@BranchGUID,
				@mtQnt,   
				@mtAvgPrice) 
			-- reset mt variables: 
			SET @mtGUID = @biMatPtr 
			SET @BranchGUID = @BuBranch
			SET @mtQnt = 0 
			SET @mtAvgPrice = 0 
		END
		IF @biAffectsCostPrice = 0 
		BEGIN 
			SET @mtQnt = @mtQnt + @buDirection * (@biQnt + @biBonusQnt)  
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
		END 
		----------------------------------- 

		FETCH FROM @c_bi INTO 
			@buGUID,
			@buDate,  
			@buDirection,
			@buBranch, 
			@biNumber,  
			@biMatPtr,
			@biStorePtr,  
			@biQnt,  
			@biBonusQnt,  
			@biUnitPrice,  
			@biUnitDiscount,  
			@biUnitExtra,
			@biAffectsCostPrice, 
			@biDiscountAffectsCostPrice,  
			@biExtraAffectsCostPrice, 
			@biBaseBillType 
	 
	END -- @c_bi loop 		-- insert the last mt statistics:
	INSERT INTO @t_Result SELECT @mtGUID,@stGuid, @BranchGUID, @mtQnt, @mtAvgPrice

	CLOSE @c_bi DEALLOCATE @c_bi
	--return result Set
	IF (@ByStore = 0)
	BEGIN
		INSERT INTO [#t_Prices]
 			SELECT
				ISNULL( [r].[GUID],  [m].[mtGUID]), 
				[BranchGUID],
				ISNULL( [r].[AvgPrice], 0),
				0x00
			FROM 
				@t_Result AS [r] INNER JOIN [vwMtGr] AS [m] ON [r].[GUID] = [m].[mtGUID]
				INNER JOIN [#MatTbl] AS [mtTbl] ON [r].[GUID] = [mtTbl].[MatGuid]
			
		RETURN @@ROWCOUNT 
	END
	ELSE
	BEGIN
		INSERT INTO [#t_Prices]
			SELECT
					ISNULL( [r].[GUID],  [m].[mtGUID]), 
					[BranchGUID],
					ISNULL( [r].[AvgPrice], 0),
					[StGUID]
				FROM 
					@t_Result AS [r] INNER JOIN [vwMtGr] AS [m] ON [r].[GUID] = [m].[mtGUID]
					INNER JOIN [#MatTbl] AS [mtTbl] ON [r].[GUID] = [mtTbl].[MatGuid]
	END

/*
select * from br000


--CREATE TABLE #SecViol( Type INT, Cnt INTEGER)
--CREATE TABLE #CostTbl( CostGUID UNIQUEIDENTIFIER, Security INT)

CREATE TABLE #MatTbl(MatGuid UNIQUEIDENTIFIER, mtSecurity INT)
INSERT INTO #MatTbl( MatGuid, mtSecurity) VALUES ('F251FC9F-3229-4314-926C-3323B4DD80EE', 1)
INSERT INTO #MatTbl( MatGuid, mtSecurity) VALUES ('9018D2C1-05E3-4360-A453-C8A8065A456B', 1)

CREATE TABLE #StoreTbl(	StoreGUID UNIQUEIDENTIFIER, Security INT)
INSERT INTO #StoreTbl VALUES ('EF638244-A716-47B1-81E2-4841CA711D46', 1)
INSERT INTO #StoreTbl VALUES ('DB8B5A7F-C8C9-4CA0-9D94-60F6815B5DC7', 1)
INSERT INTO #StoreTbl VALUES ('20EFB511-7672-4B12-8D70-F0B10466C2D1', 1)

CREATE TABLE #BillsTypesTbl( TypeGuid UNIQUEIDENTIFIER, UserSecurity INTEGER, UserReadPriceSecurity INTEGER)
INSERT INTO #BillsTypesTbl	EXEC prcGetBillsTypesList 	0x0
CREATE TABLE #CostTbl( CostPtr UNIQUEIDENTIFIER, Security INT)
CREATE TABLE #t_Prices( mtNumber UNIQUEIDENTIFIER, Branch UNIQUEIDENTIFIER, APrice FLOAT)

EXEC prcGetAvgPriceByBranch
'1/1/2000'	--	@StartDate
,'5/13/2007'--	@EndDate
,0x0--	@MatGUID
,0x0--	@GroupGUID
,0x0--	@StoreGUID
,0x0--	@CostGUID
--,0x0--	@BranchGuid
,0--	@MatType
,'BB123651-A15E-4AAA-AEBE-F5B44211DDA3'--	@CurrencyGUID
,1--	@CurrencyVal
,0x0--	@SrcTypes
,0--	@ShowUnLinked
,0--	@UseUnit

SELECT * FROM #t_Prices
DROP TABLE #StoreTbl
DROP TABLE #BillsTypesTbl
DROP TABLE #CostTbl
DROP TABLE #MatTbl
DROP TABLE #t_Prices

*/

###################################################
#END