##################################################################################
CREATE FUNCTION fnIsSegmentationSupported() RETURNS BIT 
AS BEGIN 
	IF EXISTS(SELECT 1 FROM MaterialsSegmentsManagement000)
		RETURN 1
	RETURN 0
END
##################################################################################
CREATE FUNCTION fnIsBranchesSupported() RETURNS BIT 
AS BEGIN 
	IF EXISTS(SELECT 1 FROM br000)
		RETURN 1
	RETURN 0
END
##################################################################################
CREATE FUNCTION fnIsFinancialAnalyticSupported()
RETURNS BIT
AS
BEGIN
	IF NOT EXISTS(SELECT * FROM sys.objects WHERE name = 'FinancialCycleInfo000')
		RETURN 0

	IF EXISTS(SELECT GUID FROM FinancialCycleInfo000)
		RETURN 1

	RETURN 0
END
##################################################################################
CREATE FUNCTION fnCurrency_Fix_Analysis(@Value AS [FLOAT], @OldCurGUID [UNIQUEIDENTIFIER], @OldCurVal [FLOAT], @NewCurGUID [UNIQUEIDENTIFIER], @NewCurDate AS [DATETIME] = NULL)
RETURNS TABLE
AS RETURN
(
	SELECT 
		CASE WHEN @OldCurGUID = @NewCurGUID THEN @Value / (CASE @OldCurVal WHEN 0 THEN 1 ELSE @OldCurVal END)
		ELSE 
			@Value / 
			ISNULL(
				(SELECT TOP 1 [CurrencyVal] AS [Val] FROM [mh000] WHERE [CurrencyGUID] = @NewCurGUID AND [Date] <= @NewCurDate ORDER BY [Date] DESC), 
				(SELECT [CurrencyVal] AS [Val] FROM my000 WHERE [GUID] = @newCurGUID))
		END AS [FixedCurrencyFactor])
##################################################################################
CREATE VIEW vwBiMt_Analysis
AS 
	SELECT
		bi.GUID AS biGUID,
		bi.ParentGUID AS biParentGUID,
		(CASE [mt].[Unit2FactFlag] WHEN 0 THEN [bi].[Qty] / (CASE [mt].[Unit2Fact] WHEN 0 THEN 1 ELSE [mt].[Unit2Fact] END) ELSE [bi].[Qty2] END) AS [biQty2],
		(CASE [mt].[Unit3FactFlag] WHEN 0 THEN [bi].[Qty] / (CASE [mt].[Unit3Fact] WHEN 0 THEN 1 ELSE [mt].[Unit3Fact] END) ELSE [bi].[Qty3] END) AS [biQty3],
		(CASE bi.[Unity]
			WHEN 2 THEN [bi].[Qty] / (CASE [mt].[Unit2Fact] WHEN 0 THEN 1 ELSE [mt].[Unit2Fact] END)
			WHEN 3 THEN [bi].[Qty] / (CASE [mt].[Unit3Fact] WHEN 0 THEN 1 ELSE [mt].[Unit3Fact] END)
			ELSE [bi].[Qty]
		END) AS [biBillQty],
		(CASE bi.[Unity]
			WHEN 2 THEN [bi].[BonusQnt] / (CASE [mt].[Unit2Fact] WHEN 0 THEN 1 ELSE [mt].[Unit2Fact] END)
			WHEN 3 THEN [bi].[BonusQnt] / (CASE [mt].[Unit3Fact] WHEN 0 THEN 1 ELSE [mt].[Unit3Fact] END)
			ELSE [bi].[BonusQnt]
		END) AS [biBillBonusQnt],
		(CASE [bi].[Unity]
				WHEN 2 THEN (CASE [mt].[Unit2FactFlag] WHEN 0 THEN [mt].[Unit2Fact] ELSE bi.[Qty] / (CASE bi.[Qty2] WHEN 0 THEN 1 ELSE bi.[Qty2] END) END)
				WHEN 3 THEN (CASE [mt].[Unit3FactFlag] WHEN 0 THEN [mt].[Unit3Fact] ELSE bi.[Qty] / (CASE bi.[Qty3] WHEN 0 THEN 1 ELSE bi.[Qty3] END) END)
				ELSE 1
		END) AS [mtUnitFact],
		[bi].[Unity] AS [biUnity],  
		[bi].[Price] AS [biPrice],
		[bi].[Discount] AS biDiscount,
		[bi].[Extra] AS biExtra,
		[bi].[Qty] AS biQty,  
		[bi].[BonusQnt] AS [biBonusQnt],
		[bi].[BonusDisc] AS biBonusDisc,
		[bi].[Profits] AS [biProfits],
		[mt].[GUID] AS mtGUID,  
		[mt].[Name] AS mtName,  
		[mt].[Code] AS mtCode,  
		[mt].[LatinName] AS mtLatinName,  
		[mt].[Unit2Fact] AS [mtUnit2Fact],  
		[mt].[Unit3Fact] AS [mtUnit3Fact],  
		(CASE mt.[DefUnit] 
			WHEN 2 THEN mt.[Unit2Fact] 
			WHEN 3 THEN mt.[Unit3Fact] 
			ELSE 1 
		END) AS [mtDefUnitFact], 
		(bi.[VAT] + ISNULL(bi.ExciseTaxVal, 0) + ISNULL(bi.ReversChargeVal, 0)) AS [biTotalTaxValue],
		[gr].[GUID] AS mtGroup,
		[gr].[Name] AS grName,
		[gr].[LatinName] AS grLatinName
	FROM 
		bi000 AS [bi]
		INNER JOIN mt000 AS [mt] ON [mt].[GUID] = [bi].[MatGUID] 
		INNER JOIN gr000 AS [gr] ON [gr].[GUID] = [mt].[GroupGUID] 
