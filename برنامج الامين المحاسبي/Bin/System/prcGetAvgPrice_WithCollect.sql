############################################################
CREATE PROCEDURE prcGetAvgPrice_WithCollect
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
	@Collect1	[INT] = 0,
	@Collect2	[INT] = 0,
	@Collect3	[INT] = 0
AS  
	SET NOCOUNT ON
	DECLARE @Sql [NVARCHAR](max) 
		-- declare cursors: 
	DECLARE @c_bi CURSOR 
	DECLARE @t_Result TABLE( 
		[Col1] [NVARCHAR](255)  COLLATE ARABIC_CI_AI, 
		[Col2] [NVARCHAR](255)  COLLATE ARABIC_CI_AI, 
		[Col3] [NVARCHAR](255)  COLLATE ARABIC_CI_AI, 
		[AvgPrice] [FLOAT]) 
	---------------------------------------------------------------------- 
	DECLARE
		-- mt table variables declarations:
		@Col1 [NVARCHAR](255),
		@Col2 [NVARCHAR](255),
		@Col3 [NVARCHAR](255),
		@ACol1 [NVARCHAR](255),
		@ACol2 [NVARCHAR](255),
		@ACol3 [NVARCHAR](255),
		@CCol1 [NVARCHAR](255),
		@CCol2 [NVARCHAR](255),
		@CCol3 [NVARCHAR](255),
		@mtQnt [FLOAT], 
		@mtAvgPrice [FLOAT], 
		@mtValue [FLOAT], 
		@buGUID				[UNIQUEIDENTIFIER],
		@buDate 			[DATETIME], 
		@buDirection 		[INT], 
		@biNumber 			[INT], 
		@biQnt 				[FLOAT], 
		@biBonusQnt 		[FLOAT], 
		@biUnitPrice 		[FLOAT], 
		@biUnitDiscount 	[FLOAT], 
		@biUnitExtra 		[FLOAT], 
		@biDiscExtra		[FLOAT], 
		@biAffectsCostPrice [BIT], 
		@biDiscountAffectsCostPrice [BIT], 
		@biExtraAffectsCostPrice 	[BIT], 
		@biBaseBillType				[INT] 
		 
	---------------------------------------------------------------------- 
	CREATE TABLE [#Result]
	(
		[buGUID]					[UNIQUEIDENTIFIER],
		[buNumber]					[INT],
		[buDate] 					[DATETIME],
		[buDirection] 				[INT],
		[biNumber] 					[INT],
		[Col1] [NVARCHAR](255)  COLLATE ARABIC_CI_AI, 
		[Col2] [NVARCHAR](255)  COLLATE ARABIC_CI_AI, 
		[Col3] [NVARCHAR](255)  COLLATE ARABIC_CI_AI,
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
		[buSortFlag] 				[INT]
	)
	---------------------------------------------------------------------- 
	SET @CCol1 = dbo.fnGetMatCollectedFieldName(@Collect1,CASE @Collect1 WHEN 11 THEN 'GR' ELSE 'mt' END)
	SET @CCol2 = dbo.fnGetMatCollectedFieldName(@Collect2,CASE @Collect1 WHEN 11 THEN 'GR' ELSE 'mt' END)
	SET @CCol3 = dbo.fnGetMatCollectedFieldName(@Collect3,CASE @Collect1 WHEN 11 THEN 'GR' ELSE 'mt' END)	
	SET @Sql = 'INSERT INTO [#Result]
			SELECT
				[buGUID],
				[buNumber],
				[buDate],
				[buDirection],
				[biNumber],'
	
	SET @Sql = @Sql + @CCol1 + ',' 
	IF @CCol2 <> ''
		SET @Sql = @Sql +  @CCol2 + ',' 
	ELSE 
		SET @Sql = @Sql +  '''''' + ','
	IF @CCol3 <> ''
		SET @Sql = @Sql + @CCol3 + ',' 
	ELSE 
		SET @Sql = @Sql +  '''''' + ','
	SET @Sql = @Sql + '[biQty],
				[biBonusQnt],
				CASE WHEN [UserReadPriceSecurity] >= [BuSecurity] THEN [FixedbiUnitPrice] ELSE 0 END, -- CASE WHEN UserReadPriceSecurity >= BuSecurity THEN FixedBiPrice / (CASE mtUnitFact WHEN 0 THEN 1 ELSE mtUnitFact END) ELSE 0 END,
				CASE WHEN [UserReadPriceSecurity] >= [BuSecurity] THEN [FixedbiUnitDiscount] ELSE 0 END, -- CASE WHEN UserReadPriceSecurity >= BuSecurity THEN  ((CASE (buTotal * biQty) WHEN 0 THEN ((FixedbiDiscount / biQty) + biBonusDisc) ELSE ((CASE biQty WHEN 0 THEN 0 ELSE (FixedbiDiscount / biQty) END) + (ISNULL((SELECT SUM(diDiscount) FROM vwDi WHERE vwDi.diType = buType AND vwDi.diParent = buNumber),0) * FixedBiPrice / mtUnitFact) / buTotal) END) + biBonusDisc) * mcDiscountAffectsCostPrice ELSE 0 END,
				CASE WHEN [UserReadPriceSecurity] >= [BuSecurity] THEN [FixedbiUnitExtra] ELSE 0 END, -- CASE WHEN UserReadPriceSecurity >= BuSecurity THEN (CASE buTotal WHEN 0 THEN biExtra ELSE biExtra + buTotalExtra * FixedBiPrice / mtUnitFact / buTotal END) * mcExtraAffectsCostPrice ELSE 0 END,
				CASE WHEN [UserReadPriceSecurity] >= [BuSecurity] THEN ([FixedBiExtra] * [btExtraAffectCost]) - ([btDiscAffectCost] * [FixedBiDiscount]) ELSE 0 END,
				[btAffectCostPrice],
				[btDiscAffectCost],
				[btExtraAffectCost],
				[btBillType],
				[r].[buSecurity],
				[bt].[UserReadPriceSecurity],
				[bt].[UserSecurity],
				[buSortFlag]
			FROM
				[dbo].[fnExtended_Bi_Fixed](''' + CAST(@CurrencyGUID AS NVARCHAR(40))+''') AS [r]
				INNER JOIN [#BillsTypesTbl] AS [bt] ON [r].[BuType] = [bt].[TypeGUID]
				INNER JOIN [#MatTbl] AS [mtTbl] ON [r].[biMatPtr] = [mtTbl].[MatGuid]'+ dbo.fnGetInnerJoinGroup(CASE WHEN @Collect1 = 11 OR @Collect2 = 11 OR @Collect3 = 11 THEN 1 ELSE 0 END ,'mtGroup') + '
			WHERE
				[buIsPosted] > 0 AND [buDate] BETWEEN '
	SET @Sql = @Sql + [dbo].[fnDateString] (@StartDate) + ' AND ' + [dbo].[fnDateString](@EndDate) 
	EXEC(@Sql)
	-- setup bi cursor: 
	SET @c_bi = CURSOR FAST_FORWARD FOR 
			SELECT  
				[buGUID],  
				[buDate],  
				[buDirection],
				[biNumber],  
				[Col1],  
				[Col2], 
				[Col3],  
				[biQnt],  
				[biBonusQnt],  
				[biUnitPrice],  
				[biUnitDiscount],  
				[biUnitExtra], 
				[biDiscExtra],
				[biAffectsCostPrice], 
				[biDiscountAffectsCostPrice],  
				[biExtraAffectsCostPrice], 
				[biBaseBillType] 
			FROM 
				[#Result] 
			WHERE 
				[UserSecurity] >= [Security]
			ORDER BY 
				[Col1],  
				[Col2], 
				[Col3],   
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
			@Col1,
			@Col2,  
			@Col3,  
			@biQnt,  
			@biBonusQnt,  
			@biUnitPrice,  
			@biUnitDiscount,  
			@biUnitExtra, 
			@biDiscExtra,
			@biAffectsCostPrice, 
			@biDiscountAffectsCostPrice,  
			@biExtraAffectsCostPrice, 
			@biBaseBillType 

		-- get the first material 
		SET @ACol1 = @Col1
		SET @ACol2 = @Col2
		SET @ACol3 = @Col3
		-- reset variables: 
		SET @mtQnt = 0 
		SET @mtAvgPrice = 0 
		-- start @c_bi loop 
	WHILE @@FETCH_STATUS = 0 
	BEGIN 
		-- is this a new material ? 
		IF @ACol1 <> @Col1 OR @ACol2 <> @Col2 OR @ACol3 <> @Col3
		BEGIN 
			-- insert the material record: 
			INSERT INTO @t_Result VALUES( 
				@ACol1,@ACol2,@ACol3, 
				@mtAvgPrice) 
			-- reset mt variables: 
			SET @ACol1 = @Col1
			SET @ACol2 = @Col2
			SET @ACol3 = @Col3
			SET @mtQnt = 0 
		
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
			SET @mtQnt = @mtQnt + @buDirection * (@biQnt + @biBonusQnt)
			IF @mtValue > 0 AND @mtQnt > 0 
				SET @mtAvgPrice = @mtValue / @mtQnt
			SET @mtValue = 0
		
		END 
		----------------------------------- 
		FETCH FROM @c_bi INTO 
				@buGUID,
		@buDate,  
		@buDirection,
		@biNumber,  
		@Col1,
		@Col2,  
		@Col3,  
		@biQnt,  
		@biBonusQnt,  
		@biUnitPrice,  
		@biUnitDiscount,  
		@biUnitExtra,
		@biDiscExtra, 
		@biAffectsCostPrice, 
		@biDiscountAffectsCostPrice,  
		@biExtraAffectsCostPrice, 
		@biBaseBillType 

	 
	END -- @c_bi loop 		-- insert the last mt statistics:
	INSERT INTO @t_Result values( @ACol1,@ACol2,@ACol3, @mtAvgPrice)

	CLOSE @c_bi DEALLOCATE @c_bi
		--return result Set
	SELECT * FROM @t_Result
############################################################
#END 