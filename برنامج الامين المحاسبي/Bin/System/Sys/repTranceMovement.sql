############################################################################
CREATE PROCEDURE repTranceMovement
		@PriceType				[INT] = 0,
	@StartDate 				[DATETIME],  
	@EndDate 				[DATETIME],  
	@SrcTypesguid			[UNIQUEIDENTIFIER],  
	@MatGuid 				[UNIQUEIDENTIFIER], -- 0 All Mat or MatNumber  
	@GroupGuid 				[UNIQUEIDENTIFIER],  
	@PostedValue			[INT], -- 0, 1 , -1  
	@NotesContain 			[NVARCHAR](256),-- NULL or Contain Text   
	@NotesNotContain		[NVARCHAR](256), -- NULL or Not Contain   
	@StoreGuid 				[UNIQUEIDENTIFIER], --0 all stores so don't check store or list of stores   
	@CostGuid 				[UNIQUEIDENTIFIER], -- 0 all costs so don't Check cost or list of costs   
	@AccGuid				[UNIQUEIDENTIFIER],   
	@CurrencyPtr 			[UNIQUEIDENTIFIER],   
	@MatType 				[INT], -- 0 MatStore or 1 MAtService or -1 ALL Mats Types   
	@Flag					[BIGINT] = 0,  
	@DiscreteExtraAndDisc	[BIT],	-- Discrete extra and discount on bill items.
	@EmbeddedBonus			[BIT],	-- Embed Bonus inside Quantity.
	@UseUnit				[INT] = 0,-- 0 BILL UNIT 1 FIRSTUNIT 2 SECCOUND UNIT 3 THIRD UNIT 4 [DefUnit]  
	@Lang					[BIT] = 0,  
	@MatCond				[UNIQUEIDENTIFIER] = 0X00,  
	@UserGuid				[UNIQUEIDENTIFIER] = 0X00
