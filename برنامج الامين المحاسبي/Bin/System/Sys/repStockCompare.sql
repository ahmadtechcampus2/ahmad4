################################################################################
CREATE PROCEDURE repStockCompare  
			@StoreGUID AS [UNIQUEIDENTIFIER] ,
			@IncSubStore AS [INT],-- 1 include sub Store 0 don't include
			@GroupGUID AS [UNIQUEIDENTIFIER] ,
			@Type AS [INT],-- Type Of invent 0 now 1 between tow date 2 between tow expire date
			@StartDate AS [DateTime] ,
			@EndDate AS [DateTime] ,
			@UseUnit [INT] = 3,
			@MatGuid AS [UNIQUEIDENTIFIER]  = 0X0,
			@ShowEmptyMats	AS [INT] = 1,
			@MtFlag			AS	[BIGINT] = 0,
			@Sort			[INT] = 0,
			@ShowUnLinked	[INT] = 0,
			@Lang			[BIT] = 0,
			@MatCondGuid	AS [UNIQUEIDENTIFIER]  = 0x00,	
			@CostGuid	[UNIQUEIDENTIFIER]  = 0x00,
			@MatType	[INT] = -1,
			@ShowBalancedMat	[BIT] = 0,
			@RoundFirstUint [BIT] = 0,	
			@CurrencyPtr AS [UNIQUEIDENTIFIER]  = 0x0,
			@CurrencyVal AS [FLOAT] = 1,
			@PriceType	AS [INT],
			@ShowMatClass AS [BIT] 
