###########################################################
CREATE PROCEDURE prcCallPricesProcs2
	@StartDate 				[DATETIME], 
	@EndDate 				[DATETIME], 
	@MatGUID 				[UNIQUEIDENTIFIER], -- 0 All Mat or MatNumber 
	@GroupGUID 				[UNIQUEIDENTIFIER], 
	@StoreGUID 				[UNIQUEIDENTIFIER], -- 0 all stores so don't check store or list of stores 
	@CostGUID 				[UNIQUEIDENTIFIER], -- 0 all costs so don't Check cost or list of costs 
	@MatType 				[INT], -- 0 Store or 1 Service or -1 ALL 
	@CurrencyGUID 			[UNIQUEIDENTIFIER], 
	@CurrencyVal 			[FLOAT], 
	@DetailsStores 			[INT], -- 1 show details 0 no details 
	@ShowEmpty 				[INT], --1 Show Empty 0 don't Show Empty 
	@PriceType 				[INT], 
	@PricePolicy 			[INT],
	@RateTyp				[INT], -- 0 Current  -- 1 Historical
	@ShowUnLinked 			[INT] = 0, 
	@ShowGroups 			[INT] = 0, -- if 1 add 3 new  columns for groups 
	@UseUnit 				[INT], 
	@StLevel				[INT] = 0, 
	@DetCostPrice			[INT] = 0, 
	@Lang					[INT] =0, 
	@ClassDtails			[BIT] = 0, 
	@ShowPrice				[BIT] = 1, 
	@MatCondGuid			[UNIQUEIDENTIFIER] = 0x00, 
	@ShowBalancedMat		[BIT] = 1, 
	@Class					NVARCHAR(255) = '',
	@ShowSerialNumber		[BIT] = 0,
	@GroupByExpireDate		[BIT] = 0,
	@MatWithoutExpireDate	[BIT] = 0,
	@MatWithExpireDate		[BIT] = 0,
	@ShowMatExpireDate		[BIT] = 0,
	@ShowPeriodOfExpireDate	[BIT] = 0,
	@FromExpireDate			[INT] = 0,
	@ToExpireDate			[INT] = 0,
	@GroupLevel				[INT] = 0,
	@ShowDetailsUnits		[BIT] = 0,
	@IsIncludeOpenedLC		[BIT] = 0