AS  
	SET NOCOUNT ON 
	DECLARE @BuStr [NVARCHAR](max),@IsAdmin	[BIT];
	DECLARE @ReprotCurrencyValue FLOAT = (SELECT dbo.fnGetCurVal(@CurrencyPtr, @EndDate));
	SELECT @IsAdmin = [bAdmin] FROM  [Us000] WHERE Guid = [dbo].[fnGetCurrentUserGUID]();
	-- Creating temporary tables  
	CREATE TABLE [#SecViol]( [Type] [INT], [Cnt] [INTEGER])  
	CREATE TABLE [#MatTbl]( [MatGuid] [UNIQUEIDENTIFIER], [mtSecurity] [INT])  
	CREATE TABLE [#BillsTypesTbl]( [TypeGuid] [UNIQUEIDENTIFIER], [UserSecurity] [INTEGER], [UserReadPriceSecurity] [INTEGER], [UnpostedSecurity] [INTEGER])  
	CREATE TABLE [#StoreTbl]([StoreGuid] [UNIQUEIDENTIFIER], [Security] [INT])  
	CREATE TABLE [#CostTbl]( [CostGuid] [UNIQUEIDENTIFIER], [Security] [INT])  
	CREATE TABLE [#AccTbl]([Guid] [UNIQUEIDENTIFIER], [AcSecurity] INT, [AcCodeName] NVARCHAR(500))
	CREATE TABLE [#StoreTbl2]([StoreGuid] [UNIQUEIDENTIFIER], [Security] INT, [stCodeName] NVARCHAR(500))
	CREATE TABLE [#bu]([buGuid] [UNIQUEIDENTIFIER], [FixedBuTotal] FLOAT, [buDisc] FLOAT, [buExtra] FLOAT,
				[buMatAcc] [UNIQUEIDENTIFIER], [buStorePtr] [UNIQUEIDENTIFIER],	[buCostPtr] [UNIQUEIDENTIFIER],
				[buCostName] NVARCHAR(500), [buCostLatinName] NVARCHAR(500), [buSecurity] INT, [UserSecurity] INT,
				[UserReadPriceSecurity] INT, [buType] [UNIQUEIDENTIFIER], [AcSecurity] INT, [AcCodeName] NVARCHAR(256),
				[buDate] DATETIME, [buNotes] NVARCHAR(500), [buNumber] INT, [coSecurity] INT, [FixedCurrencyFactor] INT,
				[stCodeName] NVARCHAR(256), [buBranch] [UNIQUEIDENTIFIER])
	CREATE TABLE [#MatTbl2](
		[MatGuid] [UNIQUEIDENTIFIER],
		[mtCode] NVARCHAR(256),
		[mtName] NVARCHAR(256), 
		[mtLatinName] NVARCHAR(256),
		[mtDefUnitFact] FLOAT,
		[mtDefUnitName] NVARCHAR(256),  
		[mtUnity] NVARCHAR(256),
		[mtUnit2] NVARCHAR(256), 
		[mtUnit3] NVARCHAR(256), 
		[mtUnit2Fact] FLOAT,
		[mtUnit3Fact] FLOAT, 
		[mtBarCode] NVARCHAR(256), 
		[mtBarCode2] NVARCHAR(256), 
		[mtBarCode3] NVARCHAR(256),
		[mtType] INT, 
		[mtSpec] NVARCHAR(1000), 
		[mtOrigin] NVARCHAR(256), 
		[mtPos] NVARCHAR(256), 
		[mtCompany] NVARCHAR(256),  
		[mtColor] NVARCHAR(256), 
		[mtDim]NVARCHAR(256), 
		[mtVAT] FLOAT, 
		[mtProvenance] NVARCHAR(256), 
		[mtQuality] NVARCHAR(256),  
		[mtModel] NVARCHAR(256), 
		[mtUnit2FactFlag] BIT, 
		[mtUnit3FactFlag] BIT, 
		[mtDefUnit] INT,
		[GroupGuid] [UNIQUEIDENTIFIER], 
		[mtFlag] FLOAT, 
		[mtSecurity] INT, 
		CurrencyGuid [UNIQUEIDENTIFIER],
		CurrencyVal FLOAT,
		CurrencyValByHistory FLOAT,
		[mtWhole] FLOAT, 
		[mtWhole2] FLOAT,
		[mtWhole3] FLOAT, 
		[mtHalf] FLOAT, 
		[mtHalf2] FLOAT, 
		[mtHalf3] FLOAT, 
		[mtVendor] FLOAT, 
		[mtVendor2] FLOAT,
		[mtVendor3] FLOAT, 
		[mtExport] FLOAT, 
		[mtExport2] FLOAT, 
		[mtExport3] FLOAT, 
		[mtRetail] FLOAT, 
		[mtRetail2] FLOAT,
		[mtRetail3] FLOAT, 
		[mtEndUser] FLOAT, 
		[mtEndUser2] FLOAT, 
		[mtEndUser3] FLOAT) 
		
	CREATE TABLE [#trbu] ([buType] [UNIQUEIDENTIFIER], [buGuid] [UNIQUEIDENTIFIER], [InNumber] INT, [OutNumber] INT, 
		[InbuStorePtr] [UNIQUEIDENTIFIER], [OutbuStorePtr] [UNIQUEIDENTIFIER], [InstCodeName] NVARCHAR(256), 
		[OutstCodeName] NVARCHAR(256), [InAccGuid] [UNIQUEIDENTIFIER], [OutAccGuid] [UNIQUEIDENTIFIER], 
		[InAcc] NVARCHAR(256), [OutAcc] NVARCHAR(256), [AccSecurity] INT, [buNotes] NVARCHAR(1000), 
		[InCost] [UNIQUEIDENTIFIER], [InCostName] NVARCHAR(500), [InCostLatinName] NVARCHAR(500),
		[OutCost] [UNIQUEIDENTIFIER], [OutCostName] NVARCHAR(500), [OutCostLatinName] NVARCHAR(500),
		[buSecurity] INT, [UserSecurity] INT, [UserReadPriceSecurity] INT, [budate] DATETIME, [FixedBuTotal] FLOAT,
		[buDisc] FLOAT, [buExtra] FLOAT, [FixedCurrencyFactor] FLOAT, [buBranch] [UNIQUEIDENTIFIER]) 
	--Filling temporary tables   
	INSERT INTO [#MatTbl]			EXEC [prcGetMatsList] 		@MatGuid, @GroupGuid, @MatType,@MatCond  
	INSERT INTO [#BillsTypesTbl]	EXEC [prcGetBillsTypesList2] 	@SrcTypesguid--, @UserGuid   
	INSERT INTO [#StoreTbl]			EXEC [prcGetStoresList] 		@StoreGuid   
	INSERT INTO [#CostTbl]			EXEC [prcGetCostsList] 		@CostGuid   
	INSERT INTO [#AccTbl] SELECT [f].[Guid],[Security] AS [AcSecurity],[Code] +'-' + CASE @Lang WHEN 0 THEN [Name] ELSE CASE [LatinName] WHEN '' THEN [Name] ELSE [LatinName] END END AS [AcCodeName] 
	FROM [dbo].[fnGetAcDescList](@AccGuid) AS f INNER JOIN [ac000] AS [ac] ON [ac].[Guid] = [f].[Guid] 
	IF (@AccGuid = 0X00) 
		INSERT INTO [#AccTbl] VALUES(0X00,0,'') 
	IF (@CostGuid = 0X00) 
		INSERT INTO [#CostTbl] VALUES(0X00,0) 
	 
	INSERT INTO [#BillsTypesTbl] SELECT [OutTypeGuid],[UserSecurity], [UserReadPriceSecurity], [UnpostedSecurity]  
	FROM [#BillsTypesTbl] AS [bt] INNER JOIN [tt000] AS [tt] ON [tt].[InTypeGuid] = [bt].[TypeGuid] 
	 
	INSERT INTO [#StoreTbl2] SELECT [StoreGuid],[s].[Security],[Code] +'-' + CASE @Lang WHEN 0 THEN [Name] ELSE CASE [LatinName] WHEN '' THEN [Name] ELSE [LatinName] END END AS [stCodeName]  
	FROM [#StoreTbl] AS [s] INNER JOIN [st000] AS [st] ON [st].[Guid] = [StoreGuid] 
	INSERT INTO [#bu]
	SELECT  
		[bu].[buGuid],[FixedBuTotal],([buTotalDisc]- ([buItemsDisc]+[buBonusDisc])) *  [FixedCurrencyFactor] AS [buDisc], 
		([buTotalExtra] - [buItemsExtra]) * [FixedCurrencyFactor] AS [buExtra],[buMatAcc],[buStorePtr],[buCostPtr],[co000].[Name], [co000].[LatinName],[buSecurity], 
		CASE [buIsPosted] WHEN 1 THEN [bt].[UserSecurity] ELSE [UnpostedSecurity] END AS [UserSecurity] ,[UserReadPriceSecurity],[buType],[AcSecurity],[AcCodeName],[buDate],[buNotes],[buNumber] 
		,[co].[Security] AS [coSecurity],[FixedCurrencyFactor],[stCodeName],[buBranch]
	FROM [fnBu_Fixed](@CurrencyPtr) AS [bu]  
	INNER JOIN [#BillsTypesTbl] AS [bt] ON [bt].[TypeGuid] = [buType] 
	INNER JOIN [#AccTbl] AS [ac] ON [ac].[Guid] = [buMatAcc] 
	INNER JOIN [#CostTbl] AS [co] ON [co].[CostGuid] =  [buCostPtr] 
	INNER JOIN [#StoreTbl2] AS [st] ON [StoreGuid] = [buStorePtr] 
	LEFT JOIN [co000] ON [co000].[GUID] = [buCostPtr]
	WHERE  
		[budate] BETWEEN @StartDate AND @EndDate   
		AND( (@PostedValue = -1)	OR ([BuIsPosted] = @PostedValue))   
	CREATE CLUSTERED INDEX [trbuInd] ON [#bu]([buGuid]) 
	INSERT INTO [#MatTbl2] 
	SELECT 
		[MatGuid],
		[Code] AS [mtCode],
		[Name] AS [mtName],
		[LatinName] AS [mtLatinName],  
		CASE [DefUnit] WHEN 1 THEN 1 WHEN 2 THEN [Unit2Fact] ELSE  [Unit3Fact] END [mtDefUnitFact],  
		CASE [DefUnit] WHEN 1 THEN [Unity] WHEN 2 THEN [Unit2] ELSE  [Unit3] END [mtDefUnitName],  
		[Unity] AS [mtUnity],  
		[Unit2] AS [mtUnit2],  
		[Unit3] AS [mtUnit3],  
		[Unit2Fact] AS [mtUnit2Fact],  
		[Unit3Fact] AS [mtUnit3Fact],  
		[BarCode] AS [mtBarCode],
		[BarCode2] AS [mtBarCode2],
		[BarCode3] AS [mtBarCode3],
		[Type] AS [mtType],  
		[Spec] AS [mtSpec],   
		[Origin] AS [mtOrigin],  
		[Pos] AS [mtPos],   
		[Company] AS [mtCompany],  
		[Color] AS [mtColor],  
		[Dim] AS [mtDim],
		[VAT] AS [mtVAT],   
		[Provenance] AS [mtProvenance],  
		[Quality] AS [mtQuality],  
		[Model] AS [mtModel],  
		[Unit2FactFlag] AS [mtUnit2FactFlag],  
		[Unit3FactFlag] AS [mtUnit3FactFlag],  
		[DefUnit] AS [mtDefUnit],[GroupGuid],  
		[Flag] AS [mtFlag], 
		[mtSecurity],
		CurrencyGuid,
		CurrencyVal,
		dbo.fnGetCurVal(CurrencyGuid, @EndDate) AS CurrencyValByHistory,
		[Whole] AS [mtWhole],
		[Whole2] AS [mtWhole2],
		[Whole3] AS [mtWhole3],
		[Half] AS [mtHalf],
		[Half2] AS [mtHalf2],
		[Half3] AS [mtHalf3],
		[Vendor] AS [mtVendor],
		[Vendor2] AS [mtVendor2],
		[Vendor3] AS [mtVendor3],
		[Export] AS [mtExport],
		[Export2] AS [mtExport2],
		[Export3] AS [mtExport3],
		[Retail] AS [mtRetail],
		[Retail2] AS [mtRetail2],
		[Retail3] AS [mtRetail3],
		[EndUser] AS [mtEndUser],
		[EndUser2] AS [mtEndUser2],
		[EndUser3] AS [mtEndUser3]
	FROM [mt000] AS [mt] INNER JOIN [#MatTbl] AS [m] ON [mt].[Guid] = [m].[MatGuid]  
	DROP TABLE [#MatTbl]  
	CREATE INDEX mttInd ON #MatTbl2([MatGuid] )  
	INSERT INTO [#trbu] 
	SELECT  
		ISNULL([inbu].[buType],[outbu].[buType]) AS [buType], 
		ISNULL([inbu].[buGuid],[outbu].[buGuid]) as [buGuid],  
		ISNULL([inbu].[buNumber],0) AS [InNumber], 
		ISNULL([outbu].[buNumber],0) AS [OutNumber], 
		ISNULL([inbu].[buStorePtr],0x00) AS [InbuStorePtr], 
		ISNULL([outbu].[buStorePtr],0x00) AS [OutbuStorePtr], 
		ISNULL([inbu].[stCodeName],'') AS [InstCodeName], 
		ISNULL([outbu].[stCodeName],'') AS [OutstCodeName], 
		ISNULL([inbu].[buMatAcc],0x00)	AS [InAccGuid], 
		ISNULL([outbu].[buMatAcc],0x00)	AS [OutAccGuid], 
		ISNULL([inbu].[AcCodeName],'')	AS [InAcc], 
		ISNULL([outbu].[AcCodeName],'')	AS [OutAcc]	, 
		ISNULL([inbu].[AcSecurity],[outbu].[AcSecurity]) AS [AccSecurity], 
		ISNULL([inbu].[buNotes],[outbu].[buNotes]) AS [buNotes], 
		ISNULL([inbu].[buCostPtr],0X00)	AS [InCost], 
		ISNULL([inbu].[buCostName], '') AS [InCostName],
		ISNULL([inbu].[buCostLatinName], '') AS [InCostLatinName],
		ISNULL([outbu].[buCostPtr],0X00) AS [OutCost], 
		ISNULL([outbu].[buCostName], '') AS [OutCostName],
		ISNULL([outbu].[buCostLatinName], '') AS [OutCostLatinName],
		ISNULL([inbu].[buSecurity],[outbu].[buSecurity]) AS [buSecurity], 
		ISNULL([inbu].[UserSecurity],[outbu].[UserSecurity]) AS [UserSecurity], 
		ISNULL([inbu].[UserReadPriceSecurity],[outbu].[UserReadPriceSecurity]) AS [UserReadPriceSecurity], 
		ISNULL([inbu].[budate],[outbu].[budate]) AS [budate], 
		ISNULL([inbu].[FixedBuTotal],[outbu].[FixedBuTotal]) AS [FixedBuTotal], 
		ISNULL([inbu].[buDisc],[outbu].[buDisc]) AS [buDisc], 
		ISNULL([inbu].[buExtra],[outbu].[buExtra]) AS [buExtra], 
		ISNULL([inbu].[FixedCurrencyFactor],[outbu].[FixedCurrencyFactor]) AS [FixedCurrencyFactor],
		ISNULL([inbu].[buBranch],[outbu].[buBranch]) AS [buBranch]
	FROM [#bu] AS [inbu]  
	RIGHT JOIN [ts000] AS [ts] ON [ts].[InBillGuid] = [inbu].[buGuid] 
	LEFT JOIN [#bu] AS [outbu] ON [ts].[OutBillGuid] = [outbu].[buGuid] 
	CREATE TABLE [#Result]   
	(   
		[buType] 				[UNIQUEIDENTIFIER],  
		[buGuid] 				[UNIQUEIDENTIFIER], 
		[InNumber] 				[Float],  
		[OutNumber] 			[Float],   
		[biMatPtr] 				[UNIQUEIDENTIFIER],
		[biGUID]				[UNIQUEIDENTIFIER],
		[InbuStorePtr]			[UNIQUEIDENTIFIER],  
		[OutbuStorePtr]			[UNIQUEIDENTIFIER],   
		[InstCodeName]			[NVARCHAR](256) COLLATE ARABIC_CI_AI,   
		[OutstCodeName]			[NVARCHAR](256) COLLATE ARABIC_CI_AI,   
		[InAccGuid]				[UNIQUEIDENTIFIER], 
		[OutAccGuid]			[UNIQUEIDENTIFIER], 
		[InAcc]					[NVARCHAR](256) COLLATE ARABIC_CI_AI,   
		[OutAcc]				[NVARCHAR](256) COLLATE ARABIC_CI_AI,  
		[buNotes]				[NVARCHAR](1000) COLLATE ARABIC_CI_AI,  
		[biNotes]				[NVARCHAR](256) COLLATE ARABIC_CI_AI,  
		[InCost]				[UNIQUEIDENTIFIER], 
		[InCostName]			[NVARCHAR](500),
		[InCostLatinName]		[NVARCHAR](500),
		[OutCost]				[UNIQUEIDENTIFIER],
		[OutCostName]			[NVARCHAR](500),
		[OutCostLatinName]		[NVARCHAR](500),
		[Security]				[INT],   
		[UserSecurity] 			[INT],   
		[UserReadPriceSecurity]	[INT],  
		[MatSecurity]			[INT], 
		[AccSecurity]			[INT],  
		[budate]				[DATETIME],  
		[FixedBuTotal]			[FLOAT],  
		[FixedBuTotalExtra]		[FLOAT],  
		[FixedBuTotalDisc]		[FLOAT],  
		[FixedBiDiscount]		[FLOAT],  
		[FixedBiextra]			[FLOAT],  
		[FixedBiVAT]			[FLOAT],  
		[FixedBiPrice]			[FLOAT],  
		[biQty]					[FLOAT],  
		[biQty2]				[FLOAT],  
		[biQty3]				[FLOAT], 
		[BonusQnt]				[FLOAT], 
		[DISExtraAndDisc]		[FLOAT], -- Discrete Extra and discount.
		[biTotal]				[FLOAT],
		[biLength]				[FLOAT], 
		[biWidth]				[FLOAT], 
		[biHeight]				[FLOAT], 
		[biUnity]				[INT],
		buBranch				UNIQUEIDENTIFIER			 
	) 
	 
	INSERT INTO [#Result] 
	([buType],[buGuid],[InNumber] ,	 
		[OutNumber],[biMatPtr],[biGUID],
		[InbuStorePtr],[OutbuStorePtr], 
		[InstCodeName],[OutstCodeName],	 
		[InAccGuid],[OutAccGuid],	 
		[InAcc],[OutAcc],		 
		[buNotes],[biNotes],		 
		[InCost], [InCostName], [InCostLatinName],
		[OutCost], [OutCostName], [OutCostLatinName],
		[Security],	[UserSecurity], 
		[UserReadPriceSecurity],[MatSecurity],[AccSecurity], 
		[budate], 
		[FixedBuTotal], 
		[FixedBuTotalExtra], 
		[FixedBuTotalDisc], 
		[FixedBiDiscount], 
		[FixedBiextra], 
		[FixedBiVAT], 
		[FixedBiPrice], 
		[biQty]	,   
		[biQty2], 
		[biQty3], 
		[BonusQnt], 
		[DISExtraAndDisc],
		[biTotal],
		[biLength], 
		[biWidth], 
		[biHeight], 
		[biUnity],buBranch) 
	SELECT  
		[buType],[buGuid],[InNumber] ,	 
		[OutNumber] ,[bi].[MatGuid], [bi].[GUID],
		[InbuStorePtr],	[OutbuStorePtr], 
		[InstCodeName],	[OutstCodeName],	 
		[InAccGuid],[OutAccGuid],	 
		[InAcc],[OutAcc],		 
		[buNotes],	[bi].[Notes],		 
		[InCost], [InCostName], [InCostLatinName],
		[OutCost], [OutCostName], [OutCostLatinName],
		[buSecurity],[UserSecurity], 
		[UserReadPriceSecurity],[mtSecurity],[AccSecurity], 
		[budate], 
		[FixedBuTotal], 
		[buExtra], 
		[buDisc], 
		([bi].[discount] + [BonusDisc])*[FixedCurrencyFactor], 
		[bi].[Extra]*[FixedCurrencyFactor], 
		[bi].[vat]*[FixedCurrencyFactor], 
		CASE @PriceType 
			WHEN 0 THEN [bi].[Price]*[bi].[Qty]*[FixedCurrencyFactor] / (CASE [bi].[Unity] 
                                                                                          WHEN 1 THEN 1 
                                                                                          WHEN 2 THEN [mtUnit2Fact] 
                                                                                          ELSE [mtUnit3Fact] 
                                                                                      END)
																					  
			WHEN 1 THEN  (CASE [bi].[Unity] WHEN 1 THEN [mtWhole]
											WHEN 2 THEN [mtWhole2]
											ELSE  [mtWhole3]  END)
											/ mt.CurrencyVal * mt.CurrencyValByHistory / @ReprotCurrencyValue * [bi].[Qty]
											
			WHEN 2 THEN (CASE [bi].[Unity] WHEN 1 THEN [mtHalf]
											WHEN 2 THEN [mtHalf2]
											ELSE  [mtHalf3]  END)
											/ mt.CurrencyVal * mt.CurrencyValByHistory / @ReprotCurrencyValue * [bi].[Qty]
											
			WHEN 3 THEN (CASE [bi].[Unity] WHEN 1 THEN [mtVendor]
											WHEN 2 THEN [mtVendor2]
											ELSE  [mtVendor3]  END)
											/ mt.CurrencyVal * mt.CurrencyValByHistory / @ReprotCurrencyValue * [bi].[Qty]
			
			WHEN 4 THEN (CASE [bi].[Unity] WHEN 1 THEN [mtExport]
											WHEN 2 THEN [mtExport2]
											ELSE  [mtExport3]  END)
											/ mt.CurrencyVal * mt.CurrencyValByHistory / @ReprotCurrencyValue * [bi].[Qty]
											
			WHEN 5 THEN (CASE [bi].[Unity] WHEN 1 THEN [mtRetail]
											WHEN 2 THEN [mtRetail2]
											ELSE  [mtRetail3]  END)
											/ mt.CurrencyVal * mt.CurrencyValByHistory / @ReprotCurrencyValue * [bi].[Qty]
											
			WHEN 6 THEN (CASE [bi].[Unity] WHEN 1 THEN [mtEndUser]
											WHEN 2 THEN [mtEndUser2]
											ELSE  [mtEndUser3]  END)
											/ mt.CurrencyVal * mt.CurrencyValByHistory / @ReprotCurrencyValue * [bi].[Qty]
			WHEN 7 THEN dbo.fnGetOutbalanceAveragePriceByUnit(mt.matGuid, bu.budate, [bi].[Unity]) * [bi].[Qty] / @ReprotCurrencyValue
		END,
		[bi].[Qty], 
		CASE [mt].[mtUnit2FactFlag] WHEN 0 THEN CASE [mt].[mtUnit2Fact] WHEN 0 THEN 0 ELSE [bi].[Qty] /  [mt].[mtUnit2Fact] END ELSE [Qty2] END,  
		CASE [mt].[mtUnit3FactFlag] WHEN 0 THEN CASE [mt].[mtUnit3Fact] WHEN 0 THEN 0 ELSE [bi].[Qty] /  [mt].[mtUnit3Fact] END ELSE [Qty3] END,   
		[BonusQnt], 
		0, -- DISExtraAndDisc
		0, -- biTotal
		[bi].[Length], 
		[bi].[Width], 
		[bi].[Height], 
		[bi].[Unity],buBranch
	FROM [#trbu] AS [bu]  
	INNER JOIN [bi000] AS [bi] ON [bu].[buGuid] = [bi].[ParentGuid] 
	INNER JOIN 	[#MatTbl2] AS [mt] ON [mt].[MatGuid] = [bi].[MatGuid]
	WHERE 
		( (@NotesContain = '')	OR ([BuNotes] LIKE '%'+ @NotesContain + '%') OR ( [Bi].[Notes] LIKE '%' + @NotesContain + '%'))   
		AND( (@NotesNotContain ='')	OR (([BuNotes] NOT LIKE '%' + @NotesNotContain + '%') AND ([Bi].[Notes] NOT LIKE '%'+ @NotesNotContain + '%'))) 
	
	IF @IsAdmin = 0   
		EXEC [prcCheckSecurity]   
	-- calc non-zero DISExtraAndDisc records
	IF @DiscreteExtraAndDisc = 1
	BEGIN
		UPDATE [#Result] SET
		[DISExtraAndDisc] = (([FixedBuTotalExtra]+FixedBiVAT)*[FixedBiPrice])/FixedBuTotal - ([FixedBuTotalDisc]*FixedBiPrice)/[FixedBuTotal] - FixedBiDiscount + FixedBiextra
		WHERE FixedBuTotal != 0
	END
	-- apply DISExtraAndDisc and bonus calculations:
	UPDATE [#Result] SET
	-- [biTotal] = CASE @DiscreteExtraAndDisc WHEN 1 THEN ([FixedBiPrice]+[DISExtraAndDisc])/([biQty]+[BonusQnt]) ELSE [FixedBiPrice]/([biQty]+[BonusQnt]) END,
	[biTotal] = [FixedBiPrice]/([biQty]+[BonusQnt]),
	[biQty] = [biQty] + CASE @EmbeddedBonus WHEN 1 THEN [BonusQnt] ELSE 0 END,
	--[FixedBiPrice] = [FixedBiPrice] + CASE [DISExtraAndDisc] WHEN 0 THEN 0 ELSE [DISExtraAndDisc] END
	FixedBiDiscount =  CASE WHEN [DISExtraAndDisc] < 0 THEN
									( CASE @DiscreteExtraAndDisc WHEN 0 THEN [FixedBiDiscount] ELSE ABS([DISExtraAndDisc]) END)
									ELSE [FixedBiDiscount] END,
	FixedBiextra = CASE WHEN [DISExtraAndDisc] > 0 THEN
								  ( CASE @DiscreteExtraAndDisc WHEN 0 THEN [FixedBiextra] ELSE [DISExtraAndDisc] END)
								  ELSE [FixedBiextra] END

	SET @BuStr = 'SELECT ' 
	SET @BuStr = @BuStr + '[buType],[buGuid],[InNumber],[OutNumber] , 
		[InbuStorePtr],[OutbuStorePtr],[InAccGuid],[budate],		 
		[OutAccGuid],[InAcc],[OutAcc],[buNotes],[mt].[mtVAT],[biGUID],
		[MatGuid],[biNotes],[mtName],[InstCodeName],[OutstCodeName],' 
	
	IF @IsAdmin = 1  
	BEGIN 
		SET @BuStr = @BuStr + '[FixedBuTotal],	[FixedBuTotalExtra],[FixedBuTotalDisc],
		[FixedBiDiscount],[FixedBiextra],[FixedBiVAT],[FixedBiPrice],' 
	END 
	ELSE 
	BEGIN 
		SET @BuStr = @BuStr + ' 
			CASE WHEN [r].[UserReadPriceSecurity] >= [r].[Security] THEN [r].[FixedBuTotal] ELSE 0 END AS [FixedBuTotal],  
			CASE WHEN [r].[UserReadPriceSecurity] >= [r].[Security] THEN [r].[FixedBuTotalExtra]  ELSE 0 END AS [FixedBuTotalExtra],  
			CASE WHEN [r].[UserReadPriceSecurity] >= [r].[Security] THEN [r].[FixedBuTotalDisc]   ELSE 0 END AS [FixedBuTotalDisc],
			CASE WHEN [r].[UserReadPriceSecurity] >= [r].[Security] THEN [r].[FixedBiDiscount]  ELSE 0 END AS [FixedBiDiscount], 
			CASE WHEN [r].[UserReadPriceSecurity] >= [r].[Security] THEN [r].[FixedBiextra] ELSE 0 END AS [FixedBiextra], 
			CASE WHEN [r].[UserReadPriceSecurity] >= [r].[Security] THEN [FixedBiVAT] ELSE 0 END AS [FixedBiVAT], 
			CASE WHEN [r].[UserReadPriceSecurity] >= [r].[Security] THEN [FixedBiPrice] ELSE 0 END AS [FixedBiPrice],' 
	END 

	-- Unit Name:
	IF @UseUnit = 4 -- movement unit:
		SET @BuStr = @BuStr + '	CASE [biUnity] WHEN 1 THEN [mtUnity] WHEN 2 THEN CASE [mt].[mtUnit2Fact] WHEN 0 THEN [mtUnity] ELSE [mtUnit2] END  ELSE CASE [mt].[mtUnit3Fact] WHEN 0 THEN [mtUnity] ELSE [mtUnit3] END END AS [mtUnityName],' 
	ELSE IF @UseUnit = 0 
		SET @BuStr = @BuStr + '	[mt].[mtUnity] AS [mtUnityName],' 
	ELSE IF @UseUnit = 1 
		SET @BuStr = @BuStr + '	CASE [mt].[mtUnit2Fact] WHEN 0 THEN [mtUnity] ELSE [mtUnit2] END  AS [mtUnityName],' 
	ELSE IF @UseUnit = 2 
		SET @BuStr = @BuStr + ' CASE [mt].[mtUnit2Fact] WHEN 0 THEN [mtUnity] ELSE [mtUnit3] END  AS [mtUnityName] ,' 
	ELSE 
		SET @BuStr = @BuStr + ' [mtDefUnitName] AS [mtUnityName],' 



	IF @Flag & 0x00000010 > 0 
		SET @BuStr = @BuStr + '[biQty2],[biQty3],[mtUnit2],[mtUnit3],' 
	IF @UseUnit = 4  
		SET @BuStr = @BuStr + ' 
				[biQty]	/CASE  [biUnity] WHEN 1 THEN 1 WHEN 2 THEN [mtUnit2Fact]  WHEN 3 THEN [mtUnit3Fact] ELSE [mtDefUnitFact] END AS [biQty],  
				[BonusQnt] /CASE [biUnity] WHEN 1 THEN 1 WHEN 2 THEN [mtUnit2Fact]  WHEN 3 THEN [mtUnit3Fact] ELSE [mtDefUnitFact] END AS [BonusQnt]'
	ELSE IF @UseUnit = 0 
		SET @BuStr = @BuStr  + '[biQty]  as [biQty] , [BonusQnt]  as  [BonusQnt] '
	ELSE IF @UseUnit = 1 
		SET @BuStr = @BuStr + ' 
				[biQty] /CASE [mtUnit2Fact] WHEN 0 THEN 1 ELSE [mtUnit2Fact] END AS [biQty],
				[BonusQnt]/ CASE [mtUnit2Fact] WHEN 0 THEN 1 ELSE [mtUnit2Fact] END AS [BonusQnt]' 
	ELSE IF @UseUnit = 2 
		SET @BuStr = @BuStr + ' 
				[biQty] /CASE [mtUnit3Fact] WHEN 0 THEN 1 ELSE [mtUnit3Fact] END AS [biQty], 
				[BonusQnt]/ CASE [mtUnit3Fact] WHEN 0 THEN 1 ELSE [mtUnit3Fact] END AS [BonusQnt]' 
	ELSE 
		SET @BuStr = @BuStr  + ' 
				[biQty] /CASE [mtDefUnitFact] WHEN 0 THEN 1 ELSE [mtDefUnitFact] END AS [biQty],
				[BonusQnt]/ CASE [mtDefUnitFact] WHEN 0 THEN 1 ELSE [mtDefUnitFact] END AS [BonusQnt]'
				
	SET @BuStr = @BuStr + ',[biTotal] ,ISNULL(br.Name,'''') brName'
	SET @BuStr = @BuStr + ' FROM [#Result] AS [r] INNER JOIN [#MatTbl2] AS [mt] ON [mt].[MatGuid] = [r].[biMatPtr] ' 
	SET @BuStr = @BuStr + ' LEFT JOIN br000 BR ON br.Guid = buBranch '
	SET @BuStr = @BuStr + ' ORDER BY [buDate],[buType],[InNumber],[OutNumber]'	 
	
	-- detailed result
	EXEC (@BuStr) 
	
	-- master result:
	SELECT buType, 
	buGuid,
	InNumber,
	budate,
	InAcc,
	OutAcc,
	buNotes,
	InstCodeName,
	OutstCodeName,
	InCost,
	InCostName,
	InCostLatinName,
	OutCost,
	OutCostName,
	OutCostLatinName,
	SUM(FixedBuTotal) AS [FixedBuTotal],
	SUM(FixedBiDiscount) AS [FixedBiDiscount],
	SUM(FixedBiextra) AS [FixedBiextra],
	[FixedBuTotalExtra],
	[FixedBuTotalDisc],
	SUM(FixedBiPrice) AS [FixedBiPrice],
	SUM(biQty) AS [biQty],
	SUM(BonusQnt) AS [BonusQnt]
	FROM [#Result]
	GROUP BY buType, buGuid, InNumber, budate, InAcc, OutAcc, buNotes, InstCodeName,
	OutstCodeName, InCost, InCostName, InCostLatinName, OutCost, OutCostName, OutCostLatinName, FixedBuTotalExtra, FixedBuTotalDisc
	
	SELECT * FROM [#SecViol] 
############################################################################
CREATE FUNCTION fnGetTransInOutIDs(@OutBillGUID UNIQUEIDENTIFIER, @OutBillTypeGUID UNIQUEIDENTIFIER)
RETURNS @Result TABLE(InGUID UNIQUEIDENTIFIER, OutGUID UNIQUEIDENTIFIER)
BEGIN
	DECLARE @billNumber BIGINT;

	-- „‰«ﬁ·… „⁄—›… „‰ ≈œ«—… «·√‰„«ÿ
	IF EXISTS(SELECT 1 FROM ts000 WHERE OutBillGUID = @OutBillGUID)
	BEGIN
		INSERT INTO @Result
		SELECT InBillGuid, OutBillGUID FROM ts000 WHERE OutBillGUID = @OutBillGUID
	END
	-- „‰«ﬁ·… ⁄«œÌ…
	ELSE IF EXISTS(SELECT 1 FROM bt000 WHERE GUID = @OutBillTypeGUID AND Type = 2 AND BillType = 5 AND SortNum = 4)
	BEGIN
		SELECT @billNumber = Number FROM Bu000 WHERE GUID = @OutBillGUID;

		INSERT INTO @Result
		SELECT 
			(SELECT TOP 1 GUID FROM bu000 WHERE Number = @billNumber AND 
				TypeGuid = (SELECT TOP 1 GUID FROM bt000 WHERE Type = 2 AND BillType = 4 AND SortNum = 3))
			, 
			@OutBillGUID
	END
	-- „‰«ﬁ·… »ﬁÌœ
	ELSE IF EXISTS(SELECT 1 FROM bt000 WHERE GUID = @OutBillTypeGUID AND Type = 2 AND BillType = 5 AND SortNum = 8)
	BEGIN
		SELECT @billNumber = Number FROM Bu000 WHERE GUID = @OutBillGUID;

		INSERT INTO @Result
		SELECT 
			(SELECT TOP 1 GUID FROM bu000 WHERE Number = @billNumber AND 
				TypeGuid = (SELECT TOP 1 GUID FROM bt000 WHERE Type = 2 AND BillType = 4 AND SortNum = 7))
			, 
			@OutBillGUID
	END
	
	RETURN
END
###################################################################################
#END
		
		
