##################################################################
CREATE PROC prcBill_ReGenCostEntrys
	@ceGuid						[UNIQUEIDENTIFIER],
	@buGuid						[UNIQUEIDENTIFIER],
	@btGuid						[UNIQUEIDENTIFIER],
	@UseOutbalanceAVGPrice		[BIT] = 0,
	@buDate						[DATETIME],
	@btDirection				[INT],
	@btConsideredGiftsOfSales	[BIT],
	@btShortEntry				[BIT],
	@txt_bonus					[NVARCHAR](50),
	@btCostToItems				[BIT],
	@buNotes					[NVARCHAR](1000),
	@buCurrencyVAL				[FLOAT],
	@buVendor					[INT],
	@buSalesManPtr				[BIGINT],
	@buCurrencyGUID				[UNIQUEIDENTIFIER],
	@btCostToCust				[BIT],
	@recType_ItemsContInvCost	[INT],
	@recType_ContInvStock		[INT]
AS
	SET NOCOUNT ON

	DECLARE @language [INT]	SET @language = [dbo].[fnConnections_getLanguage]() 

	DECLARE 
		@buIsPosted			[INT], 
		@btDefCostPrice		[FLOAT],
		@btDefCostAccGUID	[UNIQUEIDENTIFIER], 
		@btDefStockAccGUID	[UNIQUEIDENTIFIER];
	
	DECLARE @t_ContInv TABLE ( 
		[mtGUID]	[UNIQUEIDENTIFIER], 
		[Price]		[FLOAT], 
		[Unity] 	INT,
		[UnitFact]  FLOAT)   

	DECLARE @t_contInvBuf TABLE ( 
		[mtGUID]	[UNIQUEIDENTIFIER], 
		[Price]		[FLOAT],   
		[Unity] 	INT,
		[UnitFact]  FLOAT)   

	SELECT @buIsPosted = [buIsPosted] FROM [vwBu] WHERE [buGUID] = @buGuid
	
	SELECT 
		@btDefCostPrice =		[btDefCostPrice],
		@btDefCostAccGUID =		[btDefCostAcc],
		@btDefStockAccGUID =	[btDefStockAcc]
	FROM [vwBt]
	WHERE [btGUID] = @btGuid
	
	IF @btDefCostPrice = 2048 
		INSERT INTO @t_ContInvBuf 
			SELECT [biMatPtr],
					CASE WHEN @UseOutbalanceAVGPrice = 1 
						THEN [dbo].fnGetOutbalanceAveragePrice([biMatPtr], @buDate)
						ELSE 
							CASE ISNULL((SELECT [DefPrice] FROM [cu000] WHERE [GUID] = [buCustPtr]), 0) 
								WHEN 0 THEN CASE [biUnity] WHEN 1 THEN [mtWhole]	WHEN 2 THEN [mtWhole2]		ELSE [mtWhole3]		END 
								WHEN 1 THEN CASE [biUnity] WHEN 1 THEN [mtHalf]		WHEN 2 THEN [mtHalf2]		ELSE [mtHalf3]		END 
								WHEN 2 THEN CASE [biUnity] WHEN 1 THEN [mtExport]	WHEN 2 THEN [mtExport2]		ELSE [mtExport3]	END 
								WHEN 3 THEN CASE [biUnity] WHEN 1 THEN [mtVendor]	WHEN 2 THEN [mtVendor2]		ELSE [mtVendor3]	END 
								WHEN 4 THEN CASE [biUnity] WHEN 1 THEN [mtRetail]	WHEN 2 THEN [mtRetail2]		ELSE [mtRetail3]	END 
								WHEN 5 THEN CASE [biUnity] WHEN 1 THEN [mtEndUser]	WHEN 2 THEN [mtEndUser2]	ELSE [mtEndUser3]	END 
								ELSE 0 
							END
					END,   
				[biUnity],
				[mtUnitFact]   
			FROM [vwExtended_bi] 
			WHERE [buGUID] = @buGuid 
	ELSE 
		INSERT INTO @t_ContInvBuf 
			SELECT [biMatPtr], 
					CASE WHEN @UseOutbalanceAVGPrice = 1 
						THEN [dbo].fnGetOutbalanceAveragePrice([biMatPtr], @buDate)
						ELSE
							CASE @btDefCostPrice   
								WHEN 2		THEN [biUnitCostPrice] -- CASE [biBillQty] + [biBillBonusQnt] 	WHEN 0 THEN 0 ELSE (([biPrice] * [biBillQty]) - [biProfits] - ([biQty] * [biUnitDiscount]* [btDiscAffectProfit]) + ([biQty] * [biUnitExtra] * [btExtraAffectProfit])) / ([biBillQty] + [biBillBonusQnt]) END 
								WHEN 4		THEN CASE [biUnity] WHEN 1 THEN [mtWhole]	WHEN 2 THEN [mtWhole2]	ELSE [mtWhole3]		END 
								WHEN 8		THEN CASE [biUnity] WHEN 1 THEN [mtHalf]	WHEN 2 THEN mtHalf2		ELSE [mtHalf3]		END 
								WHEN 16		THEN CASE [biUnity] WHEN 1 THEN [mtExport]	WHEN 2 THEN [mtExport2]	ELSE [mtExport3]	END 
								WHEN 32		THEN CASE [biUnity] WHEN 1 THEN [mtVendor]	WHEN 2 THEN [mtVendor2]	ELSE [mtVendor3]	END 
								WHEN 64		THEN CASE [biUnity] WHEN 1 THEN [mtRetail]	WHEN 2 THEN [mtRetail2]	ELSE [mtRetail3]	END 
								WHEN 128	THEN CASE [biUnity] WHEN 1 THEN [mtEndUser]	WHEN 2 THEN [mtEndUser2] ELSE [mtEndUser3] 	END   
								WHEN 256	THEN [biPrice] 
								WHEN 512	THEN CASE [biUnity] WHEN 1 THEN [mtLastPrice]	WHEN 2 THEN [mtLastPrice2] 	ELSE [mtLastPrice3]	END 
								ELSE 0 
							END
						END,   
				[biUnity],
				[mtUnitFact]   
			FROM [vwExtended_bi] 
			WHERE [buGUID] = @buGuid 

	INSERT INTO @t_contInv 
	SELECT [mtGuid], AVG([price]), [unity], [UnitFact]
	FROM @t_contInvBuf 
	GROUP BY [mtGuid], [unity], [UnitFact]

