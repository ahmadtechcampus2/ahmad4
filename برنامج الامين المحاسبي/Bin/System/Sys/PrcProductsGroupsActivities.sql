#####################################################################
CREATE PROCEDURE prcProductsGroupsActivity
	@StartDate 			[DATETIME],   
	@EndDate 			[DATETIME],   
	@PrevStartDate 		[DATETIME],   
	@PrevEndDate 		[DATETIME],   
	@MatPtr 			[UNIQUEIDENTIFIER], -- 0 All Mat or MatNumber   
	@GroupPtr 			[UNIQUEIDENTIFIER],   
	@StorePtr 			[UNIQUEIDENTIFIER], -- 0 all stores so don't check store or list of stores   
	@CostPtr 			[UNIQUEIDENTIFIER], -- 0 all costs so don't Check cost or list of costs   
	@MatType 			[INT], -- 0 Store or 1 Service or -1 ALL   
	@CurrencyPtr 		[UNIQUEIDENTIFIER],   
	@CurrencyVal 		[FLOAT],   
	@DetailsStores 		[INT], -- 1 show details 0 no details   
	@ShowEmpty 			[INT], --1 Show Empty 0 don't Show Empty   
	@SrcTypes 			[UNIQUEIDENTIFIER],   
	@PriceType 			[INT],   
	@PricePolicy 		[INT],   
	@ShowUnLinked 		[INT] = 0,   
	@Acc 				[UNIQUEIDENTIFIER] = 0x0,-- 0 all acounts or one cust when @ForCustomer not 0 or AccNumber   
	@CustPtr 			[UNIQUEIDENTIFIER] = 0x0, -- 0 all custs or group of custs when @ForAccount not 0 or CustNumber   
	@ShowGroups 		[INT] = 0, -- if 0 matonly if 1 mats and groups if 2 groups only     
	@UseCostInOutPut 	[INT] = 0,   
	@UseUnit 			[INT],   
	@ShowMtFldsFlag		[BIGINT] = 0,   
	@Lang				[BIT] = 0,   
	@ShowOnlyMoved		[BIT] = 0,   
	@MatCondGuid		[UNIQUEIDENTIFIER] = 0x00,   
	@GrpLevel		[INT] = 0 ,  	  
	@ShowStoreProducts bit,  
	@ShowServiceProducts bit, 
	@ShowAssestProducts bit 
	