AS
	SET NOCOUNT ON
	
	DECLARE @Zero FLOAT 
	SET @Zero = dbo.fnGetZeroValueQTY()

	DECLARE
		@UserGUID AS [UNIQUEIDENTIFIER] ,
		@UserMatSec AS [INT],
		@UserStoreSec AS [INT],
		@Sql [NVARCHAR](MAX),
		@mtStr [NVARCHAR](1000),
		@mtStr2 [NVARCHAR](1000),
		@Sql2 [NVARCHAR](100) = '',
		@Sql3 [NVARCHAR](10) = ''
	SET @UserGUID = [dbo].[fnGetCurrentUserGUID]() 
	SET @UserMatSec = [dbo].[fnGetUserMaterialSec_Browse]( @UserGUID)
	SET @UserStoreSec = [dbo].[fnGetUserStoreSec_Browse]( @UserGUID)
	
	CREATE TABLE [#SecViol]( [Type] [INT], [Cnt] [INTEGER])
	CREATE TABLE [#Src]( [Type] [UNIQUEIDENTIFIER] , [Sec] [INT], [ReadPrice] [INT],[UnPostedSec] [INT])
	CREATE TABLE [#Store]( [Number] [UNIQUEIDENTIFIER] , [Security] [INT])
	CREATE TABLE [#CostTbl]( [CostGUID] [UNIQUEIDENTIFIER], [Security] [INT]) 
	CREATE TABLE [#Mat] ( [mtNumber] [UNIQUEIDENTIFIER] , [mtSecurity] [INT])   
	--Filling temporary tables
	INSERT INTO [#Mat] EXEC [prcGetMatsList]  @MatGuid, @GroupGuid,@MatType,@MatCondGuid
	INSERT INTO [#Src] EXEC [prcGetBillsTypesList2] 	
	IF @IncSubStore = 0 AND @StoreGUID!=0X0
		INSERT INTO [#Store] VALUES(@StoreGUID,0)
	ELSE 
		INSERT INTO [#Store] EXEC [prcGetStoresList] @StoreGuid 
	CREATE TABLE [#EndResult]
				(	 
					[Security] [INT],
					[TypeSecurity] [INT],
					[mtGUID] [UNIQUEIDENTIFIER] ,
					[Name] [NVARCHAR] (500) COLLATE ARABIC_CI_AI,
					[mtCompositionName] [NVARCHAR] (500) COLLATE ARABIC_CI_AI,
					[Code] [NVARCHAR] (500) COLLATE ARABIC_CI_AI,
					[MatSecurity] [INT],
					[stSecurity] [INT],
					[Qty] [FLOAT],
					[Qty2] [FLOAT],
					[Qty3] [FLOAT],
					[DefUnit] [INT],
					[DefUnitFact] [FLOAT],
					[Unit2Fact] [FLOAT],
					[Unit3Fact] [FLOAT],
					[DefUnitName] [NVARCHAR] (500) ,
					[ExpireDate]  [DateTime] ,
					[ClassPtr] [NVARCHAR](500)
				)
	IF (@CostGuid <> 0X00) AND  ( @Type = 0)
	BEGIN
		SET @Type = 1
		SET @StartDate = '1/1/1980'
		SET @EndDate = '1/1/9999'
	END
	
	IF( @Type = 0)
		BEGIN
				INSERT INTO [#EndResult]
				SELECT
					0,
					0,
					[bi].[biMatPtr],
					[bi].[mtName],
					[mtCompositionName],
					[bi].[mtCode],
					[bi].[mtSecurity],
					0,--stSecurity
					SUM(ISNULL( ( [bi].[biQty] + [bi].[biBonusQnt])* [bi].[buDirection], 0)),
					SUM([bi].[biCalculatedQty2]),  
					SUM([bi].[biCalculatedQty3]), 
					0,
					0,
					[bi].[mtUnit2Fact],
					[bi].[mtUnit3Fact],
					'',
					Null,
					''
				FROM
					[vwExtended_bi] AS [bi] 
					INNER JOIN [#Mat] AS [mt] ON [bi].[biMatPtr] = [mt].[mtNumber]
					INNER JOIN [#Store] AS [St] ON [bi].[biStorePtr] = [St].[Number]
				WHERE
				    @ShowMatClass = 0
				GROUP BY
					[bi].[biMatPtr],
					[bi].[mtName],
					[mtCompositionName],
					[bi].[mtCode],
					[bi].[mtSecurity],
					[bi].[mtUnit2Fact],
					[bi].[mtUnit3Fact], 
					[bi].[mtUnit2],
					[bi].[mtUnit3],
					[bi].[mtUnity]

			INSERT INTO [#EndResult]
				SELECT
					0,
					0,
					[bi].[biMatPtr],
					[bi].[mtName],
					[mtCompositionName],
					[bi].[mtCode],
					[bi].[mtSecurity],
					0,--stSecurity
					SUM(ISNULL( ( [bi].[biQty] + [bi].[biBonusQnt])* [bi].[buDirection], 0)),
					SUM([bi].[biCalculatedQty2]),  
					SUM([bi].[biCalculatedQty3]), 
					0,
					0,
					[bi].[mtUnit2Fact],
					[bi].[mtUnit3Fact],
					'',
					Null,
					[bi].[biClassPtr]
				FROM
					[vwExtended_bi] AS [bi] 
					INNER JOIN [#Mat] AS [mt] ON [bi].[biMatPtr] = [mt].[mtNumber]
					INNER JOIN [#Store] AS [St] ON [bi].[biStorePtr] = [St].[Number]
				WHERE
					@ShowMatClass = 1
				GROUP BY
					[bi].[biMatPtr],
					[bi].[mtName],
					[mtCompositionName],
					[bi].[mtCode],
					[bi].[mtSecurity],
					[bi].[mtUnit2Fact],
					[bi].[mtUnit3Fact], 
					[bi].[mtUnit2],
					[bi].[mtUnit3],
					[bi].[mtUnity],
					[bi].[biClassPtr]
		END
	ELSE
	IF( @Type = 2) 
	BEGIN
			
		CREATE TABLE [#RESULT](	
					[ID] [INT],  
					[MatPtr] [UNIQUEIDENTIFIER] ,  
					[MatCode] [NVARCHAR] (500) ,  
					[MatName] [NVARCHAR] (500) ,  
					[Price] [FLOAT],  
					[Qty] [FLOAT],  
					[Qty2] [FLOAT],  
					[Qty3] [FLOAT],  
					[ExpireDate] [DateTime] ,  
					[Date] [DateTime] ,  
					[buStore] [UNIQUEIDENTIFIER] ,
					[Remaining] [FLOAT], 
					[Remaining2] [FLOAT],  
					[Remaining3] [FLOAT],  
					[MatUnitName] [NVARCHAR] (500) ,  
					[BillType] [UNIQUEIDENTIFIER] ,  
					[BillNum] [UNIQUEIDENTIFIER] ,  
					[BillNotes] [NVARCHAR] (MAX) ,  
					[Age] [INT],
					[MtClassPtr] [NVARCHAR] (MAX) ) 
		
		INSERT INTO [#RESULT] exec [repMatExpireDate2] @EndDate, 1/*@ShowBonus*/,0, @CurrencyPtr, @CurrencyVal, @StartDate,0,1,0X00,0,@CostGUID
	
		INSERT INTO [#EndResult]
				SELECT
					[bi].[buSecurity],
					[bt].[Sec],
					[bi].[biMatPtr],
					[bi].[mtName],
					[mtCompositionName],
					[bi].[mtCode],
					[bi].[mtSecurity],
					0,--stSecurity
					SUM(ISNULL( ( [bi].[biQty] + [bi].[biBonusQnt])* [bi].[buDirection], 0)),
					SUM([bi].[biCalculatedQty2]),  
					SUM([bi].[biCalculatedQty3]), 
					0,
					0,
					[bi].[mtUnit2Fact],
					[bi].[mtUnit3Fact],
					'',
					'1/1/1980',
					[bi].[biClassPtr]
				FROM
					[vwExtended_bi] AS [bi] 
					INNER JOIN [#Src] AS [bt] ON [bi].[buType] = [bt].[Type]
					INNER JOIN [#Mat] AS [mt] ON [bi].[biMatPtr] = [mt].[mtNumber]
					INNER JOIN [#Store] AS [St] ON [bi].[biStorePtr] = [St].[Number]
				WHERE
					CAST([buDate] AS DATE) BETWEEN @StartDate AND @EndDate
					AND [mtExpireFlag] = 0 AND @ShowMatClass =1
				GROUP BY
					[bi].[buSecurity],
					[bt].[Sec],
					[bi].[biMatPtr],
					[bi].[mtName],
					[mtCompositionName],
					[bi].[mtCode],
					[bi].[mtSecurity],
					[bi].[mtDefUnit],
					[bi].[mtDefUnitFact],
					[bi].[mtUnit2Fact],
					[bi].[mtUnit3Fact], 
					[bi].[mtDefUnitName],
					[bi].[mtUnit2],
					[bi].[mtUnit3],
					[bi].[mtUnity],
					[bi].[biClassPtr]

		INSERT INTO [#EndResult] 
				SELECT
					0, --Security, 
					0, --BillBrowseSec, 
					[MatPtr], 
					[MatName], 
					[mtCompositionName],  
					[MatCode], 
					0, --mtSecurity, 
					0, --storeSecurity
					SUM([Remaining])  , 
					SUM([Qty2]),  
					SUM([Qty3]),
					0, 
					0,
					[mt].[mtUnit2Fact], 
					[mt].[mtUnit3Fact], 
					'',
					[ExpireDate],
					''
				FROM 
					[#Result] AS [Res] INNER JOIN [vwMt] AS [mt] 
					ON [Res].[MatPtr] = [mt].[mtGuid]
				WHERE
					@ShowMatClass =0
				GROUP BY
					[MatPtr], 
					[MatName], 
					[mtCompositionName],  
					[MatCode], 
					[mt].[mtUnit2Fact], 
					[mt].[mtUnit3Fact], 
					[mt].[mtUnit2],
					[mt].[mtUnit3],
					[mt].[mtUnity],
					[ExpireDate]
		
			INSERT INTO [#EndResult]
					SELECT
						[bi].[buSecurity],
						[bt].[Sec],
						[bi].[biMatPtr],
						[bi].[mtName],
						[bi].[mtCompositionName], 
						[bi].[mtCode],
						[bi].[mtSecurity],
						0,--stSecurity
						SUM(ISNULL( ( [bi].[biQty] + [bi].[biBonusQnt])* [bi].[buDirection], 0)),
						SUM([bi].[biCalculatedQty2]),  
						SUM([bi].[biCalculatedQty3]), 
						0,
						0,
						[bi].[mtUnit2Fact],
						[bi].[mtUnit3Fact],
						'',
						'1/1/1980',
						''
					FROM
						[vwExtended_bi] AS [bi] 
						INNER JOIN [#Src] AS [bt] ON [bi].[buType] = [bt].[Type]
						INNER JOIN [#Mat] AS [mt] ON [bi].[biMatPtr] = [mt].[mtNumber]
						INNER JOIN [#Store] AS [St] ON [bi].[biStorePtr] = [St].[Number]
					WHERE
						CAST([buDate] AS DATE) BETWEEN @StartDate AND @EndDate
						AND [mtExpireFlag] = 0 AND @ShowMatClass =0
					GROUP BY
						[bi].[buSecurity],
						[bt].[Sec],
						[bi].[biMatPtr],
						[bi].[mtName],
						[bi].[mtCompositionName], 
						[bi].[mtCode],
						[bi].[mtSecurity],
						[bi].[mtUnit2Fact],
						[bi].[mtUnit3Fact], 
						[bi].[mtUnit2],
						[bi].[mtUnit3],
						[bi].[mtUnity]
	END 
	ELSE
	BEGIN
		INSERT INTO [#CostTbl]			EXEC [prcGetCostsList] 		@CostGUID 
		IF (ISNULL(@CostGUID,0X00)=0X00) 
			INSERT INTO [#CostTbl] VALUES (0X00,0)
		INSERT INTO [#EndResult]
				SELECT
					[bi].[buSecurity],
					[bt].[Sec],
					[bi].[biMatPtr],
					[bi].[mtName],
					[bi].[mtCompositionName], 
					[bi].[mtCode],
					[bi].[mtSecurity],
					0,--stSecurity
					SUM(ISNULL( ( [bi].[biQty] + [bi].[biBonusQnt])* [bi].[buDirection], 0)),
					SUM([bi].[biCalculatedQty2]),  
					SUM([bi].[biCalculatedQty3]), 
					0,
					0,
					[bi].[mtUnit2Fact],
					[bi].[mtUnit3Fact],
					'',
					Null,
					[bi].[biClassPtr]
				FROM
					[vwExtended_bi] AS [bi] 
					INNER JOIN [#Src] AS [bt] ON [bi].[buType] = [bt].[Type]
					INNER JOIN [#Mat] AS [mt] ON [bi].[biMatPtr] = [mt].[mtNumber]
					INNER JOIN [#Store] AS [St] ON [bi].[biStorePtr] = [St].[Number]
					INNER JOIN [#CostTbl] AS [co] ON  [CostGUID] = [bi].[biCostPtr]
				WHERE
					CAST([buDate] AS DATE) BETWEEN @StartDate AND @EndDate
					AND @ShowMatClass = 1
				GROUP BY
					[bi].[buSecurity],
					[bt].[Sec],
					[bi].[biMatPtr],
					[bi].[mtName],
					[bi].[mtCompositionName], 
					[bi].[mtCode],
					[bi].[mtSecurity],
					[bi].[mtUnit2Fact],
					[bi].[mtUnit3Fact], 
					[bi].[mtUnit2],
					[bi].[mtUnit3],
					[bi].[mtUnity],
					[bi].[biClassPtr]

		--without class classification
		INSERT INTO [#EndResult]
				SELECT
					[bi].[buSecurity],
					[bt].[Sec],
					[bi].[biMatPtr],
					[bi].[mtName],
					[bi].[mtCompositionName], 
					[bi].[mtCode],
					[bi].[mtSecurity],
					0,--stSecurity
					SUM(ISNULL( ( [bi].[biQty] + [bi].[biBonusQnt])* [bi].[buDirection], 0)),
					SUM([bi].[biCalculatedQty2]),  
					SUM([bi].[biCalculatedQty3]), 
					0,
					0,
					[bi].[mtUnit2Fact],
					[bi].[mtUnit3Fact],
					'',
					Null,
					''
				FROM
					[vwExtended_bi] AS [bi] 
					INNER JOIN [#Src] AS [bt] ON [bi].[buType] = [bt].[Type]
					INNER JOIN [#Mat] AS [mt] ON [bi].[biMatPtr] = [mt].[mtNumber]
					INNER JOIN [#Store] AS [St] ON [bi].[biStorePtr] = [St].[Number]
					INNER JOIN [#CostTbl] AS [co] ON  [CostGUID] = [bi].[biCostPtr]
				WHERE
					CAST([buDate] AS DATE) BETWEEN @StartDate AND @EndDate
					AND @ShowMatClass = 0
				GROUP BY
					[bi].[buSecurity],
					[bt].[Sec],
					[bi].[biMatPtr],
					[bi].[mtName],
					[bi].[mtCompositionName], 
					[bi].[mtCode],
					[bi].[mtSecurity],
					[bi].[mtUnit2Fact],
					[bi].[mtUnit3Fact], 
					[bi].[mtUnit2],
					[bi].[mtUnit3],
					[bi].[mtUnity]
					
	END
	
	IF @ShowBalancedMat > 0 
		BEGIN
			DELETE [#Mat] WHERE [mtNumber] IN (SELECT [mtGUID] FROM [#EndResult])
			INSERT INTO [#EndResult]([Security] ,[TypeSecurity],[mtGUID],[Name],[mtCompositionName],[Code],[MatSecurity],[stSecurity],[Qty],[Unit2Fact],[Unit3Fact],[ExpireDate],[ClassPtr])
						SELECT
							0,
							0,
							[mtGUID],
							[mtName],
							mtCompositionName,
							[mtCode],
							[mt].[mtSecurity],
							0, --stSec
							null,
							[mtUnit2Fact],
							[mtUnit3Fact],
							Null,
							[bi].ClassPtr
						FROM
							[vwMt] AS [mat] INNER JOIN [#Mat] AS [mt] 
							ON [mat].[mtGuid] = [mt].[mtNumber]
							INNER JOIN [bi000]as [bi] ON [bi].[MatGUID] = [mt].mtNumber
							WHERE [mat].[mtGUID] IN (SELECT [biMatPtr] FROM [vwExtended_Bi] WHERE [mat].[mtGUID] = [biMatPtr] AND biStorePtr = @StoreGUID)
		END

	IF @ShowEmptyMats > 0
		BEGIN
			INSERT INTO [#EndResult]([Security] ,[TypeSecurity],[mtGUID],[Name],[mtCompositionName],[Code],[MatSecurity],[stSecurity],[Qty],[Unit2Fact],[Unit3Fact],[ExpireDate]) 
				SELECT  
					0,
					0,
					[mtGUID],
					[mtName],
					mtCompositionName,
					[mtCode],
					[mt].[mtSecurity],
					0, --stSec
					null,
					[mtUnit2Fact],
					[mtUnit3Fact],
					Null
				FROM  
					[vwMt] AS [mat] 
					INNER JOIN [#Mat] AS [mt] ON [mat].[mtGuid] = [mt].[mtNumber] 
					WHERE NOT EXISTS(SELECT biMatPtr FROM [vwBi] WHERE [mat].[mtGUID] = [biMatPtr] AND biStorePtr = @StoreGUID)
		END

	IF @ShowBalancedMat = 0
		BEGIN
			DELETE #EndResult WHERE ABS([Qty])< @Zero
		END
	
	EXEC [prcCheckSecurity] @result = '#EndResult'

	
	UPDATE E
	SET [DefUnit] = CASE @UseUnit 
							WHEN 3 THEN [mtDefUnit] 
							WHEN 1 THEN CASE WHEN [mtUnit2Fact] = 0 THEN 1 ELSE 2 END  
							WHEN 2 THEN CASE WHEN [mtUnit3Fact] = 0 THEN 1 ELSE 3 END
							WHEN 5 THEN 1
							ELSE 1
					END,
		[DefUnitFact] =  CASE @UseUnit 
							WHEN 3 THEN [mtDefUnitFact] 
							WHEN 1 THEN CASE WHEN [mtUnit2Fact] = 0 THEN 1 ELSE [mtUnit2Fact] END  
							WHEN 2 THEN CASE WHEN [mtUnit3Fact] = 0 THEN 1 ELSE [mtUnit3Fact] END
							WHEN 5 THEN CASE WHEN [mtUnit3Fact] > 0 THEN [mtUnit3Fact]  WHEN [mtUnit3Fact] = 0 AND [mtUnit2Fact] > 0 THEN [mtUnit2Fact] ELSE 1 END
							ELSE 1
						 END ,
		[DefUnitName] =  CASE @UseUnit 
							WHEN 3 THEN [mtDefUnitName]
							WHEN 1 THEN  CASE WHEN [mtUnit2Fact] = 0 THEN [mtUnity] ELSE [mtUnit2] END
							WHEN 2 THEN CASE WHEN [mtUnit2Fact] = 0 THEN [mtUnity] ELSE [mtUnit3] END
							WHEN 5 THEN CASE WHEN [mtUnit3Fact] > 0 THEN [mtUnit3]   WHEN [mtUnit3Fact] = 0 AND [mtUnit2Fact] > 0 THEN [mtUnit2] ELSE [mtUnity] END
							ELSE [mtUnity]
						 End
	FROM 
		#EndResult AS E
		JOIN [vwMt] AS [mat] ON [mat].mtGUID = E.mtGUID

	--DELETE FROM [#EndResult] WHERE Qty <= 0

	IF @UseUnit = 5
	BEGIN
		ALTER TABLE #EndResult ADD Unt1 [FLOAT] NULL, Unt2 [FLOAT] NULL, Unt3 [FLOAT] NULL
		
		UPDATE E
		SET [Unt1] =  (dbo.[fnGetUnitQty]([mtGUID],E.[Qty], 1)),
			[Unt2] =  (dbo.[fnGetUnitQty]([mtGUID],E.[Qty],2)),
			[Unt3] =  (dbo.[fnGetUnitQty]([mtGUID],E.[Qty],3)),
			[DefUnitName] = CASE (@MtFlag & 0x00040000) WHEN 0 THEN MT.[Unity] +CASE MT.[Unit2] WHEN '' THEN '' ELSE ' - ' END+ MT.[Unit2] +CASE MT.[Unit3] WHEN '' THEN '' ELSE ' - ' END+ MT.[Unit3] ELSE MT.[Unity] +CASE MT.[Unit2] WHEN '' THEN '' ELSE ' - '+ MT.[Unit2] +' '+CONVERT(NVARCHAR,MT.Unit2Fact) END +CASE MT.[Unit3] WHEN '' THEN '' ELSE ' - '+ MT.[Unit3] +' '+CONVERT(NVARCHAR,MT.Unit3Fact) END END
		FROM 
			#EndResult AS E
			JOIN mt000 AS MT ON MT.GUID = E.mtGUID
	END
	ELSE
	BEGIN
		UPDATE #EndResult SET qty = qty / defunitfact
	END

	CREATE TABLE [#t_Prices] 
	( 
		[MatGUID] 	[UNIQUEIDENTIFIER], 
		[Price] 	[FLOAT] 
	) 

	INSERT INTO [#t_Prices]
	SELECT
		[v_mt].[mtGUID],
		ISNULL( [v_mt].[mtPrice], 0)AS [APrice]
	FROM
		[dbo].[fnGetMtPricesWithSec]( @PriceType, 0, @UseUnit, @CurrencyPtr, @EndDate) AS [v_mt]
	
	SET @mtStr = '	,[mt].[mtType] 	,[mt].[mtSpec] 	,[mt].[mtOrigin] 	,[mt].[mtPos] 	,[mt].[mtCompany] 	,[mt].[mtColor] 	,[mt].[mtProvenance] 	,[mt].[mtQuality] 	,[mt].[mtModel] ,[mt].[mtVat] 	,[mt].[mtBarcode2] 	,[mt].[mtBarcode3] 	,[mt].[mtDim] ,[tp].[Price] '
	
	SET @mtStr2 = @mtStr	
	
		IF @UseUnit = 0
		BEGIN
			SET @mtStr = @mtStr + ',[mt].[mtBarCode] '
			SET @mtStr2 = @mtStr2 + ',[mt].[mtBarCode] '
		END
		ELSE IF @UseUnit = 1
		BEGIN
			SET @mtStr = @mtStr + ',[mt].[mtBarCode2] AS [mtBarCode] '
			SET @mtStr2 = @mtStr2 + ',[mt].[mtBarCode2]'
		END
		ELSE IF @UseUnit = 2
		BEGIN
			SET @mtStr = @mtStr + ',[mt].[mtBarCode3] AS [mtBarCode] '
			SET @mtStr2 = @mtStr2 + ',[mt].[mtBarCode3]'
		END
		ELSE IF @UseUnit = 3
		BEGIN
			SET @mtStr = @mtStr + ',CASE [DefUnit] WHEN 1 THEN [mt].[mtBarCode] WHEN 2 THEN [mt].[mtBarcode2] ELSE [mt].[mtBarcode3] END AS [mtBarCode]'
			SET @mtStr2 = @mtStr2 + ',CASE [DefUnit] WHEN 1 THEN [mt].[mtBarCode] WHEN 2 THEN [mt].[mtBarcode2] ELSE [mt].[mtBarcode3] END '
		END
		ELSE 
		BEGIN
			SET @mtStr = @mtStr + ',CASE [DefUnit] WHEN 1 THEN [mt].[mtBarCode] WHEN 2 THEN [mt].[mtBarcode2] ELSE [mt].[mtBarcode3] END AS [mtBarCode]'
			SET @mtStr2 = @mtStr2 + ',CASE [DefUnit] WHEN 1 THEN [mt].[mtBarCode] WHEN 2 THEN [mt].[mtBarcode2] ELSE [mt].[mtBarcode3] END '
		END
	
		SET @mtStr = @mtStr + '	,[gr].[Name] AS [grName] ,[gr].[Code] AS [grCode] '
		SET @mtStr2 = @mtStr2 + '	,[gr].[Name] ,[gr].[Code] '
	
	IF @RoundFirstUint > 0
	BEGIN
		SET @Sql2 = ' ROUND('
		SET @Sql3 = ',0)'
	END
	
	SET @Sql = 'SELECT  [e].[mtGUID],[e].[Code], ' + @Sql2 + 'ISNULL(SUM([e].[Qty]),0) ' + @Sql3 + ' AS [Qty],[e].[DefUnitFact],[e].[Unit2Fact],[e].[Unit3Fact],[e].[DefUnitName],'
	
	IF @ShowMatClass=1
		SET @Sql = @Sql + '[e].[ClassPtr],'
	
	IF @Lang = 0
		SET @Sql = @Sql + '[e].[Name],'
	ELSE
		SET @Sql = @Sql + 'CASE [mtLatinName] WHEN ' + '''' + ''' THEN [e].[Name]  ELSE [mtLatinName] END AS [Name],'
	
  IF @Lang = 0
		SET @Sql = @Sql + '[e].[mtCompositionName],'
	ELSE
		SET @Sql = @Sql + 'CASE [mtCompositionLatinName] WHEN ' + '''' + ''' THEN [e].[mtCompositionName]  ELSE [mtCompositionLatinName] END AS [mtCompositionName],'

	IF @UseUnit = 0
			SET @Sql = @Sql + ' 1 AS [DefUnit],'
	ELSE IF @UseUnit = 1
		SET @Sql = @Sql + ' CASE  [e].[Unit2Fact] WHEN 0 THEN  1 ELSE 2 END AS [DefUnit],'
	ELSE IF @UseUnit = 2
		SET @Sql = @Sql +  ' CASE  [e].[Unit3Fact] WHEN 0 THEN  1 ELSE 3 END AS [DefUnit],'
	ELSE
		SET @Sql = @Sql + '[e].[DefUnit],'
	SET @Sql = 	@Sql + '[ExpireDate] AS [ExpireDate]'
	
	IF @ShowUnLinked = 1
		SET @Sql = 	@Sql + ',SUM([Qty2]) AS [Qty2],SUM([Qty3]) AS [Qty3],[mt].[mtUnit2FactFlag],[mt].[mtUnit3FactFlag] '
	
	IF @UseUnit = 5
		SET @Sql = 	@Sql + ',SUM([e].[Unt1]) AS Unt1, SUM([e].[Unt2]) AS Unt2, SUM([e].[Unt3]) AS Unt3'
		SET @Sql = 	@Sql + @mtStr
	
	SET @Sql = 	@Sql + ' FROM  [#EndResult] AS [e]'
	
	SET @Sql = 	@Sql + 'INNER JOIN [vwmt] AS [mt] ON [mt].[mtGUID] = [e].[mtGUID]'
	
	SET @Sql = 	@Sql + 'INNER JOIN [gr000] AS [gr] ON [gr].[GUID] = [mt].[mtGroup]'

	SET @Sql = 	@Sql + 'LEFT JOIN [#t_Prices] AS [tp] ON [tp].[MatGUID] = [e].[mtGUID]'
	
	SET @Sql = 	@Sql + 'GROUP BY '
	SET @Sql = 	@Sql + '[e].[mtGUID], [e].[Name], [e].[Code], [e].[DefUnit], [e].[DefUnitFact], [e].[Unit2Fact], [e].[Unit3Fact], [e].[DefUnitName], [e].[mtCompositionName], [mtCompositionLatinName], '
	IF @ShowMatClass=1
		SET @Sql = @Sql + '[e].[ClassPtr],'
	SET @Sql = 	@Sql + ' [ExpireDate]'
	
	IF @ShowUnLinked = 1
		SET @Sql = 	@Sql + ',[mt].[mtUnit2FactFlag],[mt].[mtUnit3FactFlag] '
	
	IF @Lang > 0
		SET @Sql = 	@Sql + ',[mtLatinName]'
	
	SET @Sql = 	@Sql + @mtStr2

	IF @UseUnit = 5
		SET @Sql = 	@Sql + 'ORDER BY [e].[mtGUID],[e].[DefUnit] DESC '
	ELSE
	BEGIN
		IF @sort = 0
			SET @Sql = 	@Sql + 'ORDER BY [Code]'
		IF @sort = 1
			SET @Sql = 	@Sql + 'ORDER BY [Name]'
		IF @sort = 2
			SET @Sql = 	@Sql + 'ORDER BY [mtType]'
		IF @sort = 3
			SET @Sql = 	@Sql + 'ORDER BY [mtSpec]'
		IF @sort = 4
			SET @Sql = 	@Sql + 'ORDER BY [mtColor]'
		IF @sort = 5
			SET @Sql = 	@Sql + 'ORDER BY [mtOrigin]'
		IF @sort = 6
			SET @Sql = 	@Sql + 'ORDER BY [mtPos]'
		IF @sort = 7
			SET @Sql = 	@Sql + 'ORDER BY [mtProvenance]'
		IF @sort = 8
			SET @Sql = 	@Sql + 'ORDER BY [mtDim]'
		IF @sort = 9
			SET @Sql = 	@Sql + 'ORDER BY [mtCompany]'
		IF @sort = 10
			SET @Sql = 	@Sql + 'ORDER BY [mtBarCode]'
		IF @sort = 11
			SET @Sql = 	@Sql + 'ORDER BY [mtQuality]'
		IF @sort = 12
			SET @Sql = 	@Sql + 'ORDER BY [mtModel]'
	END

	EXECUTE sp_executesql @Sql
	SELECT * FROM [#SecViol]

/*
	prcConnections_Add2 'admin'
	EXECUTE [repStockCompare] '00000000-0000-0000-0000-000000000000', 0, '00000000-0000-0000-0000-000000000000', 0, '1980-01-01', '1980-01-01', 3, '00000000-0000-0000-0000-000000000000', 1, 812122112, 0, 0, 0, '00000000-0000-0000-0000-000000000000', '00000000-0000-0000-0000-000000000000', 257, 1, 0, 'f81398f4-a9f9-4d23-8ea2-e7408078742b', 1.000000, 2
*/

################################################################################
#End