--insert Items ContInv CostAccounts: 
	SELECT --DISTINCT   
		@recType_ItemsContInvCost, 
		[biNumber], 
		@buDate, 
		CASE @btDirection 
			WHEN 1 THEN 0 
			ELSE 
				CASE WHEN n.BonusOnly = 0 
					THEN [ci].[Price] * [ci].UnitFact * CASE WHEN @btConsideredGiftsOfSales = 1 THEN ([bi].[biBillQty] - [bi].[biBillBonusQnt]) ELSE [bi].[biBillQty] END
					ELSE [ci].[Price] * [ci].UnitFact * CASE WHEN @btConsideredGiftsOfSales = 1 THEN [bi].[biBillBonusQnt] ELSE 0 END 
				END
		END,
		CASE @btDirection 
			WHEN 1 THEN 
				CASE WHEN n.BonusOnly = 0
					THEN [ci].[Price] * [ci].UnitFact * CASE WHEN @btConsideredGiftsOfSales = 1 THEN ([bi].[biBillQty] - [bi].[biBillBonusQnt]) ELSE [bi].[biBillQty] END
					ELSE [ci].[Price] * [ci].UnitFact * CASE WHEN @btConsideredGiftsOfSales = 1 THEN [bi].[biBillBonusQnt] ELSE 0 END
				END
			ELSE 0 
		END, 
		CASE @btShortEntry WHEN 1 THEN CAST (@buNotes AS NVARCHAR(1000)) ELSE CASE [biNotes] WHEN '' THEN [mtName] + (CASE WHEN n.BonusOnly = 1 THEN ' (' + @txt_bonus + ')' ELSE '' END) ELSE [mtName] + '-' + [biNotes] END END, 
		@buCurrencyVal, 
		[biClassPtr], 
		@buVendor, 
		@buSalesManPtr, 
		@ceGuid, 
		[maCostAccGUID], 
		@buCurrencyGUID, 
		CASE @btCostToItems WHEN 1 THEN [biCostPtr] ELSE 0x0 END, 
		[maStoreAccGUID], 
		CASE @btShortEntry WHEN 1 THEN 0x0 ELSE biGuid END,
		301,
		0x0 -- DiGUID
	FROM #t_bi AS [bi] INNER JOIN @t_ContInv AS [ci] ON [bi].[biMatPtr] = [ci].[mtGUID] AND [ci].[unity] = [bi].[biUnity] CROSS JOIN (SELECT 0 AS BonusOnly UNION SELECT 1 AS BonusOnly) n  