AS  
	SET NOCOUNT ON  
	
	DECLARE @sql AS [NVARCHAR](max),@Cnt [INT]  
	-- Creating temporary tables  
	CREATE TABLE [#SecViol]( [Type] [INT], [Cnt] [INTEGER])  
	CREATE TABLE [#MatTbl]( [MatGUID] [UNIQUEIDENTIFIER], [mtSecurity] [INT])  
	CREATE TABLE [#BillsTypesTbl]( [TypeGuid] [UNIQUEIDENTIFIER], [UserSecurity] [INTEGER], UserReadPriceSecurity [INTEGER],[UnPostedSecurity] [INT])  
	CREATE TABLE [#BillsTypesTb2]( [TypeGuid] [UNIQUEIDENTIFIER], [UserSecurity] [INTEGER], UserReadPriceSecurity [INTEGER],[UnPostedSecurity] [INT])  
	CREATE TABLE [#StoreTbl](	[StoreGUID] [UNIQUEIDENTIFIER], [Security] [INT])  
	CREATE TABLE [#CostTbl]( [CostGUID] [UNIQUEIDENTIFIER], [Security] [INT])  
	CREATE TABLE [#CustTbl]( [CustGUID] [UNIQUEIDENTIFIER], [Security] [INT])  
	CREATE TABLE [#Grp]([Guid] [UNIQUEIDENTIFIER], [Level] INT, [Code] NVARCHAR(250), [Name] NVARCHAR(250), [LatinName] NVARCHAR(250), [ParentGuid] [UNIQUEIDENTIFIER])
		  
	--Filling temporary tables  
	INSERT INTO [#MatTbl]			EXEC [prcGetMatsList] 		@MatPtr, @GroupPtr, @MatType,@MatCondGuid  
	INSERT INTO [#BillsTypesTb2]	EXEC [prcGetBillsTypesList2] 	0x0  
	INSERT INTO [#BillsTypesTbl]	EXEC [prcGetBillsTypesList2] 	@SrcTypes
	INSERT INTO [#StoreTbl]		EXEC [prcGetStoresList] 		@StorePtr  
	INSERT INTO [#CostTbl]		EXEC [prcGetCostsList] 		@CostPtr  
	INSERT INTO [#CustTbl]		EXEC [prcGetCustsList] 		@CustPtr, @Acc  
	  
	IF @SrcTypes IS NULL  
		SET @SrcTypes = ''  
	IF [dbo].[fnGetUserMaterialSec_Balance]([dbo].[fnGetCurrentUserGuid]()) > 0  
		begin
		update [#BillsTypesTbl] set [userSecurity] = [dbo].[fnGetMaxSecurityLevel]()
		update [#BillsTypesTb2] set [userSecurity] = [dbo].[fnGetMaxSecurityLevel]()
		end  
	if [dbo].[fnGetUserMaterialSec_Balance]([dbo].[fnGetCurrentUserGuid]()) <= 0  
			RETURN  
	--SELECT * from #BillsTypesTbl  
	CREATE TABLE [#MainResult] (  
		[MtNumber]		[UNIQUEIDENTIFIER],  
		[PrevBalQnt]	[FLOAT] DEFAULT 0,  
		[PrevBalAPrice]	[FLOAT] DEFAULT 0,  
		  
		[SumInQty]		[FLOAT] DEFAULT 0,  
		[SumOutQty]		[FLOAT] DEFAULT 0,  
		[SumInBonusQty]	[FLOAT] DEFAULT 0,  
		[SumOutBonusQty][FLOAT] DEFAULT 0,  
		  
		[SumInPrice]	[FLOAT] DEFAULT 0,  
		[SumOutPrice]	[FLOAT] DEFAULT 0,  
		[SingleInPrice]	[FLOAT] DEFAULT 0,  
		[SingleOutPrice][FLOAT] DEFAULT 0,  
		  
		[SumInExtra]	[FLOAT] DEFAULT 0,  
		[SumOutExtra]	[FLOAT] DEFAULT 0,  
		[SumInDisc]		[FLOAT] DEFAULT 0,  
		[SumOutDisc]	[FLOAT] DEFAULT 0,  
		[SumInDiscVal]	[FLOAT] DEFAULT 0,  
		[SumOutDiscVal]	[FLOAT] DEFAULT 0,  
		[EndBalQnt]		[FLOAT] DEFAULT 0,  
		[EndBalAPrice]	[FLOAT] DEFAULT 0,  
		[mtUnity]		[NVARCHAR](256) COLLATE ARABIC_CI_AI,  
		[mtUnit2]		[NVARCHAR](256) COLLATE ARABIC_CI_AI,  
		[mtUnit3]		[NVARCHAR](256) COLLATE ARABIC_CI_AI,  
		[mtDefUnitFact]	[FLOAT],  
		[grName]		[NVARCHAR](256) COLLATE ARABIC_CI_AI,  
		[grCode]		[NVARCHAR](256) COLLATE ARABIC_CI_AI,  
		[mtName]		[NVARCHAR](256) COLLATE ARABIC_CI_AI,  
		[mtCode]		[NVARCHAR](256) COLLATE ARABIC_CI_AI,  
		[mtLatinName]	[NVARCHAR](256) COLLATE ARABIC_CI_AI,  
		[mtUnit2Fact]	[FLOAT],  
		[mtUnit3Fact]	[FLOAT],
		[mtVAT]			[FLOAT],  
		[mtBarCode]		[NVARCHAR](256) COLLATE ARABIC_CI_AI,  
		[mtSpec]		[NVARCHAR](1000) COLLATE ARABIC_CI_AI,  
		[mtDim]			[NVARCHAR](256) COLLATE ARABIC_CI_AI,  
		[mtOrigin]		[NVARCHAR](256) COLLATE ARABIC_CI_AI,  
		[mtPos]			[NVARCHAR](256) COLLATE ARABIC_CI_AI,  
		[mtCompany]		[NVARCHAR](256) COLLATE ARABIC_CI_AI,  
		[mtColor]		[NVARCHAR](256) COLLATE ARABIC_CI_AI,  
		[mtProvenance]	[NVARCHAR](256) COLLATE ARABIC_CI_AI,  
		[mtQuality]		[NVARCHAR](256) COLLATE ARABIC_CI_AI,  
		[mtModel]		[NVARCHAR](256) COLLATE ARABIC_CI_AI,  
		[mtType]		[INT],  
		[mtDefUnitName]	[NVARCHAR](256) COLLATE ARABIC_CI_AI,  
		[MtGroup]		[UNIQUEIDENTIFIER],  
		[GroupParentPtr][UNIQUEIDENTIFIER] DEFAULT 0x0,  
		[RecType] 		[NVARCHAR](1) COLLATE ARABIC_CI_AI DEFAULT 'm' NOT NULL,  
		[Level] 		[INT] DEFAULT 0 NOT NULL,  
		[mtBarCode2]	[NVARCHAR](256) COLLATE ARABIC_CI_AI,  
		[mtBarCode3]	[NVARCHAR](256) COLLATE ARABIC_CI_AI,  
		[Sumcurcost]	[FLOAT],
		[MaterialGuid]	[UNIQUEIDENTIFIER]
		)  
		CREATE TABLE [#MainResult2](     
				[MtNumber] [UNIQUEIDENTIFIER], [PrevBalQnt] FLOAT,  
				[PrevBalAPrice] FLOAT, [SumInQty] FLOAT, [SumOutQty] FLOAT,  
				[SumInBonusQty] FLOAT, [SumOutBonusQty] FLOAT,  
				[SumInPrice] FLOAT, [SumOutPrice] FLOAT,  
				[EndBalQnt] FLOAT, [EndBalAPrice] FLOAT,  
				[mtName] [NVARCHAR](256), [mtCode] [NVARCHAR](256),
				[mtLatinName] [NVARCHAR](256), [MtGroup] [NVARCHAR](256),
				[RecType] [NVARCHAR](1), [Level] INT, [Sumcurcost] FLOAT
		)
	CREATE TABLE [#InOutResult] (  
		[MtPtr]			[UNIQUEIDENTIFIER],  
		[mtName]		[NVARCHAR](256) COLLATE ARABIC_CI_AI,  
		[mtCode]		[NVARCHAR](256) COLLATE ARABIC_CI_AI,  
		[mtLatinName]	[NVARCHAR](256) COLLATE ARABIC_CI_AI,  
		[mtUnity]		[NVARCHAR](256) COLLATE ARABIC_CI_AI,   
		[mtUnit2]		[NVARCHAR](256) COLLATE ARABIC_CI_AI,  
		[mtUnit3]		[NVARCHAR](256) COLLATE ARABIC_CI_AI,  
		[mtDefUnitName]	[NVARCHAR](256) COLLATE ARABIC_CI_AI,  
		[SumInQty]		[FLOAT],  
		[SumOutQty]		[FLOAT],  
		[SumInQty2]		[FLOAT],  
		[SumOutQty2]	[FLOAT],  
		[SumInQty3]		[FLOAT],  
		[SumOutQty3]	[FLOAT],  
		[SumInBonusQty]	[FLOAT],  
		[SumOutBonusQty][FLOAT],  
		[SumInPrice]	[FLOAT],  
		[SumInVat]		[FLOAT],  
		[SumOutPrice]	[FLOAT],  
		[SumOutVat]		[FLOAT],  
		[SumInExtra]	[FLOAT],  
		[SumOutExtra]	[FLOAT],  
		[SumInDisc]		[FLOAT],  
		[SumOutDisc]	[FLOAT],  
		[SumInDiscVal]	[FLOAT],  
		[SumOutDiscVal]	[FLOAT],  
		[InFixedBiTotalPrice] [FLOAT],  
		[OutFixedBiTotalPrice] [FLOAT],  
		[Sumcurcost]	[FLOAT]  
		)  
	--calc EndBal  
	--Get Qtys  
		CREATE TABLE [#t_Qtys]  
		(  
			[mtNumber] 	[UNIQUEIDENTIFIER],  
			[Qnt] 		[FLOAT],  
			[Qnt2] 		[FLOAT],  
			[Qnt3] 		[FLOAT],  
			[StoreGUID]	[UNIQUEIDENTIFIER]  
		)  
		CREATE TABLE [#t_Prices]  
		(  
			[mtNumber] 	[UNIQUEIDENTIFIER],  
			[APrice]	[FLOAT]  
		)  
	---- Get Qtys And Prices  
		CREATE TABLE [#PricesQtys]  
		(  
			[mtNumber]	[UNIQUEIDENTIFIER],  
			[APrice]	[FLOAT],  
			[Qnt]		[FLOAT],  
			[Qnt2]		[FLOAT],  
			[Qnt3]		[FLOAT],  
			[StoreGUID]	[UNIQUEIDENTIFIER]  
		)   
		IF @MatType >= 3  
			SET @MatType = -1  
		
		EXEC [prcGetQntPrice] @PrevStartDate, @EndDate, @MatPtr, @GroupPtr, @StorePtr, @CostPtr, @MatType, @CurrencyPtr,	@CurrencyVal, @SrcTypes, @PriceType, @PricePolicy, @ShowUnLinked, @UseUnit  
		IF @ShowEmpty = 1  
			INSERT INTO [#PricesQtys] SELECT [MatGUID], 0, 0, 0, 0, 0X0 FROM [#MatTbl] WHERE [MatGUID] NOT IN (SELECT [mtNumber] FROM [#PricesQtys])  
		--calc Inout Move  
		
		EXEC [prcCalcInOutMtMove]	@StartDate,	@EndDate, @SrcTypes, @MatPtr, @GroupPtr, 1/*@PostedValue*/, 0/*@Vendor*/, 0/*@SalesMan*/, ''/*@NotesContain*/, ''/*@NotesNotContain*/, @CustPtr, @StorePtr, @CostPtr, @Acc, @CurrencyPtr, @CurrencyVal, @MatType, @UseUnit  
		  
		  
		UPDATE [#InOutResult]  
			SET [SumInPrice] =[InFixedBiTotalPrice] ,[SumOutPrice] = [OutFixedBiTotalPrice]  
		  
		SET @sql = '			  
		INSERT INTO [#MainResult]  
		(  
			[Sumcurcost],  
			[MtNumber],  
			[PrevBalQnt],  
			[PrevBalAPrice],  
			[SumInQty],  
			[SumOutQty],  
			[SumInBonusQty],  
			[SumOutBonusQty],  
			[SumInPrice],  
			[SumOutPrice],  
			[SingleInPrice],  
			[SingleOutPrice],  
			[SumInExtra],  
			[SumOutExtra],  
			[SumInDisc],  
			[SumOutDisc],  
			[SumInDiscVal],  
			[SumOutDiscVal],  
			[EndBalQnt],  
			[EndBalAPrice],  
			[mtUnity],  
			[mtUnit2],  
			[mtUnit3],  
			[mtDefUnitFact],'  
		IF (@ShowMtFldsFlag & 0x00040000)  > 0  
			SET @sql = @sql + '[grName],[grCode],'  
		SET @sql = @sql + '[mtName],[mtCode],[mtLatinName],  
			[mtUnit2Fact],[mtUnit3Fact],[mtBarCode],  
			[mtSpec],[mtDim],[mtOrigin],  
			[mtPos],[mtCompany],[mtColor],  
			[mtProvenance],[mtQuality],[mtModel],  
			[mtType],[mtDefUnitName],  
			[MtGroup],[mtBarCode2],[mtBarCode3],[mtVAT]
			,[MaterialGuid]
		)  
		SELECT  
			[t].[Sumcurcost],  
			[pr].[MtNumber],  
			0,0,  
			ISNULL([t].[SumInQty],0),  
			ISNULL([t].[SumOutQty],0),  
			ISNULL([t].[SumInBonusQty],0),  
			ISNULL([t].[SumOutBonusQty],0),  
			ISNULL([t].[SumInPrice],0),  
			ISNULL([t].[SumOutPrice],0),  
			ISNULL([t].[SumInPrice] / (CASE ([t].[SumInQty] + [t].[SumInBonusQty]) WHEN 0 THEN 1 ELSE ([t].[SumInQty] + [t].[SumInBonusQty]) END),0),  
			ISNULL([t].[SumOutPrice] / (CASE ([t].[SumOutQty] + [t].[SumOutBonusQty]) WHEN 0 THEN 1 ELSE ([t].[SumOutQty] + [t].[SumOutBonusQty]) END),0),  
			ISNULL([t].[SumInExtra],0),  
			ISNULL([t].[SumOutExtra],0),  
			ISNULL([t].[SumInDisc],0),  
			ISNULL([t].[SumOutDisc],0),  
			ISNULL([t].[SumInDiscVal],0),  
			ISNULL( [t].[SumOutDiscVal],0),  
			[pr].[Qnt] AS [EndBalQnt], '
			 
			IF @priceType =32768 
			SET @sql= @sql+'dbo.fnGetOutbalanceAveragePrice([pr].[MtNumber],'''+cast(@EndDate as nvarchar(max))+''') /dbo.fnGetCurVal('''+CAST(@CurrencyPtr AS NVARCHAR(MAX))+''','''+CAST(@EndDate AS NVARCHAR(MAX))+''') AS [EndBalAPrice], '
			ELSE
			SET @sql= @sql+' [pr].[APrice] AS [EndBalAPrice], '
			
			SET @sql=@sql+' 
			[mt].[mtUnity],  
			[mt].[mtUnit2],  
			[mt].[mtUnit3],  
			[mt].[mtDefUnitFact],'  
			IF (@ShowMtFldsFlag & 0x00040000)  > 0  
				SET @sql = @sql + 'CASE  ' + CAST (@LANG AS NVARCHAR(2)) +' WHEN 0 THEN [grName] ELSE CASE [grLatinName] WHEN '+ '''' + '''' +' THEN [grName] ELSE [grLatinName] END END,[grCode],'  
			SET @sql = @sql + '[mt].[mtName],[mt].[mtCode],  
			[mt].[mtLatinName],[mt].[mtUnit2Fact],[mt].[mtUnit3Fact],  
			[mt].[mtBarCode],[mt].[mtSpec],  
			[mt].[mtDim],[mt].[mtOrigin],  
			[mt].[mtPos],[mt].[mtCompany],  
			[mt].[mtColor],  
			[mt].[mtProvenance],  
			[mt].[mtQuality],  
			[mt].[mtModel],  
			[mt].[mtType],  
			[mt].[mtDefUnitName],  
			[mt].[MtGroup],  
			[mt].[mtBarCode2],  
			[mt].[mtBarCode3],
			[mt].[mtVAT],
			[pr].[MtNumber]
		FROM [#PricesQtys] AS [pr] '  
		IF @ShowOnlyMoved = 1  
			SET @sql = @sql + ' INNER'  
		ELSE  
			SET @sql = @sql + 'LEFT'  
		SET @sql = @sql + ' JOIN [#InOutResult] AS [t] ON [pr].[MtNumber] = [t].[MtPtr]'  
		SET @sql = @sql + ' INNER JOIN [vwmt] AS [mt] ON [pr].[MtNumber] = [mt].[MtGUID]'  
		IF (@ShowMtFldsFlag & 0x00040000)  > 0  
			SET @sql = @sql + ' INNER JOIN [vwGr] AS [gr] ON [mt].[mtgroup] = [GR].[grGuid]'  
		EXEC (@sql)  
		--calc PrevBal  
		--DELETE FROM #Result2  
		--INSERT INTO #Result2 EXEC prcCallPricesProcs @PrevStartDate, @PrevEndDate,@MatPtr,@GroupPtr,@StorePtr,@CostPtr,@MatType,@CurrencyPtr,@CurrencyVal,@UserId,@CondId,@DetailsStores,@ShowEmpty, @SrcTypes, @PriceType, @PricePolicy, @SortType, @ShowUnLinked, @AccPtr, @CustPtr, 0/* ShowGroups*/,@CalcPrices, @UseUnit  
		TRUNCATE TABLE [#t_Qtys]  
		TRUNCATE TABLE [#t_Prices]  
		TRUNCATE TABLE [#PricesQtys]  
		
		EXEC [prcGetQntPrice] @PrevStartDate, @PrevEndDate, @MatPtr, @GroupPtr, @StorePtr, @CostPtr, @MatType, @CurrencyPtr,	@CurrencyVal, @SrcTypes, @PriceType, @PricePolicy, @ShowUnLinked, @UseUnit  
		  
		UPDATE [#MainResult]  
			SET [PrevBalQnt] = [t].[Qnt], 
			[PrevBalAPrice] = (case @priceType when 32768 then dbo.fnGetOutbalanceAveragePrice([t].[MtNumber],@StartDate )/dbo.fnGetCurVal(@CurrencyPtr ,@StartDate)  ELSE [t].[APrice] END )
		FROM  
		(   
			SELECT [Qnt], [APrice], [mtNumber] FROM [#PricesQtys]  
		)AS [t]   
		WHERE [#MainResult].[MtNumber] = [t].[mtNumber]  
	--	Modify Qty As Selected Unit  
	---- Update Single Price for PrevBal And EndBalbalances: Price * uf  
		UPDATE [#MainResult]  
		SET  
			[PrevBalQnt] 		= [PrevBalQnt] / CASE @UseUnit WHEN 1 THEN (CASE [mtUnit2Fact] WHEN 0 THEN 1 ELSE [mtUnit2Fact] END)  
														WHEN 2 THEN (CASE [mtUnit3Fact] WHEN 0 THEN 1 ELSE [mtUnit3Fact] END)  
														WHEN 3 THEN (CASE [mtDefUnitFact] WHEN 0 THEN 1 ELSE [mtDefUnitFact] END)  
														ELSE 1  
											END,  
			[EndBalQnt] 		= [EndBalQnt] / CASE @UseUnit WHEN 1 THEN (CASE [mtUnit2Fact] WHEN 0 THEN 1 ELSE [mtUnit2Fact] END)  
														WHEN 2 THEN (CASE [mtUnit3Fact] WHEN 0 THEN 1 ELSE [mtUnit3Fact] END)  
														WHEN 3 THEN (CASE [mtDefUnitFact] WHEN 0 THEN 1 ELSE [mtDefUnitFact] END)  
														ELSE 1  
											END,  
			[PrevBalAPrice] 	= [PrevBalAPrice] * CASE @UseUnit WHEN 1 THEN (CASE [mtUnit2Fact] WHEN 0 THEN 1 ELSE [mtUnit2Fact] END)  
														WHEN 2 THEN (CASE [mtUnit3Fact] WHEN 0 THEN 1 ELSE [mtUnit3Fact] END)  
														WHEN 3 THEN (CASE [mtDefUnitFact] WHEN 0 THEN 1 ELSE [mtDefUnitFact] END)  
														ELSE 1  
											END,  
			[EndBalAPrice] 	= [EndBalAPrice] * CASE @UseUnit WHEN 1 THEN (CASE [mtUnit2Fact] WHEN 0 THEN 1 ELSE [mtUnit2Fact] END)  
														WHEN 2 THEN (CASE [mtUnit3Fact] WHEN 0 THEN 1 ELSE [mtUnit3Fact] END)  
														WHEN 3 THEN (CASE [mtDefUnitFact] WHEN 0 THEN 1 ELSE [mtDefUnitFact] END)  
														ELSE 1  
											END  
	--------  
	IF @UseCostInOutPut = 1  
		UPDATE [#MainResult]  
			--SET SumOutQty = PrevBalQnt + [SumInQty] - [EndBalQnt],  
				SET --[SumOutQty] = [PrevBalQnt] + [SumInQty] + [SumInBonusQty] - [EndBalQnt] - [SumOutBonusQty],  
					[SumOutPrice] = [EndBalAPrice]*[SumOutQty],[SingleOutPrice] = [EndBalAPrice]-- ([PrevBalAPrice] * PrevBalQnt) + SumInPrice - ([EndBalQnt] * [EndBalAPrice])  
	  
	-------------------------  
		--add Groups IF @ShowGroups = 1  
		IF @ShowGroups > 0  
		BEGIN  
			INSERT INTO [#Grp] SELECT [f].[Guid],[Level],[Code],[Name],[LatinName],[ParentGuid]     
			FROM [dbo].[fnGetGroupsListByLevel](@GroupPtr,0) AS [f] INNER JOIN [gr000] AS [gr] ON [gr].[Guid] = [f].[Guid]  
			DECLARE @Level [INT]  
			SET @Level = 0  
			-- start looping:   
			INSERT INTO [#MainResult] (  
				[MtNumber],[PrevBalQnt],  
				[PrevBalAPrice],  
				[SumInQty],[SumOutQty],  
				[SumInBonusQty],[SumOutBonusQty],  
				[SumInPrice],[SumOutPrice],  
				[EndBalQnt],[EndBalAPrice],  
				[mtName],[mtCode],[mtLatinName],[MtGroup],[RecType],[Level],[Sumcurcost])  
			SELECT [GUID],SUM([PrevBalQnt]),SUM(PrevBalAPrice),  
			SUM([SumInQty]),SUM([SumOutQty]),SUM([SumInBonusQty]),SUM([SumOutBonusQty]),  
			SUM([SumInPrice]),SUM([SumOutPrice]),SUM([EndBalQnt]),SUM([EndBalAPrice])  
			,[Name],[Code],[LatinName],[gr].[ParentGuid] ,'g',[gr].[Level],SUM([Sumcurcost]*[SumOutQty])  
			FROM [#Grp] AS [gr] INNER JOIN [#MainResult] AS [r] ON [gr].[Guid] = [r].[MtGroup]  
			GROUP BY [GUID],[Name],[Code],[LatinName],[gr].[ParentGuid] ,[gr].[Level]	  
			  
			SELECT @Level = MAX([Level]) FROM [#MainResult] WHERE [RecType] = 'g'  
			  
			WHILE @Level > 1  
			BEGIN  
				  
				INSERT INTO [#MainResult] (  
				[MtNumber],[PrevBalQnt],  
				[PrevBalAPrice],  
				[SumInQty],[SumOutQty],  
				[SumInBonusQty],[SumOutBonusQty],  
				[SumInPrice],[SumOutPrice],  
				[EndBalQnt],[EndBalAPrice],  
				[mtName],[mtCode],[mtLatinName],[MtGroup],[RecType],[Level],[Sumcurcost])  
				SELECT [GUID],SUM([PrevBalQnt]),SUM(PrevBalAPrice),  
				SUM([SumInQty]),SUM([SumOutQty]),SUM([SumInBonusQty]),SUM([SumOutBonusQty]),  
				SUM([SumInPrice]),SUM([SumOutPrice]),SUM([EndBalQnt]),SUM([EndBalAPrice]),  
				[Name],[Code],[LatinName],[gr].[ParentGuid] ,'g',[gr].[Level],SUM([Sumcurcost]*[SumOutQty])  
				FROM [#Grp] AS [gr] INNER JOIN [#MainResult] AS [r] ON [gr].[Guid] = [r].[MtGroup]  
				WHERE [r].[Level]= @Level AND [RecType] = 'g'  
				GROUP BY [GUID],[Name],[Code],[LatinName],[gr].[ParentGuid] ,[gr].[Level]		  
			  
				SET @Level = @Level - 1  
			END   
			 INSERT INTO [#MainResult2] 
			 SELECT     
				[MtNumber],SUM([PrevBalQnt]) AS [PrevBalQnt],  
				SUM([PrevBalAPrice]) AS [PrevBalAPrice] ,  
				SUM([SumInQty]) AS [SumInQty],SUM([SumOutQty]) AS [SumOutQty],  
				SUM([SumInBonusQty]) AS [SumInBonusQty],SUM([SumOutBonusQty]) AS [SumOutBonusQty],  
				SUM([SumInPrice]) AS [SumInPrice],SUM([SumOutPrice])AS [SumOutPrice],  
				SUM([EndBalQnt]) AS [EndBalQnt],SUM([EndBalAPrice]) AS [EndBalAPrice],  
				[mtName],[mtCode],[mtLatinName],[MtGroup],[RecType],[Level],SUM([Sumcurcost]) AS [Sumcurcost]   
			FROM [#MainResult] WHERE [RecType] = 'g'  
			GROUP BY  
				[MtNumber],[mtName],[mtCode],[mtLatinName],[MtGroup],[RecType],[Level]  
			DELETE [#MainResult] WHERE [RecType] = 'g'  
			INSERT INTO [#MainResult] (  
				[MtNumber],[PrevBalQnt],  
				[PrevBalAPrice],  
				[SumInQty],[SumOutQty],  
				[SumInBonusQty],[SumOutBonusQty],  
				[SumInPrice],[SumOutPrice],  
				[EndBalQnt],[EndBalAPrice],  
				[mtName],[mtCode],[mtLatinName],[MtGroup],[RecType],[Level],[Sumcurcost])  
			SELECT * FROM [#MainResult2]  
			  
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
		END  
	--- check sec  
	EXEC prcCheckSecurity @Result = '#MainResult'  
	-- return result to caller:  
		IF @ShowGroups = 2	-- groups Only  
			DELETE FROM [#MainResult] WHERE [RecType] = 'm'  
	  
	SET @sql = ' SELECT '  
	  
	  
	SET @sql =  @sql + '  
		[r].[Sumcurcost],
		[r].[MaterialGuid],
		[r].[mtNumber], 
		[r].[mtName] AS [MtName], 
		ISNULL( [r].[PrevBalQnt], 0) AS [PrevBalQnt],  
		ISNULL( [r].[PrevBalAPrice], 0) AS [PrevBalAPrice],  
		ISNULL( [r].[SumInQty], 0) AS [SumInQty],  
		ISNULL( [r].[SumOutQty], 0) AS [SumOutQty],  
		ISNULL( [r].[SumInBonusQty], 0) AS [SumInBonusQty],  
		ISNULL( [r].[SumOutBonusQty], 0) AS [SumOutBonusQty],  
		ISNULL( [r].[SumInPrice], 0) AS [SumInPrice],   
		ISNULL( [r].[SumOutPrice], 0) AS [SumOutPrice],  
		ISNULL( [r].[SingleInPrice], 0) AS [SingleInPrice],  
		ISNULL( [r].[SingleOutPrice], 0) AS [SingleOutPrice],  
		ISNULL( [r].[EndBalQnt], 0) AS [EndBalQnt],  
		ISNULL( [r].[EndBalAPrice], 0) AS [EndBalAPrice],'  
		--IF @ShowMtFldsFlag & 0x00000020 > 0	  
			SET @sql =  @sql +'[r].[mtUnity] AS [mtUnity],'  
		SET @sql =  @sql + '[r].[mtUnit2] AS [mtUnit2],  
			 [r].[mtUnit3] AS [mtUnit3],  
			 [r].[mtDefUnitFact] AS [mtDefUnitFact],  
			 [r].[grName] AS [grName],[r].[grCode] AS [grCode],'  
		--IF @ShowMtFldsFlag & 0x00000002 > 0  
		--	SET @sql =  @sql + '[r].[mtName] AS [mtName],'  
		--IF @ShowMtFldsFlag & 0x00000001 > 0  
			SET @sql =  @sql + '[r].[mtCode] AS [MtCode],'  
		IF @ShowMtFldsFlag & 0x00000004 > 0  
			SET @sql =  @sql + '[r].[mtLatinName] AS [mtLatinName],'  
		SET @sql =  @sql + '[mtUnit2Fact] AS [mtUnit2Fact],  
			[r].[mtUnit3Fact] AS [mtUnit3Fact],  
			[r].[mtBarCode] AS [mtBarCode],'  
		IF @ShowMtFldsFlag & 0x00000200 > 0  
			SET @sql =  @sql + '[r].[mtSpec] AS [mtSpec],'  
		IF @ShowMtFldsFlag & 0x00000400 > 0  
			SET @sql =  @sql + ' [r].[mtDim] AS [mtDim],'  
		IF @ShowMtFldsFlag & 0x00000800 > 0  
			SET @sql =  @sql + ' [r].[mtOrigin] AS [mtOrigin],'  
		IF @ShowMtFldsFlag & 0x00001000 > 0	  
			SET @sql =  @sql + '[r].[mtPos] AS [mtPos],'  
		IF @ShowMtFldsFlag & 0x00020000 > 0  
			SET @sql =  @sql + '[r].[mtCompany] AS [mtCompany],'  
		IF @ShowMtFldsFlag & 0x00080000 > 0  
			SET @sql =  @sql + '[r].[mtColor] AS [mtColor],'  
		IF @ShowMtFldsFlag & 0x00100000 > 0  
			SET @sql =  @sql + '[r].[mtProvenance] AS [mtProvenance],'  
		IF @ShowMtFldsFlag & 0x00200000 > 0  
			SET @sql =  @sql + '[r].[mtQuality] AS [mtQuality],'  
		IF @ShowMtFldsFlag & 0x00400000 > 0	  
			SET @sql =  @sql +'[r].[mtModel] AS [mtModel],'
		IF @ShowMtFldsFlag & 0x02000000 > 0	   
			SET @sql =  @sql +'[r].[mtVAT] AS [mtVAT],'  
		  
		--SET @sql =  @sql + '[r].[mtType] AS [mtType],'  
		SET @sql =  @sql +'[r].[mtDefUnitName] AS [mtDefUnitName],  
			[r].[MtGroup] AS [MtGroup],  
			ISNULL( [r].[GroupParentPtr], 0x0) AS [GroupParentPtr],  
			ISNULL( [r].[RecType], ''m'') AS [RecType],  
			ISNULL( [r].[Level], 0) AS [Level]'  
		IF @ShowMtFldsFlag & 0x00800000 > 0  
			SET @sql =  @sql +',[r].[mtBarCode2] AS [mtBarCode2]'  
		IF @ShowMtFldsFlag & 0x01000000 > 0  
			SET @sql =  @sql +',[r].[mtBarCode3]  AS [mtBarCode3] '  
	IF @UseUnit = 1   
		SET @Sql = @Sql + ',CASE [mtUnit2Fact] WHEN 0 THEN 1 ELSE [mtUnit2Fact] END AS [mtUnitFact]'  
	IF @UseUnit = 2   
		SET @Sql = @Sql + ',CASE [mtUnit3Fact] WHEN 0 THEN 1 ELSE [mtUnit3Fact] END AS [mtUnitFact]'  
	IF @UseUnit = 3   
		SET @Sql = @Sql + ',[mtDefUnitFact] AS [mtUnitFact]'  
	
	-------------------------------------------------------------------------------------------------------  
	SET @sql =  @sql +' FROM [#MainResult] AS [r]'  
	------------------------------------------------------------------------------------------------------    
	 
	 
	SET @sql =  @sql +' WHERE RecType = ''g''' 
	IF @ShowStoreProducts = 1 
	BEGIN 
		SET @sql = @sql + ' OR mtType = 0'  
	END 
	IF @ShowServiceProducts = 1 
	BEGIN 
		SET @sql = @sql + ' OR mtType = 1' 			 
	END	 
	IF @ShowAssestProducts = 1 
	BEGIN 
		SET @sql = @sql + ' OR mtType = 2' 
	END	 
	IF @ShowEmpty = 0 
		SET @sql = @sql + ' AND (PrevBalQnt != 0 OR EndBalQnt != 0 OR SumInQty != 0 OR SumOutQty != 0)' 	 						 
	 
	SET @Sql = @Sql + ' ORDER BY [mtCode]'  
	 
	UPDATE #MainResult SET GroupParentPtr = MtGroup 
		WHERE RecType = 'g' 
	EXEC( @Sql)  
	SELECT *FROM [#SecViol]  
/*  
prcConnections_add2 '„œÌ—'  
exec  [prcProductsGroupsActivity] '7/27/2013 0:0:0.0', '12/31/2013 0:0:0.0', '1/1/2013', '7/26/2013', '00000000-0000-0000-0000-000000000000', '00000000-0000-0000-0000-000000000000', '00000000-0000-0000-0000-000000000000', '00000000-0000-0000-0000-000000000000', 0, 'd00fa98c-dde4-404c-9932-a26e1b76d35a', 1.000000, 0, 0, '905531f7-43e0-4582-8d82-dec6161462b5', 128, 120, 1, 0, '00000000-0000-0000-0000-000000000000', '00000000-0000-0000-0000-000000000000', 0, 1, 0, 3, -842150401, 0, 0, '00000000-0000-0000-0000-000000000000', 0, '', 1, 0, 0
*/  
#########################################################
#END