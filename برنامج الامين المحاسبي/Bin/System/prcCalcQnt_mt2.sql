##########################################################
CREATE PROCEDURE prcGetLastPriceNewEquation
	@StartDate 			[DATETIME],
	@EndDate 			[DATETIME],
	@MatGUID 			[UNIQUEIDENTIFIER], -- 0 All Mat or MatNumber
	@GroupGUID 			[UNIQUEIDENTIFIER],
	@StoreGUID 			[UNIQUEIDENTIFIER], -- 0 all stores so don't check store or list of stores
	@CostGUID 			[UNIQUEIDENTIFIER], -- 0 all costs so don't Check cost or list of costs
	@MatType 			[INT], -- 0 Store or 1 Service or -1 ALL
	@CurrencyGUID 		[UNIQUEIDENTIFIER], -- if 0x0 then use buy currencyPtr else use fixed Price
	@SrcTypesguid		[UNIQUEIDENTIFIER],
	@ShowUnLinked 		[INT] = 0,
	@UseUnit 			[INT],
	@CalcLastCost		[INT] = 0,
	@ProcessExtra		[INT] = 0,
	@type				[INT]=0,
	@IsIncludeOpenedLC	[BIT] = 0
AS
	SET NOCOUNT ON
	DECLARE @ReadLastPricePerm INT
	SELECT @ReadLastPricePerm = [dbo].[fnGetReadMatLastPrice]( [dbo].[fnGetCurrentUserGUID]())

	DECLARE  @defCurr UNIQUEIDENTIFIER
	SELECT @defCurr = dbo.fnGetDefaultCurr()

	CREATE TABLE [#Result]
	(
		ID INT IDENTITY(1,1),
		[biMatPtr] 				[UNIQUEIDENTIFIER],
		
	
		[biPrice]				[FLOAT],
		[FixedbiPrice]			[FLOAT],
		[biCurrencyVal]			[FLOAT],
		[biUnitDiscount]		[FLOAT],
		[biUnitExtra]			[FLOAT],
		[Security]				[INT],
		[UserReadPriceSecurity]	[INT],
		[UserSecurity] 			[INT],
		[MtSecurity]			[INT],
		[mtUnitFact]			[FLOAT],
		[biStorePtr]			[UNIQUEIDENTIFIER],
		[FixedbiPriceED]		[FLOAT],
		[budate]				[DATETIME]
	)
	INSERT INTO [#Result]
	(
		[biMatPtr], 				
							
		[biPrice],				
		[FixedbiPrice],			
		[biCurrencyVal],			
		[biUnitDiscount],		
		[biUnitExtra],			
						
		[Security],				
		[UserReadPriceSecurity],	
		[UserSecurity], 			
		[MtSecurity],			
		[mtUnitFact],			
		[biStorePtr],			
		[FixedbiPriceED],
		[budate]
	)
	SELECT
		[r].[biMatPtr],
		
		CASE WHEN [UserReadPriceSecurity] >= [BuSecurity] THEN [r].[biPrice] ELSE 0 END AS [biPrice],
		CASE WHEN [UserReadPriceSecurity] >= [BuSecurity] THEN [r].[FixedbiPrice] ELSE 0 END AS [FixedbiPrice],
		[r].[biCurrencyVal],
		CASE WHEN [UserReadPriceSecurity] >= [BuSecurity] THEN [r].[biUnitDiscount] ELSE 0 END AS [biUnitDiscount],
		CASE WHEN [UserReadPriceSecurity] >= [BuSecurity] THEN [r].[biUnitExtra] ELSE 0 END AS [biUnitExtra],
		[r].[buSecurity],
		[bt].[UserSecurity],
		[bt].[UserReadPriceSecurity],
		[r].[MtSecurity],
		[r].[mtUnitFact],
		[r].[biStorePtr],
		CASE @ReadLastPricePerm  WHEN 1 THEN 0 ELSE CASE WHEN [UserReadPriceSecurity] >= [BuSecurity] THEN ([r].[FixedBiTotal] -[r].[biVAT] + CASE WHEN  @type = 124 AND @IsIncludeOpenedLC = 1 THEN lc.NetVal ELSE r.biLCExtra - r.biLCDisc END)/CASE [r].[biQty] WHEN 0 THEN 1 ELSE [r].[biQty] END ELSE 0 END END,
		[buDate]
	FROM
		[dbo].[fnExtended_Bi_Fixed]( @defCurr) AS [r]
		INNER JOIN [#BillsTypesTbl] AS [bt] ON [r].[buType] = [bt].[TypeGuid]
		INNER JOIN [#MatTbl] AS [mtTbl] ON [r].[biMatPtr] = [mtTbl].[MatGUID]
		LEFT JOIN [LCRelatedExpense000] AS lc ON lc.LCGUID = r.buLCGUID AND @type = 124 AND @IsIncludeOpenedLC = 1 
	WHERE
		((@CostGUID = 0x0) OR ([BiCostPtr] IN( SELECT [CostGUID] FROM [#CostTbl])))
		AND [buDate] BETWEEN @StartDate AND @EndDate
		AND [btAffectLastPrice] > 0
		AND ((@MatType = -1) OR ([mtType] = @MatType))
		AND [buIsPosted] > 0 
	ORDER BY [r].[biMatPtr],[r].[buDate],[r].[buSortFlag],[r].[buNumber],[r].[biNumber]

	EXEC [prcCheckSecurity]


	INSERT INTO [#t_Prices]
	SELECT
		[vwmtGr].[mtGUID],
		ISNULL( [bi5].[LastPrice], 0) AS [APrice]
	FROM
		[vwmtGr] INNER JOIN [#MatTbl] AS [mtTbl] ON [vwmtGr].[mtGUID] = [mtTbl].[MatGUID]
		INNER JOIN
		(
			SELECT
				[bi3].[biMatPtr],
					
				MAX([bi3].[biPrice]) AS [LastPrice]
			FROM
			(
				SELECT
					[biMatPtr],
				CASE @type WHEN 122 THEN	
						CASE WHEN budate = m.LastPriceDate THEN 
							(((CASE @defCurr
										WHEN 0x0 THEN [biPrice] / (case [mtUnitFact] when 0 then 1 else [mtUnitFact] end) / (CASE [biCurrencyVal] WHEN 0 THEN 1 ELSE [biCurrencyVal] END) 
										ELSE (CASE @CalcLastCost WHEN 1 THEN ( [FixedbiPrice] / (case [mtUnitFact] when 0 then 1 else [mtUnitFact] end) + [biUnitExtra] - [biUnitDiscount])
																	ELSE ( CASE @ProcessExtra WHEN 0 THEN [FixedbiPrice] / (case [mtUnitFact] when 0 then 1 else [mtUnitFact] end) 
																							ELSE [FixedbiPriceED] END
								) END)
									END) /m.LastPriceCurVal )*dbo.fnGetCurVal(m.CurrencyGUID,m.LastPriceDate))/dbo.fnGetCurVal(@CurrencyGUID,m.LastPriceDate)
						ELSE 
							(CASE @defCurr WHEN 0x0 THEN [biPrice] / (case [mtUnitFact] when 0 then 1 else [mtUnitFact] end) / (CASE [biCurrencyVal] WHEN 0 THEN 1 ELSE [biCurrencyVal] END) 
								ELSE (CASE @CalcLastCost WHEN 1 THEN ( [FixedbiPrice] / (case [mtUnitFact] when 0 then 1 else [mtUnitFact] end) + [biUnitExtra] - [biUnitDiscount])
															ELSE ( CASE @ProcessExtra WHEN 0 THEN [FixedbiPrice] / (case [mtUnitFact] when 0 then 1 else [mtUnitFact] end) 
																					ELSE [FixedbiPriceED] END
							) END)
								END)/dbo.fnGetCurVal(@CurrencyGUID,budate)
							
						END  
				ELSE 
					CASE WHEN budate = m.LastPriceDate THEN 
							(((CASE @defCurr
								WHEN 0x0 THEN [biPrice] / (case [mtUnitFact] when 0 then 1 else [mtUnitFact] end) / (CASE [biCurrencyVal] WHEN 0 THEN 1 ELSE [biCurrencyVal] END) 
								ELSE (CASE @CalcLastCost WHEN 1 THEN ( [FixedbiPrice] / (case [mtUnitFact] when 0 then 1 else [mtUnitFact] end) + [biUnitExtra] - [biUnitDiscount])
															ELSE ( CASE @ProcessExtra WHEN 0 THEN [FixedbiPrice] / (case [mtUnitFact] when 0 then 1 else [mtUnitFact] end) 
																					ELSE [FixedbiPriceED] END
						) END)
							END) /m.LastPriceCurVal )*dbo.fnGetCurVal(m.CurrencyGUID,@EndDate))/dbo.fnGetCurVal(@CurrencyGUID,@EndDate)
					ELSE
							(CASE @defCurr WHEN 0x0 THEN [biPrice] / (case [mtUnitFact] when 0 then 1 else [mtUnitFact] end) / (CASE [biCurrencyVal] WHEN 0 THEN 1 ELSE [biCurrencyVal] END) 
										ELSE (CASE @CalcLastCost WHEN 1 THEN ( [FixedbiPrice] / (case [mtUnitFact] when 0 then 1 else [mtUnitFact] end) + [biUnitExtra] - [biUnitDiscount])
																	ELSE ( CASE @ProcessExtra WHEN 0 THEN [FixedbiPrice] / (case [mtUnitFact] when 0 then 1 else [mtUnitFact] end) 
																							ELSE [FixedbiPriceED] END
									) END)
										END)/dbo.fnGetCurVal(@CurrencyGUID,@EndDate)
						END
				END AS [biPrice]
			FROM
				[#Result] AS [bi1]
				INNER JOIN mt000 m on m.guid=[biMatPtr]
			WHERE
				(Id IN (SELECT MAX(ID) FROM [#Result] GROUP BY [biMatPtr] )) 
			AND [UserSecurity] >= [bi1].Security
		) AS [bi3]
	GROUP BY
			[bi3].[biMatPtr]
			
	)AS [bi5]
		ON [vwMtGr].[mtGUID] = [bi5].[biMatPtr]
	WHERE
		((@MatType = -1) OR ([mtType] = @MatType))
	
##########################################################
CREATE PROCEDURE prcGetFirstInFirstOutPriseQTY2
	@StartDate [DATETIME], 
	@EndDate [DATETIME], 
	@CurrencyGUID [UNIQUEIDENTIFIER] = 0X00 
AS 
	SET NOCOUNT ON 
	 
	DECLARE @t_Result TABLE(  
			[GUID] [UNIQUEIDENTIFIER],  
			[Qnt] [FLOAT],  
			[Price] [FLOAT])
	DECLARE 
			-- mt table variables declarations: 
			@mtGUID [UNIQUEIDENTIFIER], 
			@mtQnt [FLOAT], 
			@mtQnt2 [FLOAT],  
			@mtPrice [FLOAT],  
			@mtValue [FLOAT],  
			-- bi cursor input variables declarations:  
			@buGUID				[UNIQUEIDENTIFIER], 
			@buDate 			[DATETIME],  
			@biNumber 			[INT],  
			@biMatPtr 			[UNIQUEIDENTIFIER], 
			@biQnt 				[FLOAT],  
			@biUnitPrice 			[FLOAT],  
			@biBaseBillType			[INT], 
			@id				[INT]  
	DECLARE @c_bi CURSOR   
	CREATE TABLE #RESULT 
		( 
			[buGUID]			[UNIQUEIDENTIFIER], 
			[buNumber]			[INT], 
			[buDate] 			[DATETIME], 
			[buDirection] 		[INT], 
			[biNumber] 			[INT], 
			[biMatPtr]			[UNIQUEIDENTIFIER], 
			[biQnt]				[FLOAT], 
			[biUnitPrice] 			[FLOAT], 
			[biBaseBillType]		[INT], 
			[buSortFlag] 			[INT],
			[buCurval]         [FLOAT] 
		) 
	DECLARE  @defCurr UNIQUEIDENTIFIER = (SELECT TOP 1 GUID FROM my000 WHERE CurrencyVal = 1);

	INSERT INTO #RESULT 
	SELECT 
			[buGUID], 
			[buNumber], 
			[buDate], 
			[buDirection], 
			[biNumber], 
			[biMatPtr], 
			[biQty] + [biBonusQnt], 
			CASE WHEN [UserReadPriceSecurity] >= [BuSecurity] THEN ([btAffectCostPrice]*[FixedbiUnitPrice]) - ([btDiscAffectCost]*[FixedbiUnitDiscount]) + ([btExtraAffectCost]*[FixedbiUnitExtra]) ELSE 0 END, -- CASE WHEN UserReadPriceSecurity >= BuSecurity THEN FixedBiPrice / (CASE mtUnitFact WHEN 0 THEN 1 ELSE mtUnitFact END) ELSE 0 END,
	        [btBillType], 
			[buSortFlag] ,
			buCurrencyVal
		FROM 
			(([dbo].[fnExtended_Bi_Fixed](@defCurr) AS [r] 
			INNER JOIN [#BillsTypesTbl] AS [bt] ON [r].[BuType] = [bt].[TypeGUID]) 
			INNER JOIN [#MatTbl] AS [mtTbl] ON [r].[biMatPtr] = [mtTbl].[MatGuid]) 
			--INNER JOIN [#StoreTbl] AS [st] ON [st].[StoreGUID] = [co].[biStorePtr] 
		WHERE 
			[buIsPosted] > 0 AND [buDate] BETWEEN @StartDate AND @EndDate  
			AND [bt].[UserSecurity] >= [r].[buSecurity]  

	CREATE INDEX [RESIND] ON [#RESULT]([biMatPtr],[buNumber],[buDate],[buDirection],[biNumber],[buSortFlag])  
	CREATE TABLE [#IN_RESULT] 
		( 
			[ID]				[INT] IDENTITY(1,1), 
			[buGUID]			[UNIQUEIDENTIFIER], 
			[buNumber]			[INT], 
			[buDate] 			[DATETIME], 
			[biNumber] 			[INT], 
			[biMatPtr]			[UNIQUEIDENTIFIER], 
			[biQnt]				[FLOAT], 
			[biUnitPrice] 		[FLOAT], 
			[biBaseBillType]	[INT], 
			[buSortFlag] 		[INT] ,
			[buCurVal]   [FLOAT]
		)
	INSERT INTO [#IN_RESULT] ([buGUID],[buNumber],[buDate],[biNumber],[biMatPtr],[biQnt],[biUnitPrice],[biBaseBillType],[buSortFlag],[buCurVal])  
		SELECT 
			[buGUID],[buNumber],[buDate],[biNumber],[biMatPtr],[biQnt],[biUnitPrice], 
			[biBaseBillType],[buSortFlag] ,[buCurval]
		FROM [#RESULT] 
		WHERE [buDirection] > 0 
		ORDER BY  
			[biMatPtr], 
			[buDate], 
			[buSortFlag], 
			[buNumber], 
			[biNumber]  
	CREATE CLUSTERED INDEX INRESIND ON [#IN_RESULT]([ID],[biMatPtr]) 
	SET @id = 0 
	SET @c_bi = CURSOR FAST_FORWARD FOR  
		SELECT   
			[biMatPtr],   
			[biQnt] 
		FROM  
			[#Result]  
		WHERE  
			[buDirection] = -1 
		ORDER BY  
			[biMatPtr],   
			[buDate],   
			[buSortFlag],   
			[buNumber], 
			[biNumber] 
	OPEN @c_bi FETCH NEXT FROM @c_bi INTO 
		@biMatPtr,   
		@biQnt 
	SET @mtGUID = @biMatPtr  
	-- reset variables:  
	SET @mtQnt = 0  
	SET @mtPrice = 0  
	WHILE @@FETCH_STATUS = 0  
	BEGIN  
		-- is this a new material ?  
		IF @mtGUID <> @biMatPtr 
		BEGIN  
			-- insert the material record:  
			/* 
			INSERT INTO @t_Result VALUES(  
				@mtGUID,  
				@mtQnt,    
				@mtPrice) 
				*/  
			-- reset mt variables:  
			SET @mtGUID = @biMatPtr  
			SET @mtQnt = 0  
			SET @mtPrice = 0  
		END 
		SET @mtQnt = @biQnt   
		WHILE (@mtQnt > 0) 
		BEGIN  
			SELECT @ID = [ID],@mtQnt2 = [biQnt],@mtPrice = [biUnitPrice] FROM [#IN_RESULT]
			WHERE [biMatPtr] = @mtGUID AND [ID] = (SELECT MIN([ID]) FROM [#IN_RESULT] 
			WHERE [biQnt] >  0 AND [biMatPtr] = @mtGUID) 
			IF (@@ROWCOUNT = 0) 
			BEGIN 
				SET @mtQnt = 0 
				SET @mtPrice = 0 
				BREAK 
			END  
			IF (@mtQnt > @mtQnt2) 
			BEGIN 
				SET @mtQnt = @mtQnt - @mtQnt2 
				UPDATE [#IN_RESULT] SET [biQnt] = 0 WHERE [ID] = @ID   
			END 
			ELSE 
			BEGIN	 
				UPDATE [#IN_RESULT] SET [biQnt] = @mtQnt2 - @mtQnt WHERE [ID] = @ID   
				SET @mtQnt = 0  
			END 
		END 
		FETCH NEXT FROM @c_bi INTO 
			@biMatPtr,   
			@biQnt 
	END 
	/* 
	INSERT INTO @t_Result VALUES(  
		@mtGUID,  
		@mtQnt,    
		@mtPrice)  
		*/ 
	CLOSE @c_bi DEALLOCATE @c_bi 
		--return result Set 
	CREATE TABLE #Qnt_RESULT(
		[MaterialGUID] [UNIQUEIDENTIFIER],  
		[SumQnt] [FLOAT])
  INSERT INTO #Qnt_RESULT([MaterialGUID],[SumQnt])
  SELECT 
	[biMatPtr],
	SUM([biQnt]) 
  FROM 
		[#IN_RESULT] 
  WHERE 
		[biQnt]>0  
  GROUP BY 
		[biMatPtr]
 


	UPDATE R
	SET R.[biUnitPrice] =([biUnitPrice] )/dbo.fnGetCurVal(@CurrencyGUID,buDate)
	from [#IN_RESULT] as R
		
	
	INSERT INTO @t_Result 
	SELECT 
		[biMatPtr], 
		SUM([biQnt]),
		([biUnitPrice] )
	FROM 
		[#IN_RESULT] AS r
		INNER JOIN [#Qnt_RESULT] AS qnt ON r.[biMatPtr] = qnt.[MaterialGUID]
	WHERE 
		[biQnt] > 0  
	GROUP BY 
			[biMatPtr]
			,[biUnitPrice]
		

		
	INSERT INTO [#t_PricesQnt] 
 		SELECT 
			ISNULL( [r].[GUID],  [mtTbl].[MatGuid]),  
			ISNULL( [r].[Price], 0) ,
			[Qnt]
		FROM  
			@t_Result AS [r]  
			INNER JOIN [#MatTbl] AS [mtTbl] ON [r].[GUID] = [mtTbl].[MatGuid] 
##########################################################
CREATE PROCEDURE prcCalcQnt_mt2
	@StartDate 			[DATETIME],
	@EndDate 			[DATETIME], 
	@MatGUID 			[UNIQUEIDENTIFIER], 
	@GroupGUID 			[UNIQUEIDENTIFIER], 
	@StoreGUID 			[UNIQUEIDENTIFIER], 
	@CostGUID 			[UNIQUEIDENTIFIER], 
	@MatType 			[INT], 
	@DetailsStores 		[INT], 
	@ShowEmpty 			[INT], 
	@SrcTypesGUID 		[UNIQUEIDENTIFIER], 
	@SortType 			[INT] = 0, 
	@ShowUnLinked 		[INT] = 0 ,
    @Level              [INT] = 0,
    @PriceType 			[INT],
	@PricePolicy 		[INT],
	@CurrencyGUID 		[UNIQUEIDENTIFIER],
	@CurrencyVal 		[FLOAT],
	@ShowGroups 		[INT] = 0,
	@ShowMtFldsFlag		[BIGINT] = 0,
	@ShowPrice			[INT] = 1,
	@ShowEmptySt		[BIT] = 0,
	@UseUnit			[INT] = 1,
	@MatCondGuid			[UNIQUEIDENTIFIER] = 0x00,
	@GrpLevel			[INT] = 0,
	@ShowBalancedMt		[BIT] = 1,
	@VeiwCFlds 	NVARCHAR (max) = '', --check veiwing of Custom Fields
	@StoreConditionGUID UNIQUEIDENTIFIER = 0x0,
	@SelectAllReportSources [BIT] = 0
AS 
	SET NOCOUNT ON 
	
	IF @SelectAllReportSources <> 0 SET @SrcTypesGUID = 0x0
	-- Dont Show Assets Mat
	IF @MatType = 256
		SET @MatType = -1
	IF @MatType = 257
		SET @MatType = 0
	IF @MatType >= 258
		SET @MatType = 1
	-- Creating temporary tables 
	CREATE TABLE [#SecViol]( [Type] [INT], [Cnt] [INTEGER]) 
	CREATE TABLE [#MatTbl]( [MatGUID] [UNIQUEIDENTIFIER], [mtSecurity] [INT]) 
	CREATE TABLE [#StoreTbl](	[StoreGUID] [UNIQUEIDENTIFIER], [Security] [INT]) 
	CREATE TABLE [#BillsTypesTbl]( [TypeGuid] [UNIQUEIDENTIFIER], [UserSecurity] [INTEGER], [UserReadPriceSecurity] [INTEGER])	 
	CREATE TABLE [#CostTbl]( [CostGUID] [UNIQUEIDENTIFIER], [Security] [INT]) 
	CREATE TABLE [#GR] ([GUID] [UNIQUEIDENTIFIER])
	CREATE TABLE [#StoreTbl2]([Guid] [UNIQUEIDENTIFIER], [stSecurity] INT, [Code] NVARCHAR(256),
				[Name] NVARCHAR(256), [LatinName] NVARCHAR(256))
	--Filling temporary tables 
	INSERT INTO [#MatTbl]		EXEC [prcGetMatsList] 		@MatGUID, @GroupGUID, @MatType,@MatCondGuid
	INSERT INTO [#StoreTbl]		EXEC [prcGetStoresList] 	@StoreGUID, @StoreConditionGUID 
	INSERT INTO [#BillsTypesTbl]	EXEC [prcGetBillsTypesList] @SrcTypesGUID 
	INSERT INTO [#CostTbl]		EXEC [prcGetCostsList] 		@CostGUID 
	CREATE CLUSTERED INDEX [hrnvInd] ON [#MatTbl]([MatGUID])
	CREATE CLUSTERED INDEX [hrnvInd] ON [#StoreTbl]([StoreGUID])
	IF [dbo].[fnGetUserMaterialSec_Balance]([dbo].[fnGetCurrentUserGuid]()) > 0
		update [#billsTypesTbl] set [userSecurity] = [dbo].[fnGetMaxSecurityLevel]()
	DECLARE @Admin [INT],@UserGuid [UNIQUEIDENTIFIER],@cnt [INT]
	SET @UserGuid = [dbo].[fnGetCurrentUserGUID]()
	SET @Admin = [dbo].[fnIsAdmin](ISNULL(@userGUID,0x00) )
	
	IF @Admin = 0
	BEGIN
		INSERT INTO [#GR] SELECT [Guid] FROM [fnGetGroupsList](@GroupGUID)
		DELETE [r] FROM [#GR] AS [r] INNER JOIN fnGroup_HSecList() AS [f] ON [r].[gUID] = [f].[GUID] where [f].[Security] > [dbo].[fnGetUserGroupSec_Browse](@UserGuid)
		DELETE [m] FROM [#MatTbl] AS [m]
		INNER JOIN [mt000] AS [mt] ON [MatGUID] = [mt].[Guid] 
		WHERE [mtSecurity] > [dbo].[fnGetUserMaterialSec_Browse](@UserGuid) 
		OR [Groupguid] NOT IN (SELECT [Guid] FRoM [#Gr])
		SET @cnt = @@ROWCOUNT
		IF @cnt > 0
			INSERT INTO [#SecViol] values(7,@cnt)
		
	END
	CREATE TABLE [#MainResult] (
	
		[MtNumber]		[UNIQUEIDENTIFIER],
		[Qnt]			[FLOAT] DEFAULT 0,
		[APrice]		[FLOAT] DEFAULT 0,
		[mtUnity]		[NVARCHAR](255) COLLATE ARABIC_CI_AI,
		[mtUnit2]		[NVARCHAR](255) COLLATE ARABIC_CI_AI,
		[mtUnit3]		[NVARCHAR](255) COLLATE ARABIC_CI_AI,
		[mtDefUnitFact]	[FLOAT],
		[mtName]		[NVARCHAR](255) COLLATE ARABIC_CI_AI,
		[mtCode]		[NVARCHAR](255) COLLATE ARABIC_CI_AI,
		[mtLatinName]	[NVARCHAR](255) COLLATE ARABIC_CI_AI,
		[mtUnit2Fact]	[FLOAT],
		[mtUnit3Fact]	[FLOAT],
		[mtBarCode]		[NVARCHAR](255) COLLATE ARABIC_CI_AI,
		[mtSpec]		[NVARCHAR](1000) COLLATE ARABIC_CI_AI,
		[mtDim]			[NVARCHAR](255) COLLATE ARABIC_CI_AI,
		[mtOrigin]		[NVARCHAR](255) COLLATE ARABIC_CI_AI,
		[mtPos]			[NVARCHAR](255) COLLATE ARABIC_CI_AI,
		[mtCompany]		[NVARCHAR](255) COLLATE ARABIC_CI_AI,
		[mtColor]		[NVARCHAR](255) COLLATE ARABIC_CI_AI,
		[mtProvenance]	[NVARCHAR](255) COLLATE ARABIC_CI_AI,
		[mtQuality]		[NVARCHAR](255) COLLATE ARABIC_CI_AI,
		[mtModel]		[NVARCHAR](255) COLLATE ARABIC_CI_AI,
		[mtBarCode2]	[NVARCHAR](255) COLLATE ARABIC_CI_AI,
		[mtBarCode3]	[NVARCHAR](255) COLLATE ARABIC_CI_AI,
		[mtVAT]			[FLOAT],
		[mtType]		[INT],
		[mtDefUnitName]	[NVARCHAR](255) COLLATE ARABIC_CI_AI,
		[MtGroup]		[UNIQUEIDENTIFIER],
		[RecType] 		[NVARCHAR](1) COLLATE ARABIC_CI_AI DEFAULT 'm' NOT NULL,
		[Level]			[INT] 
		
	)
	CREATE TABLE [#t_Prices]
	(
		[mtNumber] 	[UNIQUEIDENTIFIER],
		[APrice] 	[FLOAT]
	)
	CREATE TABLE [#t_PricesQnt]
	(
		[mtNumber] 	[UNIQUEIDENTIFIER],
		[APrice] 	[FLOAT],
		[Qnt] [FLOAT]
	)
	DECLARE  @defCurr UNIQUEIDENTIFIER = (SELECT TOP 1 GUID FROM my000 WHERE CurrencyVal = 1);
	-- Get  Prices
	IF (@ShowPrice = 1)
	BEGIN
		IF @PriceType = 2 AND (@PricePolicy = 122 or @PricePolicy=126) -- LastPrice
		BEGIN
			EXEC [prcGetLastPriceNewEquation] @StartDate , @EndDate , @MatGUID, @GroupGUID, @StoreGUID, @CostGUID, -1,	@CurrencyGUID, @SrcTypesguid, 0, 0, @type = @PricePolicy	
		END
		ELSE IF @PriceType = 2 AND @PricePolicy = 120 -- MaxPrice
		BEGIN
			EXEC [prcGetMaxPrice] @StartDate , @EndDate , @MatGUID, @GroupGUID, @StoreGUID, @CostGUID, -1,	@defCurr, 1, @SrcTypesguid, 0, 0
			UPDATE #t_Prices  
				SET APrice =(APrice/dbo.fnGetCurVal(@CurrencyGUID,@EndDate))
		END
		ELSE IF @PriceType = 2 AND @PricePolicy = 121  -- COST And AvgPrice NO STORE DETAILS
		BEGIN
			EXEC [prcGetAvgPrice]	@StartDate,	@EndDate, @MatGUID, @GroupGUID, @StoreGUID, @CostGUID, -1, @defCurr, 1, @SrcTypesguid,	0, 0
			UPDATE #t_Prices  
				SET APrice =(APrice/dbo.fnGetCurVal(@CurrencyGUID,@EndDate))
		END
		ELSE IF @PriceType = 2 AND @PricePolicy = 124 -- LastPrice with extra and discount
		BEGIN
			EXEC  [prcGetLastPriceNewEquation] @StartDate , @EndDate , @MatGUID, @GroupGUID, @StoreGUID, @CostGUID, -1,	@CurrencyGUID, @SrcTypesguid, @ShowUnLinked, 0, 0 /*@CalcLastCost*/,	1 /*@ProcessExtra*/			
		END	
		ELSE IF @PriceType = 2 AND @PricePolicy = 125
		BEGIN
				EXEC [prcGetFirstInFirstOutPriseQTY2] @StartDate , @EndDate,@CurrencyGUID
				INSERT INTO #t_Prices
				SELECT mtNumber,APrice FROM [#t_PricesQnt]
		END
		ELSE IF @PriceType = -1
			INSERT INTO [#t_Prices] SELECT [MatGUID], 0 FROM [#MatTbl]
		ELSE IF @PriceType = 0x8000 
		BEGIN
			INSERT INTO #t_Prices 
			SELECT 
				MatGuid, 
				[dbo].[fnGetOutbalanceAveragePrice](MatGuid, @EndDate)/dbo.fnGetCurVal(@CurrencyGUID,@EndDate)
			FROM  
				#MatTbl mt 
				JOIN mt000 mat ON mt.MatGuid = mat.[Guid] 
		END
		ELSE
		BEGIN
			EXEC [prcGetMtPrice] @MatGUID,	@GroupGUID, -1, @CurrencyGUID, 1, @SrcTypesguid, @PriceType, @PricePolicy, @ShowUnLinked, @UseUnit,@EndDate
			
		END
	END

--Get Qtys 
	CREATE TABLE [#t_Qtys]
	( 
		[mtNumber] 	[UNIQUEIDENTIFIER], 
		[Qnt] 		[FLOAT], 
		[Qnt2] 		[FLOAT], 
		[Qnt3] 		[FLOAT], 
		[StorePtr]	[UNIQUEIDENTIFIER] 
	) 
	 
	
	EXEC [prcGetQnt] @StartDate, @EndDate, @MatGUID, @GroupGUID, @StoreGUID, @CostGUID, @MatType, @DetailsStores, @SrcTypesGUID, @ShowUnLinked 
	
	CREATE TABLE [#t_QtysWithEmpty] 
	( 
		[mtNumber] 	[UNIQUEIDENTIFIER], 
		[Qnt] 		[FLOAT], 
		[Qnt2] 		[FLOAT], 
		[Qnt3] 		[FLOAT], 
		[StorePtr]	[UNIQUEIDENTIFIER] 
	) 
	CREATE TABLE [#t_QtysWithEmpty2]([mtNumber] [UNIQUEIDENTIFIER], Qnt FLOAT)
	CREATE TABLE [#Grp]([Guid] [UNIQUEIDENTIFIER], [Level] INT, [Code] NVARCHAR(256),
						 [Name] NVARCHAR(256), [LatinName] NVARCHAR(256), [ParentGuid] [UNIQUEIDENTIFIER])
	CREATE TABLE [#MainResult2]([MtNumber] [UNIQUEIDENTIFIER], [Qnt] FLOAT, [mtName] NVARCHAR(256),
				[mtCode] NVARCHAR(256), [mtLatinName] NVARCHAR(256), [MtGroup] [UNIQUEIDENTIFIER],
				[RecType] NVARCHAR(1), [Level] INT)
INSERT INTO [#t_QtysWithEmpty] SELECT * FROM [#t_Qtys] WHERE @ShowBalancedMt = 1 OR ABS([Qnt])> [dbo].[fnGetZeroValueQTY]()
	IF @ShowEmpty = 1 
		INSERT INTO [#t_QtysWithEmpty] 
			SELECT 
				[mt].[MatGUID], 
				0,0,0, 
				 0x0
			FROM 
				[#MatTbl]  AS [mt] 
			WHERE mt.MatGUID not in (select biMatPtr from vwBuBi)  
	INSERT INTO [#t_QtysWithEmpty2] SELECT [mtNumber] , SUM([Qnt]) AS Qnt FROM [#t_QtysWithEmpty] GROUP BY [mtNumber]
	INSERT INTO [#MainResult] 
		SELECT 
			[q].[mtNumber],
			[q].[Qnt],
			ISNULL([p].[APrice],0),[Unity],[Unit2],[Unit3],
			CASE [DefUnit] WHEN 2 THEN [Unit2Fact] WHEN 3 THEN [Unit3Fact] ELSE 1 END,
			[Name],[Code],[LatinName],[Unit2Fact],[Unit3Fact],[BarCode],[Spec],[Dim],
			[Origin],[Pos],	[Company],[Color],[Provenance],[Quality],[Model],[BarCode2],[BarCode3],[VAT],
			[Type],CASE [DefUnit] WHEN 2 THEN [Unit2] WHEN 3 THEN [Unit3] ELSE [Unity] END,
			[GroupGuid],'m',-1
		FROM ([#t_QtysWithEmpty2] AS [q] INNER JOIN [mt000] AS [mt] ON [mt].[Guid] = [q].[mtNumber])
		LEFT JOIN [#t_Prices] AS [p] ON [p].[mtNumber] = [mt].[Guid]
		
	  IF @PriceType = 2 AND @PricePolicy = 125
	  BEGIN
		update  m
			SET m.Qnt=t.Qnt
			FROM [#MainResult] m inner join [#t_PricesQnt] t on m.APrice= t.APrice and m.MtNumber= t.mtNumber 
	  END
	IF @ShowGroups <> 0
	BEGIN
		INSERT INTO [#Grp] SELECT [f].[Guid],[Level],[Code],[Name],[LatinName],[ParentGuid] 
		FROM [dbo].[fnGetGroupsListByLevel](@GroupGUID,0) AS [f] INNER JOIN [gr000] AS [gr] ON [gr].[Guid] = [f].[Guid]
	
		INSERT INTO  [#MainResult] ([MtNumber],[Qnt],[mtName],[mtCode],[mtLatinName],[MtGroup],[RecType],[Level])
			SELECT [GUID],SUM([Qnt]),[Name],[Code],[LatinName],[gr].[ParentGuid] ,'g',[gr].[Level]
			FROM [#Grp] AS [gr] INNER JOIN [#MainResult] AS [r] ON [gr].[Guid] = [r].[MtGroup]
			GROUP BY [GUID],[Name],[Code],[LatinName],[gr].[ParentGuid] ,[gr].[Level]
		DECLARE @MaxLevel [INT] 
		SELECT @MaxLevel = MAX([Level]) FROM [#MainResult]
		WHILE (@MaxLevel > 1)
		BEGIN
			INSERT INTO  [#MainResult] ([MtNumber],[Qnt],[mtName],[mtCode],[mtLatinName],[MtGroup],[RecType],[Level])
				SELECT [GUID],SUM([Qnt]),[Name],[Code],[LatinName],[gr].[ParentGuid] ,'g',[gr].[Level]
				FROM [#Grp] AS [gr] INNER JOIN [#MainResult] AS [r] ON [gr].[Guid] = [r].[MtGroup]
				WHERE [r].[Level] = @MaxLevel
				GROUP BY [GUID],[Name],[Code],[LatinName],[gr].[ParentGuid] ,[gr].[Level]
			
			SET @MaxLevel = @MaxLevel - 1
		END
		IF (@GrpLevel > 0)
		BEGIN
			UPDATE [m] SET [Level] = gr.[Level]   FROM [#MainResult] [m] INNER JOIN [#Grp] AS [gr] ON [gr].[Guid] = [m].[MtGroup] WHERE [m].[RecType] = 'm'
			SET @Cnt = 1
			WHILE 	@Cnt > 0
			BEGIN
				UPDATE [m] SET  [MtGroup] = [gr].[ParentGuid] ,[Level] = [m].[Level] - 1   FROM [#MainResult] [m] INNER JOIN [#Grp] AS [gr] ON [gr].[Guid] = [m].[MtGroup] WHERE [m].[RecType] = 'm' AND [m].[Level] > @GrpLevel 
				SET @Cnt = @@ROWCOUNT
			END
			DELETE [#MainResult]  WHERE [Level] > @GrpLevel 
		END
		INSERT INTO [#MainResult2] SELECT [MtNumber],SUM([Qnt]) AS [Qnt],[mtName],[mtCode],[mtLatinName],[MtGroup],[RecType],[Level] FROM [#MainResult] WHERE [RecType] = 'g'
		GROUP BY [MtNumber],[mtName],[mtCode],[mtLatinName],[MtGroup],[RecType],[Level]
		DELETE [#MainResult] WHERE [RecType] = 'g'
		INSERT INTO  [#MainResult] ([MtNumber],[Qnt],[mtName],[mtCode],[mtLatinName],[MtGroup],[RecType],[Level])
		SELECT [MtNumber],[Qnt],[mtName],[mtCode],[mtLatinName],[MtGroup],[RecType],[Level] FROM  [#MainResult2]
		
	END
	------Return Result Set 
    IF (@Level > 0)
    BEGIN
	        DECLARE @t_QtysWithEmpty1 TABLE( 
				[mtNumber] 	[UNIQUEIDENTIFIER], 
				[Qnt] 		[FLOAT], 
				[Qnt2] 		[FLOAT], 
				[Qnt3] 		[FLOAT], 
				[StorePtr]	[UNIQUEIDENTIFIER] 
			) 
	    DECLARE @c CURSOR 
	    SET @c= CURSOR FAST_FORWARD FOR
				SELECT [GUID], [LEVEL] FROM [fnGetStoresListByLevel](@StoreGUID,@Level)
	    OPEN @c 
	    DECLARE @Guid [UNIQUEIDENTIFIER],@Level1 [INT]
	    FETCH  FROM @c INTO @Guid,@Level1
	    WHILE @@FETCH_STATUS = 0
	    BEGIN
			INSERT INTO @t_QtysWithEmpty1 
				SELECT [mtNumber], SUM([Qnt]), SUM([Qnt2]), SUM([Qnt3]), @Guid
				FROM [#t_QtysWithEmpty]  INNER JOIN [fnGetStoresList](@Guid) ON [GUID] = [StorePtr]
				GROUP BY [mtNumber]
	    
			FETCH  FROM @c INTO @Guid,@Level1
        END
		CLOSE @c
		DEALLOCATE @c
        DELETE FROM [#t_QtysWithEmpty]  
        INSERT INTO [#t_QtysWithEmpty] SELECT * FROM @t_QtysWithEmpty1
    END
    CREATE TABLE [#Store]
		(
			[Id]			[INT] IDENTITY(1,1),
			[GUID]			[UNIQUEIDENTIFIER],
			[Code]			[NVARCHAR](255) COLLATE ARABIC_CI_AI,
			[Name]			[NVARCHAR](255) COLLATE ARABIC_CI_AI,
			[LatinName]		[NVARCHAR](255) COLLATE ARABIC_CI_AI,
			[Level]			[INT]
		)
	INSERT INTO [#StoreTbl2] SELECT [s].[StoreGUID] AS [Guid], [s].[Security] AS [stSecurity],[st].[Code],[st].[Name],[st].[LatinName] 
	FROM [#StoreTbl] AS [s] INNER JOIN [st000] AS [st] ON [st].[Guid] = [s].[StoreGUID]
	
	EXEC [prcCheckSecurity] @Result = '#StoreTbl2'
	IF (@Level > 0)
	INSERT INTO [#Store]([GUID],[Code],[Name],	[LatinName],[Level])
    SELECT 
			[fn].[GUID], 
			[st].[Code],		
			[st].[Name],
			[st].[LatinName],
			[fn].[Level]
		FROM 
			[fnGetStoresListByLevel](@StoreGUID, @Level) AS [fn] INNER JOIN [#StoreTbl2] AS [st]
			ON [fn].[GUID] = [st].[GUID]
			--INNER JOIN [fnGetStoresListTree](@StoreGUID,0) [fnT] ON [fnT].[GUID] = [fn].[GUID]
			INNER JOIN [fnGetStoresList](@StoreGUID) [fnT] ON [fnT].[GUID] = [fn].[GUID] 
			WHERE [fn].[Level] <= @Level 
			--ORDER BY [Path] 
	ELSE
		INSERT INTO [#Store]([GUID],[Code],[Name],[LatinName],[Level])
		SELECT 
				[st].[GUID], 
				[st].[Code],		
				[st].[Name],
				[st].[LatinName],
				-1
			FROM [#StoreTbl2] AS [st]
		ORDER BY [st].[Code] 
	DECLARE @Sql [NVARCHAR](max) 		
    SET @Sql = 'SELECT [GUID],[Code],[Name],[LatinName],[Level] FROM [#Store]'
    IF @ShowEmptySt = 0
		SET @Sql = @Sql + 'INNER JOIN (SELECT DISTINCT [StorePtr] FROM [#t_QtysWithEmpty]) AS [S]  ON [StorePtr] = [GUID]'
   SET @Sql = @Sql + 'ORDER BY [Code]'
    EXEC (@Sql)
    
    SET @Sql = 'DECLARE @UseUnit AS [INT] SET  @UseUnit = ' + Convert(nvarchar(1),@UseUnit)
	SET @Sql = @Sql + ' SELECT '
    SET @Sql = @Sql + [dbo].[fnGetMatFldsStr]( '', @ShowMtFldsFlag)
	IF @ShowMtFldsFlag & 0x02000000 > 0 
		SET @Sql = @Sql + ' [mtVAT], '
    SET @Sql = @Sql +  '[MtNumber],[Qnt],[APrice] * CASE @UseUnit WHEN 1 THEN (CASE [mtUnit2Fact] WHEN 0 THEN 1 ELSE ISNULL([mtUnit2Fact], 0) END) WHEN 2 THEN (CASE [mtUnit3Fact] WHEN 0 THEN 1 ELSE ISNULL([mtUnit3Fact], 0) END) WHEN 3 THEN ISNULL([mtDefUnitFact], 0) ELSE 1 END AS [APrice],CASE [MtGroup] WHEN 0x0 THEN newid() ELSE ISNULL([MtGroup], 0x0) END AS MtGroup,[RecType],ISNULL([mtUnit2Fact], 0) [mtUnit2Fact], ISNULL([mtUnit3Fact], 0) [mtUnit3Fact], ISNULL([mtDefUnitFact], 0) [mtDefUnitFact]'
	IF @ShowMtFldsFlag & 0x00000020 > 0
		 SET @Sql = @Sql + ',ISNULL([mtUnity], '''') [mtUnity],ISNULL([mtUnit2], '''') [mtUnit2],ISNULL([mtUnit3], '''') [mtUnit3],ISNULL([mtDefUnitName], '''') [mtDefUnitName]'
	IF @ShowMtFldsFlag & 0x00040000 > 0
		 SET @Sql = @Sql + ',[gr].[Name] AS [grName],[gr].[LatinName] AS [grLatinName],[gr].[Code] AS [GrCode]'
	IF @ShowMtFldsFlag & 0x00000001 > 0
		SET @Sql = @Sql + ',[mtCode]'
	IF @ShowMtFldsFlag & 0x00000002 > 0
		SET @Sql = @Sql + ', CASE [dbo].fnConnections_GetLanguage() WHEN 0 THEN [mtName] ELSE CASE [mtLatinName] WHEN '''' THEN [mtName] ELSE [mtLatinName] END END AS mtName'
	--IF @ShowMtFldsFlag & 0x00000004 > 0
	--	SET @Sql = @Sql + ',[mtLatinName]'
	IF @ShowMtFldsFlag & 0x02000000 > 0 
		SET @Sql = @Sql + ',[mtVAT]'
	IF @UseUnit = 0 
		SET @Sql = @Sql + ',1 AS [mtUnitFact]'
	IF @UseUnit = 1 
		SET @Sql = @Sql + ',CASE [mtUnit2Fact] WHEN 0 THEN 1 ELSE ISNULL([mtUnit2Fact], 0) END AS [mtUnitFact]'
	IF @UseUnit = 2 
		SET @Sql = @Sql + ',CASE [mtUnit3Fact] WHEN 0 THEN 1 ELSE ISNULL([mtUnit3Fact], 0) END AS [mtUnitFact]'
	IF @UseUnit = 3 
		SET @Sql = @Sql + ',ISNULL([mtDefUnitFact], 0) AS [mtUnitFact]'
	SET @Sql = @Sql + ', 1 AS [IsEmpty]'
	-------------------------------------------------------------------------------------------------------
	-- Checked if there are Custom Fields to View  	
	-------------------------------------------------------------------------------------------------------
	IF @VeiwCFlds <> ''	 
		SET @Sql = @Sql + @VeiwCFlds  
	------------------------------------------------------------------------------------------------------ 
	SET @Sql = @Sql + ' FROM [#MainResult] AS [r] '
	IF @ShowMtFldsFlag & 0x00040000 > 0
		SET @Sql = @Sql + ' LEFT JOIN [gr000] AS [gr] ON [gr].[Guid] = [MtGroup] '
	-------------------------------------------------------------------------------------------------------
	-- Custom Fields to View  	
	--------------------------------------------------------------------------------------------------------
	--IF @VeiwCFlds <> ''
	--BEGIN
	--	Declare @CF_Table NVARCHAR(255) --Mapped Table for Custom Fields
	--	SET @CF_Table = (SELECT CFGroup_Table FROM CFMapping000 WHERE Orginal_Table = 'mt000')  -- Mapping Table	
	--	SET @Sql = @Sql + ' LEFT JOIN ' + @CF_Table + ' ON [r].[MtNumber] = ' + @CF_Table + '.Orginal_Guid ' 	
	--END
	-------------------------------------------------------------------------------------------------------  
	SET @Sql = @Sql + ' WHERE mtType != 2 OR mtType IS NULL ORDER BY [RecType] DESC'
	IF @ShowGroups <> 0
		SET @Sql =  @Sql + '  ,[r].[Level] DESC'
	IF @SortType = 2 
		SET @Sql = @Sql + ' ,[mtName]' 
	ELSE IF @SortType = 1 
		SET @Sql = @Sql + ' ,[mtCode]' 
	ELSE IF  @SortType = 4 -- By Mat Latin Name 
		SET @Sql = @Sql + ' ,[mtLatinName]' 
	ELSE IF  @SortType = 5 -- By Mat Type 
		SET @Sql = @Sql + ' ,[mtType]'
	ELSE IF  @SortType = 6 -- By Mat Specification  
		SET @Sql = @Sql + ' ,[mtSpec]'
	ELSE IF  @SortType = 7 -- By Mat Color 
		SET @Sql = @Sql + ' ,[mtColor]'
	ELSE IF  @SortType = 8 -- By Mat Orign
		SET @Sql = @Sql + ' ,[mtOrigin]'
	ELSE IF  @SortType = 9 -- By Mat Magerment
		SET @Sql = @Sql + ' ,[mtDim]'
	ELSE IF @SortType = 10-- By Mat COMPANY
		SET @Sql = @Sql + ' ,[mtCompany]'
	ELSE IF @SortType = 11-- By Mat COMPANY
		SET @Sql = @Sql + ' ,[mtPos]'
	ELSE  -- By Mat BARCOD
		SET @Sql = @Sql + ' ,[mtBarCode]'
	EXEC (@Sql)
	SELECT mtNumber, Qnt, Qnt2, Qnt3, StorePtr FROM [#t_QtysWithEmpty]  WHERE StorePtr <> 0x0
	SELECT * FROM [#SecViol]
################################################################
#END