--	WHERE bi.biProfits <> 0  
	UNION ALL
-- 2.9: insert ContInv StockAccount data:  
		--INSERT INTO #t_en ([recType], [RecBiNumber], [Date], [Debit], [Credit], [Notes], [CurrencyVal], [Class], [Vendor], [SalesMan], [ParentGUID], [accountGUID], [CurrencyGUID], [CostGUID], [contraAccGUID], [BiGuid], [Type]) 
	SELECT -- DISTINCT   
		@recType_ContInvStock, 
		[biNumber], 
		@buDate, 
		CASE @btDirection WHEN 1 
			THEN 
				CASE WHEN n.BonusOnly = 0 
					THEN [ci].[Price] * [ci].UnitFact * CASE WHEN @btConsideredGiftsOfSales = 1 THEN ([bi].[biBillQty] - [bi].[biBillBonusQnt]) ELSE [bi].[biBillQty] END
					ELSE [ci].[Price] * [ci].UnitFact * CASE WHEN @btConsideredGiftsOfSales = 1 THEN [bi].[biBillBonusQnt] ELSE 0 END
				END
			ELSE 0 
		END, 
		CASE @btDirection WHEN 1 
			THEN 0 
			ELSE 
				CASE WHEN n.BonusOnly = 0 
					THEN [ci].[Price] * [ci].UnitFact * CASE WHEN @btConsideredGiftsOfSales = 1 THEN ([bi].[biBillQty] - [bi].[biBillBonusQnt]) ELSE [bi].[biBillQty] END
					ELSE [ci].[Price] * [ci].UnitFact * CASE WHEN @btConsideredGiftsOfSales = 1 THEN [bi].[biBillBonusQnt] ELSE 0 END 
				END
		END, 
		CASE @btShortEntry WHEN 1 THEN CAST (@buNotes AS NVARCHAR(1000)) ELSE CASE [biNotes] WHEN '' THEN [mtName] + (CASE WHEN n.BonusOnly = 1 THEN ' (' + @txt_bonus + ')' ELSE '' END) ELSE [mtName] + '-' + [biNotes] END END, 
		@buCurrencyVal, 
		[biClassPtr], 
		@buVendor, 
		@buSalesManPtr, 
		@ceGuid, 
		[maStoreAccGUID], 
		@buCurrencyGUID, 
		CASE @btCostToCust WHEN 1 THEN [biCostPtr] ELSE 0x0 END, 
		[maCostAccGUID], 
		[biGuid],
		301,
		0x0 -- DiGUID
	FROM #t_bi  AS [bi] INNER JOIN @t_ContInv AS [ci] ON [bi].[biMatPtr] = [ci].[mtGUID] AND [ci].[unity] = [bi].[biUnity] CROSS JOIN (SELECT 0 AS BonusOnly UNION SELECT 1 AS BonusOnly) n
	WHERE [ci].[Price] <> 0 
##################################################################
CREATE PROCEDURE prcReGenCostEntriesPrepare
	@SrcGuid	UNIQUEIDENTIFIER,
	@StartDate	DATETIME,
	@EndDate	DATETIME,
	@WithBillCount INT = 1
