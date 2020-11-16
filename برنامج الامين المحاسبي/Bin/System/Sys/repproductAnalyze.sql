###########################################################################
CREATE PROCEDURE Rep_ProductActivityAnalysis 
	@StartDate [DateTime] ,     
	@EndDate [DateTime] ,    
	@HaveDialy  Bit, --1: Daily, 2: Weekly, 3:Monthly, 4: Quarter
	@ReportType [INT], -- 0: ShowValue, 1: ShowQty
	@SrcGUID AS [UNIQUEIDENTIFIER] ,-- BillSrc	  
	@PriceType [INT], 
	@PricePolicy [INT], -- 120: Max Price,121: Average Price, 122: Last Price
	@InOut [INT],  
	@CurPtr [UNIQUEIDENTIFIER] ,    
	@CurVal [FLOAT],    
	@MatPtr AS [UNIQUEIDENTIFIER] ,  
	@GrpPtr AS [UNIQUEIDENTIFIER] ,
	@StorePtr AS [UNIQUEIDENTIFIER] , 
	@CostPtr AS [UNIQUEIDENTIFIER] ,
	@UseUnit AS [INT],
	@STR [NVARCHAR] (max) = '',
	@MatCondGuid AS [UNIQUEIDENTIFIER] = 0X00 ,
	@shwEmptyPeriod	[BIT] = 1,
	@ShowDiscAndExtra [BIT] = 0,
	@ShowAllGroups BIT = 0