##################################################################################
CREATE VIEW vwExtended_bi_Analysis
AS 
	SELECT  
		[bu].[GUID] AS [buGUID],  
		[bu].[TypeGUID] AS [buType],  
		[bu].[IsPosted] AS [buIsPosted],  
		CONVERT(DATE, [bu].[Date]) AS [buDate],  
		[bu].[PayType] AS [buPayType],  
		[bu].[CustGUID] AS [buCustGUID],  
		[bu].[CurrencyGUID] AS [buCurrencyGUID],  
		[bu].[CurrencyVal] AS [buCurrencyVal],
		ISNULL([br].[GUID], 0x0) AS [brGUID],
		ISNULL([br].[Name], '') AS [brName],
		ISNULL([br].[LatinName], '') AS [brLatinName],
		[bu].[Total] AS [buTotal],  
		[bt].[BillType] AS [btBillType],  
		[bt].[Type] AS [btType], 
		[bt].[Name] AS [btName],   
		[bt].[LatinName] AS [btLatinName],  
		[bt].[bIsInput] AS [btIsInput],  
		[bt].[bAffectLastPrice] AS [btAffectLastPrice],  
		[bt].[bAffectCostPrice] AS [btAffectCostPrice],  
		[bt].[bAffectProfit] AS [btAffectProfit],  
		[bt].[bAffectCustPrice] AS [btAffectCustPrice],  
		[bt].[bDiscAffectCost] AS [btDiscAffectCost],  
		[bt].[bExtraAffectCost] AS [btExtraAffectCost],  
		[bt].[bDiscAffectProfit] AS [btDiscAffectProfit],  
		[bt].[bExtraAffectProfit] AS [btExtraAffectProfit],  
		[bi].[biUnity],
		[bi].[biPrice],
		(CASE [bi].[mtUnitFact] WHEN 0 THEN 0 ELSE [bi].[biPrice] / [bi].[mtUnitFact] END) AS [biUnitPrice],  
		((CASE (bu.Total - bu.ItemsDisc) WHEN 0 THEN (CASE bi.[biQty] WHEN 0 THEN 0  ELSE [biDiscount] / bi.[biQty] END) + [biBonusDisc] ELSE ((CASE bi.[biQty] WHEN 0 THEN 0 ELSE ([biDiscount] / bi.[biQty]) END) + (
			ISNULL(DI.Discount, 0) * (bi.biPrice - (CASE biDiscount WHEN 0 THEN 0 ELSE biDiscount / bi.biQty END) * CASE bi.mtUnitFact WHEN 0 THEN 1 ELSE bi.mtUnitFact END ) / CASE bi.mtUnitFact WHEN 0 THEN 1 ELSE bi.mtUnitFact END
			) / (bu.Total - bu.ItemsDisc)) END) + (CASE bi.biQty WHEN 0 THEN 0 ELSE (bi.biBonusDisc / bi.biQty) END)) AS [biUnitDiscount],   
		((CASE (bu.Total + bu.ItemsExtra) WHEN 0 THEN (CASE bi.[biQty] WHEN 0 THEN 0  ELSE [biExtra] / bi.[biQty] END) ELSE ((CASE [biQty] WHEN 0 THEN 0 ELSE ([biExtra] / bi.[biQty]) END) + (
			ISNULL(DI.Extra, 0) * (biPrice + (CASE biExtra WHEN 0 THEN 0 ELSE biExtra / bi.biQty END) * CASE bi.mtUnitFact WHEN 0 THEN 1 ELSE bi.mtUnitFact END ) / CASE bi.mtUnitFact WHEN 0 THEN 1 ELSE bi.mtUnitFact END
			) / (bu.Total + bu.ItemsExtra)) END)) AS [biUnitExtra],
		[bi].[biQty],  
		[bi].[biBonusQnt],
		[bi].[biProfits],
		[bi].[mtGUID],
		[bi].[mtName],
		[bi].[mtCode],
		[bi].[mtLatinName],  
		[bi].[mtUnit2Fact],  
		[bi].[mtUnit3Fact],
		[bi].[mtDefUnitFact], 
		[bi].[mtGroup],
		[bi].[grName],
		[bi].[grLatinName],
		[bi].[biTotalTaxValue]
	FROM  
		bu000 bu 
		INNER JOIN bt000 AS [bt] ON [bt].[GUID] = [bu].[TypeGUID] 
		INNER JOIN vwBiMt_Analysis AS [bi] ON [bu].[GUID] = [bi].biParentGUID 
		LEFT JOIN [br000] [br] ON [br].[GUID] = [bu].[Branch]
		OUTER APPLY dbo.fnBill_GetDiSum(bu.GUID) AS DI
##################################################################################
CREATE PROC repAccountsAnalysis
	@StartDate DATE = NULL,
	@EndDate DATE = NULL,
	@AccountGUID UNIQUEIDENTIFIER = 0x0,
	@CurrencyGUID UNIQUEIDENTIFIER = 0x0,
	@CostGUID UNIQUEIDENTIFIER = 0x0