AS
	SET NOCOUNT ON;
	
	SELECT 
		a.Guid, 
		CASE [dbo].[fnConnections_getLanguage]() WHEN 0 THEN [Name] ELSE CASE [LatinName] WHEN '' THEN [Name] ELSE [LatinName] END END AS [Name] 
	INTO #bu 
	FROM 
		[fnGetBillsTypesList](@SrcGuid, DEFAULT) a 
		INNER JOIN bt000 b ON b.Guid = a.Guid
	IF(@WithBillCount = 1)
	BEGIN
		SELECT 
			bu.GUID AS [BuGuid], 
			SUM(CASE en.Type WHEN 301 THEN 1 ELSE 0 END) AS Cnt
		INTO #billcnt
		FROM 
			bu000 bu 
			INNER JOIN #bu b ON bu.TypeGuid = b.GUID
			INNER JOIN er000 er ON er.ParentGuid = bu.GUID
			INNER JOIN ce000 ce ON er.EntryGUID = ce.GUID
			INNER JOIN en000 en ON en.ParentGUID = ce.GUID
		WHERE 
			[bu].[Date] BETWEEN @StartDate AND @EndDate
		GROUP BY 
			bu.GUID
		
		SELECT * FROM #billcnt WHERE Cnt = 0
	END

	SELECT 
		bu.GUID AS [BuGuid], 
		bu.TypeGUID AS [BtGuid], 
		b.[Name] AS [btName], 
		ce.GUID AS [ceGuid],
		bu.Number AS [BuNumber]
	FROM 
		bu000 bu 
		INNER JOIN #bu b ON bu.TypeGuid = b.GUID
		INNER JOIN er000 er ON er.ParentGuid = bu.GUID
		INNER JOIN ce000 ce ON er.EntryGUID = ce.GUID
	WHERE 
		[bu].[Date] BETWEEN @StartDate AND @EndDate
	ORDER BY 
		[bu].[Date], [bu].[Number]
##################################################################
CREATE PROC prcMReGenCostEntries
	@BillGUID				[UNIQUEIDENTIFIER],
	@UseOutbalanceAVGPrice	[BIT] = 0