AS  
	SET NOCOUNT ON  
	DECLARE @Zero FLOAT 
	SET @Zero = dbo.fnGetZeroValueQTY() 
	-- Creating temporary tables  
	DECLARE @SrcTypesguid [UNIQUEIDENTIFIER]
	SET @SrcTypesguid = 0x0
	
	DECLARE @cmpUnmctch	BIT
	SET @cmpUnmctch	= 1
	IF EXISTS(SELECT * FROM [op000] WHERE [Name] = 'AmnCfg_UnmatchedMsg' AND [Type] = 0 AND Value = '0')
		SET @cmpUnmctch	= 0

	CREATE TABLE [#SecViol]( [Type] [INT], [Cnt] [INTEGER])  
	CREATE TABLE [#MatTbl]( [MatGUID] [UNIQUEIDENTIFIER], [mtSecurity] [INT])  
	CREATE TABLE [#StoreTbl](	[StoreGUID] [UNIQUEIDENTIFIER], [Security] [INT])  
	CREATE TABLE [#BillsTypesTbl]( [TypeGuid] [UNIQUEIDENTIFIER], [UserSecurity] [INTEGER], UserReadPriceSecurity [INTEGER])  
	CREATE TABLE [#CostTbl]( [CostGUID] [UNIQUEIDENTIFIER], [Security] [INT])  
	CREATE TABLE [#GR]([Guid] [UNIQUEIDENTIFIER])
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
	--Filling temporary tables  
	INSERT INTO [#MatTbl]		EXEC [prcGetMatsList] 		@MatGUID, @GroupGUID, @MatType,@MatCondGuid  
	INSERT INTO [#StoreTbl]		EXEC [prcGetStoresList] 	@StoreGUID  
	INSERT INTO [#BillsTypesTbl]EXEC [prcGetBillsTypesList]	@SrcTypesguid  
	INSERT INTO [#CostTbl]		EXEC [prcGetCostsList] 		@CostGUID  
	DECLARE @MatSecBal INT   
	SET @MatSecBal = [dbo].[fnGetUserMaterialSec_Balance]([dbo].[fnGetCurrentUserGuid]())  
	if @MatSecBal <= 0  
		RETURN  
	DECLARE @Admin [INT], @MinSec [INT],@UserGuid [UNIQUEIDENTIFIER],@cnt [INT]  
	SET @UserGuid = [dbo].[fnGetCurrentUserGUID]()  
	SET @Admin = [dbo].[fnIsAdmin](ISNULL(@userGUID,0x00) )  
	IF @Admin = 0  
	BEGIN  
		SET @MinSec = [dbo].[fnGetMinSecurityLevel]()  
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
	CREATE TABLE [#SResult]  
	(  
		[biMatPtr] 			[UNIQUEIDENTIFIER],  
		[biQty]  			[FLOAT],  
		[biQty2]			[FLOAT],  
		[biQty3]			[FLOAT],  
		[biStorePtr]		[UNIQUEIDENTIFIER],  
		[Security]			[INT],  
		[UserSecurity] 		[INT],  
		[MtSecurity]		[INT],  
		[biClassPtr]		[NVARCHAR](255) COLLATE Arabic_CI_AI,  
		[APrice]			[FLOAT],  
		[StSecurity]		[INT] , 
		[bMove]				[TINYINT],
		[SN]				[NVARCHAR](255) COLLATE Arabic_CI_AI,  
		[ExpireDate]		[DATETIME] , 
		[MtVAT]				[FLOAT] 
	) 
	CREATE TABLE [#t_PricesQnt]
	(
		[mtNumber] 	[UNIQUEIDENTIFIER],
		[APrice] 	[FLOAT],
		[Qnt] [FLOAT]
	)
	DECLARE  @defCurr UNIQUEIDENTIFIER = dbo.fnGetDefaultCurr()
	IF @ShowPrice > 0  
	BEGIN  
		IF @MatType >= 3  
			SET @MatType = -1  
		IF @PriceType = 2 AND (@PricePolicy = 122 or @PricePolicy=126)-- LastPrice  
		BEGIN  
			EXEC [prcGetLastPriceNewEquation] @StartDate , @EndDate , @MatGUID, @GroupGUID, @StoreGUID, @CostGUID, @MatType,	@CurrencyGUID, @SrcTypesguid, @ShowUnLinked, 0, @type = @PricePolicy	
		END	
		ELSE IF @PriceType = 2 AND @PricePolicy = 120 -- MaxPrice  
		BEGIN  
			EXEC [prcGetMaxPrice] @StartDate , @EndDate , @MatGUID, @GroupGUID, @StoreGUID, @CostGUID, @MatType,	@defCurr, @CurrencyVal, @SrcTypesguid, @ShowUnLinked, 0  
			UPDATE #t_Prices  
				SET APrice =(APrice/dbo.fnGetCurVal(@CurrencyGUID,@EndDate))
		END  
		ELSE IF @PriceType = 2 AND @PricePolicy = 121 AND @DetCostPrice = 0 -- COST And AvgPrice NO STORE DETAILS  
		BEGIN  
			IF @RateTyp = 0
			BEGIN
				EXEC [prcGetAvgPrice]	@StartDate,	@EndDate, @MatGUID, @GroupGUID, @StoreGUID, @CostGUID, @MatType, 
					@defCurr, @CurrencyVal, @SrcTypesguid,	@ShowUnLinked, 0, @IsIncludeOpenedLC
			
				UPDATE #t_Prices  
				SET APrice =(APrice/dbo.fnGetCurVal(@CurrencyGUID,@EndDate))
			END
			ELSE
			BEGIN
				EXEC [prcGetAvgPrice]	@StartDate,	@EndDate, @MatGUID, @GroupGUID, @StoreGUID, @CostGUID, @MatType, 
					@CurrencyGUID, @CurrencyVal, @SrcTypesguid,	@ShowUnLinked, 0, @IsIncludeOpenedLC
			END
		END  
		ELSE IF @PriceType = 2 AND @PricePolicy = 121 AND @DetCostPrice = 1 -- COST And AvgPrice  STORE DETAILS  
		BEGIN  
			EXEC [prcGetAvgPrice_WithDetailStore]	@StartDate,	@EndDate, @MatGUID, @GroupGUID, @StoreGUID, @CostGUID, @MatType, @CurrencyGUID, @CurrencyVal, @SrcTypesguid,	@ShowUnLinked, 0  
		END  
		ELSE IF @PriceType = -1  
			INSERT INTO [#t_Prices] SELECT [MatGUID], 0 FROM [#MatTbl]  
		  
		ELSE IF @PriceType = 2 AND @PricePolicy = 124 -- LastPrice with extra and discount  
		BEGIN  
			EXEC [prcGetLastPriceNewEquation] @StartDate , @EndDate , @MatGUID, @GroupGUID, @StoreGUID, @CostGUID, @MatType,	@CurrencyGUID, @SrcTypesguid, @ShowUnLinked, 0, 0 /*@CalcLastCost*/,	1 /*@ProcessExtra*/  , 124 ,@IsIncludeOpenedLC
		END  
		ELSE IF @PriceType = 2 AND @PricePolicy = 125  
		BEGIN
			EXEC [prcGetFirstInFirstOutPriseQTY2] @StartDate , @EndDate,@CurrencyGUID
				INSERT INTO #t_Prices
				SELECT mtNumber,APrice FROM [#t_PricesQnt]
		END  
		ELSE IF @PriceType = 2 AND @PricePolicy = 130  
		BEGIN  
			INSERT INTO [#t_Prices]  
			SELECT   
				[r].[biMatPtr],(SUM([FixedBiTotal])/SUM([biQty] + [biBonusQnt]) ) /CASE WHEN @RateTyp = 1 THEN  
				(dbo.fnGetCurVal(@CurrencyGUID,@EndDate))ELSE 1 END
			FROM  
				[fnExtended_bi_Fixed](CASE WHEN (@RateTyp = 1) THEN @defCurr ELSE @CurrencyGUID END) AS [r]  
				INNER JOIN [#BillsTypesTbl] AS [bt] ON [r].[buType] = [bt].[TypeGuid]  
				INNER JOIN [#MatTbl] AS [mtTbl] ON [r].[biMatPtr] = [mtTbl].[MatGUID]  
				INNER JOIN [#StoreTbl] AS [st] ON [st].[StoreGUID] = [biStorePtr]  
			WHERE  
				[budate] BETWEEN @StartDate AND @EndDate AND [BtBillType] = 0  
				AND((@CostGUID = 0x0) OR ([BiCostPtr] IN( SELECT [CostGUID] FROM [#CostTbl])))  
				AND [buIsPosted] > 0   
			GROUP BY [r].[biMatPtr] 
			 
		END  
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
			DECLARE @UnitType INT 
			SET @UnitType = CASE @UseUnit WHEN 5 THEN 0 ELSE @UseUnit END 
			EXEC [prcGetMtPrice] @MatGUID,	@GroupGUID, @MatType, @CurrencyGUID,@CurrencyVal, @SrcTypesguid, @PriceType, @PricePolicy, @ShowUnLinked, @UnitType ,@EndDate
			
		END  
	END  
	
	
	IF( EXISTS( SELECT * FROM [vwbu] WHERE [buDate] > @StartDate OR [buDate]< @EndDate)  
		OR @CostGUID <> 0X00  OR @ClassDtails = 1 OR ([dbo].[fnConnections_getBranchMask]() <> dbo.fnGetUserBranchMask())  
		OR @ShowUnLinked = 1 OR @Class <> '' 
		OR EXISTS(SELECT * FROM op000 WHERE name like 'AmncfgMultiFiles' and value = '1'))  -- we must calc sum(qty2), Sum(Qty3) from bi, bu  
	BEGIN  
		IF @ShowSerialNumber = 0
		BEGIN
			IF @DetCostPrice = 0
			BEGIN 
				INSERT INTO [#SResult]   
				SELECT   
					[r].[biMatPtr],   
					SUM(([r].[biQty] + [r].[biBonusQnt])* [r].[buDirection]),   
					SUM([r].[biQty2]* [r].[buDirection]),   
					SUM([r].[biQty3]* [r].[buDirection]),   
					CASE @DetailsStores WHEN 0 THEN 0X00 ELSE [r].[biStorePtr] END,   
					[r].[buSecurity],   
					[bt].[UserSecurity],   
					[mtTbl].[MtSecurity],   
					CASE @ClassDtails WHEN 1 THEN [biClassPtr] ELSE '' END,
					CASE  @PricePolicy WHEN 125 THEN CASE WHEN [r].[buDirection] = -1 THEN 0 
						ELSE (r.biPrice/r.biQty) * CASE 
						WHEN @useunit= 0 or (@UseUnit = 3 and mt.mtDefUnit = 1) THEN 
									CASE WHEN r.biUnity = 1 THEN r.biQty
									WHEN r.biUnity = 2 THEN r.biQty2
									ELSE  r.biQty3 END
						WHEN @useunit= 1 or (@UseUnit = 3 and mt.mtDefUnit = 2) THEN 
									CASE WHEN r.biUnity = 1 THEN r.biQty
									WHEN r.biUnity = 2 THEN r.biQty2
									ELSE  r.biQty3 END
						WHEN @useunit= 2 or (@UseUnit = 3 and mt.mtDefUnit = 3)THEN 
									CASE WHEN r.biUnity = 1 THEN r.biQty
									WHEN r.biUnity = 2 THEN r.biQty2
									ELSE  r.biQty3 END
						END END ELSE 0 END,
					[st].[Security],
					1,
					'',  
					CASE @ShowMatExpireDate WHEN 0 THEN '' ELSE [r].[biExpireDate] END , 
					[mt].[mtVat]
				FROM   
					[vwbubi] AS [r]  
					INNER JOIN [#BillsTypesTbl] AS [bt] ON [r].[buType] = [bt].[TypeGuid]   
					INNER JOIN [#MatTbl] AS [mtTbl] ON [r].[biMatPtr] = [mtTbl].[MatGUID]  
					INNER JOIN [vwMt] AS [mt] ON [mtTbl].[MatGUID] = [mt].[mtGUID]   
					INNER JOIN [#StoreTbl] AS [st] ON [st].[StoreGUID] = [biStorePtr]
				WHERE   
					[budate] BETWEEN @StartDate AND @EndDate
					AND ( @GroupByExpireDate = 0
					OR ((@MatWithoutExpireDate = 1 AND biExpireDate = '1980-01-01')
					OR (@MatWithExpireDate = 1 AND biExpireDate <> '1980-01-01')) )
					AND ((@ShowPeriodOfExpireDate = 0) OR (@ShowPeriodOfExpireDate = 1 AND biExpireDate BETWEEN dbo.fnDate_AddEx(GETDATE(), 2,@FromExpireDate) AND dbo.fnDate_AddEx(GETDATE(), 2,@ToExpireDate) ))
					AND ((@CostGUID = 0x0) OR ([BiCostPtr] IN( SELECT [CostGUID] FROM [#CostTbl])))   
					AND [buIsPosted] > 0   
					AND ( @Class = '' OR @Class =[biClassPtr] ) 
				GROUP BY   
					[r].[biMatPtr],   
					CASE @DetailsStores WHEN 0 THEN 0X00 ELSE [r].[biStorePtr] END,   
					[r].[buSecurity],   
					[bt].[UserSecurity],   
					[mtTbl].[MtSecurity],   
					CASE @ClassDtails WHEN 1 THEN [biClassPtr] ELSE '' END,   
					[st].[Security],
					[r].[biExpireDate] ,
					[mt].[mtVat],
					CASE  @PricePolicy WHEN 125 THEN CASE WHEN [r].[buDirection] = -1 THEN 0 
						ELSE (r.biPrice/r.biQty) * CASE 
						WHEN @useunit= 0 or (@UseUnit = 3 and mt.mtDefUnit = 1) THEN 
									CASE WHEN r.biUnity = 1 THEN  r.biQty
									WHEN r.biUnity = 2 THEN r.biQty2
									ELSE  r.biQty3 END
						WHEN @useunit= 1 or (@UseUnit = 3 and mt.mtDefUnit = 2) THEN 
									CASE WHEN r.biUnity = 1 THEN  r.biQty
									WHEN r.biUnity = 2 THEN r.biQty2
									ELSE  r.biQty3 END
						WHEN @useunit= 2 or (@UseUnit = 3 and mt.mtDefUnit = 3)THEN 
									CASE WHEN r.biUnity = 1 THEN  r.biQty
									WHEN r.biUnity = 2 THEN r.biQty2
									ELSE  r.biQty3 END
						END END ELSE 0 END 
			END ELSE BEGIN 
				INSERT INTO [#SResult]   
				SELECT   
					[r].[biMatPtr],   
					SUM(([r].[biQty] + [r].[biBonusQnt])* [r].[buDirection]),   
					SUM([r].[biQty2]* [r].[buDirection]),   
					SUM([r].[biQty3]* [r].[buDirection]),   
					CASE @DetailsStores WHEN 0 THEN 0X00 ELSE [r].[biStorePtr] END,   
					[r].[buSecurity],   
					[bt].[UserSecurity],   
					[mtTbl].[MtSecurity],   
					CASE @ClassDtails WHEN 1 THEN [biClassPtr] ELSE '' END,
					CASE WHEN @PricePolicy = 125 THEN P.APrice ELSE 0 END,
					[st].[Security],
					1,
					'',  
					CASE @ShowMatExpireDate WHEN 0 THEN '' ELSE [r].[biExpireDate] END , 
					[mt].[mtVat]
				FROM   
					[vwbubi] AS [r]  
					INNER JOIN [#BillsTypesTbl] AS [bt] ON [r].[buType] = [bt].[TypeGuid]   
					INNER JOIN [#MatTbl] AS [mtTbl] ON [r].[biMatPtr] = [mtTbl].[MatGUID]  
					INNER JOIN [vwMt] AS [mt] ON [mtTbl].[MatGUID] = [mt].[mtGUID]   
					INNER JOIN [#StoreTbl] AS [st] ON [st].[StoreGUID] = [r].[biStorePtr]   
					INNER JOIN #t_Prices2 P ON P.mtNumber = r.biMatPtr AND [st].[StoreGUID] = p.stNumber
				WHERE   
					[budate] BETWEEN @StartDate AND @EndDate
					AND ( @GroupByExpireDate = 0
					OR ((@MatWithoutExpireDate = 1 AND biExpireDate = '1980-01-01')
					OR (@MatWithExpireDate = 1 AND biExpireDate <> '1980-01-01')) )
					AND ((@ShowPeriodOfExpireDate = 0) OR (@ShowPeriodOfExpireDate = 1 AND biExpireDate BETWEEN dbo.fnDate_AddEx(GETDATE(), 2,@FromExpireDate) AND dbo.fnDate_AddEx(GETDATE(), 2,@ToExpireDate) ))
					AND ((@CostGUID = 0x0) OR ([BiCostPtr] IN( SELECT [CostGUID] FROM [#CostTbl])))   
					AND [buIsPosted] > 0   
					AND ( @Class = '' OR @Class =[biClassPtr] ) 
				GROUP BY   
					[r].[biMatPtr],   
					CASE @DetailsStores WHEN 0 THEN 0X00 ELSE [r].[biStorePtr] END,   
					[r].[buSecurity],   
					[bt].[UserSecurity],   
					[mtTbl].[MtSecurity],   
					CASE @ClassDtails WHEN 1 THEN [biClassPtr] ELSE '' END,   
					[st].[Security],
					[r].[biExpireDate] ,
					[mt].[mtVat],
					CASE WHEN @PricePolicy = 125 THEN P.APrice ELSE 0 END
			END
		END
		ELSE BEGIN
			IF @DetCostPrice = 0
			BEGIN 
				INSERT INTO [#SResult]   
				SELECT   
					[r].[biMatPtr],   
					SUM(( CASE ISNULL([SN].[Qty],-1) WHEN -1 THEN [r].[biQty] ELSE [SN].[Qty] END + [r].[biBonusQnt])* [r].[buDirection]),   
					SUM( CASE ISNULL([SN].[Qty],-1) WHEN -1 THEN [r].[biQty2] ELSE [SN].[Qty] END * [r].[buDirection]),     
					SUM( CASE ISNULL([SN].[Qty],-1) WHEN -1 THEN [r].[biQty3] ELSE [SN].[Qty] END * [r].[buDirection]),     
					CASE @DetailsStores WHEN 0 THEN 0X00 ELSE [r].[biStorePtr] END,   
					[r].[buSecurity],   
					[bt].[UserSecurity],   
					[mtTbl].[MtSecurity],   
							CASE @ClassDtails WHEN 1 THEN [r].[biClassPtr] ELSE '' END,
							CASE WHEN @PricePolicy = 125 THEN P.APrice ELSE 0 END,   
					[st].[Security],
					1,
					[SN].[sn],  
					CASE @ShowMatExpireDate WHEN 0 THEN '' ELSE [r].[biExpireDate] END , 
					[mt].[mtVat]
				FROM   
					[vwbubi] AS [r]   
					LEFT JOIN [vwExtended_SN] AS [SN] ON [SN].biGUID = [r].[biGUID] 
					INNER JOIN [#BillsTypesTbl] AS [bt] ON [r].[buType] = [bt].[TypeGuid]   
					INNER JOIN [#MatTbl] AS [mtTbl] ON [r].[biMatPtr] = [mtTbl].[MatGUID]
					INNER JOIN [vwMt] AS [mt] ON [mtTbl].[MatGUID] = [mt].[mtGUID]    
					INNER JOIN [#StoreTbl] AS [st] ON [st].[StoreGUID] = [r].[biStorePtr]   
							JOIN #t_Prices P ON P.mtNumber = r.biMatPtr
				WHERE   
					[r].[budate] BETWEEN @StartDate AND @EndDate 
					AND ( @GroupByExpireDate = 0
					OR ((@MatWithoutExpireDate = 1 AND [r].[biExpireDate] = '1980-01-01') 
					OR ( @MatWithExpireDate = 1 AND [r].[biExpireDate] <> '1980-01-01')))
					AND ((@ShowPeriodOfExpireDate = 0) OR (@ShowPeriodOfExpireDate = 1 AND [r].[biExpireDate] BETWEEN dbo.fnDate_AddEx(GETDATE(), 2,@FromExpireDate) AND dbo.fnDate_AddEx(GETDATE(), 2,@ToExpireDate) ))
					AND ((@CostGUID = 0x0) OR ([r].[BiCostPtr] IN( SELECT [CostGUID] FROM [#CostTbl])))   
					AND [r].[buIsPosted] > 0   
					AND ( @Class = '' OR @Class = [r].[biClassPtr] )   
				GROUP BY   
					[r].[biMatPtr],   
					CASE @DetailsStores WHEN 0 THEN 0X00 ELSE [r].[biStorePtr] END,   
					[r].[buSecurity],   
					[bt].[UserSecurity],   
					[mtTbl].[MtSecurity],   
					CASE @ClassDtails WHEN 1 THEN [r].[biClassPtr] ELSE '' END,   
					[st].[Security],
					[SN].[sn],
					[r].[biExpireDate] ,
							[mt].[mtVat],
							CASE WHEN @PricePolicy = 125 THEN P.APrice ELSE 0 END
			END ELSE BEGIN 
				INSERT INTO [#SResult]   
				SELECT   
					[r].[biMatPtr],   
					SUM(( CASE ISNULL([SN].[Qty],-1) WHEN -1 THEN [r].[biQty] ELSE [SN].[Qty] END + [r].[biBonusQnt])* [r].[buDirection]),   
					SUM( CASE ISNULL([SN].[Qty],-1) WHEN -1 THEN [r].[biQty2] ELSE [SN].[Qty] END * [r].[buDirection]),     
					SUM( CASE ISNULL([SN].[Qty],-1) WHEN -1 THEN [r].[biQty3] ELSE [SN].[Qty] END * [r].[buDirection]),     
					CASE @DetailsStores WHEN 0 THEN 0X00 ELSE [r].[biStorePtr] END,   
					[r].[buSecurity],   
					[bt].[UserSecurity],   
					[mtTbl].[MtSecurity],   
							CASE @ClassDtails WHEN 1 THEN [r].[biClassPtr] ELSE '' END,
							CASE WHEN @PricePolicy = 125 THEN P.APrice ELSE 0 END,   
					[st].[Security],
					1,
					[SN].[sn],  
					CASE @ShowMatExpireDate WHEN 0 THEN '' ELSE [r].[biExpireDate] END , 
					[mt].[mtVat]
				FROM   
					[vwbubi] AS [r]   
					LEFT JOIN [vwExtended_SN] AS [SN] ON [SN].biGUID = [r].[biGUID] 
					INNER JOIN [#BillsTypesTbl] AS [bt] ON [r].[buType] = [bt].[TypeGuid]   
					INNER JOIN [#MatTbl] AS [mtTbl] ON [r].[biMatPtr] = [mtTbl].[MatGUID]
					INNER JOIN [vwMt] AS [mt] ON [mtTbl].[MatGUID] = [mt].[mtGUID]    
					INNER JOIN [#StoreTbl] AS [st] ON [st].[StoreGUID] = [r].[biStorePtr]   
					INNER JOIN #t_Prices2 P ON P.mtNumber = r.biMatPtr AND [st].[StoreGUID] = p.stNumber
				WHERE   
					[r].[budate] BETWEEN @StartDate AND @EndDate 
					AND ( @GroupByExpireDate = 0
					OR ((@MatWithoutExpireDate = 1 AND [r].[biExpireDate] = '1980-01-01') 
					OR ( @MatWithExpireDate = 1 AND [r].[biExpireDate] <> '1980-01-01')))
					AND ((@ShowPeriodOfExpireDate = 0) OR (@ShowPeriodOfExpireDate = 1 AND [r].[biExpireDate] BETWEEN dbo.fnDate_AddEx(GETDATE(), 2,@FromExpireDate) AND dbo.fnDate_AddEx(GETDATE(), 2,@ToExpireDate) ))
					AND ((@CostGUID = 0x0) OR ([r].[BiCostPtr] IN( SELECT [CostGUID] FROM [#CostTbl])))   
					AND [r].[buIsPosted] > 0   
					AND ( @Class = '' OR @Class = [r].[biClassPtr] )   
				GROUP BY   
					[r].[biMatPtr],   
					CASE @DetailsStores WHEN 0 THEN 0X00 ELSE [r].[biStorePtr] END,   
					[r].[buSecurity],   
					[bt].[UserSecurity],   
					[mtTbl].[MtSecurity],   
					CASE @ClassDtails WHEN 1 THEN [r].[biClassPtr] ELSE '' END,   
					[st].[Security],
					[SN].[sn],
					[r].[biExpireDate] ,
					[mt].[mtVat],
					CASE WHEN @PricePolicy = 125 THEN P.APrice ELSE 0 END
			END 
		 END
		IF @Admin = 0  
			UPDATE [#SResult] SET 	[Security]	= @MinSec  
		IF @ShowUnLinked = 1  
			UPDATE [bi] SET   
				[biQty2] = (CASE [mt].[Unit2FactFlag] WHEN 0 THEN CASE [mt].[Unit2Fact] WHEN 0 THEN 0 ELSE [bi].[biQty] /  [mt].[Unit2Fact] END ELSE [bi].[biQty2] END),  
				[biQty3] = (CASE [mt].[Unit3FactFlag] WHEN 0 THEN CASE [mt].[Unit3Fact] WHEN 0 THEN 0 ELSE [bi].[biQty] /  [mt].[Unit3Fact] END ELSE [bi].[biQty3] END)  
			FROM [#SResult] AS [bi] INNER JOIN [mt000] AS [mt]  ON  [mt].[Guid] = [bi].[biMatPtr]  
	END  
	ELSE  
	BEGIN  
		INSERT INTO [#SResult]  
		SELECT  
			[mtTbl].[MatGUID],  
			msQty,  
			0,  
			0,  
			CASE @DetailsStores WHEN 0 THEN 0X00 ELSE [msStorePtr] END,  
			0,  
			0,  
			[mtTbl].[MtSecurity],  
			'',0,  
			[st].[Security], 1, '', '1/1/1980', 0   
		FROM  
			[#MatTbl] AS [mtTbl]   
			INNER JOIN [vwms] AS [ms] ON [msMatPtr] = [mtTbl].[MatGUID]  
			INNER JOIN [#StoreTbl] AS [st] ON [st].[StoreGUID] = [msStorePtr]  
		 
	END  
	IF (@ShowEmpty = 1 )
		INSERT INTO [#SResult]  
			SELECT  
				[mtTbl].[MatGUID],0,0,0,0X00,  
				0,0,[mtTbl].[MtSecurity], '', 0, 0, 0, '', '1/1/1980', 0
			FROM  
				[#MatTbl] AS [mtTbl] WHERE [mtTbl].[MatGUID] NOT IN (SELECT [biMatPtr] FROM [#SResult])  
	IF    @ShowBalancedMat = 0 
		DELETE  [#SResult] WHERE ABS([biQty]) < @Zero AND [bMove] = 1 
	EXEC [prcCheckSecurity] @Result = '#SResult'  
	CREATE TABLE [#R]  
	(  
		[StoreGUID]		[UNIQUEIDENTIFIER],  
		[mtNumber]		[UNIQUEIDENTIFIER],  
		[mtQty]			[FLOAT],  
		[Qnt2]			[FLOAT],  
		[Qnt3]			[FLOAT],  
		[APrice]		[FLOAT],  
		[StCode]		[NVARCHAR](255) COLLATE ARABIC_CI_AI,  
		[StName]		[NVARCHAR](255) COLLATE ARABIC_CI_AI,  
		[stLevel]		[INT],  
		[ClassPtr]		[NVARCHAR](255) COLLATE ARABIC_CI_AI,  
		[id]			[INT]	DEFAULT 0,  
		[mtUnitFact]	[FLOAT] DEFAULT 1,  
		[MtGroup]		[UNIQUEIDENTIFIER],  
		[RecType] 		[NVARCHAR](1) COLLATE ARABIC_CI_AI DEFAULT 'm' NOT NULL,  
		[grLevel] 		[INT],  
		[mtName]		[NVARCHAR](255) COLLATE ARABIC_CI_AI,  
		[mtCode]		[NVARCHAR](255) COLLATE ARABIC_CI_AI,  
		[mtLatinName]		[NVARCHAR](255) COLLATE ARABIC_CI_AI,  
		 
		[Move]		INT,
		[SERIALNUMBER] [NVARCHAR](255) COLLATE Arabic_CI_AI,  
		[ExpireDate]	[DATETIME], 
		[MtVAT]			[FLOAT]  
	)  
		  
	IF (@DetCostPrice = 1)  
		UPDATE [r] SET [APrice] = [p].[APrice] FROM [#SResult] AS [r] INNER JOIN [#t_Prices2] AS [p] ON [stNumber]= [biStorePtr] AND [mtNumber] =[biMatPtr]  
			
	IF @PriceType = 2 AND @PricePolicy = 125
	BEGIN
		SELECT 
			SUM(biQty)  AS biQty,
			SUM(biQty2) AS biQty2,
			SUM(biQty3) AS biQty3,
			biMatPtr,
			biStorePtr ,
			biClassPtr , 
			ExpireDate
		INTO [#Temp] 
		FROM [#SResult]
		WHERE 
			( biQty < 0) OR  APrice IS NULL
		 GROUP BY 
			 biMatPtr,
			 biStorePtr,
			 biClassPtr,
			 ExpireDate 

		 DELETE FROM [#SResult] 
		 WHERE [biQty] < 0 OR  APrice IS NULL 
		 ------------------------------------------------------------------------------------------
	 -- If we delete some row/s that only apper once in #SResult so select it and insert them/it again .
		SELECT * INTO [#temp2] 
		FROM #Temp AS temp
		WHERE  NOT Exists (SELECT biMatPtr FROM #SResult WHERE biMatPtr = temp.biMatPtr and biStorePtr = temp.biStorePtr) 
	
		INSERT INTO #SResult (biQty ,biQty2 ,biQty3,biMatPtr, biStorePtr,biClassPtr ,ExpireDate)
		(SELECT  * FROM [#Temp2])
		
		DELETE #Temp FROM #Temp 
		INNER JOIN #temp2 ON #temp2.biMatPtr = #Temp.biMatPtr AND #temp2.biStorePtr = #temp.biStorePtr
		-------------------------------------------------------------------------------------------
	END 
		ELSE  
			UPDATE [r] SET [APrice] = [p].[APrice] FROM [#SResult] AS [r] INNER JOIN [#t_Prices] AS [p] ON [mtNumber] =[biMatPtr] 

	IF( @ShowGroups = 0)      
		ALTER TABLE       
			[#R]      
		DROP COLUMN   
			[mtName],[mtCode],[mtLatinName]    
	 
	  IF @PriceType = 2 AND @PricePolicy = 125 
	BEGIN 
			DECLARE @NUMBER INT
			DECLARE @biqty FLOAT, @biqty2 FLOAT, @biqty3 FLOAT ,@biqtytemp FLOAT = 0, @biqtytemp2 FLOAT = 0, @biqtytemp3 FLOAT =0
			DECLARE @bimtptrtemp [UNIQUEIDENTIFIER] , @bistptrtemp [UNIQUEIDENTIFIER], @bimtptr [UNIQUEIDENTIFIER] , @bistptr [UNIQUEIDENTIFIER]
			DECLARE @biTempclass NVARCHAR(MAX), @biTempExpireDate NVARCHAR(MAX)  
			DECLARE @count INT = 0
			ALTER TABLE #SResult
			ADD NUM INT IDENTITY(1,1);
			DECLARE sample_cursor CURSOR FOR
				SELECT 
				biQty, biQty2, biQty3, biMatPtr, biStorePtr, biClassPtr , ExpireDate
				FROM #temp
				OPEN sample_cursor
					FETCH NEXT FROM sample_cursor INTO @biqtytemp, @biqtytemp2, @biqtytemp3, @bimtptrtemp, @bistptrtemp , @biTempclass, @biTempExpireDate
					WHILE @@FETCH_STATUS = 0
					BEGIN
						SET @count = (SELECT COUNT(*) FROM #SResult WHERE biMatPtr = @bimtptrtemp AND biStorePtr = @bistptrtemp )
						DECLARE sample_cursor2 CURSOR FOR 
						SELECT num,biQty,biQty2,biQty3,biMatPtr,biStorePtr FROM #SResult WHERE biMatPtr = @bimtptrtemp AND biStorePtr = @bistptrtemp AND [biClassPtr] = @biTempclass AND ExpireDate = @biTempExpireDate 
						OPEN sample_cursor2
						FETCH NEXT FROM sample_cursor2 into @NUMBER,@biqty,@biqty2,@biqty3,@bimtptr,@bistptr
						WHILE @@FETCH_STATUS = 0
						BEGIN
						SET @biqtytemp = @biqtytemp + @biqty 
						SET	@biqtytemp2 = @biqtytemp2 + @biqty2 
						SET	@biqtytemp3 = @biqtytemp3 + @biqty3 
						IF @biqtytemp < = 0  AND @count > 1
							DELETE FROM #SResult WHERE NUM = @NUMBER
						ELSE 
						BEGIN 
							UPDATE #SResult 
							SET biQty= @biqtytemp,
								biQty2= @biqtytemp2,
								biQty3= @biqtytemp3
							WHERE NUM = @NUMBER
							BREAK
						END
					FETCH NEXT FROM sample_cursor2 INTO @NUMBER,@biqty,@biqty2,@biqty3,@bimtptr,@bistptr
				END
				CLOSE sample_cursor2
				DEALLOCATE sample_cursor2
			FETCH NEXT FROM sample_cursor INTO @biqtytemp, @biqtytemp2, @biqtytemp3, @bimtptrtemp, @bistptrtemp, @biTempclass, @biTempExpireDate
			END
			CLOSE sample_cursor
			DEALLOCATE sample_cursor
		ALTER TABLE #SResult DROP COLUMN NUM 
	END

	INSERT INTO [#R] ([StoreGUID], [mtNumber], [mtQty], [Qnt2], [Qnt3], [APrice], [StCode], [StName], [stLevel], [ClassPtr], [id], [Move], [SERIALNUMBER], [ExpireDate], [MtVAT])  
		SELECT  
			[biStorePtr], 
			[biMatPtr], 
			SUM([biQty]), 
			SUM([biQty2]), 
			SUM([biQty3]), 
			ISNULL([APrice],0), 
			ISNULL([stCode],''), 
			ISNULL([stName],''), 
			0, 
			[biClassPtr], 
			'',   
			MAX([bMove]), [SN] , [ExpireDate] , 
			r.[MtVAT]
		FROM  
			[#SResult] AS [r]  
			LEFT JOIN (SELECT  
							[Guid], 
							[Code] AS [stCode],  
							CASE @Lang WHEN 0 THEN [Name] ELSE CASE [LatinName] WHEN '' THEN [Name] ELSE [LatinName] END END AS [stName]  
						FROM [st000] 
					   ) AS [st] ON [st].[Guid] = [biStorePtr]  
		GROUP BY  
			[biStorePtr],  
			[biMatPtr],  
			[APrice],  
			ISNULL([stCode],''),  
			ISNULL([stName],''),  
			[biClassPtr] ,
			[SN],
			[ExpireDate] , 
			r.[MtVAT] 
		Order By
			[SN]

	IF @ShowBalancedMat = 0 
		DELETE [#R] WHERE ABS([mtQty])< @Zero AND [Move] > 0 
	 
	DECLARE @Level [INT]  
	IF (@StLevel > 0)  
	BEGIN  
		CREATE TABLE [#R2]([StoreGUID] [UNIQUEIDENTIFIER], [mtNumber] [UNIQUEIDENTIFIER],[mtQty] FLOAT,[Qnt2] FLOAT, [Qnt3] FLOAT,
							[APrice] FLOAT, [stCode] NVARCHAR(256), [StName] NVARCHAR(256), [stLevel] INT ,[ClassPtr] NVARCHAR(256), [id] INT, [MtVAT] FLOAT)
		CREATE TABLE [#TStore]  
		(  
			[Id]	[INT] IDENTITY(1,1),  
			[Guid]	[UNIQUEIDENTIFIER],  
			[Level] [INT],  
			[StCode]		[NVARCHAR](255) COLLATE ARABIC_CI_AI,  
			[StName]		[NVARCHAR](255) COLLATE ARABIC_CI_AI  
		)  
		INSERT INTO [#TStore]([Guid], [Level],[StCode],[StName])  
		SELECT [f].[Guid], [Level] + 1 , [Code] ,  CASE @Lang WHEN 0 THEN [Name] ELSE CASE [LatinName] WHEN '' THEN [Name] ELSE [LatinName] END END FROM [fnGetStoresListTree](@StoreGUID, 0) AS [f] INNER JOIN [st000] AS [st] ON [st].[GUID] = [f].[Guid] ORDER BY [Path]  
		SET @Level = (SELECT MAX([LEVEL]) FROM [#TStore])   
		UPDATE [r] SET [stLevel] = [Level],[Id] = [st].[Id] FROM [#R] AS [r] INNER JOIN [#TStore] AS [st] ON [StoreGUID] = [Guid]  
		WHILE (@Level > 1)  
		BEGIN  
			INSERT INTO [#R] ([StoreGUID],[mtNumber],[mtQty],[Qnt2],[Qnt3],[APrice],[stCode],[StName],[stLevel],[ClassPtr],[id],[MtVAT])	    
				SELECT [t].[Guid],[mtNumber],SUM([mtQty]),SUM([Qnt2]),SUM([Qnt3]),ISNULL([APrice],0),[t].[stCode],[t].[StName],[t].[Level],[ClassPtr],[t].[id],R.[MtVAT]    
			FROM  [#R] AS [r] INNER JOIN [st000] AS [st] ON [st].[Guid] = [r].[StoreGUID] INNER JOIN [#TStore] AS [T] ON [t].[Guid] = [st].[ParentGuid]  
			WHERE [r].[stLevel] = @Level  
			GROUP BY   
				[t].[Guid],[mtNumber],ISNULL([APrice],0),[t].[stCode],[t].[StName],[t].[Level],[ClassPtr],[t].[id],R.[MtVAT]  
			IF (@StLevel = @Level)  
				DELETE [#R] WHERE [stLevel] > @StLevel  
			SET @Level = @Level - 1  
			  
			  
		END  
		IF (@StLevel = 1)  
			DELETE [#R] WHERE [stLevel] > @StLevel  
		INSERT INTO [#R2] SELECT [StoreGUID],[mtNumber],[mtQty],[Qnt2],[Qnt3],[APrice],[stCode],[StName],[stLevel],[ClassPtr],[id],[MtVAT] FROM [#R]    
		TRUNCATE TABLE [#R]  
		INSERT INTO #R  ([StoreGUID],[mtNumber],[mtQty],[Qnt2],[Qnt3],[APrice],[stCode],[StName],[stLevel],[ClassPtr],[id],[MtVAT])	    
			 SELECT [StoreGUID],[mtNumber],SUM([mtQty]),SUM([Qnt2]),SUM([Qnt3]),[APrice],[stCode],[StName],[stLevel],[ClassPtr],[id],[MtVAT]  FROM [#R2]    
			 GROUP BY [StoreGUID],[mtNumber],[APrice],[StName],[stLevel],[ClassPtr],[id],[stCode],[MtVAT] 
	END	  
	-- Show Groups  
	IF @ShowGroups > 0  
	BEGIN  
		CREATE TABLE [#grp]([Guid] [UNIQUEIDENTIFIER], [Level] INT, [grName] NVARCHAR(256), [grLatinName] NVARCHAR(256), [grCode] NVARCHAR(256), [ParentGuid] [UNIQUEIDENTIFIER])
		INSERT INTO [#grp] SELECT [f].[Guid],[f].[Level],  [Name]AS [grName], [LatinName] AS [grLatinName],[Code] AS [grCode],[ParentGuid] FROM [dbo].[fnGetGroupsListByLevel](@GroupGUID,0) AS [f] INNER JOIN [gr000] AS [gr] ON [gr].[Guid] = [f].[Guid]  
		SELECT @Level = MAX([Level]) FROM [#grp]  
		UPDATE [r]  
			SET   
			[MtGroup] = [GroupGuid],  
			[RecType] = 'm',  
			[grLevel] = [Level],  
			[mtName] = [Name],  
			[mtCode] = [Code],  
			[mtLatinName] = [LatinName],  
			[mtUnitFact] = CASE @UseUnit WHEN 0 THEN 1  
					WHEN 1 THEN CASE [Unit2Fact] WHEN 0 THEN 1 ELSE [Unit2Fact] END  
					WHEN 2 THEN CASE [Unit3Fact] WHEN 0 THEN 1 ELSE [Unit3Fact] END  
					ELSE  
						CASE [DefUnit]  
							WHEN 1 THEN 1  
							WHEN 2 THEN CASE [Unit2Fact] WHEN 0 THEN 1 ELSE [Unit2Fact] END  
							ELSE CASE [Unit3Fact] WHEN 0 THEN 1 ELSE [Unit3Fact] END  
							   
						END  
					END  
					 
		FROM [#R] AS [r]   
		INNER JOIN [mt000] AS [mt] ON [mtNumber] = [mt].[Guid]   
		INNER JOIN [#grp] AS [gr] ON  [gr].[Guid] = [GroupGuid]  

		INSERT INTO [#R]([StoreGUID],[mtNumber],[mtQty],[Qnt2],[Qnt3],[APrice],[StName],[stLevel],[ClassPtr],[id],[MtGroup],[RecType],[grLevel],[mtName],[mtCode],[mtLatinName])  
		SELECT  0x00,[gr].[Guid],SUM([mtQty]/[mtUnitFact]),SUM([Qnt2]),SUM([Qnt3]),SUM([APrice] *[mtQty]),'',[stLevel],'',[id],[gr].[ParentGuid],'g',[gr].[Level],[grName],[grCode],[grLatinName]   
		FROM [#R] AS [r] INNER JOIN  [#grp] AS [gr] ON [gr].[Guid] = [r].[MtGroup]  
		WHERE [stLevel] < = 1  
		GROUP BY [gr].[Guid],[stLevel],[id],[gr].[ParentGuid],[gr].[Level],[grName],[grCode],[grLatinName]   
		
		WHILE (@Level > 0)  
		BEGIN  
			UPDATE r 
			SET 
				[mtQty] = r.[mtQty] + r1.mtQty, 
				[Qnt2] = r.[Qnt2] + r1.[Qnt2],
				[Qnt3] = r.[Qnt3] + r1.[Qnt3],
				[APrice] = r.[APrice] + r1.[APrice]
			FROM 
				[#R] AS [r] INNER JOIN [#grp] AS [gr] ON [gr].[Guid] = [r].[mtNumber]
				INNER JOIN (
					SELECT 
						[MtGroup] AS [MtGroup], 
						SUM([mtQty]) AS mtQty, 
						SUM([Qnt2]) AS Qnt2, 
						SUM([Qnt3]) AS Qnt3,
						SUM([APrice]) AS [APrice] FROM [#R] WHERE [grLevel] = @Level AND [RecType] = 'g' 
							GROUP BY [MtGroup]) r1 ON r1.[MtGroup] = [gr].[Guid]

			INSERT INTO [#R]([StoreGUID],[mtNumber],[mtQty],[Qnt2],[Qnt3],[APrice],[StName],[stLevel],[ClassPtr],[id],[MtGroup],[RecType],[grLevel],[mtName],[mtCode],[mtLatinName],r.[MtVAT])   
			SELECT 0x00,[gr].[Guid],SUM([mtQty]),SUM([Qnt2]),SUM([Qnt3]),SUM([APrice]),'',[stLevel],'',[id],[gr].[ParentGuid],'g',[gr].[Level],[grName],[grCode],[grLatinName],r.[MtVAT]      
			FROM [#R] AS [r] INNER JOIN  [#grp] AS [gr] ON [gr].[Guid] = [r].[MtGroup]  
			WHERE [r].[grLevel] = @Level AND [RecType] = 'g' AND [gr].[Guid] not in (select mtNumber from #R)
			GROUP BY[gr].[Guid],[stLevel],[id],[gr].[ParentGuid],[gr].[Level],[grName],[grCode],[grLatinName],r.[MtVAT]   

			SET @Level = @Level - 1  
		END  

		CREATE TABLE [#MainRes3]  
		(  
			[StoreGUID]		[UNIQUEIDENTIFIER],  
			[mtNumber]		[UNIQUEIDENTIFIER],  
			[mtQty]			[FLOAT],  
			[Qnt2]			[FLOAT],  
			[Qnt3]			[FLOAT],  
			[APrice]		[FLOAT],  
			[StCode]		[NVARCHAR](255) COLLATE ARABIC_CI_AI,  
			[StName]		[NVARCHAR](255) COLLATE ARABIC_CI_AI,  
			[stLevel]		[INT],  
			[ClassPtr]		[NVARCHAR](255) COLLATE ARABIC_CI_AI,  
			[id]			[INT]	DEFAULT 0,  
			[MtGroup]		[UNIQUEIDENTIFIER],  
			[RecType] 		[NVARCHAR](1) COLLATE ARABIC_CI_AI DEFAULT 'm' NOT NULL,  
			[grLevel] 		[INT],  
			[mtName]		[NVARCHAR](255) COLLATE ARABIC_CI_AI,  
			[mtCode]		[NVARCHAR](255) COLLATE ARABIC_CI_AI,  
			[mtLatinName]		[NVARCHAR](255) COLLATE ARABIC_CI_AI,  
			[mtUnitFact]	[FLOAT],
			[SERIALNUMBER] [NVARCHAR](255) COLLATE Arabic_CI_AI , 
			[ExpireDate]		[DATETIME] , 
			[MtVAT]			[FLOAT] ,
			[Path]			[NVARCHAR](MAX),
			[MaterialGUID]  [UNIQUEIDENTIFIER],
			[Move]		INT
		) 
		INSERT INTO [#MainRes3]  
			SELECT 
				r.[StoreGUID],
				r.[mtNumber],
				SUM(r.[mtQty]) AS [mtQty],
				SUM(r.[Qnt2]) AS [Qnt2],
				SUM(r.[Qnt3]) AS [Qnt3],
				SUM(r.[APrice]) [APrice],
				r.[StCode],
				r.[StName],
				0,
				r.[ClassPtr],
				0,
				r.[MtGroup],
				r.[RecType],
				r.[grLevel],
				r.[mtName],
				r.[mtCode],
				r.[mtLatinName],
				r.[mtUnitFact],
				r.[SERIALNUMBER], 
				r.[ExpireDate], 
				r.[MtVAT],
				f.[Path],
				r.[mtNumber],
				r.[move]
			FROM 
				[#r] as r LEFT JOIN [dbo].[fnGetGroupsOfGroupSorted](0x0, 0) as f ON [r].[mtNumber] = f.[GUID]
			WHERE 
				r.[RecType] = 'g' 
			GROUP BY  
				r.[StoreGUID],
				r.[mtNumber],
				r.[StCode],
				r.[StName],
				r.[ClassPtr],
				r.[mtName],
				r.[mtCode],
				r.[mtLatinName],
				r.[MtGroup],
				r.[RecType],
				r.[grLevel],
				r.[mtUnitFact],
				r.[SERIALNUMBER], 
				r.[ExpireDate], 
				r.[MtVAT]	,
				f.[Path],
				r.[mtNumber],
				r.[move]
			UNION ALL  
			SELECT 
				r.[StoreGUID],
				r.[mtNumber],
				SUM(r.[mtQty]),
				SUM(r.[Qnt2]),
				SUM(r.[Qnt3]),
				SUM(r.[APrice]),
				r.[StCode],
				r.[StName],
				r.[stLevel],
				r.[ClassPtr],
				0,
				r.[MtGroup],
				r.[RecType],
				r.[grLevel],
				r.[mtName],
				r.[mtCode],
				r.[mtLatinName],
				r.[mtUnitFact],
				r.[SERIALNUMBER], 
				r.[ExpireDate], 
				r.[MtVAT]	,
				'Material',
				r.[mtNumber],
				r.[move]
			FROM 
				[#r] as r 
			WHERE 
				r.[RecType] = 'm' 
			GROUP BY  
				r.[StoreGUID],
				r.[mtNumber],
				r.[StCode],
				r.[StName],
				r.[stLevel],
				r.[ClassPtr],
				r.[mtName],
				r.[mtCode],
				r.[mtLatinName],
				r.[MtGroup],
				r.[RecType],
				r.[grLevel],
				r.[mtUnitFact],
				r.[SERIALNUMBER], 
				r.[ExpireDate], 
				r.[MtVAT] 
				,r.[mtNumber],
				r.[move]
	END  
	  

	--- return result sets  
	IF (@ShowGroups = 2)  
		DELETE [#MainRes3] WHERE [RecType] = 'm'   
	DECLARE @FldStr [NVARCHAR](3000)  
	SET @FldStr = ''  
	DECLARE @SqlStr [NVARCHAR](MAX)  
	DECLARE @Str [NVARCHAR](MAX)  
	SET @Str = '  
		[r].[StoreGUID] AS [StorePtr], [r].[mtNumber], [r].[mtQty] AS [Qnt],   
		[r].[Qnt2], [r].[Qnt3],	[r].[APrice],  
		ISNULL([v_mt].[mtUnity], '''') AS [mtUnity], ISNULL([v_mt].[MtUnit2], '''') AS [MtUnit2], ISNULL([v_mt].[MtUnit3], '''') AS [MtUnit3], ISNULL([v_mt].[mtDefUnitFact], '''') AS [mtDefUnitFact], ISNULL([v_mt].[grName],' + '''' + '''' +') AS [grName], ISNULL([v_mt].[grCode],' + '''' + '''' +') AS [grCode],ISNULL([r].[MtVAT], 0) AS MtVAT, '    
	IF @SHOWGROUPS > 0 
	BEGIN 
		SET @Str = @Str + ' ISNULL([r].[mtUnitFact], '''') AS [mtUnitFact],' 
	END 
	ELSE 
	BEGIN 
		IF @UseUnit = 0  
			SET @Str = @Str + 'CASE [r].[mtUnitFact] WHEN 0 THEN 1 ELSE [r].[mtUnitFact] END AS [mtUnitFact],' 		 
		ELSE IF @UseUnit = 1   
			SET @Str = @Str + 'CASE [v_mt].[mtUnit2Fact] WHEN 0 THEN 1 ELSE [v_mt].[mtUnit2Fact] END AS [mtUnitFact],'  
		ELSE IF @UseUnit = 2   
			SET @Str = @Str + 'CASE [v_mt].[mtUnit3Fact] WHEN 0 THEN 1 ELSE [v_mt].[mtUnit3Fact] END AS [mtUnitFact],'  
		ELSE   
			SET @Str = @Str + ' ISNULL([mtDefUnitFact], '''') AS [mtUnitFact],'  
	END 
	 
	DECLARE @Prefix [NVARCHAR](10)  
	SET @Prefix = ' v_mt.'  
	  
	SELECT @FldStr = ''--[dbo].[fnGetMatFldsStr]( @Prefix, @ShowMtFldsFlag/*, @CheckRecType*/)  
	  
	SET @Str = @Str + @FldStr  
	SET @Str = @Str + ' ISNULL([v_mt].[mtUnit2Fact], 0 ) as mtUnit2Fact, ISNULL([v_mt].[mtUnit3Fact], 0) as mtUnit3Fact, ISNULL([v_mt].[mtDefUnitName],'+''''+''''+') AS [mtDefUnitName],'  
	  
	IF @ShowGroups > 0  
		SET @Str = @Str + ' [r].[mtName] AS MtName, [r].[mtCode] AS MtCode, [r].[mtLatinName], [r].[MtGroup], '  
	else	  
		SET @Str = @Str + ' [v_mt].[mtName] AS MtName, [v_mt].[mtCode] AS MtCode, [v_mt].[mtLatinName], [v_mt].[MtGroup], '  
	  
	--------------------------  
	SET @Str = @Str + 'CAST(0x0 AS [UNIQUEIDENTIFIER]) AS [GroupParent],'  
	IF @ShowGroups > 0  
	BEGIN  
		SET @Str = @Str + ' [r].[RecType], '  
		SET @Str = @Str + '	[r].[grLevel]   '  
	END  
	ELSE  
	BEGIN  
		SET @Str = @Str + ' ''m'' AS [RecType], '  
		SET @Str = @Str + '	0 AS [grLevel] '  
	END  
	  
	--IF (@ShowGroups = 2)  
	--	SET @Str = @Str + ',[GroupParentPtr]  '  
	IF (@StLevel > 1) AND @DetailsStores = 1   
		SET @Str = @Str + ',ISNULL([r].[StLevel], 0) AS [STLevel] '   
	ELSE 
		SET @Str = @Str + ',0 AS [STLevel] '  
	
	IF(@ShowGroups > 0)
	BEGIN
		  CREATE TABLE #groups(groupPath NVARCHAR(max), groupGuid [UNIQUEIDENTIFIER]) 
		  INSERT INTO #groups SELECT [path] ,mtNumber FROM [#MainRes3] WHERE RecType = 'g'


		DECLARE @Id [UNIQUEIDENTIFIER]
		DECLARE @path NVARCHAR(max)

		WHILE (SELECT Count(*) FROM #groups) > 0
		BEGIN

			SELECT TOP 1 @Id = groupGuid, @path = groupPath FROM #groups	
				
			UPDATE [#MainRes3]
			SET [path] = @path + 'mat'
			WHERE MtGroup=@Id and RecType = 'm';

			DELETE #groups WHERE groupGuid = @Id

		END
	END
	  
	--==================================================================
	IF(@GroupLevel > 0)
	BEGIN
		CREATE TABLE #groupsList([Guid] [UNIQUEIDENTIFIER], ParentGuid [UNIQUEIDENTIFIER], Sec INT, Lev INT) 
		INSERT INTO #groupsList EXEC prcGetGroupParnetList 0x0, @GroupLevel


		DECLARE @ChildGuid  [UNIQUEIDENTIFIER]
		DECLARE @ParentGUID [UNIQUEIDENTIFIER]

		WHILE (SELECT Count(*) FROM #groupsList) > 0
		BEGIN

			SELECT TOP 1 @ChildGuid = [Guid], @ParentGUID = ParentGuid FROM #groupsList		

			UPDATE [#MainRes3]
			SET MtGroup = @ParentGUID
			WHERE MtGroup = @ChildGuid

			DELETE #groupsList WHERE [Guid] = @ChildGuid
		END
		DELETE [#MainRes3]
		WHERE grLevel > @GroupLevel
		AND RecType = 'g'
	END

	CREATE TABLE #FinalResult(
		[move] INT,
		[StorePtr] UNIQUEIDENTIFIER, 
		[mtNumber] UNIQUEIDENTIFIER, 
		[Qnt] FLOAT,   
		[Qnt2] FLOAT, [Qnt3] FLOAT,	
		[APrice] FLOAT,  
		[mtUnity] NVARCHAR(250), 
		[MtUnit2] NVARCHAR(250), 
		[MtUnit3] NVARCHAR(250), 
		[mtDefUnitFact] FLOAT, 
		[grName] NVARCHAR(250), 
		[grCode] NVARCHAR(250),
		MtVAT FLOAT,
		[mtUnitFact] FLOAT, 
		mtUnit2Fact FLOAT, 
		mtUnit3Fact FLOAT, 
		[mtDefUnitName] NVARCHAR(250),  
		MtName NVARCHAR(250), 
		MtCode NVARCHAR(250), 
		[mtLatinName] NVARCHAR(250), 
		[MtGroup] UNIQUEIDENTIFIER,
		[GroupParent] UNIQUEIDENTIFIER,
		[RecType] NVARCHAR(10),
		[grLevel] INT,
		[STLevel] INT,
		[Quantity1] FLOAT,
		QuantityName1 NVARCHAR(250),
		[Quantity2] FLOAT,
		QuantityName2 NVARCHAR(250),
		[Quantity3] FLOAT,
		QuantityName3 NVARCHAR(250),
		UnitName NVARCHAR(250),
		[Price] FLOAT,
		[AVal] FLOAT,
		[path] NVARCHAR(250),
		MaterialGUID UNIQUEIDENTIFIER,
		[StName] NVARCHAR(250),
		[StCode] NVARCHAR(250),
		[ClassPtr] NVARCHAR(250),
		[SERIALNUMBER] NVARCHAR(250),
		[ExpireDate] DATE,
		[Qty] FLOAT, 
		[Qty2] FLOAT,
		[Qty3] FLOAT,
		NotMatchedQty BIT
	)
	--==================================================================
	SET @SqlStr =  '
		INSERT INTO #FinalResult 
		SELECT ISNULL(r.[move], -1) AS move, ' + @Str  
	
	IF @ShowDetailsUnits > 0
	BEGIN 
		SET @SqlStr = @SqlStr + 
			', 0 AS [Quantity1], 
			CASE r.RecType WHEN ''g'' THEN '''' ELSE [mtUnity] END AS QuantityName1, 
			0 AS Quantity2, 
			CASE r.RecType WHEN ''g'' THEN '''' ELSE [MtUnit2] END AS QuantityName2, 
			0 AS Quantity3, 
			CASE r.RecType WHEN ''g'' THEN '''' ELSE [MtUnit3] END AS QuantityName3,
			'''' AS UnitName '
	END ELSE BEGIN 
		SET @SqlStr = @SqlStr + 
			', 0 AS [Quantity1], '''' AS QuantityName1, 0 AS Quantity2, '''' AS QuantityName2, 0 AS Quantity3, '''' AS QuantityName3 '
		IF @UseUnit = 0
			SET @SqlStr = @SqlStr + ', CASE [mtUnity] WHEN '''' THEN [mtDefUnitName] ELSE [mtUnity] END AS UnitName'
		ELSE IF @UseUnit = 1
			SET @SqlStr = @SqlStr + ', CASE [MtUnit2] WHEN '''' THEN [mtDefUnitName] ELSE [MtUnit2] END AS UnitName'
		ELSE IF @UseUnit = 2
			SET @SqlStr = @SqlStr + ', CASE [MtUnit3] WHEN '''' THEN [mtDefUnitName] ELSE [MtUnit3] END AS UnitName'
		ELSE 
			SET @SqlStr = @SqlStr + ', ISNULL([mtDefUnitName], '''') AS UnitName'
	END 
	
	SET @SqlStr = @SqlStr + 
		', CASE [r].RecType WHEN ''m'' THEN [r].[APrice] ELSE 0.0 END AS [Price]
		, CASE [r].RecType WHEN ''m'' THEN [r].[mtQty] * [r].[APrice] ELSE 0.0 END AS [AVal] '
		
	IF (@ShowGroups > 0) 
		SET @SqlStr = @SqlStr + ' ,[path]'
	ELSE 
		SET @SqlStr = @SqlStr + ' ,'''' AS [path]'
	IF(@ShowGroups > 0 )
		SET @SqlStr = @SqlStr + ', MaterialGUID' 
	ELSE 
		SET @SqlStr = @SqlStr + ' ,0x0 AS [MaterialGUID]'
	SET @SqlStr = @SqlStr + ' ,ISNULL([r].[StName], '''') AS [StName], ISNULL([r].[StCode], '''') AS [StCode] '  
	IF (@ClassDtails > 0)  
		SET @SqlStr = @SqlStr + ' ,ISNULL([r].[ClassPtr], '''') AS ClassPtr '
	ELSE 
		SET @SqlStr = @SqlStr + ' , '''' AS [ClassPtr] '
	IF (@ShowSerialNumber > 0)  
		SET @SqlStr = @SqlStr + ' ,[r].[SERIALNUMBER] '  
	ELSE 
		SET @SqlStr = @SqlStr + ' ,'''' AS [SERIALNUMBER] '  
	IF (@ShowMatExpireDate > 0)  
		SET @SqlStr = @SqlStr + ' ,ISNULL([r].[ExpireDate], ''1980-01-01 00:00:00.000'') AS ExpireDate '  
	ELSE 
		SET @SqlStr = @SqlStr + ' ,''1980-01-01'' AS ExpireDate '  
	
	SET @SqlStr = @SqlStr + ' 
		,CASE 
			WHEN [r].[RecType] = ''m'' THEN ' +
				CASE @UseUnit
					WHEN 0 THEN ' [r].[mtQty] '
					WHEN 1 THEN ' [r].[mtQty] / (CASE [v_mt].[mtUnit2Fact] WHEN 0 THEN [mtDefUnitFact] ELSE [v_mt].[mtUnit2Fact] END) '
					WHEN 2 THEN ' [r].[mtQty] / (CASE [v_mt].[mtUnit3Fact] WHEN 0 THEN [mtDefUnitFact] ELSE [v_mt].[mtUnit3Fact] END) '
					WHEN 3 THEN ' [r].[mtQty] / [mtDefUnitFact] '
					ELSE ' [r].[mtQty] '
				END
	SET @SqlStr = @SqlStr + ' 
			ELSE [r].[mtQty] 
		END AS Qty,'
	IF @ShowUnLinked <> 1
		SET @SqlStr = @SqlStr + ' 
			CASE [mtUnit2Fact] 
				WHEN 0 THEN 0
				ELSE [r].[mtQty] / [mtUnit2Fact]
			END AS [Qty2],
			CASE [mtUnit3Fact] 
				WHEN 0 THEN 0
				ELSE [r].[mtQty] / [mtUnit3Fact]
			END AS [Qty3], 0 '
	ELSE
		SET @SqlStr = @SqlStr + ' 
				[r].[Qnt2] AS [Qty2],
				[r].[Qnt3] AS [Qty3], 0 '

	SET @SqlStr = @SqlStr + ' FROM '  
	IF @ShowGroups > 0 
	BEGIN
		SET @SqlStr = @SqlStr + ' [#MainRes3] AS [r1] LEFT JOIN [#R] AS [r] ON [r].[mtNumber] = [r1].[mtNumber]'
		IF @DetailsStores > 0 
			SET @SqlStr = @SqlStr + ' AND r.StoreGUID = r1.StoreGUID '
		IF @ShowMatExpireDate > 0
			SET @SqlStr = @SqlStr + ' AND (r.ExpireDate = r1.ExpireDate OR r1.ExpireDate IS NULL)  '
		IF @ClassDtails > 0 
			SET @SqlStr = @SqlStr + ' AND r.[ClassPtr] = r1.ClassPtr '
		SET @SqlStr = @SqlStr + ' LEFT '
	END   
	ELSE  
		SET @SqlStr = @SqlStr + ' [#R] AS [r] INNER '  
	SET @SqlStr = @SqlStr + ' JOIN [vwmtgr] AS [v_mt] ON [r].[mtNumber] = [v_mt].[mtGUID] '  
	
	EXECUTE ( @SqlStr )  
	IF @ShowDetailsUnits > 0
	BEGIN 
		UPDATE #FinalResult
		SET 
			[Quantity3] = (CASE [mtUnit3Fact] WHEN 0 THEN 0 ELSE CAST([Qnt] / [mtUnit3Fact] AS INT) END)
		WHERE 
			RecType = 'm'
		UPDATE #FinalResult
		SET 
			[Quantity2] = (CASE [mtUnit2Fact] WHEN 0 THEN 0 ELSE CAST( ([Qnt] - [Quantity3] * [mtUnit3Fact]) / [mtUnit2Fact] AS INT) END)
		WHERE 
			RecType = 'm'
		UPDATE #FinalResult
		SET 
			[Quantity1] = ([Qnt] - [Quantity3] * [mtUnit3Fact] - [Quantity2] * [mtUnit2Fact])
		WHERE 
			RecType = 'm'
	END 
	IF @ShowGroups > 0
	BEGIN 
		CREATE TABLE #GroupFinalResult (
			MtGroup UNIQUEIDENTIFIER,
			[AVal] FLOAT,
			[Qty2] FLOAT,
			[Qty3] FLOAT,
			[Quantity1] FLOAT,
			[Quantity2] FLOAT,
			[Quantity3] FLOAT
		)
		DECLARE @MaxLevel INT
		SET @MaxLevel = (SELECT MAX(grlevel) FROM #FinalResult)
		WHILE (ISNULL(@MaxLevel, 0) >= 1)
		BEGIN 
			TRUNCATE TABLE #GroupFinalResult
			INSERT INTO #GroupFinalResult
			SELECT 
				MtGroup,
				SUM([AVal]) AS [AVal],
				SUM([Qty2]),
				SUM([Qty3]),
				SUM([Quantity1]) AS [Quantity1],
				SUM([Quantity2]) AS [Quantity2],
				SUM([Quantity3]) AS [Quantity3]
			FROM 
				#FinalResult	
			WHERE  
				@StLevel <= 1 OR STLevel < @StLevel		
			GROUP BY MtGroup
			UPDATE fr
			SET 
				AVal = gr.[AVal],
				[Qty2] = gr.[Qty2],
				[Qty3] = gr.[Qty3],
				Quantity1 = gr.[Quantity1],
				Quantity2 = gr.[Quantity2],
				Quantity3 = gr.[Quantity3]
			FROM
				#FinalResult fr 
				INNER JOIN #GroupFinalResult gr ON fr.mtNumber = gr.MtGroup AND fr.grlevel = @MaxLevel
			SET @MaxLevel = @MaxLevel - 1
		END
	END 
	IF @cmpUnmctch > 0 AND (@PriceType <> 2 AND @PricePolicy <> 125)
	BEGIN 				  
		UPDATE fr
		SET NotMatchedQty = 1
		FROM 
			#FinalResult fr 
			INNER JOIN vwMs ms ON ms.MsMatPtr = fr.mtNumber AND ms.MsStorePtr = fr.StorePtr
		WHERE 
			ABS(ms.msQty - fr.Qnt) > @Zero 
			AND 
			fr.RecType = 'm'
	END 
	
	--IF @ShowGroups > 0 AND @ShowDetailsUnits = 0
	IF @ShowDetailsUnits = 0
	BEGIN 
		UPDATE #FinalResult
		SET Price = CASE Qty WHEN 0 THEN Price ELSE AVal / Qty END 
	END 
	
	--==================================================================
	IF (@ShowGroups > 0)
	BEGIN
		  UPDATE [#FinalResult]
		  SET [MaterialGUID] = NEWID()
		  WHERE [RecType]= 'm';
	END  
	-- Main result
	SELECT 
		*,
		CASE WHEN [RecType] = 'm' THEN [mtNumber] ELSE 0x0 END AS OnlyMaterialGuid
	FROM 
		#FinalResult
	ORDER BY MtName , MtCode 
	
	-- Totals result (3 rows)
	SELECT
		'1' AS TotalsStr,
		SUM(AVal) AS TotalPrice,
		SUM(Qty) AS TotalQty,
		SUM(Qty2) AS TotalQty2,
		SUM(Qty3) AS TotalQty3,
		SUM(Quantity1) AS TotalQtyDetails1,
		SUM(Quantity2) AS TotalQtyDetails2,
		SUM(Quantity3) AS TotalQtyDetails3
	FROM 
		#FinalResult
	WHERE 
		RecType != 'g' 
		AND (AVal > 0 OR Qty > 0)
		AND ((@StLevel <= 1) OR (STLevel < @StLevel))
	UNION ALL 
	SELECT
		'2' AS TotalsStr,
		SUM(AVal) AS TotalPrice,
		SUM(Qty) AS TotalQty,
		SUM(Qty2) AS TotalQty2,
		SUM(Qty3) AS TotalQty3,
		SUM(Quantity1) AS TotalQtyDetails1,
		SUM(Quantity2) AS TotalQtyDetails2,
		SUM(Quantity3) AS TotalQtyDetails3
	FROM 
		#FinalResult
	WHERE 
		RecType != 'g' 
		AND (AVal < 0 OR Qty < 0)
		AND ((@StLevel <= 1) OR (STLevel < @StLevel))
	UNION ALL 
	SELECT
		'3' AS TotalsStr,
		SUM(AVal) AS TotalPrice,
		SUM(Qty) AS TotalQty,
		SUM(Qty2) AS TotalQty2,
		SUM(Qty3) AS TotalQty3,
		SUM(Quantity1) AS TotalQtyDetails1,
		SUM(Quantity2) AS TotalQtyDetails2,
		SUM(Quantity3) AS TotalQtyDetails3
	FROM 
		#FinalResult
	WHERE 
		RecType != 'g' 
		AND ((@StLevel <= 1) OR (STLevel < @StLevel))
	SELECT * FROM [#SecViol]    
###########################################################
#END
