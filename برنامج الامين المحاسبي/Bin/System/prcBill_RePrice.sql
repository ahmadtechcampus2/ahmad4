##################################################################################
CREATE PROCEDURE prcBills_rePrice 
	@SrcGUID		UNIQUEIDENTIFIER,  
	@FromDate		datetime,  
	@ToDate			datetime,  
	@Material		UNIQUEIDENTIFIER,
	@Group			UNIQUEIDENTIFIER,
	@Store			UNIQUEIDENTIFIER,  
	@Cost			UNIQUEIDENTIFIER,
	@SalesMan		INT,  
	@Vendor			INT,  
	@MultiplyFactor FLOAT = 100,  
	@PriceType		INT = 0x2, -- Cost Price 
	@DiscExtraType	BIT = 0, 
	@Flag			INT = 0,
	@LgGuid UNIQUEIDENTIFIER=0x0
AS  
	SET NOCOUNT ON 
	CREATE TABLE [#Src]( 
		[Type]		[UNIQUEIDENTIFIER], 
		[Sec]		[INT],  
		[ReadPrice]	[INT]) 
	INSERT INTO [#Src] EXEC [prcGetBillsTypesList] @SrcGUID 
	 
	DECLARE  
		@Parms NVARCHAR(2000) 
		
	EXEC  prcsetSrcStringLog @Parms OUTPUT 
	SET @Parms = @Parms 
		+ 'FromDate:' +  CAST(@FromDate AS NVARCHAR(100)) + CHAR(13) + 'ToDate:' + CAST(@ToDate AS NVARCHAR(100)) + CHAR(13) 
		+ 'Store:' + ISNULL((SELECT Code + '-' + [Name] FROM ST000 WHERE  [Guid] = @Store), '') 
		+ 'Cost:' + ISNULL((SELECT Code + '-' + [Name] FROM ST000 WHERE  [Guid] = @Cost), '') 
		+ 'Sales:' + CAST(@SalesMan AS NVARCHAR(10)) 
		+ 'Vendor' + CAST(@Vendor AS NVARCHAR(10)) 
		+ 'MultiplyFactor' + CAST(@MultiplyFactor AS NVARCHAR(10)) 
		+ 'PriceType' + CAST(@PriceType AS NVARCHAR(10)) 
		+ 'DiscExtraType' + CAST(@DiscExtraType AS NVARCHAR(10)) 
		+ 'Flag' + CAST(@Flag AS NVARCHAR(10)) 
	--EXEC prcCreateMaintenanceLog 15, @LgGuid OUTPUT, @Parms 
	 
	SELECT  
		a.[Type], 
		a.[Sec], 
		VATSystem, 
		CASE WHEN FldDiscValue = 1 AND  FldDiscRatio = 0 AND (@Flag & 0X0001) > 0 THEN 1 when FldDiscValue = 0 AND  FldDiscRatio = 1 AND (@Flag & 0X0001) > 0 THEN 2 ELSE 0 END shwDiscType, 
		CASE WHEN FldExtraValue = 1 AND  FldExtraRatio = 0 AND (@Flag & 0X0001) > 0 THEN 1 when FldExtraValue = 0 AND  FldExtraRatio = 1 AND (@Flag & 0X0001) > 0 THEN 2 ELSE 0 END shwExtraType,
		b.IncludeTTCDiffOnSales 
	INTO  
		[#Src2]  
	FROM  
		[#Src] a  
		INNER JOIN [bt000] b ON b.Guid = a.[Type] 

	SELECT * INTO #BITbl FROM bi000  
	SELECT * INTO #BuTbl FROM bu000
	----------------------------------------------------------
	-- For TTC Diff Included in Sales option for TTC bills
	-- Reprice total from 100.1 >> 110 >> 100
	UPDATE [#BuTbl] 
	SET [Total] = [bu1].[Total]
	FROM 
	[#BuTbl] AS [bu]  
	INNER JOIN (select [bu].[Guid], SUM([bi].[Qty] * (CASE ISNULL( [bi].[Qty],0) WHEN 0 THEN 0 ELSE ( ISNULL( ([bi].[Price] + [bi].[VAT] / [bi].[Qty]) / (1 + bi.VATRatio / 100), 0)/ (CASE [bi].[Unity] WHEN 2 THEN (CASE [mt].[Unit2Fact] WHEN 0 THEN 1 ELSE [mt].[Unit2Fact] END) WHEN 3 THEN (CASE [mt].[Unit3Fact] WHEN 0 THEN 1 ELSE [mt].[Unit3Fact] END) ELSE 1 END)) END)) AS [Total]
			FROM 
			[bi000] AS [bi] INNER JOIN [mt000] AS [mt] ON [bi].[MatGUID] = [mt].[GUID]		
			INNER JOIN [#BuTbl] AS [bu] ON [bi].[ParentGUID] = [bu].[GUID]	  
			INNER JOIN [#Src2] AS [SRC] ON [bu].[TypeGUID] = [SRC].[Type] AND [SRC].[IncludeTTCDiffOnSales] = 1  
		WHERE   
			[bi].[Qty] > 0  
			AND  
			(@SalesMan = 0 OR [bu].[SalesManPtr] = @SalesMan)  
			AND   
			(@Vendor = 0 OR [bu].[Vendor] = @Vendor) 
		GROUP BY  
			[bu].[Guid] ) AS [bu1] 
	ON [bu1].[GUID] = [bu].[GUID]

	----------------------------------------------------------
	IF (@DiscExtraType = 0) -- Save the ratio of the total discount and extra
	BEGIN
		SELECT bu.Guid BuGuid, di.guid DiGuid, (Discount * 100 / (bu.Total - ItemsDisc)) DiscountRatio, (Extra * 100 / (bu.Total + ItemsExtra)) ExtraRatio
		INTO [#SavedDiscountExtraRatio]
		FROM bu000 bu 
		INNER JOIN  [#Src] Src ON bu.TypeGuid = Src.Type
		INNER JOIN di000 di ON di.ParentGUID = bu.guid
	END
	----------------------------  
	CREATE TABLE [#Material] ([Number] [UNIQUEIDENTIFIER], [Security] [INT]);
	INSERT INTO  [#Material] EXEC [prcGetMatsList] @Material, @Group;
	----------------------------  
	CREATE TABLE [#Store] ([Number] [UNIQUEIDENTIFIER])  
	INSERT INTO  [#Store] SELECT [GUID] FROM [fnGetStoresList](@Store) 
	----------------------------  
	CREATE TABLE [#Cost] ([Number] [UNIQUEIDENTIFIER])  
	INSERT INTO   [#Cost] SELECT [GUID] FROM [fnGetCostsList] (@Cost)  
	IF @Cost = 0x0  
		INSERT INTO [#Cost] SELECT 0x0  
	---------------------------- 
	-- 0x2		[COST]		ÇáÊßáÝÉ 
	-- 0x4		[WHOLE] 	ÇáÌãáÉ  
	-- 0x8		[HALF]		äÕÝ ÇáÌãáÉ  
	-- 0x10		[EXPORT]	ÇáÊÕÏíÑ  
	-- 0x20		[VENDOR]	ÇáãæÒÚ  
	-- 0x40		[RETAIL]	ÇáãÝÑÞ  
	-- 0x80		[ENDUSER]	ÇáãÓÊåáß  
	-- 0x512	[LastPrice]	ÂÎÑ ÔÑÇÁ 
	-- 0x8000	[OutbalancedAveragePrice] ÇáæÓØí ÇáãÑÌÍ ÇáËÇÈÊ

	--IF( @PriceType = 0x2)  
	--	EXEC prcBill_rePost 0,0,@LgGuid
	EXEC prcDisableTriggers	'bi000' 
	CREATE TABLE #bimt(  
		[Guid]			[UNIQUEIDENTIFIER],  
		[Price]			[FLOAT],  
		[Discount]		[FLOAT],  
		[Extra]			[FLOAT],  
		[biPrice]		[FLOAT], 
		[Profits]		FLOAT, 
		[vat]			FLOAT,  
		VatSystem		INT, 
		UnitFact		FLOAT, 
		BonusOne		FLOAT, 
		Bonus			FLOAT, 
		Qty				FLOAT, 
		biVat			FLOAT, 
		shwDiscType		BIT, 
		shwExTraType	BIT,
		biCurrencyVal   FLOAT) 
		 
	INSERT INTO #bimt  
	SELECT   
		bi.Guid,  
		CASE [bi].[Unity]  
			WHEN 1 THEN  
				CASE @PriceType 
						WHEN 0x2    THEN ISNULL( [dbo].[fnCurrency_Fix]( [bi].[Price] - (ISNULL( [bi].[Profits], 0) / CASE [bi].[Qty] WHEN 0 THEN 0 ELSE  [bi].[Qty] END), [mt].[CurrencyGuid], [mt].[CurrencyVal], [bi].[CurrencyGuid], [bu].[Date]), 0)   
						WHEN 0x4    THEN ISNULL( [dbo].[fnCurrency_Fix]( [mt].[Whole], [mt].[CurrencyGuid], [mt].[CurrencyVal], [bi].[CurrencyGuid], [bu].[Date]), 0)  
						WHEN 0x8    THEN ISNULL( [dbo].[fnCurrency_Fix]( [mt].[Half], [mt].[CurrencyGuid], [mt].[CurrencyVal], [bi].[CurrencyGuid], [bu].[Date]), 0)  
						WHEN 0x10   THEN ISNULL( [dbo].[fnCurrency_Fix]( [mt].[Export], [mt].[CurrencyGuid], [mt].[CurrencyVal], [bi].[CurrencyGuid], [bu].[Date]), 0)  
						WHEN 0x20   THEN ISNULL( [dbo].[fnCurrency_Fix]( [mt].[Vendor], [mt].[CurrencyGuid], [mt].[CurrencyVal], [bi].[CurrencyGuid], [bu].[Date]), 0)  
						WHEN 0x40   THEN ISNULL( [dbo].[fnCurrency_Fix]( [mt].[Retail], [mt].[CurrencyGuid], [mt].[CurrencyVal], [bi].[CurrencyGuid], [bu].[Date]), 0)  
						WHEN 0x80   THEN ISNULL( [dbo].[fnCurrency_Fix]( [mt].[EndUser], [mt].[CurrencyGuid], [mt].[CurrencyVal], [bi].[CurrencyGuid], [bu].[Date]), 0)  
						WHEN 0x200  THEN ISNULL( [dbo].[fnCurrency_Fix]( [mt].[LastPrice], [mt].[CurrencyGuid], [mt].[CurrencyVal], [bi].[CurrencyGuid], [bu].[Date]), 0)
						WHEN 0x8000 THEN ISNULL([dbo].[fnCurrency_Fix]([dbo].[fnGetOutbalanceAveragePrice]([mt].[GUID], [bu].[Date]), [mt].[CurrencyGuid], [mt].[CurrencyVal], [bi].[CurrencyGuid], [bu].[Date]), 0)
				END 
			WHEN 2 THEN  
				CASE @PriceType  
						WHEN 0x2    THEN ISNULL( [dbo].[fnCurrency_Fix]([bi].[Price] - (ISNULL( [bi].[Profits], 0) / CASE [bi].[Qty] WHEN 0 THEN 0 ELSE  [bi].[Qty] END * (CASE [mt].[Unit2Fact] WHEN 0 THEN 1 ELSE [mt].[Unit2Fact] END)) , [mt].[CurrencyGuid], [mt].[CurrencyVal], [bi].[CurrencyGuid], [bu].[Date]), 0)  
						WHEN 0x4    THEN ISNULL( [dbo].[fnCurrency_Fix]( [mt].[Whole2], [mt].[CurrencyGuid], [mt].[CurrencyVal], [bi].[CurrencyGuid], [bu].[Date]), 0)  
						WHEN 0x8    THEN ISNULL( [dbo].[fnCurrency_Fix]( [mt].[Half2], [mt].[CurrencyGuid], [mt].[CurrencyVal], [bi].[CurrencyGuid], [bu].[Date]), 0)  
						WHEN 0x10   THEN ISNULL( [dbo].[fnCurrency_Fix]( [mt].[Export2], [mt].[CurrencyGuid], [mt].[CurrencyVal], [bi].[CurrencyGuid], [bu].[Date]), 0)  
						WHEN 0x20   THEN ISNULL( [dbo].[fnCurrency_Fix]( [mt].[Vendor2], [mt].[CurrencyGuid], [mt].[CurrencyVal], [bi].[CurrencyGuid], [bu].[Date]), 0)  
						WHEN 0x40   THEN ISNULL( [dbo].[fnCurrency_Fix]( [mt].[Retail2], [mt].[CurrencyGuid], [mt].[CurrencyVal], [bi].[CurrencyGuid], [bu].[Date]), 0)  
						WHEN 0x80   THEN ISNULL( [dbo].[fnCurrency_Fix]( [mt].[EndUser2], [mt].[CurrencyGuid], [mt].[CurrencyVal], [bi].[CurrencyGuid], [bu].[Date]), 0)  
						WHEN 0x200  THEN ISNULL( [dbo].[fnCurrency_Fix]( [mt].[LastPrice2], [mt].[CurrencyGuid], [mt].[CurrencyVal], [bi].[CurrencyGuid], [bu].[Date]), 0)  
						WHEN 0x8000 THEN ISNULL([dbo].[fnCurrency_Fix]([dbo].[fnGetOutbalanceAveragePrice]([mt].[GUID], [bu].[Date]), [mt].[CurrencyGuid], [mt].[CurrencyVal], [bi].[CurrencyGuid], [bu].[Date]), 0)
				END  
			WHEN 3 THEN  
				CASE @PriceType 
						WHEN 0x2    THEN  ISNULL( [dbo].[fnCurrency_Fix]([bi].[Price] - (ISNULL( [bi].[Profits], 0) / CASE [bi].[Qty] WHEN 0 THEN 0 ELSE  [bi].[Qty] END * (CASE [mt].[Unit3Fact] WHEN 0 THEN 1 ELSE [mt].[Unit3Fact] END))  , [mt].[CurrencyGuid], [mt].[CurrencyVal], [bi].[CurrencyGuid], [bu].[Date]), 0)  
						WHEN 0x4    THEN ISNULL( [dbo].[fnCurrency_Fix]( [mt].[Whole3], [mt].[CurrencyGuid], [mt].[CurrencyVal], [bi].[CurrencyGuid], [bu].[Date]), 0)  
						WHEN 0x8    THEN ISNULL( [dbo].[fnCurrency_Fix]( [mt].[Half3], [mt].[CurrencyGuid], [mt].[CurrencyVal], [bi].[CurrencyGuid], [bu].[Date]), 0)  
						WHEN 0x10   THEN ISNULL( [dbo].[fnCurrency_Fix]( [mt].[Export3], [mt].[CurrencyGuid], [mt].[CurrencyVal], [bi].[CurrencyGuid], [bu].[Date]), 0)  
						WHEN 0x20   THEN ISNULL( [dbo].[fnCurrency_Fix]( [mt].[Vendor3], [mt].[CurrencyGuid], [mt].[CurrencyVal], [bi].[CurrencyGuid], [bu].[Date]), 0)  
						WHEN 0x40   THEN ISNULL( [dbo].[fnCurrency_Fix]( [mt].[Retail3], [mt].[CurrencyGuid], [mt].[CurrencyVal], [bi].[CurrencyGuid], [bu].[Date]), 0)  
						WHEN 0x80   THEN ISNULL( [dbo].[fnCurrency_Fix]( [mt].[EndUser3], [mt].[CurrencyGuid], [mt].[CurrencyVal], [bi].[CurrencyGuid], [bu].[Date]), 0)  
						WHEN 0x200  THEN ISNULL( [dbo].[fnCurrency_Fix]( [mt].[LastPrice3], [mt].[CurrencyGuid], [mt].[CurrencyVal], [bi].[CurrencyGuid], [bu].[Date]), 0)  
						WHEN 0x8000 THEN ISNULL([dbo].[fnCurrency_Fix]([dbo].[fnGetOutbalanceAveragePrice]([mt].[GUID], [bu].[Date]), [mt].[CurrencyGuid], [mt].[CurrencyVal], [bi].[CurrencyGuid], [bu].[Date]), 0)
				END 
		END, 
		bi.Discount, 
		Extra,
		CASE SRC.IncludeTTCDiffOnSales WHEN 1 THEN ([bi].[Price] + [bi].[VAT] / [bi].[Qty]) / (1 + VATRatio / 100) ELSE [bi].[Price] END [Price],
		CASE @PriceType	 
			WHEN 0x2  THEN 0  
			ELSE [bi].[Profits]  
		END, 
		[mt].Vat, 
		CASE bu.CalcBillVat WHEN 0 THEN VatSystem ELSE 0 END,
		CASE [bi].[Unity]  
			WHEN 2 THEN (CASE [mt].[Unit2Fact] WHEN 0 THEN 1 ELSE [mt].[Unit2Fact] END)  
			WHEN 3 THEN (CASE [mt].[Unit3Fact] WHEN 0 THEN 1 ELSE [mt].[Unit3Fact] END)  
			ELSE 1  
		END, 
		BonusOne, 
		Bonus, 
		bi.Qty, 
		bi.Vat, 
		shwDiscType, 
		shwExtraType,
		bi.CurrencyVal				  
	FROM   
		[bi000] AS [bi]  
		INNER JOIN [mt000][mt] ON [mt].[Guid] = [bi].[MatGuid]  
		INNER JOIN [bu000] AS [bu] ON [bi].[ParentGUID] = [bu].[GUID]  
		INNER JOIN [#Src2] AS [SRC] ON [bu].[TypeGUID] = [SRC].[Type]  
		INNER JOIN [#Material] AS [Mat] ON [bi].[MatGUID] = [Mat].[Number]
		INNER JOIN [#Store] AS [stor] ON [bi].[StoreGuid] = [stor].[Number]  
		INNER JOIN [#Cost] AS [cost] ON [bu].[CostGuid] = [cost].[Number]  
	WHERE  
		[bi].[Qty] > 0  
		AND  
		(@SalesMan = 0 OR [bu].[SalesManPtr] = @SalesMan)  
		AND   
		(@Vendor = 0 OR [bu].[Vendor] = @Vendor)  
		AND bu.date BETWEEN @FromDate AND @ToDate 

	UPDATE #bimt SET vat = 0 , biVat = 0
		WHERE VatSystem = 0
	 
	SELECT  
		[Guid], 
		CASE  
			WHEN [Price] = 0 THEN CASE WHEN (@Flag & 0x00008) > 0 THEN  [biPrice] ELSE [Price] END  
			ELSE [Price]  
		END [Price], 
		[Discount],  
		[Extra],  
		[biPrice], 
		[Profits], 
		[vat],  
		VatSystem , 
		UnitFact, 
		BonusOne, 
		Bonus, 
		Qty, 
		CASE VatSystem WHEN 0 THEN 0 ELSE Vat END [VatRatio], 
		CASE WHEN (@Flag & 0X0002) > 0 OR [Discount] = 0 THEN 0 ELSE [Discount]  / (Qty * CASE  WHEN @DiscExtraType = 0 OR shwDiscType = 2 THEN 
																												CASE biPrice WHEN 0 THEN 1 ELSE biPrice END 
																								WHEN @DiscExtraType = 1 OR shwDiscType = 1 THEN
																												CASE [Price]  WHEN 0 THEN 1 ELSE [Price] * biCurrencyVal * (CASE VatSystem WHEN 2 THEN 100 / (100 + Vat) else 1 end)  END ELSE 1 END / UnitFact) END AS DiscRate, 
		CASE WHEN (@Flag & 0X0004) > 0 OR [Extra] = 0 THEN 0 ELSE [Extra]  / (Qty *  CASE  WHEN @DiscExtraType = 0 OR shwExtraType = 2 THEN
																												CASE biPrice WHEN 0 THEN 1 ELSE biPrice END 
																								WHEN @DiscExtraType = 1 OR shwExtraType = 1 THEN 
																												CASE [Price] WHEN 0 THEN 1 ELSE [Price] * biCurrencyVal * (CASE VatSystem WHEN 2 THEN (100 + Vat) / 100 ELSE 1 END) END ELSE 1 END  / UnitFact) END AS ExtraRate, 
		biVat 
	INTO  
		#bimt2 
	FROM  
		#bimt	 
	 
	
	UPDATE [#BITbl]  
	SET  
		[Price] = (@Multiplyfactor / 100) *   
				mt.Price * bu.CurrencyVal
				* CASE WHEN [mt].Price != 0 AND (@Flag & 0x00008) = 0 THEN (1 - CASE VatSystem WHEN 2 THEN [mt].Vat / (100 + [mt].Vat) ELSE 0 END)
																 ELSE 1 END
		,[VatRatio] = [mt].[VatRatio] 
		,[Discount] = [mt].DiscRate * (([mt].[Price] * bu.CurrencyVal * [mt].[Qty]/ UnitFact )) * CASE WHEN [mt].Price != 0 AND (@Flag & 0x00008) = 0 THEN
																						(CASE VatSystem WHEN 2 THEN 100 / (100 + [mt].Vat) else 1 end) 
																				ELSE 1 END
		,[Extra] = [mt].ExtraRate * (([mt].[Price] * bu.CurrencyVal * [mt].[Qty]/ UnitFact )) * CASE WHEN [mt].Price != 0 AND (@Flag & 0x00008) = 0 THEN
																						(CASE VatSystem WHEN 2 THEN 100 / (100 + [mt].Vat) else 1 end)		 
																				ELSE 1 END
		,[Profits] =  [mt].[Profits]			 
	FROM 
		[#BITbl] AS [bi]  
		INNER JOIN bu000 bu ON bu.Guid = bi.ParentGuid
		INNER JOIN #bimt2 AS [mt] ON [mt].[Guid] = [bi].[Guid] 

	
	EXEC prcDisableTriggers	'bu000' 
	 
	SELECT 
		SUM([bi].[Qty] * (CASE ISNULL( [bi].[Qty],0) WHEN 0 THEN 0 ELSE ( ISNULL( [bi].[Price], 0)/ (CASE [bi].[Unity] WHEN 2 THEN (CASE [mt].[Unit2Fact] WHEN 0 THEN 1 ELSE [mt].[Unit2Fact] END) WHEN 3 THEN (CASE [mt].[Unit3Fact] WHEN 0 THEN 1 ELSE [mt].[Unit3Fact] END) ELSE 1 END)) END)) AS [Total], 
		SUM([bi].[Extra]) AS [ItemExtra], 
		SUM([bi].[Discount]) AS [ItemDisc], 
		SUM([bi].[Vat]) AS [Vat], 
		SUM([bi].[BonusDisc]) AS [BonusDisc],  
		[bu].[Guid] AS [buGuid], 
		CAST(0 AS FLOAT) AS [Discount],
		CAST(0 AS FLOAT) AS [Extra]
	INTO #Bu	 
	FROM   
		[#Bitbl] AS [bi] INNER JOIN [mt000] AS [mt] ON [bi].[MatGUID] = [mt].[GUID]  
		INNER JOIN [#BuTbl] AS [bu] ON [bi].[ParentGUID] = [bu].[GUID]  
		INNER JOIN [#Src] AS [SRC] ON [bu].[TypeGUID] = [SRC].[Type]  
		INNER JOIN [#Material] AS [Mat] ON [bi].[MatGUID] = [Mat].[Number] 
		INNER JOIN [#Store] AS [stor] ON [bi].[StoreGuid] = [stor].[Number]  
		INNER JOIN [#Cost] AS [cost] ON [bu].[CostGuid] = [cost].[Number]  
	WHERE   
		[bi].[Qty] > 0  
		AND  
		(@SalesMan = 0 OR [bu].[SalesManPtr] = @SalesMan)  
		AND   
		(@Vendor = 0 OR [bu].[Vendor] = @Vendor) 
	GROUP BY  
		[bu].[Guid] 
	 
	--------------------
	IF (@DiscExtraType  = 0 )
	BEGIN
		UPDATE di000 SET Discount = SDE.DiscountRatio * (BU.Total - BU.ItemDisc) / 100,
				Extra = SDE.ExtraRatio * (BU.Total - BU.ItemExtra) / 100
		FROM  [#SavedDiscountExtraRatio] SDE INNER JOIN #Bu BU ON SDE.buGuid =  bu.[buGuid]
		WHERE di000.GUID = SDE.DiGuid
	END
	------------------------------------------------------------
	UPDATE #Bu SET #BU.Discount = S.Discount, #BU.Extra = S.Extra
	FROM (
		SELECT buGuid ,SUM(ISNULL(DI.Discount, 0)) Discount, SUM(ISNULL(DI.Extra, 0)) Extra
		FROM di000 DI INNER JOIN #Bu BU ON DI.ParentGUID = BU.buGuid
		GROUP BY buGuid) S	
	WHERE S.buGuid = #Bu.buGuid
	------------------------------------------------------------
	UPDATE #BITbl SET VAT = CASE [BT].taxBeforeDiscount	WHEN 1 THEN 
														CASE [BT].VATSystem	WHEN 2 THEN 
																	([BI].Price * [BI].Qty / UnitFact ) * [BI].VATRatio / 100
																				WHEN 1 THEN
																	[BI].Price * [BI].Qty / UnitFact * [BI].VATRatio / 100
																				ELSE 0 END     
														WHEN 0 THEN 
														CASE [BT].VATSystem	WHEN 2 THEN 
																	(([BI].Price * [BI].Qty / UnitFact ) - [BI].Discount - ([TBU].Discount * [BI].Price * [BI].Qty / UnitFact / CASE [TBU].Total WHEN 0 THEN 1 ELSE [TBU].Total END) 
																						+ CASE [BT].BillType WHEN 1 THEN 0 ELSE [BI].Extra + ([TBU].Extra * [BI].Price * [BI].Qty / UnitFact / CASE [TBU].Total WHEN 0 THEN 1 ELSE [TBU].Total END) END
																								) * [BI].VATRatio / 100
																				WHEN 1 THEN
																	(([BI].Price * [BI].Qty / UnitFact) - [BI].Discount - ([TBU].Discount * [BI].Price * [BI].Qty / UnitFact / CASE [TBU].Total WHEN 0 THEN 1 ELSE [TBU].Total END) 
																						+ CASE [BT].BillType WHEN 1 THEN 0 ELSE [BI].Extra + ([TBU].Discount * [BI].Price * [BI].Qty / UnitFact / CASE [TBU].Total WHEN 0 THEN 1 ELSE [TBU].Total END) END
																								) * [BI].VATRatio / 100
																				ELSE 0 END     
														END
														
	FROM [#BiTbl] AS [BI] INNER JOIN #bimt2 AS [mt] ON [mt].[Guid] = [bi].[Guid]  
	INNER JOIN [#BuTbl] [BU] ON [BU].GUID = [BI].ParentGUID 
	INNER JOIN #BU [TBU] ON [TBU].buGuid = [BU].GUID
	INNER JOIN  bt000 [BT] ON [BT].GUID = [BU].TypeGUID
	------------------------------------------------------------
	-- Reprice Bills where [IncludeTTCDiffOnSales] Taxes option checked and will convert from 100 >> 110 >> [100.1]
	UPDATE [#BITbl] SET Price = [BI].Price * (1 + [BI].VATRatio / 100) - [Bi].VAT / [bi].Qty 									
	FROM [#BITbl] AS [BI] INNER JOIN #bimt2 AS [mt] ON [mt].[Guid] = [bi].[Guid]  
	INNER JOIN bu000 [BU] ON [BU].GUID = [BI].ParentGUID 
	INNER JOIN #BU [TBU] ON [TBU].buGuid = [BU].GUID
	INNER JOIN #Src2 [SRC] ON [SRC].Type = [BU].TypeGUID AND [SRC].[IncludeTTCDiffOnSales] = 1
 ------------------------------------------------------------
	UPDATE #Bu SET #BU.Vat = S.Vat
	FROM (
		SELECT buGuid ,SUM(ISNULL(BI.VAT, 0)) Vat
		FROM #BITbl BI INNER JOIN #Bu BU ON BI.ParentGUID = BU.buGuid
		GROUP BY buGuid) S
	WHERE S.buGuid = #Bu.buGuid
	------------------------------------------------------------------------------------------------
	UPDATE [#BuTbl]  
	SET  
		[Total] = [b].[Total], 
		[VAT] = [b].[VAT], 
		[BonusDisc] = [b].[BonusDisc], 
		[ItemsDisc] = [b].[ItemDisc], 
		[ItemsExtra] = [b].[ItemExtra], 
		[TotalExtra] = [b].[ItemExtra] + [b].[Extra], 
		[TotalDisc] = [b].[ItemDisc] +[b].[Discount] 
	FROM  
		[#BuTbl] AS [bu]  
		INNER JOIN  [#Bu] AS [b] ON [bu].[Guid] = [b].[buGuid] 
		INNER JOIN [Bt000] AS [bt] ON [bt].[Guid] = [bu].[TypeGuid] 
		 
	------------------------------------------------------------------------------------------------
	---- Updating Totals in Bills that contains "include TTC Diff ON Sales" Option in their Type properties
	---- AS From 1000 >> 1001 as bi000 changed ubove.
	UPDATE [#BuTbl] 
	set [Total] = [bu1].[Total]
	 	FROM 
		[#BuTbl] AS [bu]  
		INNER JOIN (select [bu].[Guid], SUM([bi].[Qty] * (CASE ISNULL( [bi].[Qty],0) WHEN 0 THEN 0 ELSE ( ISNULL( [bi].[Price], 0)/ (CASE [bi].[Unity] WHEN 2 THEN (CASE [mt].[Unit2Fact] WHEN 0 THEN 1 ELSE [mt].[Unit2Fact] END) WHEN 3 THEN (CASE [mt].[Unit3Fact] WHEN 0 THEN 1 ELSE [mt].[Unit3Fact] END) ELSE 1 END)) END)) AS [Total]
		from 
		[#BITbl] AS [bi] INNER JOIN [mt000] AS [mt] ON [bi].[MatGUID] = [mt].[GUID]		
		inner join [bu000] AS [bu] ON [bi].[ParentGUID] = [bu].[GUID]	  
		INNER JOIN [#Src2] AS [SRC] ON [bu].[TypeGUID] = [SRC].[Type] AND [SRC].IncludeTTCDiffOnSales = 1 
		INNER JOIN [#Material] AS [Mat] ON [bi].[MatGUID] = [Mat].[Number] 
		INNER JOIN [#Store] AS [stor] ON [bi].[StoreGuid] = [stor].[Number]  
		INNER JOIN [#Cost] AS [cost] ON [bu].[CostGuid] = [cost].[Number]  
	WHERE   
		[bi].[Qty] > 0  
		AND  
		(@SalesMan = 0 OR [bu].[SalesManPtr] = @SalesMan)  
		AND   
		(@Vendor = 0 OR [bu].[Vendor] = @Vendor) 
	GROUP BY  
		[bu].[Guid] ) as [bu1] ON [bu1].[GUID] = [bu].[GUID]
------------------------------------------------------------------------------------------------
	INSERT INTO #temp 
	select bu.Guid
		from #BuTbl bu
	where  ( bu.FirstPay <> 0 AND ((bu.Total + bu.TotalExtra + bu.Vat) - (bu.TotalDisc  + bu.BonusDisc))  < bu.FirstPay )
		OR ((bu.Total + bu.TotalExtra + bu.Vat) - (bu.TotalDisc  + bu.BonusDisc))  < (SELECT Sum(val) from ch000 where parentguid=bu.GUID)
	if exists (select * from #temp)
	BEGIN
		delete from #BuTbl 
		where guid IN (select guid from #temp)
 
		delete from #BITbl
		where ParentGUID IN (select GUID from #temp)
	END

	CREATE TABLE #NegativeBills
	(
		Guid UNIQUEIDENTIFIER
	)

	INSERT INTO #NegativeBills
	SELECT GUID       
	FROM #BuTbl b
	WHERE (b.Total - b.TotalDisc - b.BonusDisc - b.ItemsDisc + b.TotalExtra + b.ItemsExtra) < 0
	
	SELECT * FROM #NegativeBills

	DELETE bi FROM #BITbl bi
	INNER JOIN  #NegativeBills Nbill ON bi.ParentGUID=Nbill.GUID

	DELETE bu FROM #BuTbl bu
	INNER JOIN  #NegativeBills Nbill ON bu.GUID=Nbill.GUID
     

	update bux
		SET [bux].[Total] = [b].[Total], 
		[bux].[VAT] = [b].[VAT], 
		[bux].[BonusDisc] = [b].[BonusDisc], 
		[bux].[ItemsDisc] = [b].[ItemsDisc], 
		[bux].[ItemsExtra] = [b].[ItemsExtra], 
		[bux].[TotalExtra] = [b].[TotalExtra] , 
		[bux].[TotalDisc] = [b].[TotalDisc] 
	FROM bu000  bux INNER JOIN #BuTbl b on b.GUID= bux.GUID 
	

	update bix
		SET bix.[Price] =  bi.[Price],
		bix.[VatRatio] = bi.[VatRatio],
		bix.[Discount] = bi.[Discount],
		bix.[Extra] = bi.[Extra],
		bix.[Profits] = bi.[Profits]
		FROM bi000 bix INNER JOIN #BITbl bi ON bi.GUID = bix.GUID



	INSERT INTO  
		MaintenanceLogItem000( GUID, ParentGUID, Severity, LogTime, ErrorSourceGUID1, ErrorSourceType1, Notes) 
	SELECT  
		NEWID(), @LgGuid, 0x0001, GETDATE(), [buGuid], 268500992, bt.Name + ':' + CAST(bu.Number AS NVARCHAR(10))  
	FROM  
		(SELECT DISTINCT [buGuid] FROM #bu) b  
		INNER JOIN bu000 bu ON b.buGuid = bu.Guid 
		INNER JOIN bt000 bt on bu.TypeGuid = bt.Guid
		
		
		
				 
	 
	EXEC prcEnableTriggers 'bu000' 
	EXEC prcEnableTriggers 'bi000' 
	EXEC prcCloseMaintenanceLog @LgGuid
/*
prcConnections_add2 'ãÏíÑ'
 [prcBill_Reprice] 'ce10aef8-0332-49f9-a6bb-1e2df4a78d6a', '3/15/2008', '3/16/2008', '00000000-0000-0000-0000-000000000000', '00000000-0000-0000-0000-000000000000', 0, 0, 100.000000, 128
*/
##################################################################################
CREATE PROCEDURE prcBill_rePrice 
	@SrcGUID		UNIQUEIDENTIFIER,  
	@FromDate		datetime,  
	@ToDate			datetime,  
	@Material		UNIQUEIDENTIFIER,
	@Group			UNIQUEIDENTIFIER,
	@Store			UNIQUEIDENTIFIER,  
	@Cost			UNIQUEIDENTIFIER,
	@SalesMan		INT,  
	@Vendor			INT,  
	@MultiplyFactor FLOAT = 100,  
	@PriceType		INT = 0x2, -- Cost Price 
	@DiscExtraType	BIT = 0, 
	@Flag			INT = 0,
	@DeletePaysLinks BIT = 0,
	@HasSecDeletePaysLink BIT = 1,
	@LgGuid UNIQUEIDENTIFIER=0x0
AS  
	SET NOCOUNT ON 

	DECLARE @Return INT 
	
	CREATE TABLE #ExcludeWarnings(IsExclude BIT)
	INSERT INTO #ExcludeWarnings SELECT 1

	CREATE TABLE #temp(guid UNIQUEIDENTIFIER)

	BEGIN TRAN
	EXEC @Return = prcBills_rePrice @SrcGUID, @FromDate, @ToDate, @Material, @Group, @Store, @Cost, @SalesMan, @Vendor, @MultiplyFactor, @PriceType, @DiscExtraType, @Flag,@LgGuid
	IF @Return != 0
		GOTO exitMe	

	CREATE TABLE #Bills	(
		BuGuid UNIQUEIDENTIFIER,
		[btName] [NVARCHAR](256)COLLATE ARABIC_CI_AI,
		BtGuid UNIQUEIDENTIFIER,
		buNumber INT,
		ceGuid UNIQUEIDENTIFIER,
		bAutoEntry BIT,
		ceNumber INT,
		BillCount INT,
		buDate DATETIME)

	EXEC prcDisableTriggers 'ce000'
	ALTER TABLE [ce000] ENABLE TRIGGER [trg_ce000_delete] -- necessary for er000 handling
	EXEC prcDisableTriggers 'en000'
	EXEC prcDisableTriggers 'bu000'
	EXEC prcDisableTriggers 'bi000'
	ALTER TABLE [en000] ENABLE TRIGGER [trg_en000_delete]

	INSERT INTO #Bills EXEC prcGenEntriesPrepare @SrcGUID, @FromDate, @ToDate, 0
	DECLARE 
		@b_cursor CURSOR,
		@BuGuid UNIQUEIDENTIFIER,
		@BtGuid UNIQUEIDENTIFIER,
		@ceGuid UNIQUEIDENTIFIER,
		@bAutoEntry BIT,
		@bAutoPost BIT,
		@ceNumber INT
	
	CREATE TABLE #bp_befor(BillGUID UNIQUEIDENTIFIER, PayGUID UNIQUEIDENTIFIER, Amount FLOAT, [Type] INT)
	CREATE TABLE #bp_after(BillGUID UNIQUEIDENTIFIER, PayGUID UNIQUEIDENTIFIER, Amount FLOAT, [Type] INT)
	CREATE TABLE #bp_changed(BillGUID UNIQUEIDENTIFIER, PayGUID UNIQUEIDENTIFIER, BeforAmount FLOAT, AfterAmount FLOAT, IsDeleted BIT, IsFirstPay BIT)

	SET @b_cursor = CURSOR FAST_FORWARD FOR SELECT BuGuid, BtGuid, ceGuid, bt.bAutoEntry, bt.bAutoEntry, ceNumber FROM #Bills b INNER JOIN bt000 bt ON b.BtGuid = bt.GUID 
	OPEN @b_cursor FETCH NEXT FROM @b_cursor INTO @BuGuid, @BtGuid, @ceGuid, @bAutoEntry, @bAutoPost, @ceNumber
	WHILE @@FETCH_STATUS = 0
	BEGIN 
		IF ((ISNULL(@ceGuid, 0x0) != 0x0) OR (@bAutoEntry = 1))
		BEGIN 
			DELETE #bp_befor
			DELETE #bp_after

			INSERT INTO #bp_befor SELECT @BuGuid, CASE [Type] WHEN 1 THEN @BuGuid ELSE (CASE WHEN DebtGUID = @BuGuid THEN PayGUID ELSE DebtGUID END) END, CASE WHEN DebtGUID = @BuGuid THEN Val ELSE PayVal END, [Type] FROM bp000 WHERE ((DebtGUID = @BuGuid) OR (PayGUID = @BuGuid)) -- AND [Type] = 0
			EXEC @Return = prcBill_GenEntry @BuGuid, @ceNumber, 0, 1, 0, @DeletePaysLinks, @HasSecDeletePaysLink
			IF @Return != 0
				GOTO exitMe	
			INSERT INTO #bp_after SELECT @BuGuid, CASE [Type] WHEN 1 THEN @BuGuid ELSE (CASE WHEN DebtGUID = @BuGuid THEN PayGUID ELSE DebtGUID END) END, CASE WHEN DebtGUID = @BuGuid THEN Val ELSE PayVal END, [Type] FROM bp000 WHERE ((DebtGUID = @BuGuid) OR (PayGUID = @BuGuid)) -- AND [Type] = 0			
			

		
		 
				INSERT INTO #bp_changed 
				SELECT 
					b.BillGUID,
					b.PayGUID,
					b.Amount,
					ISNULL(a.Amount, 0),
					CASE ISNULL(a.PayGUID, 0x0) WHEN 0x0 THEN 1 ELSE 0 END,
					CASE b.PayGUID WHEN b.BillGUID THEN 1 ELSE 0 END
				FROM 
					#bp_befor b 
					LEFT JOIN #bp_after a ON a.PayGUID = b.PayGUID 
				WHERE 
					(b.Amount != ISNULL(a.Amount, 0))
		

			IF @bAutoPost = 1
			BEGIN 
				EXEC prcBill_Post1 @BuGuid, 1
			END 
		END 
		FETCH NEXT FROM @b_cursor INTO @BuGuid, @BtGuid, @ceGuid, @bAutoEntry, @bAutoPost, @ceNumber
	END CLOSE @b_cursor DEALLOCATE @b_cursor

	EXEC prcGenEntriesFinalize

	COMMIT TRAN

		SELECT 
			bu.GUID AS BillGUID,
			bu.Number AS BillNumber,
			bt.Abbrev AS BillName,
			bt.LatinAbbrev AS BillLatinName,
			bp.BeforAmount,
			bp.AfterAmount,
			bp.IsDeleted,
			(CASE ISNULL(py.GUID, 0x0) WHEN 0x0 THEN (CASE ISNULL(ch.GUID, 0x0) WHEN 0x0 THEN (CASE ISNULL(buPay.GUID, 0x0) WHEN 0x0 THEN ce.GUID ELSE buPay.GUID END) ELSE ch.GUID END) ELSE py.GUID END) AS PayGUID,
			(CASE ISNULL(py.GUID, 0x0) WHEN 0x0 THEN (CASE ISNULL(ch.GUID, 0x0) WHEN 0x0 THEN (CASE ISNULL(buPay.GUID, 0x0) WHEN 0x0 THEN '' ELSE btPay.Name END) ELSE nt.Name END) ELSE et.Name END) AS PayName,
			(CASE ISNULL(py.GUID, 0x0) WHEN 0x0 THEN (CASE ISNULL(ch.GUID, 0x0) WHEN 0x0 THEN (CASE ISNULL(buPay.GUID, 0x0) WHEN 0x0 THEN '' ELSE btPay.LatinName END) ELSE nt.LatinName END) ELSE et.LatinName END) AS PayLatinName,
			(CASE ISNULL(py.GUID, 0x0) WHEN 0x0 THEN (CASE ISNULL(ch.GUID, 0x0) WHEN 0x0 THEN (CASE ISNULL(buPay.GUID, 0x0) WHEN 0x0 THEN ce.Number ELSE buPay.Number END) ELSE ch.Number END) ELSE py.Number END) AS PayNumber,
			CASE bp.IsFirstPay WHEN 1 THEN 4 ELSE (CASE ISNULL(py.GUID, 0x0) WHEN 0x0 THEN (CASE ISNULL(ch.GUID, 0x0) WHEN 0x0 THEN (CASE ISNULL(buPay.GUID, 0x0) WHEN 0x0 THEN 0 ELSE 3 END) ELSE 2 END) ELSE 1 END) END AS PayType  
		FROM 
			#bp_changed bp
			INNER JOIN bu000 bu ON bu.GUID = bp.BillGUID 
			INNER JOIN bt000 bt ON bt.GUID = bu.TypeGUID 
			LEFT JOIN bu000 buPay ON buPay.GUID = bp.PayGUID 
			LEFT JOIN bt000 btPay ON btPay.GUID = buPay.TypeGUID
			LEFT JOIN en000 en ON en.GUID = bp.PayGUID 
			LEFT JOIN ce000 ce ON ce.GUID = en.ParentGUID 
			LEFT JOIN er000 er ON er.EntryGUID = ce.GUID 
			LEFT JOIN py000 py ON er.ParentGUID = py.GUID 
			LEFT JOIN et000 et ON py.TypeGUID = et.GUID			
			LEFT JOIN ch000 ch ON er.ParentGUID = ch.GUID 
			LEFT JOIN nt000 nt ON ch.TypeGUID = nt.GUID
		ORDER BY 
			bu.Date,
			bu.Number,
			bu.GUID,
			ISNULL(ce.Date, buPay.Date),
			ISNULL(ce.Number, buPay.Number)			

	
	SELECT 
			bu.GUID AS BillGUID,
			bu.Number AS BillNumber,
			bt.Abbrev AS BillName,
			bt.LatinAbbrev AS BillLatinName,
			bu.FirstPay,
		   (SELECT SUM(val) from ch000 where ParentGUID=bu.GUID) as sumcheques
		FROM 
			 #temp bp
			INNER JOIN bu000 bu ON bu.GUID = bp.guid 
			INNER JOIN bt000 bt ON bt.GUID = bu.TypeGUID 
		ORDER BY 
			bu.Date,
			bu.Number,
			bu.GUID	
			
		exitMe:
		IF @@TRANCOUNT != 0
			ROLLBACK TRAN	
##################################################################################
CREATE PROCEDURE prcGetprohibitedCust	
	@CustGuid	UNIQUEIDENTIFIER
AS

	SELECT CustGuid,bt.Name,bu.Number,bu.[Date], bu.Total + bu.TotalExtra - bu.TotalDisc  + CASE bt.VatSystem WHEN 2 THEN 0 ELSE bu.Vat END - ISNULL(bp.Val,0) Diff FROM bu000 bu 
	INNER JOIN bt000 bt ON bt.GUID = bu.TypeGUID 
	INNER JOIN pt000 pt ON pt.RefGUID = bu.[Guid]

	LEFT JOIN er000 er ON er.ParentGUID = bu.[GUID] 
	INNER JOIN ce000 ce ON ce.[Guid] = entryGuid
	INNER JOIN en000 en ON en.parentguid = ce.GUID
	LEFT JOIN (SELECT SUM(Val) Val,DebtGUID from bp000 GROUP BY DebtGUID) bp ON bp.DebtGUID = en.GUID

	WHERE 
	bt.bIsOutput > 0 AND bu.PayType = 1 AND bu.IsPosted > 0
	AND bu.Total + bu.TotalExtra - bu.TotalDisc  + CASE bt.VatSystem WHEN 2 THEN 0 ELSE bu.Vat END - ISNULL(bp.Val,0) > 0.9
	AND bu.CustGUID = @CustGuid 
	AND dbo.fnGetDateFromTime(pt.DueDate) < dbo.fnGetDateFromTime(GETDATE()) 
	ORDER BY bu.[Date],bu.Number 

##################################################################################
#END
