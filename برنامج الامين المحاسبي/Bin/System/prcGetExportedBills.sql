################################################################
CREATE PROCEDURE prcGetExportedBills
	@StartDate				[DATETIME] = NULL,
	@EndDate				[DATETIME] = NULL,
	@SrcGuid				[UNIQUEIDENTIFIER] = NULL,
	@CashAcc				[INT] = 0,
	@StGuid					[UNIQUEIDENTIFIER] = 0X0
AS
	SET NOCOUNT ON
	CREATE TABLE [#res]
	(
		[buType] 		[UNIQUEIDENTIFIER],
		[Branch]		[UNIQUEIDENTIFIER],
		[Guid]			[UNIQUEIDENTIFIER],
		[buCustAccGuid] 	[UNIQUEIDENTIFIER],
		[buStorePtr]		[UNIQUEIDENTIFIER]
	)
	CREATE TABLE [#Bi2]	
	(
		[NUM] INT IDENTITY(1,1),
		[TypeGuid] [UNIQUEIDENTIFIER],
		[guid] [UNIQUEIDENTIFIER],
		[Number] [FLOAT],
		[MatGuid] [UNIQUEIDENTIFIER],
		[StoreGuid] [UNIQUEIDENTIFIER],
		[Qty] [FLOAT],
		[price] [FLOAT],
		[BonusQnt] [FLOAT],
		[Discount] [FLOAT],
		[Extra] [FLOAT],
		[unity] [INT],
		[Notes] [NVARCHAR](256) COLLATE ARABIC_CI_AI, 
		[CurrencyGUID] [UNIQUEIDENTIFIER],
		[CurrencyVal] [FLOAT],
		[Profits] [FLOAT],
		[BonusDisc] [FLOAT],
		[Qty2] [FLOAT],
		[Qty3] [FLOAT],
		[CostGUID] [UNIQUEIDENTIFIER],
		[ClassPtr]  [NVARCHAR](256) COLLATE ARABIC_CI_AI, 
		ClassPrice FLOAT,
		[ExpireDate] [DATETIME],
		[ProductionDate] [DATETIME],
		[Length] [FLOAT],
		[Width]		[FLOAT],
		[Height]	[FLOAT],
		[Count]		FLOAT,
		[biGuid]	[UNIQUEIDENTIFIER],
		[Guid2]		[UNIQUEIDENTIFIER],
		[Vat]		[FLOAT],
		[VATRatio]	[FLOAT],
		[mtName]	[NVARCHAR](256) COLLATE ARABIC_CI_AI,
		[buBranch]	[UNIQUEIDENTIFIER],
		[soGuid]	[UNIQUEIDENTIFIER],
		[soType]	[INT]
	)
	DECLARE @CurPtr [UNIQUEIDENTIFIER]
	DECLARE @Date [DATETIME]
	
	CREATE TABLE [#BranchTbl]( [GUID] [UNIQUEIDENTIFIER])
	CREATE TABLE [#StoreTbl]( [StoreGUID] [UNIQUEIDENTIFIER], [Security] [INT]) 
	
	INSERT INTO [#StoreTbl]	EXEC [prcGetStoresList] 		@StGuid 
	
	IF (@CashAcc = 1)
	BEGIN
		SELECT @CurPtr = [GUID] FROM [MY000] WHERE [CurrencyVal] = 1
		SET @Date = CAST(CAST(Month(GETDATE()) AS [NVARCHAR](2))+'/' + CAST(Day(GETDATE()) AS [NVARCHAR](2))+'/'+ CAST(Year(GETDATE()) AS [NVARCHAR](4)) AS [DATETIME])
	END
	-- select * from RepSrcs select * from bt000
	INSERT INTO [#res]
		 SELECT  [buType], [buBranch], NEWID(),[buCustAcc],[buStorePtr]
		FROM ( SELECT DISTINCT [buType], [buBranch],[buCustAcc],[buStorePtr] FROM [vwbu] AS [bu] INNER JOIN [RepSrcs] AS [r] ON [bu].[buType] = [r].[IdType] WHERE ([r].[IdTbl] = @SrcGuid) ) AS [RE]
	CREATE CLUSTERED INDEX IND ON [#res]([buType],[Branch],[buCustAccGuid])
	IF @CashAcc = 0
		SELECT
			[buType] 			AS [TypeGuid],
			[buGuid]			AS [guid],
			[buNumber] 			AS [Number],
			[buPayType] 		AS [PayType],
			[buCust_Name] 		AS [Cust_Name],
			[buCustPtr] 		AS [CustGuid],
			[buCustAcc] 		AS [CustAccGUID],
			[buDate] 			AS [date],
			[buBranch] 			AS [Branch],
			[buCheckTypeGUID]	AS [CheckTypeGUID],
			[buCurrencyPtr] 	AS [CurrencyGUID],
			[buCurrencyVal] 	AS [CurrencyVal],
			[buStorePtr]		AS [StoreGUID],
			[buNotes] 			AS [Notes],
			[buMatAcc]			AS [MatAccGUID],
			[buVendor] 			AS [Vendor],
			[buSalesManPtr] 	AS [SalesManPtr],
			[buCostPtr] 		AS [CostGUID],
			[buTotal] 			AS [Total],
			[buTotalExtra]		AS [TotalExtra],
			[buTotalDisc] 		AS [TotalDisc],
			[buFirstPay] 		AS [FirstPay],
			[buFPayAcc]			AS [FPayAccGUID],
			[buSecurity] 		AS [Security],
			[buVat]				AS [vat],
			[buTextFld1]		AS [TextFld1],
			[buTextFld2]		AS [TextFld2],
			[buTextFld3]		AS [TextFld3],
			[buTextFld4]		AS [TextFld4],
			[buItemsDiscAcc]	AS [ItemsDiscAccGUID],
			[buItemsExtraAccGUID]	AS [ItemsExtraAccGUID],
			[buCostAccGUID]			AS [CostAccGUID],
			[buStockAccGUID]		AS [StockAccGUID],
			[buBonusAccGUID]		AS [BonusAccGUID],
			[buBonusContraAccGUID]	AS [BonusContraAccGUID],
			[buVATAccGUID]			AS [VATAccGUID],
			ISNULL(SCPGuid,0X00)	AS SCPGuid,
			ISNULL(ts.Guid, 0X00)	AS BillTransferGuid,
			ISNULL(bu.CustomerAddressGuid, 0x0) AS CustomerAddressGuid
			
		FROM
			[vwbu] AS [bu] INNER JOIN [RepSrcs] AS [r] ON [bu].[buType] = [r].[IdType] 
			INNER JOIN [#StoreTbl] AS [ST] ON [ST].[StoreGuid] = [bu].[buStorePtr]
			LEFT JOIN (SELECT BillGUID,A.GUID SCPGuid FROM SCPurchases000 A INNER JOIN BillRel000 B ON A.GUID = B.ParentGUID) V ON V.BillGUID = [bu].[buGuid]
			LEFT JOIN Ts000 AS ts ON (ts.OutBillGuid = bu.[buGuid] OR ts.InBillGuid = bu.[buGuid])
		
		WHERE 
			(([buNumber] BETWEEN [r].[StartNum] AND [r].[EndNum]) OR ([buDate] BETWEEN @StartDate AND @EndDate))
			AND (([r].[IdTbl] = @SrcGuid) OR ( ISNULL([r].[IdTbl],0X0) = 0X0))
		ORDER BY [bu].[budate],[bu].[buSortFlag],[bu].[buType], [bu].[buNumber]
	ELSE
		SELECT
			[bu].[buType] 			AS [TypeGuid],
			CASE [buPayType] When 0 THEN [re].[GUID] ELSE [buGuid] END	AS [guid],
			CASE [buPayType] When 0 THEN 0 ELSE [buNumber] END	AS [Number],
			[buPayType] 		AS [PayType],
			CASE [buPayType] When 0 THEN '' ELSE [buCust_Name] END	AS [Cust_Name],
			CASE [buPayType] When 0 THEN 0x00  ELSE [buCustPtr] END	AS [CustGuid],
			[buCustAcc]	AS [CustAccGUID],
			CASE [buPayType] When 0 THEN @Date ELSE [buDate] END		AS [date],
			[buBranch] 		AS [Branch],
			[buCheckTypeGUID] AS [CheckTypeGUID],
			CASE [buPayType] When 0 THEN @CurPtr ELSE [buCurrencyPtr] END	AS [CurrencyGUID],
			CASE [buPayType] When 0 THEN 1 ELSE [buCurrencyVal] END	AS [CurrencyVal],
			[bu].[buStorePtr] AS [StoreGUID],
			CASE [buPayType] When 0 THEN '' ELSE [buNotes] 	END	AS [Notes],
			CASE [buPayType] When 0 THEN 0x00  ELSE [buMatAcc] END AS [MatAccGUID],
			CASE [buPayType] When 0 THEN 0 ELSE [buVendor] END		AS [Vendor],
			CASE [buPayType] When 0 THEN 0 ELSE [buSalesManPtr] END 	AS [SalesManPtr],
			CASE [buPayType] When 0 THEN 0x00  ELSE [buCostPtr] END		AS [CostGUID],
			SUM([buTotal]) 		AS [Total],
			SUM([buTotalExtra])	AS [TotalExtra],
			SUM([buTotalDisc]) 	AS [TotalDisc],
			CASE [buPayType] When 0 THEN 0 ELSE [buFirstPay] END		AS [FirstPay],
			CASE [buPayType] When 0  THEN 0x00 ELSE [buFPayAcc] END		AS [FPayAccGUID],
			CASE [buPayType] When 0 THEN 1 ELSE [buSecurity] END		AS [Security],
			SUM([buVat])			AS [vat],
			CASE [buPayType] When 0 THEN '' ELSE [buTextFld1] END AS [TextFld1],
			CASE [buPayType] When 0 THEN '' ELSE [buTextFld2] END AS [TextFld2],
			CASE [buPayType] When 0 THEN '' ELSE [buTextFld3] END AS [TextFld3],
			CASE [buPayType] When 0 THEN '' ELSE [buTextFld4] END AS [TextFld4],
			CASE [buPayType] When 0 THEN 0X00 ELSE [buItemsDiscAcc] END AS [ItemsDiscAccGUID],
			CASE [buPayType] When 0 THEN 0X00 ELSE [buItemsExtraAccGUID] END AS [ItemsExtraAccGUID],
			CASE [buPayType] When 0 THEN 0X00 ELSE [buCostAccGUID] END AS [CostAccGUID],
			CASE [buPayType] When 0 THEN 0X00 ELSE [buStockAccGUID] END AS [StockAccGUID],
			CASE [buPayType] When 0 THEN 0X00 ELSE [buBonusAccGUID] END AS [BonusAccGUID],
			CASE [buPayType] When 0 THEN 0X00 ELSE [buBonusContraAccGUID] END AS [BonusContraAccGUID],
			CASE [buPayType] When 0 THEN 0X00 ELSE [buVATAccGUID] END AS [VATAccGUID],
			CASE [buPayType] When 0 THEN 0X00 ELSE ISNULL(SCPGuid,0X00) END	AS SCPGuid,
			ISNULL(ts.Guid, 0x00)	AS BillTransferGuid,
			ISNULL(bu.CustomerAddressGuid, 0x0) AS CustomerAddressGuid
		FROM
			[vwbu] AS [bu] INNER JOIN [RepSrcs] AS [r] ON [bu].[buType] = [r].[IdType] 
			INNER JOIN [#RES] AS [re] ON [bu].[buType] = [re].[buType] AND [bu].[buBranch] = [re].[Branch] AND [bu].[buCustAcc] = [re].[buCustAccGuid] AND [re].[buStorePtr] = [bu].[buStorePtr]
			INNER JOIN [#StoreTbl] AS [ST] ON [ST].[StoreGUID] = [bu].[buStorePtr]
			LEFT JOIN (SELECT BillGUID,A.GUID SCPGuid FROM SCPurchases000 A INNER JOIN BillRel000 B ON A.GUID = B.ParentGUID) V ON V.BillGUID = [bu].[buGuid]
			LEFT JOIN Ts000 AS ts ON (ts.OutBillGuid = bu.[buGuid] OR ts.InBillGuid = bu.[buGuid])
		WHERE 
			(([buNumber] BETWEEN [r].[StartNum] AND [r].[EndNum]) OR ([buDate] BETWEEN @StartDate AND @EndDate))
			AND (([r].[IdTbl] = @SrcGuid) OR ( ISNULL([r].[IdTbl],0X0) = 0X0))
		GROUP BY
			[bu].[buType],
			CASE [buPayType] When 0 THEN [re].[GUID] ELSE [buGuid] END	,
			CASE [buPayType] When 0 THEN 0 ELSE [buNumber] END,
			[buPayType],
			CASE [buPayType] When 0 THEN '' ELSE [buCust_Name] END,
			CASE [buPayType] When 0 THEN 0x00  ELSE [buCustPtr] END,
			[buCustAcc],
			CASE [buPayType] When 0 THEN @Date ELSE [buDate] 	END	,
			[buBranch],
			[buCheckTypeGUID],
			CASE [buPayType] When 0 THEN @CurPtr ELSE [buCurrencyPtr] END,
			CASE [buPayType] When 0 THEN 1 ELSE [buCurrencyVal] END	,
			[bu].[buStorePtr],
			CASE [buPayType] When 0 THEN '' ELSE [buNotes] 	END,
			CASE [buPayType] When 0 THEN 0x00  ELSE [buMatAcc] END,
			CASE [buPayType] When 0 THEN 0 ELSE [buVendor] END,
			CASE [buPayType] When 0 THEN 0 ELSE [buSalesManPtr] END,
			CASE [buPayType] When 0 THEN 0x00  ELSE [buCostPtr] END,
			CASE [buPayType] When 0 THEN 0 ELSE [buFirstPay] END,
			CASE [buPayType] When 0 THEN 0x00  ELSE [buFPayAcc] END,
			CASE [buPayType] When 0 THEN 1 ELSE [buSecurity] END,
			CASE [buPayType] When 0 THEN '' ELSE [buTextFld1] END ,
			CASE [buPayType] When 0 THEN '' ELSE [buTextFld2] END,
			CASE [buPayType] When 0 THEN '' ELSE [buTextFld3] END,
			CASE [buPayType] When 0 THEN '' ELSE [buTextFld4] END,
			CASE [buPayType] When 0 THEN 0X00 ELSE [buItemsDiscAcc] END,
			CASE [buPayType] When 0 THEN 0X00 ELSE [buItemsExtraAccGUID] END,
			CASE [buPayType] When 0 THEN 0X00 ELSE [buCostAccGUID] END,
			CASE [buPayType] When 0 THEN 0X00 ELSE [buStockAccGUID] END,
			CASE [buPayType] When 0 THEN 0X00 ELSE [buBonusAccGUID] END,
			CASE [buPayType] When 0 THEN 0X00 ELSE [buBonusContraAccGUID] END,
			CASE [buPayType] When 0 THEN 0X00 ELSE [buVATAccGUID] END,
			CASE [buPayType] When 0 THEN 0X00 ELSE ISNULL(SCPGuid,0X00) END,
			ISNULL(ts.Guid, 0x00),
			bu.CustomerAddressGuid
		ORDER BY CASE [buPayType] When 0 THEN @Date ELSE [buDate] END,[bu].[buType], CASE [buPayType] When 0 THEN 0 ELSE [buNumber] END
-- second Result Set From di000 discount
	SELECT 
		 [Number],	[Discount],[Extra],	[CurrencyVal],[Notes] ,	[Flag],	[di].[Guid] AS [Guid], [ClassPtr],
			CASE @CashAcc WHEN 1 THEN CASE [buPayType] When 0 THEN [re].[Guid] ELSE [ParentGUID] END  ELSE [ParentGUID] END AS [ParentGUID] ,
			[AccountGUID] ,[CurrencyGUID],[CostGUID] ,[ContraAccGUID]
	FROM [di000] AS [di]
		INNER JOIN [vwbu] AS [bu] ON [bu].[buGuid] = [di].[ParentGuid]
		INNER JOIN [RepSrcs] AS [r] ON [bu].[buType] = [r].[IdType] 
		INNER JOIN [#RES] AS [re] ON [bu].[buType] = [re].[buType] AND [bu].[buBranch] = [re].[Branch] AND [bu].[buCustAcc] = [re].[buCustAccGuid] AND [re].[buStorePtr] = [bu].[buStorePtr]
		INNER JOIN [#StoreTbl] AS [ST] ON [ST].[StoreGuid] = [bu].[buStorePtr]
	WHERE 
		([buNumber] BETWEEN [r].[StartNum] AND [r].[EndNum]) OR ([buDate] BETWEEN @StartDate AND @EndDate)
		AND (([r].[IdTbl] = @SrcGuid) OR ( [r].[IdTbl] = NULL))
		
-- third Result set
	SELECT * FROM ((([ch000] AS [ch] INNER JOIN [vwbu] AS [bu] ON [bu].[buGuid] = [ch].[ParentGuid]) 
				  INNER JOIN [RepSrcs] AS [r] ON [bu].[buType] = [r].[IdType])
				  INNER JOIN [#StoreTbl] AS [ST] ON [ST].[StoreGuid] = [bu].[buStorePtr])
						WHERE 
							([buNumber] BETWEEN [r].[StartNum] AND [r].[EndNum]) OR ([buDate] BETWEEN @StartDate AND @EndDate)
							AND (([r].[IdTbl] = @SrcGuid) OR ( [r].[IdTbl] = NULL))
-- Next ResulSet from bi000
	SELECT
		[bi].[buType],
		CASE @CashAcc WHEN 1 THEN CASE [buPayType] When 0 THEN [re].[Guid] ELSE [buGuid] END  ELSE [buGuid] END AS [guid],
		CASE @CashAcc WHEN 1 THEN CASE [buPayType] When 0 THEN 0 ELSE [buNumber] END ELSE [buNumber] END AS [Number],
		[biMatPtr] ,
		[biStorePtr],
		[biQty],
		[biPrice],
		[biBonusQnt],
		[biDiscount],
		[biExtra],
		[biUnity],
		[biNotes],
		[biCurrencyPtr],
		[biCurrencyVal],
		[biProfits],
		[biBonusDisc],
		[biQty2],
		[biQty3],
		[biCostPtr],
		[biClassPtr],
		CP.CLassPrice AS biClassPrice,
		[biExpireDate],
		[biProductionDate],
		[biLength],
		[biWidth],
		[biHeight],
		biCount,
		CASE @CashAcc WHEN 1 THEN CASE [buPayType] When 0 THEN 0X00 ELSE [biGuid] END ELSE [biGuid] END AS [Guid2],
		[biVat],
		[biVATR],
		[mtName],
		[biGuid],
		[buBranch],
		[bisoGuid] ,
		[bisoType],
		[bi].[buStorePtr],
		[buNumber],
		[buPayType],
		[buDate],
		[biNumber]
	INTO [#Bi111]
	FROM
		[vwExtended_bi] AS [bi] --INNER JOIN [RepSrcs] AS [r] ON [bi].[buType] = [r].[IdType] 
		INNER JOIN [#RES] AS [re] ON [bi].[buType] = [re].[buType] AND ISNULL([bi].[buBranch], 0X0) = ISNULL([re].[Branch], 0X0) AND [bi].[buCustAcc] = [re].[buCustAccGuid] AND [bi].[buStorePtr] = [re].[buStorePtr]
		JOIN bi000 CP ON bi.biGuid = CP.[Guid]
	--WHERE 
	--	([buNumber] BETWEEN [r].[StartNum] AND [r].[EndNum]) OR ([buDate] BETWEEN @StartDate AND @EndDate)
	--	AND (([r].[IdTbl] = @SrcGuid) OR ( [r].[IdTbl] = NULL))
	ORDER BY [bi].[buType], CASE @CashAcc WHEN 1 THEN CASE [buPayType] When 0 THEN 0 ELSE [buNumber] END ELSE [buNumber] END, [bi].[biNumber]
	
	SELECT
		[bi].[buType],
		[bi].[buDate],
		bi.[guid],
		[Number],
		[biNumber] ,
		[biMatPtr] ,
		[biStorePtr],
		[biQty],
		[biPrice],
		[biBonusQnt],
		[biDiscount],
		[biExtra],
		[biUnity],
		[biNotes],
		[biCurrencyPtr],
		[biCurrencyVal],
		[biProfits],
		[biBonusDisc],
		[biQty2],
		[biQty3],
		[biCostPtr],
		[biClassPtr],
		biClassPrice,
		[biExpireDate],
		[biProductionDate],
		[biLength],
		[biWidth],
		[biHeight],
		biCount,
		[Guid2],
		[biVat],
		[biVATR],
		[mtName],
		[biGuid],
		[buBranch],
		[bisoGuid] ,
		[bisoType],
		[buStorePtr]
	INTO [#Bi1]
	FROM
		[#Bi111] AS [bi] INNER JOIN [RepSrcs] AS [r] ON [bi].[buType] = [r].[IdType] 
		--INNER JOIN [#RES] AS [re] ON [bi].[buType] = [re].[buType] AND [bi].[buBranch] = [re].[Branch] AND [bi].[buCustAcc] = [re].[buCustAccGuid] AND [bi].[buStorePtr] = [re].[buStorePtr])
	WHERE 
		([buNumber] BETWEEN [r].[StartNum] AND [r].[EndNum]) OR ([buDate] BETWEEN @StartDate AND @EndDate)
		AND (([r].[IdTbl] = @SrcGuid) OR ( [r].[IdTbl] = NULL))
	
	INSERT INTO [#Bi2]([TypeGuid],[guid],[Number],[MatGuid],[StoreGuid],[Qty],[price],[BonusQnt],
	[Discount],[Extra],[unity],[Notes],[CurrencyGUID],[CurrencyVal],[Profits],[BonusDisc],[Qty2],[Qty3],[CostGUID],[ClassPtr], ClassPrice,[ExpireDate],[ProductionDate],[Length],[Width],[Height], [Count],[Guid2],[Vat],[VATRatio],[mtName],[biGuid],[buBranch]
	,[soGuid],[soType] )	
		SELECT
			[bi].[buType],
			[guid],
			[Number],
			[biMatPtr] ,
			[biStorePtr],
			[biQty],
			[biPrice],
			[biBonusQnt],
			[biDiscount],
			[biExtra],
			[biUnity],
			[biNotes],
			[biCurrencyPtr],
			[biCurrencyVal],
			[biProfits],
			[biBonusDisc],
			[biQty2],
			[biQty3],
			[biCostPtr],
			[biClassPtr],
			biClassPrice,
			[biExpireDate],
			[biProductionDate],
			[biLength],
			[biWidth],
			[biHeight],
			biCount,
			[guid2],
			[biVat],
			[biVATR],
			[mtName],
			[biGuid],
			[buBranch],
			[bisoGuid] ,
			[bisoType]
		FROM
			[#Bi1] AS [bi]
			INNER JOIN [#StoreTbl] AS [ST] ON [ST].[StoreGuid] = [bi].[buStorePtr]
		ORDER BY [buDate],[buType],[guid],[biNumber]
		
	
	IF (@CashAcc = 1)
	BEGIN
		SELECT DISTINCT 
			NEWID() AS [GUID], 
			[MatGuid] ,
			[StoreGuid],
			[price],
			[unity],
			[Notes],
			[CurrencyGUID],
			[CurrencyVal],
			[CostGUID],
			[ClassPtr],
			ClassPrice,
			[ExpireDate],
			[ProductionDate],
			[Length],
			[Width],
			[Height],
			[Count],
			[buBranch]
		INTO [#V]
		FROM [#Bi2]
	
		UPDATE [B] SET [GUID2] =  [V].[Guid] 
		FROM [#Bi2] AS [B] INNER JOIN [#V] AS [V] ON
			[B].[MatGuid] = [V].[MatGuid]
			AND [B].[StoreGuid] = [V].[StoreGuid]
			AND [B].[price] = [V].[price]
			AND [B].[unity] = [V].[unity]
			AND [B].[Notes] = [V].[Notes]
			AND [B].[CurrencyGUID] = [V].[CurrencyGUID]
			AND [B].[CurrencyVal] = [V].[CurrencyVal]
			AND [B].[CostGUID] = [V].[CostGUID]
			AND [B].[ClassPtr] = [V].[ClassPtr]
			AND [B].[ClassPrice] = [V].[ClassPrice]
			AND [B].[ExpireDate] = [V].[ExpireDate]
			AND [B].[ProductionDate] = [V].[ProductionDate]
			AND [B].[Length] = [V].[Length]
			AND [B].[Width] = [V].[Width]
			AND [B].[Height] = [V].[Height]
			AND [B].[buBranch] = [V].[buBranch]
		WHERE [GUID2] = 0X00
	 END
	SELECT  [TypeGuid],[guid], [Number],
		[MatGuid] ,
		[StoreGuid],
		SUM([Qty]) AS[Qty],
		[price],
		SUM([BonusQnt]) AS [BonusQnt],
		SUM([Discount]) AS [Discount],
		SUM([Extra]) AS [Extra],
		[unity],
		[Notes],
		[CurrencyGUID],
		[CurrencyVal],
		SUM([Profits]) AS [Profits],
		SUM([BonusDisc]) AS [BonusDisc],
		SUM([Qty2]) AS [Qty2],
		SUM([Qty3]) AS [Qty3],
		[CostGUID],
		[ClassPtr],
		ClassPrice,
		[ExpireDate],
		[ProductionDate],
		[Length],
		[Width],
		[Height],
		[Count],
		[Guid2] AS [biGuid],
		SUM([Vat]) AS [Vat] ,
		SUM([VATRatio]) AS [VATRatio],
		[mtName],
		[buBranch],
		[soGuid],
		[soType]
	FROM [#Bi2]
	GROUP BY
		[TypeGuid],[guid], [Number],
		[MatGuid] ,
		[StoreGuid],
		[price],
		[unity],
		[Notes],
		[CurrencyGUID],
		[CurrencyVal],
		[CostGUID],
		[ClassPtr],
		ClassPrice,
		[ExpireDate],
		[ProductionDate],
		[Length],
		[Width],
		[Height],
		[Count],
		[Guid2],
		[mtName],
		[buBranch],
		[soGuid],
		[soType]
	ORDER BY MIN([NUM])
-- FROM vwbu AS bu INNER JOIN RepSrcs AS r ON bu.buType = r.IdType,
	--- return third result set From sn000
	SELECT
		[bi].[TypeGuid],
		[bi].[GUID2]  AS [biGuid],
		[sn].[Guid] 	AS [snGuid],
		[sn].[SN]		AS [SN],
		[sn].[Notes] 	AS [snNotes],
		[sn].[MatGuid] 	AS [snMatGuid]
	FROM [vcsns] AS [sn] INNER JOIN [#Bi2] AS [bi] ON [sn].[biGuid] = [bi].[biGuid] 
	ORDER BY
		[bi].[TypeGuid],
		[bi].[biGuid],
		[sn].[SN]
	
/*
prcConnections_add2 '„œÌ—'
EXEC  [prcGetExportedBills] '1/1/1980', '1/1/1980', '04e94be9-fa4d-4746-8a43-71d419f24224', 1, '00000000-0000-0000-0000-000000000000'
select class,* from en000
*/
##############################################################################
CREATE PROC prcGetExportedAcc
	@ExpAllAcc		INT,
	@From			NVARCHAR(255),
	@To				NVARCHAR(255)
AS
	SET NOCOUNT ON
	IF @ExpAllAcc = 0
		SELECT 
			[acGuid], 
			ISNULL([cuGuid], 0x0) [cuGuid], 
			ISNULL([ca].[GUID], 0x0) [addressGUID]
		FROM 
			[vwAc] [ac]
			LEFT JOIN [vwcu] [cu] ON [ac].[acGuid] = [cuAccount]
			LEFT JOIN vwCustAddress [ca] on [ca].CustomerGUID = [cu].[cuGUID]
		WHERE 
			[acType] <> 2 
			AND [acCode] BETWEEN @From AND @To
		ORDER BY
			[acNumber] 
	ELSE
		SELECT 
			[acGuid], 
			ISNULL([cuGuid], 0x0) [cuGuid], 
			ISNULL([ca].[GUID], 0x0) [addressGUID]
		FROM 
			[vwAc] [ac]
			LEFT JOIN [vwcu] [cu] ON [ac].[acGuid] = [cuAccount]
			LEFT JOIN vwCustAddress [ca] on [ca].CustomerGUID = [cu].[cuGUID]
		WHERE 
			[acType] <> 2
		ORDER BY
			[acNumber]
##############################################################################
#END