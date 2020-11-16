##############################################
CREATE PROCEDURE repProductProfit
	@StartDate 		[DateTime] , 
	@EndDate 		[DateTime] , 
	@SrcTypesGUID	[UNIQUEIDENTIFIER] , 
	@MatGUID 		[UNIQUEIDENTIFIER] , 
	@GroupGUID 		[UNIQUEIDENTIFIER] , 
	@StoreGUID 		[UNIQUEIDENTIFIER] , 
	@CostGUID 		[UNIQUEIDENTIFIER] , 
	@CurrencyGUID 	[UNIQUEIDENTIFIER] , 
	@CurrencyVal 	[FLOAT], 
	@Vendor 		[FLOAT], 
	@SalesMan 		[FLOAT], 
	@UseUnit		[INT] = 3, --0 First 1 Seccount 2 third 
	@MotCond		[UNIQUEIDENTIFIER] = 0X00, 
	@CustCond		[UNIQUEIDENTIFIER] = 0X0,
	@ShowGroups [INT] = 0,
	@GrpLevel [INT] = 0,
	@ShowBonus [INT] = 0,
	@ShowDiscExtra [INT] = 0,
	@ShowVat [INT] = 0
AS
SET NOCOUNT ON  
	
	DECLARE @Level AS [INT] 
	DECLARE @Admin [INT],@UserGuid [UNIQUEIDENTIFIER] 
	DECLARE @SQL NVARCHAR(max) 
	DECLARE @Col1 NVARCHAR(100) 
	DECLARE @Col2 NVARCHAR(100) 
	DECLARE @Col3 NVARCHAR(100) 
	DECLARE @ViewType INT
	SET @ViewType = 0
	--SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED		 
	-- Creating temporary tables   
	CREATE TABLE [#SecViol]( [Type] [INT], [Cnt] [INTEGER])   
	CREATE TABLE [#MatTbl](	[MatGUID] [UNIQUEIDENTIFIER] , [mtSecurity] [INT])   
	CREATE TABLE [#BillsTypesTbl]( [TypeGuid] [UNIQUEIDENTIFIER] , [UserSecurity] [INTEGER], [UserReadPriceSecurity] [INTEGER])   
	CREATE TABLE [#StoreTbl]( [StoreGUID] [UNIQUEIDENTIFIER] , [Security] [INT])   
	CREATE TABLE [#CostTbl]( [CostGUID] [UNIQUEIDENTIFIER] , [Security] [INT])   
	CREATE TABLE [#Cust]( [CustGUID] [UNIQUEIDENTIFIER], [Security] [INT]) 
	--Filling temporary tables   
	INSERT INTO [#MatTbl]			EXEC [prcGetMatsList] 			@MatGUID, @GroupGUID,-1,@MotCond   
	INSERT INTO [#BillsTypesTbl]	EXEC [prcGetBillsTypesList]		0x0--'ALL'   
	INSERT INTO [#StoreTbl]			EXEC [prcGetStoresList]			@StoreGUID   
	INSERT INTO [#CostTbl]			EXEC [prcGetCostsList]			@CostGUID   
	INSERT INTO [#Cust]				EXEC [prcGetCustsList]			0x0,0x0,@CustCond 
	IF (@CustCond = 0x00)
		INSERT INTO [#Cust] VALUES (0X00,0) 	
	-- Get Qtys   
	CREATE TABLE [#t_Qtys]  
	(   
		[mtNumber] 	[UNIQUEIDENTIFIER] ,   
		[Qnt] 		[FLOAT],   
		[Qnt2] 		[FLOAT],   
		[Qnt3] 		[FLOAT],   
		[StoreGUID]	[UNIQUEIDENTIFIER]    
	) --3100 upgard   
	CREATE TABLE [#t_Prices]   
	(   
		[mtNumber] 	[UNIQUEIDENTIFIER] ,   
		[APrice] 	[FLOAT]   
	)   
	---- Get Qtys And Prices   
	CREATE TABLE [#PricesQtys]   
	(   
		[mtNumber]	[UNIQUEIDENTIFIER] ,   
		[APrice]	[FLOAT],   
		[Qnt]		[FLOAT],   
		[Qnt2]		[FLOAT],   
		[Qnt3]		[FLOAT],   
		[StoreGUID]	[UNIQUEIDENTIFIER]    
	)   
	EXEC [prcGetQntPriceForAllSrcs] '1/1/1980', @EndDate,	@MatGUID, @GroupGUID, @StoreGUID, @CostGUID, @CurrencyGUID, @CurrencyVal, @Vendor, @SalesMan   
	CREATE TABLE [#PricesQtysNoStores]   
	(   
		[mtNumber]	[UNIQUEIDENTIFIER] ,   
		[APrice]		[FLOAT],   
		[Qnt]			[FLOAT]   
	)   
	
	INSERT INTO [#PricesQtysNoStores]   
	SELECT   
		[mtNumber],   
		[APrice],   
		SUM([Qnt])   
	FROM   
		[#PricesQtys]   
	GROUP BY   
		[mtNumber],   
		[APrice]   

	TRUNCATE TABLE [#t_Prices]   
	CREATE TABLE [#t_ALLPrices]   
	(   
		[mtNumber] 			[UNIQUEIDENTIFIER] ,   
		[LastPriceByCur] 	[FLOAT],   
		[LastCostPrice]		[FLOAT]   
	)   
	EXEC [prcGetLastPriceForAllSrcs] 	'1/1/1980',	@EndDate, @MatGUID, @GroupGUID, @StoreGUID, @CostGUID, @CurrencyGUID, @CurrencyVal, @Vendor, @SalesMan   
	--select * from #t_Prices   
	--select * from #t_ALLPrices   
	TRUNCATE TABLE [#BillsTypesTbl]   
	INSERT INTO [#BillsTypesTbl] EXEC [prcGetBillsTypesList] @SrcTypesGUID    

	CREATE TABLE [#PreResult] (   
		[BiMatPtr]				[UNIQUEIDENTIFIER] ,   
		[mtGUID]				[UNIQUEIDENTIFIER] ,   
		[MtName]				[NVARCHAR] (256) COLLATE ARABIC_CI_AI,   
		[MtCode]				[NVARCHAR] (256) COLLATE ARABIC_CI_AI,   
		[MtLatinName]			[NVARCHAR] (256) COLLATE ARABIC_CI_AI,   
		[MtDefUnitFact]			[FLOAT],   
		[mtDefUnitName]			[NVARCHAR] (256) COLLATE ARABIC_CI_AI,   
		[mtBarCode]				[NVARCHAR] (256) COLLATE ARABIC_CI_AI,   
		[mtSpec]				[NVARCHAR] (1000) COLLATE ARABIC_CI_AI,   
		[mtDim]					[NVARCHAR] (256) COLLATE ARABIC_CI_AI,   
		[mtOrigin]				[NVARCHAR] (256) COLLATE ARABIC_CI_AI,   
		[mtPos]					[NVARCHAR] (256) COLLATE ARABIC_CI_AI,   
		[mtCompany]				[NVARCHAR] (256) COLLATE ARABIC_CI_AI,   
		[mtColor]				[NVARCHAR] (256) COLLATE ARABIC_CI_AI,   
		[mtProvenance]			[NVARCHAR] (256) COLLATE ARABIC_CI_AI,   
		[mtQuality]				[NVARCHAR] (256) COLLATE ARABIC_CI_AI,   
		[mtModel]				[NVARCHAR] (256) COLLATE ARABIC_CI_AI,   
		[mtType]				[INT], 
		[mtVAT]					[FLOAT],  
		[grName]				[NVARCHAR] (256) COLLATE ARABIC_CI_AI,   
		[grLatinName]			[NVARCHAR] (256) COLLATE ARABIC_CI_AI,
		[grGUID]				[UNIQUEIDENTIFIER] ,  
		[mcIsInput] 			[INT],    
		[biQty]					[FLOAT],  
		[mcIsOutput] 			[FLOAT],   
		[BiBonusQnt] 			[FLOAT],   
		[FixedBiPrice] 			[FLOAT], 
		[FixedBiCost]			[FLOAT],
		[FixedBiBonusCost]		[FLOAT],   
		[FixedBiProfits]		[FLOAT],  	 
		[FixedBuTotalExtra]		[FLOAT],   
		[FixedBuTotal] 			[FLOAT],   
		[FixedBuTotalDisc] 		[FLOAT],   
		[FixedBiDiscount]		[FLOAT],   
		[FixedBiBonusDisc]		[FLOAT],   
		[FixedBiVat]			[FLOAT],   
		[Security]				[INT],   
		[UserSecurity] 			[INT],   
		[UserReadPriceSecurity]	[INT],   
		[MtSecurity]			[INT], 
		[mtBarCode2]			[NVARCHAR] (256) COLLATE ARABIC_CI_AI,  
		[mtBarCode3]			[NVARCHAR] (256) COLLATE ARABIC_CI_AI, 
		[Level]					[INT], 
		[Root] 					[INT], 
		[Qty2]					[FLOAT], 
		[Qty3]					[FLOAT],
		[btVATSystem]			[INT] )

	CREATE TABLE #TEMP (
		[BiMatPtr]				[UNIQUEIDENTIFIER], 
		SUMbiQty				FLOAT, 
		[btIsInput]				BIT,  
		[btIsOutput]			BIT,  
		SUMBiBonusQnt			FLOAT, 
		[FixedBiPrice]			FLOAT,
		[FixedBiCost]			FLOAT,
		[FixedBiBonusCost]		FLOAT, 
		[FixedBiProfits]		FLOAT,  	
		[FixedBuTotalExtra]		FLOAT, 
		[FixedBuTotal]			FLOAT,   
		[FixedBuTotalDisc]		FLOAT,
		[FixedBiDiscount]		FLOAT,   
		[FixedBiBonusDisc]		FLOAT,   
		[FixedBiVat]			FLOAT,  
		FIXEDBIEXTRA			FLOAT, 
		[buSecurity]			INT, 
		[UserSecurity]			INT,   
		[UserReadPriceSecurity]	INT,  
		[MtSecurity]			INT, 
		[biQty]					FLOAT,  
		[biQty2]				FLOAT,  
		[biQty3]				FLOAT, 
		[biUnity]				FLOAT,
		[btVATSystem]			INT ) 

	CREATE TABLE [#Grp] (
		[GUID]			[UNIQUEIDENTIFIER], 
		[Path]			VARCHAR(8000), 
		[Level]			INT, 
		[grName]		NVARCHAR(250), 
		[grCode]		NVARCHAR(250), 
		[grLatinName]	NVARCHAR(250),
		[parentGuid]	[UNIQUEIDENTIFIER], 
		[GroupName]		NVARCHAR(250), 
		[Security]		INT )
	
	CREATE TABLE #Profit (
		BiGuid	UNIQUEIDENTIFIER PRIMARY KEY , 
		Profit	FLOAT, 
		Cost	FLOAT )

	DECLARE @DefCurr UNIQUEIDENTIFIER = (SELECT dbo.fnGetDefaultCurr())

	IF @CurrencyGUID = @DefCurr 
		INSERT INTO #Profit 
		SELECT biGUID , biProfits, bi.biUnitCostPrice FROM vwBuBi bi
		WHERE bi.buDate BETWEEN @StartDate AND @EndDate AND (bi.[BuIsPosted] = 1 OR bi.btAffectProfit = 1)
	ELSE
		INSERT INTO #Profit 
		SELECT BiGuid, Profit, Cost
		FROM  dbo.fnGetBillMaterialsCost(@MatGUID, @GroupGUID, @CurrencyGUID, @EndDate) t


	INSERT INTO #TEMP
	SELECT  
		[BiMatPtr], 
		SUM([biQty])SUMbiQty, 
		[btIsInput],  
		[btIsOutput],  
		SUM([BiBonusQnt])SUMBiBonusQnt, 
		SUM(CASE WHEN [UserReadPriceSecurity] >= [BuSecurity] THEN [FixedBiPrice]*[biQty]
		ELSE 0 END) [FixedBiPrice],--/ [MtUnitFact] 
		SUM(CASE WHEN [UserReadPriceSecurity] >= [BuSecurity] THEN t.Cost * ([rv].biQty) ELSE 0 END),  
		SUM(CASE WHEN [UserReadPriceSecurity] >= [BuSecurity] THEN t.Cost *  ( [rv].biBonusQnt) ELSE 0 END),  
		SUM(CASE WHEN [UserReadPriceSecurity] >= [BuSecurity] THEN 	t.Profit ELSE 0 END)[FixedBiProfits],   
		SUM(CASE WHEN [UserReadPriceSecurity] >= [BuSecurity] THEN [rv].[btExtraAffectProfit] * ([FixedBiPrice]*[biQty] ) *([FixedBuTotalExtra] - ([FixedCurrencyFactor] * [buItemsExtra]) -FixedDIExtra)/CASE [FixedBuTotal] WHEN 0 THEN 1 ELSE [FixedBuTotal] END ELSE 0 END  ) [FixedBuTotalExtra], --/ [MtUnitFact]  
		SUM(CASE WHEN [UserReadPriceSecurity] >= [BuSecurity] THEN [FixedBuTotal]
		-- / @AVGCurrecny 
		ELSE 0 END) [FixedBuTotal],   
		SUM(CASE WHEN [UserReadPriceSecurity] >= [BuSecurity] THEN [rv].[btDiscAffectProfit] * ([FixedBiPrice]
		-- / @AVGCurrecny 
		*[biQty]) * (([FixedBuTotalDisc] - [FixedBuItemsDisc] -([buBonusDisc]*[FixedCurrencyFactor]) - FixedDIDiscount))/CASE [FixedBuTotal] WHEN 0 THEN 1 ELSE [FixedBuTotal] END ELSE 0 END )[FixedBuTotalDisc] ,--/ [MtUnitFact]   
		SUM(CASE WHEN [UserReadPriceSecurity] >= [BuSecurity] THEN [rv].[btDiscAffectProfit] * ([FixedBiDiscount] + [FixedTotalDiscountPercent]) ELSE 0 END )[FixedBiDiscount],   
		SUM(CASE WHEN [UserReadPriceSecurity] >= [BuSecurity] THEN [rv].[btDiscAffectProfit] * [FixedBiBonusDisc] ELSE 0 END )[FixedBiBonusDisc],   
		SUM(CASE WHEN [UserReadPriceSecurity] >= [BuSecurity] THEN [FixedBiVAT] ELSE 0 END )[FixedBiVat],  
		SUM((([biExtra] * [FixedCurrencyFactor])*[rv].[btExtraAffectProfit] ) +( FixedTotalExtraPercent*[rv].[btExtraAffectProfit] )) FIXEDBIEXTRA, 
		[buSecurity], 
		[bt].[UserSecurity],   
		[bt].[UserReadPriceSecurity],  
		[mtTbl].[MtSecurity], 
		[biQty],  
		[biQty2],  
		[biQty3], 
		[biUnity],
		[btVATSystem]  
	FROM 	[dbo].[fn_bubi_Fixed]( @CurrencyGUID)[rv] 
		INNER JOIN [#Profit] t ON [rv].biGUID = [t].BiGuid
		INNER JOIN [#BillsTypesTbl] AS [bt] ON [rv].[buType] = [bt].[TypeGuid] 
		INNER JOIN [#MatTbl] AS [mtTbl] ON [rv].[biMatPtr] = [mtTbl].[MatGuid] 
		INNER JOIN [#StoreTbl] AS [st] ON  [rv].[BiStorePtr] = [StoreGUID]
		INNER JOIN [#Cust] AS [cust] ON [rv].[buCustPtr] = [cust].[CustGUID] 
	WHERE 
		[buDate] BETWEEN @StartDate AND @EndDate     
		AND( ([rv].[BuVendor] = @Vendor) 		OR (@Vendor = 0 ))   
		AND( ([rv].[BuSalesManPtr] = @SalesMan) 	OR (@SalesMan = 0))   
		AND( (@CostGUID = 0x0) 	OR ( EXISTS( SELECT [CostGUID] FROM [#CostTbl] WHERE [CostGUID] = [rv].[BiCostPtr]) ) )    
	GROUP BY 
		[BiMatPtr], 
		[btIsOutput], 
		[btIsInput],    
		[buSecurity], 
		[bt].[UserSecurity],   
		[bt].[UserReadPriceSecurity],  
		[mtTbl].[MtSecurity], 
		[biQty],  
		[biQty2],  
		[biQty3], 
		[biUnity],
		[btVATSystem] 
	INSERT INTO [#PreResult]   
	SELECT 
		T.[BiMatPtr],
		mt.mtGUID,   
		mt.[MtName],   
		mt.[MtCode],   
		mt.[MtLatinName],  
		(CASE @UseUnit WHEN 0 THEN 1 WHEN 1  THEN CASE mt.[MtUnit2Fact] WHEN 0 THEN 1 ELSE  mt.[MtUnit2Fact] END WHEN 2  THEN CASE mt.[MtUnit3Fact] WHEN 0 THEN 1 ELSE  mt.[MtUnit3Fact] END ELSE mt.[MtDefUnitFact] END)[MtDefUnitFact],   
		(CASE @UseUnit WHEN 0 THEN [mtUnity] WHEN 1  THEN CASE mt.[MtUnit2Fact] WHEN 0 THEN [mtUnity] ELSE  mt.[mtUnit2] END WHEN 2  THEN CASE mt.[MtUnit3Fact] WHEN 0 THEN [mtUnity] ELSE  mt.[mtUnit3] END ELSE mt.[mtDefUnitName] END)[mtDefUnitName],  
		mt.[mtBarCode],   
		mt.[mtSpec],   
		mt.[mtDim],   
		mt.[mtOrigin],   
		mt.[mtPos],   
		mt.[mtCompany],   
		mt.[mtColor],   
		mt.[mtProvenance],   
		mt.[mtQuality],   
		mt.[mtModel],   
		mt.[mtType],
		mt.[mtVAT],   
		mt.[grName], 
		mt.[grLatinName],  
		mt.[mtGroup], 
		[btIsInput],    
		SUM(T.SUMbiQty),  
		[btIsOutput], 
		SUM(T.SUMBiBonusQnt),   
		SUM((T.[FixedBiPrice]/(CASE T.[biUnity]  
				WHEN 2 THEN (CASE [mt].[mtUnit2FactFlag] WHEN 0 THEN [mt].[mtUnit2Fact] ELSE [biQty] / (CASE [biQty2] WHEN 0 THEN 1 ELSE [biQty2] END) END)  
				WHEN 3 THEN (CASE [mt].[mtUnit3FactFlag] WHEN 0 THEN [mt].[mtUnit3Fact] ELSE [biQty] / (CASE [biQty3] WHEN 0 THEN 1 ELSE [biQty3] END) END)  
				ELSE 1 END))) ,  
		SUM(T.[FixedBiCost]),
		SUM(T.[FixedBiBonusCost]),  
		SUM(T.[FixedBiProfits]), 
		SUM((T.[FixedBuTotalExtra]/(CASE T.[biUnity]  
				WHEN 2 THEN (CASE [mt].[mtUnit2FactFlag] WHEN 0 THEN [mt].[mtUnit2Fact] ELSE [biQty] / (CASE [biQty2] WHEN 0 THEN 1 ELSE [biQty2] END) END)  
				WHEN 3 THEN (CASE [mt].[mtUnit3FactFlag] WHEN 0 THEN [mt].[mtUnit3Fact] ELSE [biQty] / (CASE [biQty3] WHEN 0 THEN 1 ELSE [biQty3] END) END)  
				ELSE 1 END)))+ SUM(FIXEDBIEXTRA) , 
		SUM(T.[FixedBuTotal]),   
		SUM((T.[FixedBuTotalDisc]/(CASE T.[biUnity]  
				WHEN 2 THEN (CASE [mt].[mtUnit2FactFlag] WHEN 0 THEN [mt].[mtUnit2Fact] ELSE [biQty] / (CASE [biQty2] WHEN 0 THEN 1 ELSE [biQty2] END) END)  
				WHEN 3 THEN (CASE [mt].[mtUnit3FactFlag] WHEN 0 THEN [mt].[mtUnit3Fact] ELSE [biQty] / (CASE [biQty3] WHEN 0 THEN 1 ELSE [biQty3] END) END)  
				ELSE 1 END))), 
		SUM(T.[FixedBiDiscount]),   
		SUM(T.[FixedBiBonusDisc]),   
		SUM(T.[FixedBiVat]),  
		T.[buSecurity],   
		T.[UserSecurity],   
		T.[UserReadPriceSecurity],   
		T.[MtSecurity], 
		mt.[mtBarCode2], 
		mt.[mtBarCode3],0,1, 
		SUM((CASE [mt].[mtUnit2FactFlag] WHEN 0 THEN (CASE [mt].[mtUnit2Fact] WHEN 0 THEN 0 ELSE CASE @ShowBonus WHEN 1 THEN T.[SUMbiQty] / [mt].[mtUnit2Fact] ELSE (T.[SUMbiQty] + SUMBiBonusQnt)/ [mt].[mtUnit2Fact] END END) ELSE T.[biQty2] END)) ,  
		SUM((CASE [mt].[mtUnit3FactFlag] WHEN 0 THEN (CASE [mt].[mtUnit3Fact] WHEN 0 THEN 0 ELSE CASE @ShowBonus WHEN 1 THEN T.[SUMbiQty] / [mt].[mtUnit3Fact] ELSE (T.[SUMbiQty] + SUMBiBonusQnt)/ [mt].[mtUnit3Fact] END END) ELSE T.[biQty3] END))
		,0--T.[btVATSystem]
	FROM   
		#TEMP T INNER JOIN [dbo].[vwMtGr] mt ON T.[BiMatPtr] = mt.mtGUID 
	GROUP BY  
		T.[BiMatPtr],   
		mt.[MtName],
		mt.[mtGUID],   
		mt.[MtCode],   
		mt.[MtLatinName],   
		mt.[MtDefUnitFact],   
		mt.[mtDefUnitName],  
		mt.[mtBarCode],   
		mt.[mtSpec],   
		mt.[mtDim],   
		mt.[mtOrigin],   
		mt.[mtPos],   
		mt.[mtCompany],   
		mt.[mtColor],   
		mt.[mtProvenance],   
		mt.[mtQuality],   
		mt.[mtModel],   
		mt.[mtType],
		mt.[mtVAT],   
		mt.[grName],
		mt.[grLatinName],   
		mt.[mtGroup],     
		T.[buSecurity],   
		T.[UserSecurity],   
		T.[UserReadPriceSecurity],   
		T.[MtSecurity], 
		mt.[mtBarCode2], 
		mt.[mtBarCode3]	,	 
		[mt].[mtUnit2FactFlag], 
		[mt].[mtUnit2Fact], 
		[mt].[mtUnit3Fact], 
		[mt].[mtUnit3FactFlag], 
		[biQty2], 
		T.[biQty], 
		T.[biQty3], 
		T.biUnity, 
		mt.mtUnity, 
		mt.mtUnit2, 
		mt.mtUnit3, 
		[btIsInput], 
		[btIsOutput]
		--,T.[btVATSystem]
	---check sec   
	EXEC [prcCheckSecurity] @result = '#PreResult'  
	IF (@ShowGroups = 1) 
	BEGIN 
		SET @UserGuid = [dbo].[fnGetCurrentUserGUID]() 
		SET @Admin = [dbo].[fnIsAdmin](ISNULL(@userGUID,0x00) ) 
	 
		INSERT INTO [#Grp]
	   SELECT [f].[Guid],
			  [f].[Path],
			  [f].[Level],
			  [gr].[Name]	   AS [grName],
			  [gr].[Code]	   AS [grCode],
			  [gr].[LatinName] AS [grLatinName],
			  [gr].[parentGuid],
			  [grName]		   AS [GroupName],
			  [gr].[Security] 
		FROM [dbo].[fnGetGroupsOfGroupSorted]( @GroupGUID, 0) AS [f]  
		INNER JOIN [gr000] AS [gr] ON [gr].[Guid] = [f].[Guid] 
		LEFT JOIN [vwgr] AS [vgr] ON [gr].[parentGuid] = [vgr].[grGuid]  

		IF @Admin = 0 
		BEGIN 
			UPDATE [#Grp] SET [Level] = -1 WHERE  [Security] > [dbo].[fnGetUserGroupSec_Browse](@UserGuid) 
			SET @Level = @@RowCount 
			WHILE @Level > 0 
			BEGIN 
				UPDATE [gr] SET [parentGuid] = ISNULL([gr1].[parentGuid],0X00),[GroupName] = ISNULL([gr1].[GroupName],'') ,[Level] = [gr].[Level] - 1 FROM [#Grp] AS [gr] LEFT JOIN [#Grp] AS [gr1] ON [gr].[parentGuid] = [gr1].[Guid] WHERE [gr1].[Level] = -1 
				SET @Level = @@RowCount 
			END 
		END 

		INSERT INTO [#PreResult]([BiMatPtr], [mtGUID], [MtName], [MtCode], [MtLatinName], [grName], [grGUID], [mcIsInput], [biQty], [mcIsOutput], [BiBonusQnt],  
								 [FixedBiPrice], [FixedBiCost], [FixedBiBonusCost], [FixedBiProfits], [FixedBuTotalExtra], [FixedBuTotal], [FixedBuTotalDisc], 
								 [FixedBiDiscount], [FixedBiBonusDisc], [FixedBiVat], [Level], [Root], [Qty2], [Qty3]) 
		SELECT 
				[gr].[Guid],
				0x0,
				CASE [gr].[Level] WHEN -1 THEN '' ELSE [gr].[grName] END ,
				CASE [gr].[Level] WHEN -1 THEN '' ELSE [grCode] END,
				[gr].[grLatinName],
				[gr].[GroupName] ,
				[gr].[parentGuid] ,
				[mcIsInput],SUM([biQty] / CASE [MtDefUnitFact]	 WHEN 0 THEN 1 ELSE [MtDefUnitFact] END),
				[mcIsOutput],SUM([BiBonusQnt] / CASE [MtDefUnitFact] WHEN 0 THEN 1 ELSE [MtDefUnitFact]	 END),  
				SUM([FixedBiPrice]),
				SUM([FixedBiCost]),
				SUM([FixedBiBonusCost]) ,
				SUM([FixedBiProfits]),
				SUM([FixedBuTotalExtra]),
				SUM([FixedBuTotal]),
				SUM([FixedBuTotalDisc]), 
				SUM([FixedBiDiscount]),
				SUM([FixedBiBonusDisc]),
				SUM([FixedBiVat]),
				[gr].[Level],
				0,
				SUM([Qty2]),
				SUM([Qty3]) 
		FROM [#Grp] AS [gr] INNER JOIN [#PreResult] AS [r] ON [gr].[Guid] = [r].[grGUID] 
		GROUP BY 
			[gr].[Guid], [gr].[grName], [grCode], [gr].[grLatinName], [gr].[parentGuid], [gr].[GroupName], [mcIsInput], [mcIsOutput], [gr].[Level] 

		IF @Admin = 0 
		BEGIN 
			DELETE [#Grp] WHERE [Level] = -1 AND [Guid] NOT IN (SELECT [grGUID] FROM [#PreResult]) 
		END 
		IF @ViewType = 1 
			DELETE [#PreResult] WHERE [Root] = 1 
		UPDATE r SET [Level] = [gr].[Level] FROM [#PreResult] AS [r] INNER JOIN [#Grp] [gr] ON [gr].[Guid] = [r].[grGUID]  WHERE [Root] = 1 
		 
		SELECT @Level = MAX([Level]) FROM [#PreResult] 
		WHILE @Level > 0  
		BEGIN 
			INSERT INTO [#PreResult]([BiMatPtr], [mtGUID], [MtName], [MtCode], [MtLatinName], [grName], [grGUID], [mcIsInput], [biQty], [mcIsOutput], [BiBonusQnt],  
									 [FixedBiPrice], [FixedBiCost], [FixedBiBonusCost], [FixedBiProfits], [FixedBuTotalExtra], [FixedBuTotal], [FixedBuTotalDisc], 
									 [FixedBiDiscount], [FixedBiBonusDisc], [FixedBiVat], [Level], [Root], [Qty2], [Qty3]) 
			SELECT [gr].[Guid],
					0x0,
					[gr].[grName],
					[grCode],
					[gr].[grLatinName],
					[gr].[GroupName],
					[gr].[parentGuid],
					[mcIsInput],
					SUM([biQty]),
					[mcIsOutput],
					SUM([BiBonusQnt]),  
					SUM([FixedBiPrice]),
					SUM([FixedBiCost]),
					SUM([FixedBiBonusCost]),
					SUM([FixedBiProfits]),
					SUM([FixedBuTotalExtra]),
					SUM([FixedBuTotal]),
					SUM([FixedBuTotalDisc]), 
					SUM([FixedBiDiscount]),
					SUM([FixedBiBonusDisc]),
					SUM([FixedBiVat]),
					[gr].[Level],
					0,
					SUM([Qty2]),
					SUM([Qty3]) 
			FROM [#Grp] AS [gr] INNER JOIN [#PreResult] AS [r] ON [gr].[Guid] = [r].[grGUID] 
			WHERE [r].[Level] = @Level and root = 0 
			GROUP BY 
				[gr].[Guid], [gr].[grName], [grCode], [gr].[grLatinName], [gr].[parentGuid], [gr].[GroupName], [mcIsInput], [mcIsOutput], [gr].[Level] 
			IF (@GrpLevel <> 0)  
			BEGIN  
				IF (@GrpLevel <= @Level)  
				BEGIN  
					IF @ViewType <> 1  
						UPDATE [r] SET [grGUID] = [gr].[parentGuid],[grName] = [gr].[GroupName] FROM  [#PreResult] AS [r] INNER JOIN [#Grp] AS [gr] ON [gr].[Guid] = [r].[grGUID]  
						WHERE [r].[Level] >= @GrpLevel and root = 1   
					DELETE [#PreResult] WHERE [Level] = @Level and root <> 1 
				END  
			END  
			SET @Level = @Level - 1 
		END 
		  
	END 
	DECLARE @Result TABLE 
	(   
		[BiMatPtr]				[UNIQUEIDENTIFIER] ,   
		[mtGUID]				[UNIQUEIDENTIFIER] ,   
		[MtName]				[NVARCHAR] (256) COLLATE ARABIC_CI_AI,   
		[MtCode]				[NVARCHAR] (256) COLLATE ARABIC_CI_AI,   
		[MtLatinName]			[NVARCHAR] (256) COLLATE ARABIC_CI_AI,   
		[MtDefUnitFact]			[FLOAT],   
		[mtDefUnitName]			[NVARCHAR] (256) COLLATE ARABIC_CI_AI,   
		[grName]				[NVARCHAR] (256) COLLATE ARABIC_CI_AI,
		[grLatinName]			[NVARCHAR] (256) COLLATE ARABIC_CI_AI,
		[grGUID]				[UNIQUEIDENTIFIER] ,   
		[BalQnt]				[FLOAT],
		[BalPrice]				[FLOAT],
		[LastPrice]				[FLOAT],
		[LastCost]				[FLOAT],
		[SumInQty]				[FLOAT],
		[SumOutQty]				[FLOAT],
		[SumInBonus]			[FLOAT],
		[SumOutBonus]			[FLOAT],
		[SumInPrice]			[FLOAT],
		[SumOutPrice]			[FLOAT],
		[SumInCost]				[FLOAT],
		[SumOutCost]			[FLOAT],
		[SumInBonusCost]		[FLOAT],
		[SumOutBonusCost]		[FLOAT],
		[SumInBiProfits]		[FLOAT],
		[SumOutBiProfits]		[FLOAT],
		[SumInExtra]			[FLOAT],
		[SumOutExtra]			[FLOAT],
		[SumInDisc]				[FLOAT],
		[SumOutDisc]			[FLOAT],
		[SumInBiDiscVal]		[FLOAT],
		[SumOutBiDiscVal]		[FLOAT],
		[SumInBiBonusDisc]		[FLOAT],
		[SumOutBiBonusDisc]		[FLOAT],
		[SumInBiVat]			[FLOAT],
		[SumOutBiVat]			[FLOAT],
		[Root]					[INT],
		[SumInQty2]				[FLOAT],
		[SumOutQty2]			[FLOAT],
		[SumInQty3]				[FLOAT],
		[SumOutQty3]			[FLOAT],
		[btVATSystem]			[INT],
		[Type]					[INT]
	)
	--select * from [#PreResult]
		DECLARE @RBMat AS [INT] 
		SET @RBMat=[dbo].[fnGetUserMaterialSec_Balance]([dbo].[fnGetCurrentUserGuid]()) 
		INSERT INTO @Result (BiMatPtr, mtGUID, MtName, MtCode, MtLatinName, MtDefUnitFact,mtDefUnitName, grName, grLatinName, grGUID, BalQnt, BalPrice, LastPrice, LastCost, SumInQty, SumOutQty,
							 SumInBonus, SumOutBonus, SumInPrice, SumOutPrice, SumInCost, SumOutCost, SumInBonusCost, SumOutBonusCost,  SumInBiProfits, SumOutBiProfits, SumInExtra, SumOutExtra, SumInDisc, SumOutDisc, SumInBiDiscVal, SumOutBiDiscVal, SumInBiBonusDisc, SumOutBiBonusDisc, 
							 SumInBiVat, SumOutBiVat, Root, SumInQty2, SumOutQty2, SumInQty3, SumOutQty3, btVATSystem, Type)
		SELECT   
			[r].[BiMatPtr], 
			[r].[mtGUID],  
			[r].[MtName],   
			[r].[MtCode],   
			[r].[MtLatinName],   
			ISNULL([r].[MtDefUnitFact], 1),    
			[r].[MtDefUnitName], 
			[r].[grName],   
			[r].[grLatinName],
			[r].[grGUID],   
			ISNULL(CASE WHEN @RBMat >= 0 THEN ([p].[Qnt] / CASE [r].[MtDefUnitFact] WHEN 0 THEN 1 ELSE [r].[MtDefUnitFact] END) ELSE 0 END, 0) AS [BalQnt],   
			ISNULL([p].[APrice] * [r].[MtDefUnitFact], 0) AS [BalPrice],   
			ISNULL([a].[LastPriceByCur] * [r].[MtDefUnitFact], 0) AS [LastPrice],   
			ISNULL([a].[LastCostPrice] * [r].[MtDefUnitFact],0) AS [LastCost],   
			SUM( [r].[mcIsInput] * [r].[biQty] )AS [SumInQty],   
			SUM( [r].[mcIsOutput] * [r].[biQty] ) AS [SumOutQty],   
			SUM( [r].[mcIsInput] * [r].[BiBonusQnt])AS [SumInBonus],   
			SUM( [r].[mcIsOutput] * [r].[BiBonusQnt]) AS [SumOutBonus],   
			 
			ISNULL( SUM( [r].[mcIsInput] *   [r].[FixedBiPrice]  ), 0) AS [SumInPrice],   
			ISNULL( SUM( [r].[mcIsOutput] *  [r].[FixedBiPrice] ), 0) AS [SumOutPrice],  	
			ISNULL( SUM( [r].[mcIsInput] *   [r].[FixedBiCost]  ), 0) AS [SumInCost],   
			ISNULL( SUM( [r].[mcIsOutput] *  [r].[FixedBiCost] ), 0) AS [SumOutCost], 
			ISNULL( SUM( [r].[mcIsInput] *   [r].[FixedBiBonusCost]  ), 0) AS [SumInBonusCost],   
			ISNULL( SUM( [r].[mcIsOutput] *  [r].[FixedBiBonusCost] ), 0) AS [SumOutBonusCost],  		   
			ISNULL( SUM( [r].[mcIsInput] * [r].[FixedBiProfits]), 0) AS [SumInBiProfits],   
			ISNULL( SUM( [r].[mcIsOutput] * [r].[FixedBiProfits]), 0) AS [SumOutBiProfits],   
			ISNULL( SUM( [r].[mcIsInput] * [r].[FixedBuTotalExtra] ), 0) AS [SumInExtra],   
			ISNULL( SUM( [r].[mcIsOutput] * [r].[FixedBuTotalExtra]), 0) AS [SumOutExtra],   
			ISNULL( SUM( [r].[mcIsInput] * [r].[FixedBuTotalDisc]),0 ) AS [SumInDisc],   
			ISNULL( SUM( [r].[mcIsOutput] * [r].[FixedBuTotalDisc]),0) AS [SumOutDisc],   
			ISNULL( SUM( [r].[mcIsInput] * [r].[FixedbiDiscount]), 0) AS [SumInBiDiscVal],   
			ISNULL( SUM( [r].[mcIsOutput] * [r].[FixedbiDiscount]), 0) AS [SumOutBiDiscVal],   
			ISNULL( SUM( [r].[mcIsInput] * [r].[FixedBiBonusDisc]), 0) AS [SumInBiBonusDisc],   
			ISNULL( SUM( [r].[mcIsOutput] * [r].[FixedBiBonusDisc]), 0) AS [SumOutBiBonusDisc], 
			ISNULL( SUM( [r].[mcIsInput] * [r].[FixedBiVat]), 0) AS [SumInBiVat],   
			ISNULL( SUM( [r].[mcIsOutput] * [r].[FixedBiVat]), 0) AS [SumOutBiVat], 
			[r].[Root] , 
			SUM( [r].[mcIsInput] * [r].[Qty2] )AS [SumInQty2],   
			SUM( [r].[mcIsOutput] * [r].[Qty2]) AS [SumOutQty2], 
			SUM( [r].[mcIsInput] * [r].[Qty3] )AS [SumInQty3],   
			SUM( [r].[mcIsOutput] * [r].[Qty3]) AS [SumOutQty3],
			[r].[btVATSystem],
			CASE [r].[Root] WHEN 0 THEN 1 ELSE 0 END AS [Type]
			FROM   
				([#PreResult] AS [r]  
				LEFT JOIN [#PricesQtysNoStores] AS [p] ON [r].[biMatPtr] = [p].[mtNumber])   
				LEFT JOIN [#t_ALLPrices] AS [a] ON [a].[mtNumber] = [r].[BiMatPtr]
			GROUP BY   
				[r].[BiMatPtr], 
				[r].[mtGUID],    
				[r].[MtName],   
				[r].[MtCode],   
				[r].[MtLatinName],   
				[r].[MtDefUnitFact],  
				[r].[grName],
				[r].[grLatinName],    
				[r].[grGUID],   
				[r].[mtDefUnitName], 
				[grGUID],   
				[p].[Qnt],   
				[p].[APrice],   
				[a].[LastPriceByCur],   
				[a].[LastCostPrice], 
				[r].[Root], 
				[r].[btVATSystem] 
	

	DECLARE @TotalsProfits AS FLOAT
	SET @TotalsProfits = 0
	SELECT  @TotalsProfits = SUM(CASE @ShowVat WHEN 1 THEN ([SumOutBiProfits] - [SumInBiProfits]) + ([SumOutBiVat] - [SumInBiVat]) ELSE ([SumOutBiProfits] - [SumInBiProfits]) END) 
	FROM @Result 
	WHERE mtGUID <> 0x0
	
	SELECT 
	[r].*,
	[SumOutQty2] - [SumInQty2] AS [Qty2],
	[SumOutQty3] - [SumInQty3] AS [Qty3],
	[SumOutBiVat] - [SumInBiVat] AS [Vat],
	[SumOutPrice] - [SumInPrice] + ([SumOutBiVat] - [SumInBiVat]) AS [GrndPrice],
	(([SumOutQty] - [SumInQty]) + (CASE @ShowBonus WHEN 0 THEN ([SumOutBonus] - [SumInBonus]) ELSE 0 END)) / (CASE MtDefUnitFact WHEN 0 THEN 1 ELSE MtDefUnitFact END) AS [Qty],
	[SumOutBonus] - [SumInBonus] AS [Bonus],
	(([SumOutBiProfits] - [SumInBiProfits])+([SumOutBiVat] - [SumInBiVat])) AS [Profit],
	[SumInPrice] - [SumInBiProfits] AS [InCost],
	[SumOutPrice] - [SumOutBiProfits] AS [OutCost],
	[SumOutBiDiscVal] + [SumOutDisc] AS [OutDiscount],
	[SumInBiDiscVal] + [SumInDisc] AS [InDiscount],
	CASE [SumInQty] + [SumInBonus] WHEN 0 THEN 1 ELSE ([SumInQty] + [SumInBonus]) END AS [INQTY],
	CASE [SumOutQty] + [SumOutBonus] WHEN 0 THEN 1 ELSE ([SumOutQty] + [SumOutBonus]) END AS [OUTQTY],
	SumInBonusCost AS [InBonusCostSales],
	SumInCost AS [InCostSales],
	SumOutBonusCost AS [OutBonusCostSales],
	SumOutCost AS [OutCostSales],
	SumOutBonusCost - SumInBonusCost  AS [BonusCostSales],
	SumOutCost - SumInCost  AS [CostSales],
	[SumOutExtra] - [SumInExtra] AS [Extra],
	[SumOutBiDiscVal] + [SumOutDisc] -  [SumInBiDiscVal] - [SumInDisc] AS [Discount],
	([SumOutBiBonusDisc] - [SumInBiBonusDisc]) AS [BonusDiscount],
	(CASE (CASE [Root] WHEN 1 THEN [BalQnt] + ((([SumOutQty] - [SumInQty]) + (CASE @ShowBonus WHEN 0 THEN ([SumOutBonus] - [SumInBonus]) ELSE 0 END)) / (CASE MtDefUnitFact WHEN 0 THEN 1 ELSE MtDefUnitFact END)) ELSE 0 END) WHEN 0 THEN 0 ELSE (((([SumOutQty] - [SumInQty]) + (CASE @ShowBonus WHEN 0 THEN ([SumOutBonus] - [SumInBonus]) ELSE 0 END)) / (CASE MtDefUnitFact WHEN 0 THEN 1 ELSE MtDefUnitFact END)) / (CASE [Root] WHEN 1 THEN [BalQnt] + ((([SumOutQty] - [SumInQty]) + (CASE @ShowBonus WHEN 0 THEN ([SumOutBonus] - [SumInBonus]) ELSE 0 END)) / (CASE MtDefUnitFact WHEN 0 THEN 1 ELSE MtDefUnitFact END)) ELSE 0 END)) END) AS [MatMoveRate],
	(([SumOutBiProfits] - [SumInBiProfits])) AS [ProfitVat],
	CASE @ShowVat WHEN 1 THEN  (CASE @ShowDiscExtra WHEN 0 THEN 
	(([SumOutPrice] - [SumInPrice] + ([SumOutBiVat] - [SumInBiVat])) - ([SumOutBiDiscVal] + [SumOutDisc] -  [SumInBiDiscVal] - [SumInDisc]) - ([SumOutBiBonusDisc] - [SumInBiBonusDisc]) + ([SumOutExtra] - [SumInExtra])) ELSE ([SumOutPrice] - [SumInPrice] + ([SumOutBiVat] - [SumInBiVat])) END ) ELSE ((CASE @ShowDiscExtra WHEN 0 THEN (([SumOutPrice] - [SumInPrice] + ([SumOutBiVat] - [SumInBiVat])) - ([SumOutBiDiscVal] + [SumOutDisc] -  [SumInBiDiscVal] - [SumInDisc]) - ([SumOutBiBonusDisc] - [SumInBiBonusDisc]) + ([SumOutExtra] - [SumInExtra])) ELSE ([SumOutPrice] - [SumInPrice] + ([SumOutBiVat] - [SumInBiVat]) ) END ) - ([SumOutBiVat] - [SumInBiVat])) END AS [GrandPrice],
	CASE @ShowDiscExtra WHEN 1 THEN (([SumOutBiDiscVal] + [SumOutDisc] -  [SumInBiDiscVal] - [SumInDisc]) +
	([SumOutBiBonusDisc] - [SumInBiBonusDisc])) ELSE 0 END AS [GrandDisk],
	CASE @ShowDiscExtra WHEN 1 THEN ([SumOutExtra] - [SumInExtra]) ELSE 0 END AS [GrandExtra],
	CASE @ShowVat WHEN 1 THEN ((([SumOutBiProfits] - [SumInBiProfits]) + ([SumOutBiVat] - [SumInBiVat])) / ISNULL(NULLIF(@TotalsProfits, 0), 1)) ELSE (([SumOutBiProfits] - [SumInBiProfits]) / ISNULL(NULLIF(@TotalsProfits, 0), 1)) END  AS [ProfitsPerAll]
	FROM @Result [r]
	
	SELECT * FROM [#SecViol]	--SET TRANSACTION ISOLATION LEVEL READ COMMITTED 
####################################################
#END