AS 
	SET NOCOUNT ON 

	DECLARE @Lang INT 
	SET @Lang = [dbo].[fnConnections_GetLanguage]()

	CREATE TABLE [#Accounts] ([AccountGUID] UNIQUEIDENTIFIER)	
	IF ISNULL(@AccountGUID, 0x0) != 0x0
		INSERT INTO [#Accounts]([AccountGUID]) SELECT [GUID] FROM dbo.[fnGetAccountsList](@AccountGUID, 0)

	CREATE TABLE [#Costs] ([CostGUID] UNIQUEIDENTIFIER)	
	IF ISNULL(@CostGUID, 0x0) != 0x0
		INSERT INTO [#Costs]([CostGUID]) SELECT [GUID] FROM [dbo].[fnGetCostsList](@CostGUID)

	IF ISNULL(@CurrencyGUID, 0x0) = 0x0
		SET @CurrencyGUID = (SELECT TOP 1 GUID FROM my000 WHERE CurrencyVal = 1 ORDER BY Number)

	SELECT 
		en.ceDate AS EntryDate,
		en.acCode AS AccountCode,
		CASE @Lang WHEN 0 THEN en.acName ELSE (CASE ISNULL(en.acLatinName, '') WHEN '' THEN en.acName ELSE en.acLatinName END) END AS AccountName,
		ISNULL(CASE @Lang WHEN 0 THEN ac.Name ELSE (CASE ISNULL(ac.LatinName, '') WHEN '' THEN ac.Name ELSE ac.LatinName END) END, '') AS ParentAccountName,
		SUM( en.FixedEnDebit - en.FixedEnCredit ) AS Balance
	FROM 
		dbo.fnExtended_En_Fixed(@CurrencyGUID) en
		left join ac000 ac on ac.guid = en.acParent
	WHERE 
		en.ceIsPosted = 1
		AND 
		((ISNULL(@AccountGUID, 0x0) = 0x0) OR EXISTS(SELECT 1 FROM [#Accounts] WHERE [AccountGUID] = en.enAccount))
		AND 
		((ISNULL(@CostGUID, 0x0) = 0x0) OR EXISTS(SELECT 1 FROM [#Costs] WHERE [CostGUID] = en.enCostPoint))
		AND 
		((@StartDate IS NULL) OR (en.ceDate >= @StartDate))
		AND 
		((@EndDate IS NULL) OR (en.ceDate <= @EndDate))

	GROUP BY 
		en.ceDate, 
		en.acCode, 
		CASE @Lang WHEN 0 THEN en.acName ELSE (CASE ISNULL(en.acLatinName, '') WHEN '' THEN en.acName ELSE en.acLatinName END) END,
		ISNULL(CASE @Lang WHEN 0 THEN ac.Name ELSE (CASE ISNULL(ac.LatinName, '') WHEN '' THEN ac.Name ELSE ac.LatinName END) END, '')
##################################################################################
CREATE PROC repExpensesAnalysis
	@StartDate DATE = NULL,
	@EndDate DATE = NULL,
	@AccountGUID UNIQUEIDENTIFIER = 0x0,
	@CurrencyGUID UNIQUEIDENTIFIER = 0x0,
	@CostGUID UNIQUEIDENTIFIER = 0x0
AS 
	SET NOCOUNT ON 

	DECLARE @Lang INT 
	SET @Lang = [dbo].[fnConnections_GetLanguage]()

	CREATE TABLE [#Accounts] ([AccountGUID] UNIQUEIDENTIFIER)	
	IF ISNULL(@AccountGUID, 0x0) != 0x0
		INSERT INTO [#Accounts]([AccountGUID]) SELECT [GUID] FROM dbo.[fnGetAccountsList](@AccountGUID, 0)

	CREATE TABLE [#Costs] ([CostGUID] UNIQUEIDENTIFIER)	
	IF ISNULL(@CostGUID, 0x0) != 0x0
		INSERT INTO [#Costs]([CostGUID]) SELECT [GUID] FROM [dbo].[fnGetCostsList](@CostGUID)

	IF ISNULL(@CurrencyGUID, 0x0) = 0x0
		SET @CurrencyGUID = (SELECT TOP 1 GUID FROM my000 WHERE CurrencyVal = 1 ORDER BY Number)

	SELECT 
		en.ceDate AS EntryDate,
		en.acCode AS AccountCode,
		CASE @Lang WHEN 0 THEN en.acName ELSE (CASE ISNULL(en.acLatinName, '') WHEN '' THEN en.acName ELSE en.acLatinName END) END AS AccountName,
		SUM( en.FixedEnDebit - en.FixedEnCredit ) AS Balance
	FROM 
		dbo.fnExtended_En_Fixed(@CurrencyGUID) en
	WHERE 
		en.ceIsPosted = 1
		AND 
		((ISNULL(@AccountGUID, 0x0) = 0x0) OR EXISTS(SELECT 1 FROM [#Accounts] WHERE [AccountGUID] = en.enAccount))
		AND 
		((ISNULL(@CostGUID, 0x0) = 0x0) OR EXISTS(SELECT 1 FROM [#Costs] WHERE [CostGUID] = en.enCostPoint))
		AND 
		((@StartDate IS NULL) OR (en.ceDate >= @StartDate))
		AND 
		((@EndDate IS NULL) OR (en.ceDate <= @EndDate))

	GROUP BY en.ceDate, en.acCode, CASE @Lang WHEN 0 THEN en.acName ELSE (CASE ISNULL(en.acLatinName, '') WHEN '' THEN en.acName ELSE en.acLatinName END) END
##################################################################################
CREATE PROC repMaterialsSegmentsAnalysis
	@StartDate DATE = NULL,
	@EndDate DATE = NULL,
	@UseUnit INT = 0,		-- 0: unit 1, 1: unit 2, 2: unit 3, 3: def unit
	@CurrencyGUID UNIQUEIDENTIFIER = 0x0,
	@GroupGUID UNIQUEIDENTIFIER = 0x0
AS 
	SET NOCOUNT ON 

	DECLARE @Lang INT 
	SET @Lang = [dbo].[fnConnections_GetLanguage]()

	CREATE TABLE [#Groups] ([GroupGUID] [UNIQUEIDENTIFIER])	

	IF ISNULL(@CurrencyGUID, 0x0) = 0x0
		SET @CurrencyGUID = (SELECT TOP 1 GUID FROM my000 WHERE CurrencyVal = 1 ORDER BY Number)

	IF ISNULL(@GroupGUID, 0x0) != 0x0
		INSERT INTO [#Groups]([GroupGUID]) SELECT [GUID] FROM dbo.[fnGetGroupsOfGroup](@GroupGUID)
		 
	CREATE TABLE #Result (
		BillDate DATE,
		MaterialGUID UNIQUEIDENTIFIER,
		CustomerName NVARCHAR(500),
		MaterialName NVARCHAR(500),
		MaterialCode NVARCHAR(500),
		GroupName NVARCHAR(500),
		BillTypeName NVARCHAR(500),
		ParentMaterialName NVARCHAR(500),
		IsCompstion BIT,
		ItemQuantity FLOAT,
		ItemNetTotal FLOAT
	)

	CREATE TABLE #Segments (
		ColumnName_Code NVARCHAR(500),
		ColumnName_Name NVARCHAR(500),
		Caption_Name NVARCHAR(500),
		Caption_LatinName NVARCHAR(500)
	)

	INSERT INTO #Result
	SELECT 
		bi.buDate,
		bi.biMatPtr,
		ISNULL(CASE @Lang WHEN 0 THEN cu.CustomerName ELSE (CASE ISNULL(cu.LatinName, '') WHEN '' THEN cu.CustomerName ELSE cu.LatinName END) END, ''),
		CASE 
			WHEN mtP.GUID IS NULL THEN CASE @Lang WHEN 0 THEN bi.mtName ELSE (CASE ISNULL(bi.mtLatinName, '') WHEN '' THEN bi.mtName ELSE bi.mtLatinName END) END
			ELSE CASE @Lang WHEN 0 THEN bi.mtCompositionName ELSE (CASE ISNULL(bi.mtCompositionLatinName, '') WHEN '' THEN bi.mtCompositionName ELSE bi.mtCompositionLatinName END) END
		END, 		
		bi.mtCode,
		CASE @Lang WHEN 0 THEN gr.Name ELSE (CASE ISNULL(gr.LatinName, '') WHEN '' THEN gr.Name ELSE gr.LatinName END) END,
		CASE @Lang WHEN 0 THEN bt.Name ELSE (CASE ISNULL(bt.LatinName, '') WHEN '' THEN bt.Name ELSE bt.LatinName END) END,
		ISNULL(CASE @Lang WHEN 0 THEN mtP.Name ELSE (CASE ISNULL(mtP.LatinName, '') WHEN '' THEN mtP.Name ELSE mtP.LatinName END) END, ''),
		CASE WHEN mtP.GUID IS NULL THEN 0 ELSE 1 END, 
		SUM(
			(CASE bt.bIsInput WHEN 1 THEN -1 ELSE 1 END) * 
			((bi.biQty + bi.biBonusQnt) / 
			(CASE @UseUnit 
				WHEN 1 THEN (CASE bi.mtUnit2Fact WHEN 0 THEN 1 ELSE bi.mtUnit2Fact END)
				WHEN 2 THEN (CASE bi.mtUnit3Fact WHEN 0 THEN 1 ELSE bi.mtUnit3Fact END)
				WHEN 3 THEN [bi].[mtDefUnitFact]
				ELSE 1			  
			END))),
		SUM((CASE bt.bIsInput WHEN 1 THEN -1 ELSE 1 END) * [bi].[FixedbiTotal])

	FROM 
		dbo.fnExtended_bi_Fixed(@CurrencyGUID) bi
		INNER JOIN bt000 bt ON bt.GUID = bi.buType
		INNER JOIN gr000 gr ON gr.GUID = bi.mtGroup
		LEFT JOIN mt000 mtP ON mtP.GUID = bi.mtParent
		LEFT JOIN cu000 cu ON cu.GUID = bi.buCustPtr
	WHERE 
		(bt.type = 1 AND (bt.BillType IN (1, 3)))
		AND 
		bi.buIsPosted = 1
		AND 
		((@StartDate IS NULL) OR (bi.buDate >= @StartDate))
		AND 
		((@EndDate IS NULL) OR (bi.buDate <= @EndDate))
		AND 
		((ISNULL(@GroupGUID, 0x0) = 0x0) OR EXISTS(SELECT 1 FROM [#Groups] WHERE [GroupGUID] = gr.GUID))

	GROUP BY 
		bi.buDate,
		bi.biMatPtr,
		ISNULL(CASE @Lang WHEN 0 THEN cu.CustomerName ELSE (CASE ISNULL(cu.LatinName, '') WHEN '' THEN cu.CustomerName ELSE cu.LatinName END) END, ''),
		CASE 
			WHEN mtP.GUID IS NULL THEN CASE @Lang WHEN 0 THEN bi.mtName ELSE (CASE ISNULL(bi.mtLatinName, '') WHEN '' THEN bi.mtName ELSE bi.mtLatinName END) END
			ELSE CASE @Lang WHEN 0 THEN bi.mtCompositionName ELSE (CASE ISNULL(bi.mtCompositionLatinName, '') WHEN '' THEN bi.mtCompositionName ELSE bi.mtCompositionLatinName END) END
		END, 		
		bi.mtCode,
		CASE @Lang WHEN 0 THEN gr.Name ELSE (CASE ISNULL(gr.LatinName, '') WHEN '' THEN gr.Name ELSE gr.LatinName END) END,
		CASE @Lang WHEN 0 THEN bt.Name ELSE (CASE ISNULL(bt.LatinName, '') WHEN '' THEN bt.Name ELSE bt.LatinName END) END,
		ISNULL(CASE @Lang WHEN 0 THEN mtP.Name ELSE (CASE ISNULL(mtP.LatinName, '') WHEN '' THEN mtP.Name ELSE mtP.LatinName END) END, ''),
		CASE WHEN mtP.GUID IS NULL THEN 0 ELSE 1 END

	DECLARE 
		@C CURSOR,
		@SegmentGUID UNIQUEIDENTIFIER,
		@Number INT,
		@SQL NVARCHAR(MAX),
		@SegmentName NVARCHAR(250),
		@SegmentLatinName NVARCHAR(250)

	SET @C = CURSOR FAST_FORWARD FOR SELECT SegmentId, Number FROM MaterialsSegmentsManagement000 ORDER BY Number
	OPEN @C FETCH NEXT FROM @C INTO @SegmentGUID, @Number
	WHILE @@FETCH_STATUS = 0 
	BEGIN 
		IF EXISTS(
			SELECT * FROM 
				#Result r 
				INNER JOIN MaterialElements000 me ON r.MaterialGUID = me.MaterialId
				INNER JOIN SegmentElements000 se ON se.Id = me.ElementId
				INNER JOIN Segments000 s ON s.Id = se.SegmentId
			WHERE s.Id = @SegmentGUID 
		)
		BEGIN 			
			SET @SQL = '
				ALTER TABLE #Result ADD	SegmentCode' + CAST(@Number AS NVARCHAR(10)) + ' NVARCHAR(250)
				ALTER TABLE #Result ADD	SegmentName' + CAST(@Number AS NVARCHAR(10)) + ' NVARCHAR(250) '
			
			SELECT 
				@SegmentName = Name,
				@SegmentLatinName = LatinName
			FROM Segments000
			WHERE Id = @SegmentGUID 

			SET @SQL = @SQL + '
				INSERT INTO #Segments SELECT ''SegmentCode' + CAST(@Number AS NVARCHAR(10)) + ''', ''SegmentName' + CAST(@Number AS NVARCHAR(10)) + 
				''', ''' + @SegmentName + ''', ''' + @SegmentLatinName + ''''
			
			-- PRINT (@SQL)
			EXEC (@SQL)

			SET @SQL = '
				UPDATE #Result SET 
					SegmentCode' + CAST(@Number AS NVARCHAR(10)) + ' = se.Code,
					SegmentName' + CAST(@Number AS NVARCHAR(10)) + ' = CASE ' + CAST(@Lang AS NVARCHAR(10)) + ' WHEN 0 THEN se.Name ELSE (CASE ISNULL(se.LatinName, '''') WHEN '''' THEN se.Name ELSE se.LatinName END) END
				FROM 
					#Result r
					INNER JOIN MaterialElements000 me ON r.MaterialGUID = me.MaterialId
					INNER JOIN SegmentElements000 se ON se.Id = me.ElementId
					INNER JOIN Segments000 s ON s.Id = se.SegmentId
				WHERE s.Id = ''' + CAST(@SegmentGUID AS NVARCHAR(250)) + ''''
			
			-- PRINT (@SQL)
			EXEC (@SQL)
		END
		FETCH NEXT FROM @C INTO @SegmentGUID, @Number
	END 

	SELECT * FROM #Result
	SELECT * FROM #Segments
##################################################################################
CREATE PROC repMaterialsSegmentsInventory
	@UseUnit INT = 0,		-- 0: unit 1, 1: unit 2, 2: unit 3, 3: def unit
	@CurrencyGUID UNIQUEIDENTIFIER = 0x0,
	@GroupGUID UNIQUEIDENTIFIER = 0x0,
	@StoreGUID UNIQUEIDENTIFIER = 0x0
AS 
	SET NOCOUNT ON 

	DECLARE @Lang INT 
	SET @Lang = [dbo].[fnConnections_GetLanguage]()

	CREATE TABLE [#Groups] ([GroupGUID] [UNIQUEIDENTIFIER])	
	CREATE TABLE [#Stores] ([StoreGUID] [UNIQUEIDENTIFIER])	

	IF ISNULL(@CurrencyGUID, 0x0) = 0x0
		SET @CurrencyGUID = (SELECT TOP 1 GUID FROM my000 WHERE CurrencyVal = 1 ORDER BY Number)

	IF ISNULL(@GroupGUID, 0x0) != 0x0
		INSERT INTO [#Groups]([GroupGUID]) SELECT [GUID] FROM dbo.[fnGetGroupsOfGroup](@GroupGUID)

	IF ISNULL(@StoreGUID, 0x0) != 0x0	 
		INSERT INTO [#Stores]([StoreGUID]) SELECT [GUID] FROM [dbo].[fnGetStoresList](@StoreGUID)

	CREATE TABLE #Result (
		MaterialGUID UNIQUEIDENTIFIER,
		MaterialName NVARCHAR(500),
		MaterialCode NVARCHAR(500),
		GroupName NVARCHAR(500),
		StoreName NVARCHAR(500),
		ParentMaterialName NVARCHAR(500),
		IsCompstion BIT,
		ItemQuantity FLOAT,
		AvgPrice FLOAT,
		OrderLimit FLOAT
	)

	CREATE TABLE #Segments (
		ColumnName_Code NVARCHAR(500),
		ColumnName_Name NVARCHAR(500),
		Caption_Name NVARCHAR(500),
		Caption_LatinName NVARCHAR(500)
	)

	INSERT INTO #Result
	SELECT 
		bi.biMatPtr,
		CASE 
			WHEN mtP.GUID IS NULL THEN CASE @Lang WHEN 0 THEN bi.mtName ELSE (CASE ISNULL(bi.mtLatinName, '') WHEN '' THEN bi.mtName ELSE bi.mtLatinName END) END
			ELSE CASE @Lang WHEN 0 THEN bi.mtCompositionName ELSE (CASE ISNULL(bi.mtCompositionLatinName, '') WHEN '' THEN bi.mtCompositionName ELSE bi.mtCompositionLatinName END) END
		END, 		
		bi.mtCode,
		CASE @Lang WHEN 0 THEN gr.Name ELSE (CASE ISNULL(gr.LatinName, '') WHEN '' THEN gr.Name ELSE gr.LatinName END) END,
		CASE @Lang WHEN 0 THEN st.Name ELSE (CASE ISNULL(st.LatinName, '') WHEN '' THEN st.Name ELSE st.LatinName END) END,
		ISNULL(CASE @Lang WHEN 0 THEN mtP.Name ELSE (CASE ISNULL(mtP.LatinName, '') WHEN '' THEN mtP.Name ELSE mtP.LatinName END) END, ''),
		CASE WHEN mtP.GUID IS NULL THEN 0 ELSE 1 END, 
		SUM(
			(CASE bt.bIsInput WHEN 1 THEN 1 ELSE -1 END) * 
			((bi.biQty + bi.biBonusQnt) / 
			(CASE @UseUnit 
				WHEN 1 THEN (CASE bi.mtUnit2Fact WHEN 0 THEN 1 ELSE bi.mtUnit2Fact END)
				WHEN 2 THEN (CASE bi.mtUnit3Fact WHEN 0 THEN 1 ELSE bi.mtUnit3Fact END)
				WHEN 3 THEN [bi].[mtDefUnitFact]
				ELSE 1			  
			END))),
		MAX(bi.mtAvgPrice * bi.FixedCurrencyFactor),
		MAX(mt.OrderLimit / 			
			(CASE @UseUnit 
				WHEN 1 THEN (CASE bi.mtUnit2Fact WHEN 0 THEN 1 ELSE bi.mtUnit2Fact END)
				WHEN 2 THEN (CASE bi.mtUnit3Fact WHEN 0 THEN 1 ELSE bi.mtUnit3Fact END)
				WHEN 3 THEN [bi].[mtDefUnitFact]
				ELSE 1			  
			END))
	FROM 
		dbo.fnExtended_bi_Fixed(@CurrencyGUID) bi
		INNER JOIN bt000 bt ON bt.GUID = bi.buType
		INNER JOIN gr000 gr ON gr.GUID = bi.mtGroup
		INNER JOIN mt000 mt ON mt.GUID = bi.biMatPtr
		INNER JOIN st000 st ON st.GUID = bi.biStorePtr
		LEFT JOIN mt000 mtP ON mtP.GUID = bi.mtParent
	WHERE 
		bi.buIsPosted = 1
		AND 
		((ISNULL(@GroupGUID, 0x0) = 0x0) OR EXISTS(SELECT 1 FROM [#Groups] WHERE [GroupGUID] = gr.GUID))
		AND 
		((ISNULL(@StoreGUID, 0x0) = 0x0) OR EXISTS(SELECT 1 FROM [#Stores] WHERE [StoreGUID] = st.GUID))
	GROUP BY 
		bi.biMatPtr,
		CASE 
			WHEN mtP.GUID IS NULL THEN CASE @Lang WHEN 0 THEN bi.mtName ELSE (CASE ISNULL(bi.mtLatinName, '') WHEN '' THEN bi.mtName ELSE bi.mtLatinName END) END
			ELSE CASE @Lang WHEN 0 THEN bi.mtCompositionName ELSE (CASE ISNULL(bi.mtCompositionLatinName, '') WHEN '' THEN bi.mtCompositionName ELSE bi.mtCompositionLatinName END) END
		END, 		
		bi.mtCode,
		CASE @Lang WHEN 0 THEN gr.Name ELSE (CASE ISNULL(gr.LatinName, '') WHEN '' THEN gr.Name ELSE gr.LatinName END) END,
		CASE @Lang WHEN 0 THEN st.Name ELSE (CASE ISNULL(st.LatinName, '') WHEN '' THEN st.Name ELSE st.LatinName END) END,
		ISNULL(CASE @Lang WHEN 0 THEN mtP.Name ELSE (CASE ISNULL(mtP.LatinName, '') WHEN '' THEN mtP.Name ELSE mtP.LatinName END) END, ''),
		CASE WHEN mtP.GUID IS NULL THEN 0 ELSE 1 END

	DELETE #Result WHERE ItemQuantity = 0

	DECLARE 
		@C CURSOR,
		@SegmentGUID UNIQUEIDENTIFIER,
		@Number INT,
		@SQL NVARCHAR(MAX),
		@SegmentName NVARCHAR(250),
		@SegmentLatinName NVARCHAR(250)

	SET @C = CURSOR FAST_FORWARD FOR SELECT SegmentId, Number FROM MaterialsSegmentsManagement000 ORDER BY Number
	OPEN @C FETCH NEXT FROM @C INTO @SegmentGUID, @Number
	WHILE @@FETCH_STATUS = 0 
	BEGIN 
		IF EXISTS(
			SELECT * FROM 
				#Result r 
				INNER JOIN MaterialElements000 me ON r.MaterialGUID = me.MaterialId
				INNER JOIN SegmentElements000 se ON se.Id = me.ElementId
				INNER JOIN Segments000 s ON s.Id = se.SegmentId
			WHERE s.Id = @SegmentGUID 
		)
		BEGIN 			
			SET @SQL = '
				ALTER TABLE #Result ADD	SegmentCode' + CAST(@Number AS NVARCHAR(10)) + ' NVARCHAR(250)
				ALTER TABLE #Result ADD	SegmentName' + CAST(@Number AS NVARCHAR(10)) + ' NVARCHAR(250) '
			
			SELECT 
				@SegmentName = Name,
				@SegmentLatinName = LatinName
			FROM Segments000
			WHERE Id = @SegmentGUID 

			SET @SQL = @SQL + '
				INSERT INTO #Segments SELECT ''SegmentCode' + CAST(@Number AS NVARCHAR(10)) + ''', ''SegmentName' + CAST(@Number AS NVARCHAR(10)) + 
				''', ''' + @SegmentName + ''', ''' + @SegmentLatinName + ''''
			
			-- PRINT (@SQL)
			EXEC (@SQL)

			SET @SQL = '
				UPDATE #Result SET 
					SegmentCode' + CAST(@Number AS NVARCHAR(10)) + ' = se.Code,
					SegmentName' + CAST(@Number AS NVARCHAR(10)) + ' = CASE ' + CAST(@Lang AS NVARCHAR(10)) + ' WHEN 0 THEN se.Name ELSE (CASE ISNULL(se.LatinName, '''') WHEN '''' THEN se.Name ELSE se.LatinName END) END
				FROM 
					#Result r
					INNER JOIN MaterialElements000 me ON r.MaterialGUID = me.MaterialId
					INNER JOIN SegmentElements000 se ON se.Id = me.ElementId
					INNER JOIN Segments000 s ON s.Id = se.SegmentId
				WHERE s.Id = ''' + CAST(@SegmentGUID AS NVARCHAR(250)) + ''''
			
			-- PRINT (@SQL)
			EXEC (@SQL)
		END
		FETCH NEXT FROM @C INTO @SegmentGUID, @Number
	END 

	SELECT *, (ItemQuantity * AvgPrice) AS ItemPrice FROM #Result
	SELECT * FROM #Segments
##################################################################################
CREATE PROC repProfitsAnalysis
	@StartDate DATE = NULL,
	@EndDate DATE = NULL,
	@UseUnit INT = 0,		-- 0: unit 1, 1: unit 2, 2: unit 3, 3: def unit
	@CurrencyGUID UNIQUEIDENTIFIER = 0x0,
	@GroupGUID UNIQUEIDENTIFIER = 0x0
AS 
	SET NOCOUNT ON 

	DECLARE @Lang INT 
	SET @Lang = [dbo].[fnConnections_GetLanguage]()

	DECLARE @Groups TABLE ([GroupGUID] [UNIQUEIDENTIFIER])	
	IF ISNULL(@CurrencyGUID, 0x0) = 0x0
		SET @CurrencyGUID = (SELECT TOP 1 GUID FROM my000 WHERE CurrencyVal = 1 ORDER BY Number)
	IF ISNULL(@GroupGUID, 0x0) != 0x0
		INSERT INTO @Groups([GroupGUID]) SELECT [GUID] FROM dbo.[fnGetGroupsOfGroup](@GroupGUID)

	SELECT 
		bi.buDate AS BillDate,
		CASE @Lang WHEN 0 THEN bi.mtName ELSE (CASE ISNULL(bi.mtLatinName, '') WHEN '' THEN bi.mtName ELSE bi.mtLatinName END) END AS MaterialName,
		CASE @Lang WHEN 0 THEN bi.grName ELSE (CASE ISNULL(bi.grLatinName, '') WHEN '' THEN bi.grName ELSE bi.grLatinName END) END AS GroupName,
		CASE @Lang WHEN 0 THEN bi.btName ELSE (CASE ISNULL(bi.btLatinName, '') WHEN '' THEN bi.btName ELSE bi.btLatinName END) END AS BillTypeName,
		CASE @Lang WHEN 0 THEN bi.brName ELSE (CASE ISNULL(bi.brLatinName, '') WHEN '' THEN bi.brName ELSE bi.brLatinName END) END AS BranchName,
		SUM((CASE bi.btIsInput WHEN 1 THEN -1 ELSE 1 END) * 
			((([biUnitPrice] - [biUnitDiscount] + [biUnitExtra]) * [biQty]) + [biTotalTaxValue]) * ISNULL(my.[FixedCurrencyFactor], 1)) AS ItemNetTotal,
		SUM((CASE bi.btIsInput WHEN 1 THEN -1 ELSE 1 END) * [bi].[biProfits] * ISNULL(my.[FixedCurrencyFactor], 1)) AS ItemProfit,
		SUM((CASE bi.btIsInput WHEN 1 THEN -1 ELSE 1 END) * (
			(((([biUnitPrice] - [biUnitDiscount] + [biUnitExtra]) * [biQty]) + [biTotalTaxValue]) - [bi].[biProfits])) * ISNULL(my.[FixedCurrencyFactor], 1)) AS ItemCostPrice,
		SUM(
			(CASE bi.btIsInput WHEN 1 THEN -1 ELSE 1 END) * 
			((bi.biQty + bi.biBonusQnt) / 
			(CASE @UseUnit 
				WHEN 1 THEN (CASE bi.mtUnit2Fact WHEN 0 THEN 1 ELSE bi.mtUnit2Fact END)
				WHEN 2 THEN (CASE bi.mtUnit3Fact WHEN 0 THEN 1 ELSE bi.mtUnit3Fact END)
				WHEN 3 THEN [bi].[mtDefUnitFact]
				ELSE 1			  
			END))) AS ItemQuantity
	FROM 
		vwExtended_bi_Analysis bi
		OUTER APPLY [dbo].[fnCurrency_Fix_Analysis](1, bi.[buCurrencyGUID], bi.[buCurrencyVal], @CurrencyGUID, bi.[buDate]) AS my
	WHERE 
		bi.btAffectProfit = 1 AND  bi.buIsPosted = 1 AND 
		((@StartDate IS NULL) OR (bi.buDate >= @StartDate)) AND 
		((@EndDate IS NULL) OR (bi.buDate <= @EndDate)) AND 
		((ISNULL(@GroupGUID, 0x0) = 0x0) OR EXISTS(SELECT 1 FROM @Groups WHERE [GroupGUID] = bi.mtGroup))
	GROUP BY 
		bi.buDate,
		CASE @Lang WHEN 0 THEN bi.mtName ELSE (CASE ISNULL(bi.mtLatinName, '') WHEN '' THEN bi.mtName ELSE bi.mtLatinName END) END,
		CASE @Lang WHEN 0 THEN bi.grName ELSE (CASE ISNULL(bi.grLatinName, '') WHEN '' THEN bi.grName ELSE bi.grLatinName END) END,
		CASE @Lang WHEN 0 THEN bi.btName ELSE (CASE ISNULL(bi.btLatinName, '') WHEN '' THEN bi.btName ELSE bi.btLatinName END) END,
		CASE @Lang WHEN 0 THEN bi.brName ELSE (CASE ISNULL(bi.brLatinName, '') WHEN '' THEN bi.brName ELSE bi.brLatinName END) END
##################################################################################
CREATE PROC repSalesAnalysis
	@StartDate DATE = NULL,
	@EndDate DATE = NULL,
	@UseUnit INT = 0,		-- 0: unit 1, 1: unit 2, 2: unit 3, 3: def unit
	@CurrencyGUID UNIQUEIDENTIFIER = 0x0,
	@GroupGUID UNIQUEIDENTIFIER = 0x0
AS 
	SET NOCOUNT ON 

	DECLARE @Lang INT 
	SET @Lang = [dbo].[fnConnections_GetLanguage]()

	DECLARE @Groups TABLE ([GroupGUID] [UNIQUEIDENTIFIER])	
	IF ISNULL(@CurrencyGUID, 0x0) = 0x0
		SET @CurrencyGUID = (SELECT TOP 1 GUID FROM my000 WHERE CurrencyVal = 1 ORDER BY Number)
	IF ISNULL(@GroupGUID, 0x0) != 0x0
		INSERT INTO @Groups([GroupGUID]) SELECT [GUID] FROM dbo.[fnGetGroupsOfGroup](@GroupGUID)
		 
	SELECT 
		bi.buDate AS BillDate,
		ISNULL(CASE @Lang WHEN 0 THEN cu.CustomerName ELSE (CASE ISNULL(cu.LatinName, '') WHEN '' THEN cu.CustomerName ELSE cu.LatinName END) END, '') AS CustomerName,
		CASE @Lang WHEN 0 THEN bi.mtName ELSE (CASE ISNULL(bi.mtLatinName, '') WHEN '' THEN bi.mtName ELSE bi.mtLatinName END) END AS MaterialName,
		CASE @Lang WHEN 0 THEN bi.grName ELSE (CASE ISNULL(bi.grLatinName, '') WHEN '' THEN bi.grName ELSE bi.grLatinName END) END AS GroupName,
		CASE @Lang WHEN 0 THEN bi.btName ELSE (CASE ISNULL(bi.btLatinName, '') WHEN '' THEN bi.btName ELSE bi.btLatinName END) END AS BillTypeName,
		CASE @Lang WHEN 0 THEN bi.brName ELSE (CASE ISNULL(bi.brLatinName, '') WHEN '' THEN bi.brName ELSE bi.brLatinName END) END AS BranchName,
		bi.buPayType AS PayType,
		SUM((CASE bi.[btIsInput] WHEN 1 THEN -1 ELSE 1 END) * 
			((([bi].[biUnitPrice] - [biUnitDiscount] + [biUnitExtra]) * [biQty]) + [biTotalTaxValue]) * ISNULL(my.[FixedCurrencyFactor], 1)) AS ItemNetTotal,         
		SUM(
			(CASE bi.btIsInput WHEN 1 THEN -1 ELSE 1 END) * 
			((bi.biQty + bi.biBonusQnt) /
			(CASE @UseUnit 
				WHEN 1 THEN (CASE bi.mtUnit2Fact WHEN 0 THEN 1 ELSE bi.mtUnit2Fact END)
				WHEN 2 THEN (CASE bi.mtUnit3Fact WHEN 0 THEN 1 ELSE bi.mtUnit3Fact END)
				WHEN 3 THEN [bi].[mtDefUnitFact]
				ELSE 1			  
			END))) AS ItemQuantity
	FROM 
		vwExtended_bi_Analysis bi
		LEFT JOIN cu000 cu ON cu.GUID = bi.buCustGUID		
		OUTER APPLY [dbo].[fnCurrency_Fix_Analysis](1, bi.[buCurrencyGUID], bi.[buCurrencyVal], @CurrencyGUID, bi.[buDate]) AS my
	WHERE 
		(bi.btType = 1 AND (bi.btBillType IN (1, 3)))
		AND 
		bi.buIsPosted = 1
		AND 
		((@StartDate IS NULL) OR (bi.buDate >= @StartDate))
		AND 
		((@EndDate IS NULL) OR (bi.buDate <= @EndDate))
		AND 
		((ISNULL(@GroupGUID, 0x0) = 0x0) OR EXISTS(SELECT 1 FROM @Groups WHERE [GroupGUID] = bi.mtGroup))
	GROUP BY 
		bi.buDate,
		ISNULL(CASE @Lang WHEN 0 THEN cu.CustomerName ELSE (CASE ISNULL(cu.LatinName, '') WHEN '' THEN cu.CustomerName ELSE cu.LatinName END) END, ''),
		CASE @Lang WHEN 0 THEN bi.mtName ELSE (CASE ISNULL(bi.mtLatinName, '') WHEN '' THEN bi.mtName ELSE bi.mtLatinName END) END,
		CASE @Lang WHEN 0 THEN bi.grName ELSE (CASE ISNULL(bi.grLatinName, '') WHEN '' THEN bi.grName ELSE bi.grLatinName END) END,
		CASE @Lang WHEN 0 THEN bi.btName ELSE (CASE ISNULL(bi.btLatinName, '') WHEN '' THEN bi.btName ELSE bi.btLatinName END) END,
		CASE @Lang WHEN 0 THEN bi.brName ELSE (CASE ISNULL(bi.brLatinName, '') WHEN '' THEN bi.brName ELSE bi.brLatinName END) END,
		bi.buPayType
##################################################################################
#END