AS
	SET NOCOUNT ON
	-- cursor and its variable
	DECLARE @c_bi CURSOR        
	DECLARE
		@buType [UNIQUEIDENTIFIER] , @buNumber [INT], @buGUID [UNIQUEIDENTIFIER] , @buDate [DateTime] , @buDirection [INT],
		@biMatPtr [UNIQUEIDENTIFIER] , @biQnt [FLOAT], @biUnitPrice [FLOAT], @mtUnitPrice [FLOAT],
		@biUnitDiscount [FLOAT], @biUnitExtra [FLOAT], @biAffectsLastPrice [BIT], @biAffectsCostPrice [BIT],
		@biExtraAffectsCostPrice [BIT],	@biDiscountAffectsCostPrice [BIT], @repDirection [INT], @TotalPrice [FLOAT],
		@biUnitPrice2 [FLOAT],@UnitFact [FLOAT],@RW INT,@prId INT,
		@biLCDisc [FLOAT], @biLCExtra [FLOAT]


	--- base variables and tables
	DECLARE 
		@CurMatPtr [UNIQUEIDENTIFIER] , @CurrentDate [DateTime] , @mtTotalQnt [FLOAT],@CurrentStartDate [DateTime] , 
		@mtMaxPrice [FLOAT],@mtAvgPrice [FLOAT], @mtLastPrice [FLOAT], @mtValue [FLOAT], @tmp [FLOAT]
	CREATE TABLE [#T_Result](
					
					[Type] [UNIQUEIDENTIFIER] ,
					[Security] [INT],
					[UserSecurity] [INT],
					[UserReadPriceSecurity] [INT], 
					[buDate] [DateTime] ,
					[buDirection] [INT],
					[repDirection] [INT],
					[biMatPtr] [UNIQUEIDENTIFIER] ,
					[biQnt] [FLOAT],
					[biPrice] [FLOAT],
					[mtUnitPrice] [FLOAT],
					[biUnitDiscount] [FLOAT],
					[biUnitExtra] [FLOAT],
					[biAffectsLastPrice] [INT],
					[biAffectsCostPrice] [INT],
					[biDiscountAffectsCostPrice] [INT],
					[biExtraAffectsCostPrice] [INT],
					[UnitFact] [FLOAT],
					biQty  [FLOAT],
					prId int,
					[LCDisc] [FLOAT],
					[LCExtra] [FLOAT]
					)
	 
	CREATE TABLE [#SecViol]( [Type] [INT], [Cnt] [INT]) 

	CREATE TABLE [#FinalResult] ([id] [INT], [StartDate] [DateTime] , [EndDate] [DateTime] , [Val] [FLOAT],	[Extra] [FLOAT], [Disc] [FLOAT],[Group] UNIQUEIDENTIFIER DEFAULT 0X00)
	CREATE TABLE [#CostTbl]( [coGUID] [UNIQUEIDENTIFIER] , [Security] [INT])
	CREATE TABLE [#MatTbl] ( [MatGUID] [UNIQUEIDENTIFIER] , [Security] [INT],[Group] UNIQUEIDENTIFIER DEFAULT 0X00)
	CREATE TABLE [#StoreTbl]( [stGUID] [UNIQUEIDENTIFIER] , [Security] [INT])
	CREATE TABLE [#BillTbl]( [Type] [UNIQUEIDENTIFIER] , [Security] [INT], [ReadPriceSecurity] [INT])
	
	CREATE TABLE [#t_Prices]
	(
		[mtNumber] 	[UNIQUEIDENTIFIER] ,
		[APrice] 	[FLOAT]
	) 

	--- Fill tables and variables
	INSERT INTO [#CostTbl]	EXEC [prcGetCostsList]		@CostPtr
	INSERT INTO [#StoreTbl]	EXEC [prcGetStoresList]		@StorePtr
	INSERT INTO [#MatTbl]([MatGUID],[Security])	EXEC [prcGetMatsList]		@MatPtr,@GrpPtr,-1,@MatCondGuid
	INSERT INTO [#BillTbl] 	EXEC [prcGetBillsTypesList] @SrcGUID
	--IF @CostPtr = 0x0
		--INSERT INTO #CostTbl SELECT 0, 0
	DECLARE @Pr TABLE
	(
		ID INT IDENTITY(1,1),
		[StartDate] DATETIME,
		[EndDate] DATETIME,
		[Group] UNIQUEIDENTIFIER DEFAULT 0X00)
	IF @HaveDialy =1 
		INSERT INTO @Pr ([StartDate],[EndDate])
			SELECT [StartDate],[EndDate] FROM [dbo].[fnGetPeriod]( 1, @StartDate, @EndDate) ORDER BY [StartDate]
	ELSE
		INSERT INTO @Pr ([StartDate],[EndDate])
			SELECT [StartDate],[EndDate] FROM [dbo].[fnGetStrToPeriod] ( @STR ) ORDER BY [StartDate]
	
	IF (@ShowAllGroups >0)
	BEGIN
		SET @RW = 1
		UPDATE M SET [Group] = GroupGuid FROM [#MatTbl] m INNER JOIN mt000 mt ON m.MatGUID = mt.GUID
		WHILE (@RW > 0)
		BEGIN
			UPDATE M SET [Group] = gr.ParentGUID FROM [#MatTbl] m INNER JOIN gr000 gr ON m.[Group]  = gr.GUID
				WHERE gr.ParentGUID <> @GrpPtr
			SET @RW = @@ROWCOUNT 
		END 
		INSERT INTO @Pr ([StartDate],[EndDate],[Group]) select  [StartDate], [EndDate] ,GR.grGuid FROM vwGr gr,@Pr WHERE GR.grParent  = @GrpPtr ORDER BY GR.grGuid,[StartDate]
		DELETE @Pr WHERE [Group] = 0X00
	END
	INSERT INTO [#FinalResult] ([id], [StartDate], [EndDate] , [Val],	[Extra] , [Disc],[Group])   
			SELECT id, [StartDate], [EndDate], 0, 0, 0,[Group] FROM @Pr
	
	
	IF( @PricePolicy = 128)
		SELECT @PricePolicy = [Value] FROM [op000] WHERE [Name] = 'AmnCfg_DefaultPrice'
	DECLARE @CurrOne UNIQUEIDENTIFIER
	SET @CurrOne =( SELECT TOP 1 [guid] FROM [my000] WHERE [currencyVal] = 1)
	INSERT INTO [#T_Result]
				(
					[Type] ,
					[Security] ,
					[UserSecurity] ,
					[UserReadPriceSecurity] , 
					[buDate] ,
					[buDirection] ,
					[repDirection] ,
					[biMatPtr] ,
					[biQnt] ,
					[biPrice] ,
					[mtUnitPrice] ,
					[biUnitDiscount] ,
					[biUnitExtra] ,
					[biAffectsLastPrice] ,
					[biAffectsCostPrice] ,
					[biDiscountAffectsCostPrice] ,
					[biExtraAffectsCostPrice] ,
					[UnitFact],
					biQty,
					prId,
					[LCDisc],
					[LCExtra]
				)
				SELECT        
					[buType],
					[buSecurity],
					[Security],
					[ReadPriceSecurity],
					
					[buDate],
					[buDirection],
					BDIR,
					[biMatPtr],
					([biQty] + [biBonusQnt])/ UnitFact,
					PriceSecFact * ([FixedBiPrice] * [biQty]) / (UnitFact * ([biQty] +[biBonusQnt])),
					PriceSecFact * RPrice,
					PriceSecFact * 
								
					CASE WHEN  [FixedbuTotal]= 0 OR [biQty] = 0 THEN 0 ELSE  
					(((FixedbuTotalDisc - FixedbuItemsDisc) * [FixedBiPrice] * biQty / (biUnitFact * [FixedbuTotal]))
					+([FixedbiBonusDisc] + [FixedbiDiscount])) / ([biQty] + [biBonusQnt])
								END  * [btDiscAffectCost]  ,
					CASE WHEN  [FixedbuTotal]= 0 OR [biQty] = 0 THEN 0 ELSE  
						 ([FixedbuTotalExtra] * [FixedBiPrice] * biQty / (biUnitFact * [FixedbuTotal]))/ ([biQty] + [biBonusQnt]) END * [btExtraAffectCost],
						 --([FixedbiExtra] +([FixedbuTotalExtra] * [FixedBiPrice] * biQty / (biUnitFact * [FixedbuTotal])))/ ([biQty] + [biBonusQnt]) END * [btExtraAffectCost],
					PriceSecFact * [btAffectLastPrice],
					PriceSecFact * [btAffectCostPrice],
					PriceSecFact * [btDiscAffectCost],
					PriceSecFact * [btExtraAffectCost],
					UnitFact,
					biQty,
					prId,
					LCDisc,
					LCExtra
				FROM
				(
				select 
					[bi].[buType],[bi].[buSecurity],[bt].[Security],
					[bt].[ReadPriceSecurity],biDiscount,biExtra,
					[bi].[buNumber],[bi].[buGUID],[bi].[buDate],
					[bi].[buDirection],FixedbuTotalDisc,
					CASE @InOut
						WHEN 1 THEN  [bi].[buDirection]
						WHEN 2 THEN (-[bi].[buDirection])
						ELSE 1
					END BDIR,
					[FixedCurrencyFactor],
					[bi].[biNumber],[bi].[biMatPtr],
					[bi].[biQty],[bi].[biBonusQnt],[bi].[FixedBiPrice],
					bi.buSortFlag,
					CASE WHEN [ReadPriceSecurity] >= [buSecurity] THEN 1 ELSE 0 END * CASE @PriceType WHEN 256 THEN [bi].[FixedBiPrice] ELSE [f].[fixedPrice] END RPrice,
					 [bi].[FixedbuTotal],
					[bi].[FixedbiDiscount],[bi].[FixedbiBonusDisc],
					[bi].[btDiscAffectCost],
					[bi].[FixedbiExtra],[bi].[FixedbuTotalExtra],[bi].[btExtraAffectCost],
					[bi].[btAffectLastPrice],
					[bi].[btAffectCostPrice],(select id from @pr pr WHERE buDate BETWEEN Startdate AND ENDDATE AND pr.[Group]  = mt.[Group])prId ,
				(CASE [bi].[biUnity] 
						WHEN 2 THEN (CASE [f].[mtUnit2FactFlag] WHEN 0 THEN f.[mtUnit2Fact] ELSE [biQty] / (CASE [biQty2] WHEN 0 THEN 1 ELSE [biQty2] END) END) 
						WHEN 3 THEN (CASE f.[mtUnit3FactFlag] WHEN 0 THEN f.[mtUnit3Fact] ELSE [biQty] / (CASE [biQty3] WHEN 0 THEN 1 ELSE [biQty3] END) END) 
						ELSE 1 
					END) mtUnitFact,
					
					CASE WHEN [ReadPriceSecurity] >= [buSecurity] THEN 1 ELSE 0 END PriceSecFact,
					CASE @UseUnit
					WHEN 0 THEN 1
					WHEN 1 THEN  ISNULL( CASE [f].[mtUnit2Fact] WHEN 0 THEN 1 ELSE [f].[mtUnit2Fact] END, 1)
					WHEN 2 THEN  ISNULL( CASE [f].[mtUnit3Fact] WHEN 0 THEN 1 ELSE [f].[mtUnit3Fact] END, 1)
					ELSE  ISNULL( CASE [f].[mtDefUnitFact] WHEN 0 THEN 1 ELSE [f].[mtDefUnitFact] END, 1)
					END UnitFact,
					CASE [bi].[biUnity] 
						WHEN 2 THEN (CASE [f].[mtUnit2FactFlag] WHEN 0 THEN f.[mtUnit2Fact] ELSE [biQty] / (CASE [biQty2] WHEN 0 THEN 1 ELSE [biQty2] END) END) 
						WHEN 3 THEN (CASE f.[mtUnit3FactFlag] WHEN 0 THEN f.[mtUnit3Fact] ELSE [biQty] / (CASE [biQty3] WHEN 0 THEN 1 ELSE [biQty3] END) END) 
						ELSE 1 
					END biUnitFact,FixedbuItemsDisc,
					[bi].FixedBiLCDisc LCDisc,
					[bi].FixedBiLCExtra LCExtra
					FROM	
					dbo.fn_bubi_Fixed( @CurPtr) AS [bi]
					INNER JOIN [dbo].[fnExtended_mt_fixed]( @PriceType, @PricePolicy, @UseUnit,@CurPtr,@EndDate) AS [f]
						ON [f].[mtGUID] = [bi].[biMatPtr]
					INNER JOIN [#BillTbl] AS [bt]
						ON [bt].[Type] = [bi].[buType]
					
					INNER JOIN [#StoreTbl] AS [st]
						ON [st].[stGUID] = [bi].[biStorePtr]
					INNER JOIN [#MatTbl] AS [mt]
						ON [mt].[MatGUID] = [bi].[biMatPtr]
				WHERE
					[bi].[buIsPosted] <> 0 AND
					(@CostPtr = 0x0 OR EXISTS( SELECT [coGUID] FROM [#CostTbl] WHERE [bi].[biCostPtr] = [coGUID])) AND
					[bi].[buDate] BETWEEN @StartDate AND @EndDate) AS c
				ORDER BY
					[biMatPtr], [buDate], [buSortFlag], [buNumber]
	
		EXEC [prcCheckSecurity] @result = '#T_Result'

		IF @PriceType <> 2
		BEGIN	
			DECLARE  @defCurr UNIQUEIDENTIFIER = (SELECT TOP 1 GUID FROM my000 WHERE CurrencyVal = 1);
			EXEC [prcGetMtPrice] @MatPtr,	@GrpPtr, -1, @CurPtr, @CurVal, @SrcGUID, @PriceType, @PricePolicy, 0, @UseUnit,@EndDate
			--UPDATE P
			--SET APrice =((P.APrice/mt.CurrencyVal)*dbo.fnGetCurVal(mt.CurrencyGUID,@EndDate))/dbo.fnGetCurVal(@CurPtr,@EndDate)
								  
			--FROM
			--	#t_Prices P
			--	INNER JOIN mt000 mt on  mt.GUID= p.mtNumber
		END
	IF	@PriceType = 256 OR @ReportType > 0
	BEGIN
		SELECT ISNULL(SUM( CASE @ReportType WHEN 0 THEN (repDirection *  biPrice * biQty * UnitFact) ELSE [biQnt]*[repDirection] END), 0) [Val], ISNULL(SUM([buDirection] * r.[biUnitExtra] * biQty), 0) Extra, ISNULL(SUM([buDirection] * r.[biUnitDiscount] * biQty), 0) [Disc], [StartDate], [EndDate],Q.[Group]
		FROM [#T_Result] r
		RIGHT JOIN [#FinalResult] Q ON  Q.id = R.prid
		GROUP BY [StartDate], [EndDate],Q.[Group]
		HAVING @shwEmptyPeriod = 1 
		OR ABS(ISNULL(SUM([buDirection] * CASE @ReportType WHEN 0 THEN [biPrice]*[biQnt] ELSE [biQnt] END),0)) > [dbo].[fnGetZeroValuePrice]()
		ORDER BY Q.[Group],[StartDate]
		IF (@ShowAllGroups > 0)
			SELECT grCode,grName,grGuid from vwGr WHERE grParent = @GrpPtr ORDER BY grGuid 
		SELECT * FROM [#SecViol]
		
		RETURN
	END

		SET @c_bi = CURSOR FAST_FORWARD FOR
			SELECT
				[Type],
				[buDate],
				[buDirection],
				[repDirection],
				[biMatPtr],
				[biQnt],
				[biPrice],
				[mtUnitPrice],
				[biUnitDiscount],
				[biUnitExtra],
				[biAffectsLastPrice],
				[biAffectsCostPrice],
				[biDiscountAffectsCostPrice],
				[biExtraAffectsCostPrice],
				[UnitFact],
				prId,
				[LCDisc],
				[LCExtra]
			FROM [#T_Result]
			ORDER BY [biMatPtr],prId
		OPEN @c_bi
		FETCH NEXT FROM @c_bi INTO
						@buType,
						@buDate,
						@buDirection,
						@repDirection,
						@biMatPtr,
						@biQnt,
						@biUnitPrice,
						@mtUnitPrice,
						@biUnitDiscount,
						@biUnitExtra,
						@biAffectsLastPrice,
						@biAffectsCostPrice,
						@biDiscountAffectsCostPrice,
						@biExtraAffectsCostPrice,
						@UnitFact,
						@prId,
						@biLCDisc,
						@biLCExtra

	SELECT @CurMatPtr = 0x0, @mtTotalQnt = 0, @CurrentDate = 0, @tmp = 0, @mtValue = 0,
			@mtMaxPrice = 0, @mtAvgPrice = 0, @mtLastPrice = 0,@TotalPrice = 0,@CurrentStartDate = 0
	SET @RW = 0
	IF @@FETCH_STATUS = 0
	BEGIN
		SELECT @CurrentDate = [EndDate], @CurrentStartDate = [StartDate] FROM [#FinalResult] WHERE @buDate BETWEEN [StartDate] AND [EndDate]
		SELECT @CurMatPtr = @biMatPtr
		SET @biUnitPrice2 = 0
				IF @PriceType <> 2
					SELECT @biUnitPrice2 = [APrice] FROM [#t_Prices] WHERE [mtNumber] = @biMatPtr
			
		
	END
	
	WHILE @@FETCH_STATUS = 0
	BEGIN       
		IF @CurMatPtr <> @biMatPtr OR @prId > @RW 
		BEGIN
			--IF @biQnt <> 0
			UPDATE [#FinalResult]
				SET [Val] = [Val] + ( CASE @ReportType
								WHEN 0 THEN
									CASE @PriceType
										WHEN 2 THEN
											(CASE @PricePolicy
												WHEN 120 THEN 	@mtMaxPrice * @mtTotalQnt
												WHEN 121 THEN  @mtAvgPrice * @mtTotalQnt
												WHEN 122 THEN  @mtLastPrice * @mtTotalQnt
												ELSE  @mtUnitPrice * @mtTotalQnt
												END)
										ELSE @TotalPrice 
									END
								ELSE @mtTotalQnt
								END)
			WHERE [id] = @RW
			IF @prId > @RW 
				SET @TotalPrice = 0
			IF @CurMatPtr <> @biMatPtr
			BEGIN
				SELECT @CurMatPtr = @biMatPtr, @mtAvgPrice = 0, @mtLastPrice = 0, @mtMaxPrice = 0,@TotalPrice = 0
				SET @biUnitPrice2 = 0
				IF @PriceType <> 2
					SELECT @biUnitPrice2 = [APrice] FROM [#t_Prices] WHERE [mtNumber] = @biMatPtr
			END
			SELECT     
				@mtTotalQnt = 0, @mtValue = 0,@TotalPrice = 0/*, @tmp = 0*/

			SET @RW = @prId 
		END

		SET @TotalPrice = @TotalPrice + (@biUnitPrice2*@biQnt*@UnitFact * @repDirection)
		SET @mtTotalQnt = @mtTotalQnt + @biQnt * @repDirection
		IF( @PriceType = 2)
		BEGIN
			IF( @PricePolicy = 120)
				IF @biAffectsLastPrice <> 0
					IF @mtUnitPrice > @biUnitPrice
						SET @mtMaxPrice = @biUnitPrice
			IF( @PricePolicy = 121)
				IF @biAffectsCostPrice <> 0
				BEGIN
					IF ( @tmp + @biQnt) > 0
					BEGIN
						SET @mtValue = ( @mtAvgPrice * @tmp + @buDirection * @biQnt * (@biUnitPrice + (@biUnitExtra * @biExtraAffectsCostPrice) - (@biUnitDiscount * @biDiscountAffectsCostPrice)))
						SET @mtValue = @mtValue - @biLCDisc + @biLCExtra
						IF @mtValue > 0 AND @mtTotalQnt <> 0
							SET @mtAvgPrice = ( @mtValue / (@tmp + @biQnt ))
					END
					ELSE
					BEGIN
							SET @mtAvgPrice =  0
					END
				END
			SET @tmp = @tmp +  @biQnt * @buDirection
			IF( @PricePolicy = 122)
					IF @biAffectsLastPrice <> 0
						SET @mtLastPrice = @biUnitPrice
		END
		
		FETCH NEXT FROM @c_bi INTO
			@buType,
			@buDate,
			@buDirection,
			@repDirection,
			@biMatPtr,
			@biQnt,
			@biUnitPrice,
			@mtUnitPrice,
			@biUnitDiscount,
			@biUnitExtra,
			@biAffectsLastPrice,
			@biAffectsCostPrice,
			@biDiscountAffectsCostPrice,
			@biExtraAffectsCostPrice,
			@UnitFact,
			@prId,
			@biLCDisc,
			@biLCExtra 
	END

	IF @mtTotalQnt <> 0   
		UPDATE [#FinalResult]
			SET [Val] = [Val] +
					( CASE @ReportType
						WHEN 0 THEN (
							CASE @PriceType
								WHEN 2 THEN
									(CASE @PricePolicy
										WHEN 120 THEN 	@mtMaxPrice * @mtTotalQnt
										WHEN 121 THEN  @mtAvgPrice * @mtTotalQnt
										WHEN 122 THEN  @mtLastPrice * @mtTotalQnt
										ELSE  @mtUnitPrice * @mtTotalQnt
									END)
								ELSE @TotalPrice
							END)
						ELSE @mtTotalQnt
					END )
		WHERE ID = @RW
	CLOSE @c_bi
	DEALLOCATE @c_bi
	
	---------------------
	IF (@ShowDiscAndExtra > 0)
	BEGIN
		UPDATE F SET 
		 [Extra] = [V].[Extra],
		 [Disc]  = [V].[Disc],
		 [Val]   = [Val] + [V].[Disc] - [V].[Extra]
		FROM #FinalResult F 
		INNER JOIN  
			(
				SELECT SUM([t].[biUnitExtra] * biQty) Extra, SUM([T].[biUnitDiscount] * biQty) [Disc], [StartDate], [EndDate] 
				FROM [#FinalResult] r 
				INNER JOIN [#T_Result] [t] ON [t].[buDate] BETWEEN [StartDate] AND [EndDate]
				GROUP BY [StartDate], [EndDate]
			) V ON [F].[StartDate] = [V].[StartDate] AND [F].[EndDate] = [V].[EndDate]
	END
	---------------------

	SELECT [StartDate], [EndDate], [Val], [Extra], [Disc],[Group] FROM [#FinalResult] WHERE @shwEmptyPeriod = 1 OR ABS([Val]) > [dbo].[fnGetZeroValuePrice]() ORDER BY ID
	IF (@ShowAllGroups > 0)
		SELECT grCode,grName,grGuid from vwGr WHERE grParent = @GrpPtr ORDER BY grGuid 
	SELECT  * FROM [#SecViol]
	
/*
prcConnections_Add2 'admin'
exec  [Rep_ProductActivityAnalysis] '8/1/2008 0:0:0.0', '8/15/2008 23:59:20.957', 0, 1, '338501de-ba5a-46cd-8308-0fdf2a61d43e', 4, 120, 1, 'e8e66a6e-2262-4dd2-bd71-e63fe58a8eba', 1.000000, 'f72bf097-eb21-4727-a947-986816e048bd', '00000000-0000-0000-0000-000000000000', '00000000-0000-0000-0000-000000000000', '00000000-0000-0000-0000-000000000000', 3, '8-1-2008 0:0,8-15-2008 23:59', '00000000-0000-0000-0000-000000000000', 0, 0
select 2130000 - 22000
*/
########################################################################################
#END