AS
	SET NOCOUNT ON; 

	--IF NOT EXISTS (SELECT * FROM [en000] WHERE [ParentGUID] = @ceGUID AND [Type] = 301)
	--	RETURN

	DECLARE @IsGCCSystemEnabled [BIT]
	SET @IsGCCSystemEnabled = dbo.fnOption_GetInt('AmnCfg_EnableGCCTaxSystem', '0')

	DECLARE @ceGUID [UNIQUEIDENTIFIER]
	SELECT TOP 1 @ceGUID = ce.GUID FROM bu000 bu INNER JOIN er000 er ON bu.GUID = er.ParentGUID INNER JOIN ce000 ce ON ce.GUID = er.EntryGUID WHERE bu.GUID = @BillGUID
	IF ISNULL(@ceGUID, 0x0) = 0x0
		RETURN

	DECLARE @language [INT]	SET @language = [dbo].[fnConnections_getLanguage]() 

	DECLARE @maxNum						[INT],	
			@buDate						[DATETIME],
			@buIsPosted					[INT], 
			@btGuid						[UNIQUEIDENTIFIER],
		    @btDefCostPrice				[FLOAT],
			@btShortEntry				[BIT],
			@btConsideredGiftsOfSales	[BIT],
			@btDirection				[INT],
			@btDefCostAccGUID			[UNIQUEIDENTIFIER], 
			@btDefStockAccGUID			[UNIQUEIDENTIFIER],
			@btCostToItems				[BIT],
			@buMatAccGUID				[UNIQUEIDENTIFIER], 
			@buVATAccGUID				[UNIQUEIDENTIFIER],
			@btDefBillAccGUID			[UNIQUEIDENTIFIER],
			@buNotes					[NVARCHAR](1000),
			@buCustAccGUID				[UNIQUEIDENTIFIER],
			@buCurrencyVAL				[FLOAT],
			@buSalesManPtr				[BIGINT],	
			@buVendor					[INT],
			@buCurrencyGUID				[UNIQUEIDENTIFIER],
			@buCustomerGUID				[UNIQUEIDENTIFIER],
			@btCostToCust				[BIT],
			@btBillType					[INT],
			@ceIsPosted					[BIT];

	CREATE TABLE #t_bi( 
		[biGuid]					[UNIQUEIDENTIFIER],
		[mtName]					[NVARCHAR](256) COLLATE ARABIC_CI_AI , 
		[biMatPtr]					[UNIQUEIDENTIFIER], 
		[biCurrencyVAL]				[FLOAT], 
		[biClassPtr]				[NVARCHAR](256) COLLATE ARABIC_CI_AI , 
		[biCurrencyPtr]				[UNIQUEIDENTIFIER], 
		[biVAT]						[FLOAT], 
		[biNumber]					[INT], 
		[biPrice]					[FLOAT], 
		[biDiscount]				[FLOAT], 
		[biBonusDisc]				[FLOAT],
		[biExtra]					[FLOAT],
		[biBillQty]					[FLOAT], 
		[biBillBonusQnt]			[FLOAT], 
		[biNotes]					[NVARCHAR](1000) COLLATE ARABIC_CI_AI, 
		[biCostPtr]					[UNIQUEIDENTIFIER], 
		[biProfits]					[FLOAT], 
		[biUnity]					[INT],   
		[maMatAccGUID]				[UNIQUEIDENTIFIER], 
		[maDiscAccGUID]				[UNIQUEIDENTIFIER], 
		[maExtraAccGUID]			[UNIQUEIDENTIFIER], 
		[maVATAccGUID]				[UNIQUEIDENTIFIER], 
		[maStoreAccGUID]			[UNIQUEIDENTIFIER], 
		[maCostAccGUID]				[UNIQUEIDENTIFIER], 
		[maBonusAccGuid]			[UNIQUEIDENTIFIER], 
		[maBonusContraAccGuid]		[UNIQUEIDENTIFIER],
		[biContractDiscount]		[FLOAT], 
		[maContractDiscAccGUID]		[UNIQUEIDENTIFIER],
		[biBillname]				[NVARCHAR](256) COLLATE ARABIC_CI_AI ,
		[biBillNumber]					[INT],
		[biIsApplyTaxOnGifts]		[BIT], 
		[biMatGroupPtr] [UNIQUEIDENTIFIER],
		[biSOGuid] [UNIQUEIDENTIFIER],
		biTotalDiscountPercent		FLOAT,
		biTotalExtraPercent			FLOAT, 
		maCashAccGUID  [UNIQUEIDENTIFIER],
		biExcise FLOAT,
		biReversCharge FLOAT,
		IsProfitMargin BIT)

	CREATE Table #t_en ( 
		[ID]				[INT] IDENTITY(1,1),
		[recType]			[INT], 
		[RecBiNumber]		[INT], 
		[Date]				[DATETIME], 
		[Debit]				[FLOAT], 
		[Credit]			[FLOAT], 
		[Notes]				[NVARCHAR](1000) COLLATE ARABIC_CI_AI, 
		[CurrencyVal]		[FLOAT], 
		[Class]				[NVARCHAR](256) COLLATE ARABIC_CI_AI , 
		[Vendor]			[INT], 
		[SalesMan]			[BIGINT], 
		[ParentGUID]		[UNIQUEIDENTIFIER], 
		[accountGUID]		[UNIQUEIDENTIFIER], 
		[CurrencyGUID]		[UNIQUEIDENTIFIER], 
		[CostGUID]			[UNIQUEIDENTIFIER], 
		[contraAccGUID]		[UNIQUEIDENTIFIER],
		[BiGuid]			[UNIQUEIDENTIFIER],
		[Type]				[INT] DEFAULT 0,
		DiGUID				[UNIQUEIDENTIFIER] DEFAULT 0x0 ) 

	DECLARE @txt_bonus [NVARCHAR](50) 
	SET @txt_bonus = [dbo].[fnStrings_get]('BILLENTRY\ITEMS_BONUS', @language) 

	SELECT 
		@btGuid			= [TypeGUID],
		@buIsPosted		= [IsPosted], 
		@buCustAccGUID	= [CustAccGUID], 
		@buCurrencyVAL	= [CurrencyVAL], 
		@buCurrencyGUID	= [CurrencyGUID], 
		@buDate			= [Date], 
		@buMatAccGUID	= [MatAccGUID], 
		@buVATAccGUID	= [VATAccGUID],
		@buNotes		= [bu].[Notes], 
		@buSalesManPtr	= [SalesManPtr], 
		@buVendor		= [Vendor], 
		@buCustomerGUID	= [CustGUID]
	FROM 
		[vtBu] AS [bu]
		LEFT JOIN [vtCu] ON [bu].[CustGUID] = [vtCu].[GUID]
	WHERE [bu].[GUID] = @BillGUID 

	SELECT 
		@btDirection				= [btDirection], 
		@btDefBillAccGUID			= [btDefBillAcc], 
		@btDefCostPrice				= [btDefCostPrice], 
		@btConsideredGiftsOfSales	= [btConsideredGiftsOfSales],
		@btCostToItems				= [btCostToItems], 
		@btCostToCust				= [btCostToCust], 
		@btShortEntry				= [btShortEntry], 
		@btBillType					= [bt].[BillType],
		@btDefCostPrice				= [btDefCostPrice],
		@btShortEntry				= [btShortEntry], 
		@btConsideredGiftsOfSales	= [btConsideredGiftsOfSales],
		@btDirection				= [btDirection],
		@btDefCostAccGUID			= [btDefCostAcc],
		@btDefStockAccGUID			= [btDefStockAcc],
		@btCostToItems				= [btCostToItems]
	FROM 
		[vwBt] AS [vwbt] 
		INNER JOIN bt000 AS [bt] ON [vwbt].[btGuid] = [bt].[Guid]
	WHERE 
		[btGUID] = @btGuid

	INSERT INTO #t_bi EXEC prcBill_GetBiFields 
							@btConsideredGiftsOfSales, @buMatAccGUID, @btDefBillAccGUID, @buVATAccGUID, 
							@buCustAccGUID, @btBillType, @IsGCCSystemEnabled, @BillGUID, @buCustomerGUID		
	-- IF @buIsPosted != 0 
	-- BEGIN
	INSERT INTO #t_en 
	EXEC prcBill_ReGenCostEntrys 
			@ceGUID, @BillGUID, @btGuid, @UseOutbalanceAVGPrice, @buDate, @btDirection, @btConsideredGiftsOfSales, 
			@btShortEntry, @txt_bonus, @btCostToItems, @buNotes, @buCurrencyVAL, @buVendor, @buSalesManPtr, 
			@buCurrencyGUID, @btCostToCust, 0, 0						
	-- END

	SELECT @ceIsPosted = [IsPosted] FROM ce000 WHERE [GUID] = @ceGUID 

	-- unpost
	IF @ceIsPosted = 1 
		UPDATE [ce000] 
		SET [IsPosted] = 0
		WHERE [GUID] = @ceGUID	

	DELETE FROM [en000] WHERE [ParentGUID] = @ceGUID AND [Type] = 301

	SELECT @maxNum = MAX(Number) FROM en000 WHERE [ParentGUID] = @ceGUID

	INSERT INTO [en000] ([Number], [Date], [Debit], [Credit], [Notes], [CurrencyVal], [Class], [Vendor], [SalesMan], [ParentGUID], [accountGUID], [CurrencyGUID], [CostGUID], [contraAccGUID], [BiGuid], [Type]) 
	SELECT 
		[en].[ID] + @maxNum,
		[Date], 
		[Debit], 
		[Credit], 
		[Notes], 
		[CurrencyVal], 
		[Class], 
		[Vendor], 
		[SalesMan], 
		[ParentGUID], 
		[accountGUID], 
		[CurrencyGUID], 
		ISNULL([CostGUID], 0x0), 
		ISNULL([contraAccGUID], 0x0),
		ISNULL([BiGuid], 0x0),
		[Type]
	FROM  #t_en AS [en]
	WHERE ([Credit] <> 0 OR [Debit] <> 0) AND ISNULL([AccountGUID],0x0) != 0x0 	

	UPDATE ce000
	SET 
		[Debit] =	[en].[SumDebit], 
		[Credit] =	[en].[SumCredit]
	FROM (SELECT SUM([Debit]) AS [SumDebit], SUM([Credit]) AS [SumCredit] FROM en000 WHERE [ParentGUID] = @ceGUID) AS en

	-- Post: 
	IF @ceIsPosted = 1 
		UPDATE [ce000] 
		SET 
			[IsPosted] = 1, 
			[PostDate] = GETDATE()
		WHERE 
			[GUID] = @ceGUID
###############################################################################
#END