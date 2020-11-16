##################################################################################
CREATE PROC repGCCDetailedValueAddedTaxReturn
	@TaxDurationGUID	[UNIQUEIDENTIFIER],
	@TaxDetailRecId		[INT],
	@UserGUID			[UNIQUEIDENTIFIER] = 0x0 -- 0x0 for this DB
AS
	SET NOCOUNT ON 

	IF ISNULL(@UserGUID, 0x0) != 0x0
	BEGIN 
		EXEC prcConnections_Add @UserGUID
	END

	DECLARE @lang [INT] = [dbo].[fnConnections_GetLanguage]()
	DECLARE @DurationStartDate Date = (SELECT [dbo].[fnOption_get]('AmnCfg_FPDate', DEFAULT))
	DECLARE @DurationEndDate Date = (SELECT [dbo].[fnOption_get]('AmnCfg_EPDate', DEFAULT))
	IF @TaxDurationGuid <> 0x0 
	BEGIN 
		SET @DurationStartDate = (SELECT StartDate FROM GCCTaxDurations000 WHERE GUID  = @TaxDurationGuid )
		SET @DurationEndDate = (SELECT EndDate FROM GCCTaxDurations000 WHERE GUID  = @TaxDurationGuid )
	END 

	DECLARE @IsSudiaGCCCountry BIT 
	SET @IsSudiaGCCCountry = CASE dbo.fnOption_GetInt('AmnCfg_GCCTaxSystemCountry', '0') WHEN 1 THEN 1 ELSE 0 END

	CREATE TABLE #Result (
		buGuid				[UNIQUEIDENTIFIER],
		buDate				[DATETIME],
		buType				[UNIQUEIDENTIFIER],
		buFormatedNumber	[NVARCHAR](250),
		buNumber			[INT],
		ceGuid				[UNIQUEIDENTIFIER],
		ceParentGuid		[UNIQUEIDENTIFIER],
		enNotes				[NVARCHAR](1000)  DEFAULT '',
		cuGuid				[UNIQUEIDENTIFIER],
		biGuid				[UNIQUEIDENTIFIER],
		biNum				[INT],
		biQty				[FLOAT],
		biPrice				[FLOAT],
		biTotalPrice		[FLOAT],
		biDisc				[FLOAT],
		biExtra				[FLOAT],
		biNetPrice			[FLOAT],
		biTaxValue			[FLOAT],
		biAdjustment		[FLOAT],
		biIsAdjustment		[BIT],
		biCustomsRate		[FLOAT],
		billType			[INT],
		biTaxCode			[INT],
		buReturnedBillNum	[NVARCHAR](500),
		buReturnedBillDate	[DATETIME],
		OriginName			[NVARCHAR](1000),
		acGUID				[UNIQUEIDENTIFIER],
		ValueDif			FLOAT,
		TaxDif				FLOAT,
		BiPurchaseVal		FLOAT)

	CREATE TABLE #TotalsResult (
		totalType			[INT],
		totalValue			[FLOAT],
		totalNetPrice		[FLOAT],
		totalAdjustment		[FLOAT],
		totalTax			[FLOAT],
		totalCustomsRate	[FLOAT])
	------------------------------ OUTPUT	RESULT ------------------------------------------
	IF @TaxDetailRecId < 11  -- SR Local Locations
	BEGIN
		DECLARE @LocationNum [INT] = @TaxDetailRecId - 1
		
		INSERT	INTO #Result ([buGuid], [buDate], [buType], [buFormatedNumber], buNumber, [ceGuid], [enNotes] ,[cuGuid], [biGuid], [biNum], [biQty], [biPrice], [biTotalPrice], [biDisc], 
							[biExtra], [biNetPrice], [biTaxValue], [biAdjustment], biIsAdjustment, biCustomsRate, [BillType], [buReturnedBillNum], [buReturnedBillDate], OriginName, acGUID) 
		SELECT	[vw].[BuGuid],
				[bu].[buDate],
				[vw].[BtGuid],
				CASE WHEN @lang <> 0 AND ISNULL([bu].[buLatinFormatedNumber], '') <> '' THEN [bu].[buLatinFormatedNumber] ELSE [bu].[buFormatedNumber] END,		
				[bu].[buNumber],
				[er].[erEntryGUID],
				[vw].[biNotes],
				[vw].[BuCustGUID],
				[vw].[BiGuid],
				[vw].[BiNumber],
				[vw].[BiBillQty],
				[vw].[BiPrice],
				[vw].[BiBillQty] * [vw].[BiPrice],
				[vw].[BiQty] * [vw].[BiUnitDiscount],
				[vw].[BiQty] * [vw].[BiUnitExtra],
				[vw].[BiNetPrice],
				CASE WHEN [vw].[BiTaxCode] = 1 THEN [vw].[BiVat] ELSE 0 END,
				CASE WHEN [vw].[BiTaxCode] = 6 THEN [vw].[BiVat] ELSE 0 END,
				CASE WHEN [vw].[BiTaxCode] = 6 THEN 1 ELSE 0 END,
				[vw].CustomsRate,
				[vw].[BillType],
				[bu].[ReturendBillNumber],
				[bu].[ReturendBillDate],
				vw.btLocalizedName,
				bu.buCustAcc
		  FROM	vwGCCBillItemInfo [vw] INNER JOIN vwER [er] ON [vw].[BuGuid] = [er].[erParentGUID]
				INNER JOIN vwBu [bu] ON [bu].[buGUID] = [vw].[BuGuid]
		 WHERE	(([vw].[BillType] = 1 AND [vw].[BiTaxCode] = 1) OR ([vw].[BillType] = 3 AND ([vw].[BiTaxCode] = 1 OR [vw].[BiTaxCode] = 6)))  
				AND [vw].[LocationNumber] = @LocationNum
				AND (CAST([vw].[BuDate] AS DATE) BETWEEN @DurationStartDate AND @DurationEndDate) 
				AND [vw].[BiReversChargeVal] = 0
				AND [vw].[EnType] <> 203 AND [vw].[EnType] <> 204 
		

		-- for PU with SR in bi tax code 
		DECLARE @MinLocationNumber INT 
		SET @MinLocationNumber = (SELECT TOP 1 Number FROM GCCCustLocations000 loc WHERE Classification = 0 AND 
			NOT EXISTS(SELECT GUID FROM GCCCustLocations000 WHERE ParentLocationGUID = loc.GUID) ORDER BY Number)
		
		IF @LocationNum = @MinLocationNumber
		BEGIN 
			INSERT	INTO #Result ([buGuid], [buDate], [buType], [buFormatedNumber], buNumber, [ceGuid], [enNotes] , [cuGuid], [biGuid], [biNum], [biQty], [biPrice], [biTotalPrice], [biDisc], 
								[biExtra], [biNetPrice], [biTaxValue], [biAdjustment], biIsAdjustment, biCustomsRate, [BillType], [buReturnedBillNum], [buReturnedBillDate], OriginName, acGUID) 
			SELECT	[vw].[BuGuid],
					[bu].[buDate],
					[vw].[BtGuid],
					CASE WHEN @lang <> 0 AND ISNULL([bu].[buLatinFormatedNumber], '') <> '' THEN [bu].[buLatinFormatedNumber] ELSE [bu].[buFormatedNumber] END,		
					[bu].[buNumber],
					[er].[erEntryGUID],
					[vw].[biNotes],
					[vw].[BuCustGUID],
					[vw].[BiGuid],
					[vw].[BiNumber],
					[vw].[BiBillQty],
					[vw].[BiPrice],
					[vw].[BiBillQty] * [vw].[BiPrice],
					[vw].[BiQty] * [vw].[BiUnitDiscount],
					[vw].[BiQty] * [vw].[BiUnitExtra],
					[vw].[BiNetPrice],
					CASE WHEN [vw].[BiTaxCode] = 1 THEN [vw].[BiVat] ELSE 0 END,
					CASE WHEN [vw].[BiTaxCode] = 6 THEN [vw].[BiVat] ELSE 0 END,
					CASE WHEN [vw].[BiTaxCode] = 6 THEN 1 ELSE 0 END,
					[vw].CustomsRate,
					[vw].[BillType],
					[bu].[ReturendBillNumber],
					[bu].[ReturendBillDate],
					vw.btLocalizedName,
					bu.buCustAcc
			  FROM	vwGCCBillItemInfo [vw] INNER JOIN vwER [er] ON [vw].[BuGuid] = [er].[erParentGUID]
					INNER JOIN vwBu [bu] ON [bu].[buGUID] = [vw].[BuGuid]
			 WHERE	(([vw].[BillType] = 1 AND [vw].[BiTaxCode] = 1) OR ([vw].[BillType] = 3 AND ([vw].[BiTaxCode] = 1 OR [vw].[BiTaxCode] = 6)))  
					AND [vw].[LocationClassification] = 3 -- PU
					AND (CAST([vw].[BuDate] AS DATE) BETWEEN @DurationStartDate AND @DurationEndDate) 
					AND [vw].[BiReversChargeVal] = 0
					AND [vw].[EnType] <> 203 AND [vw].[EnType] <> 204 
		END
	END
	ELSE IF @TaxDetailRecId = 11 -- «·”⁄ÊœÌ… «·„Ê«ÿ‰Ì‰
	BEGIN
		INSERT	INTO #Result ([buGuid], [buDate], [buType], [buFormatedNumber], buNumber, [ceGuid], [enNotes], [cuGuid], [biGuid], [biNum], [biQty], [biPrice], [biTotalPrice], [biDisc],
							[biExtra], [biNetPrice], [biTaxValue], [biAdjustment], biIsAdjustment, biCustomsRate, [BillType], [buReturnedBillNum], [buReturnedBillDate], OriginName, acGUID) 
		SELECT 	[bi].[BuGuid],
			[bi].[buDate],
			[bi].[buType],
			CASE WHEN @lang <> 0 AND ISNULL([bi].[buLatinFormatedNumber], '') <> '' THEN [bi].[buLatinFormatedNumber] ELSE [bi].[buFormatedNumber] END,
			[bi].[buNumber],
			[er].[erEntryGUID],
			[bi].[biNotes],
			[bi].[buCustPtr],
			[bi].[biGUID],
			[bi].[biNumber],
			[bi].[BiBillQty],
			[bi].[BiPrice],
			[bi].[BiBillQty] * [bi].[BiPrice],
			[bi].[BiQty] * [bi].[biUnitDiscount],
			[bi].[BiQty] * [bi].[biUnitExtra],
			[bi].[biQty] * ([bi].[biUnitPrice] - [bi].[biUnitDiscount] + [bi].[biUnitExtra]),
			CASE WHEN [bi].[BiTaxCode] = 12 THEN [bi].[BiVat] ELSE 0 END,
			CASE WHEN [bi].[BiTaxCode] = 6 THEN [bi].[BiVat] ELSE 0 END,
			CASE WHEN [bi].[BiTaxCode] = 6 THEN 1 ELSE 0 END,

			bi.biCustomsRate,
			[bi].[btBillType],
			[bi].[buReturendBillNumber],
			[bi].[buReturendBillDate],
			CASE @lang
				WHEN 0 THEN bi.btName 
				ELSE CASE bi.btLatinName WHEN '' THEN bi.btName ELSE bi.btLatinName END 
			END,
			[bi].[buCustAcc]
		FROM	vwExtended_bi [bi] 
			INNER JOIN vwEr [er] ON [er].[erParentGUID] = [bi].[buGUID]
			RIGHT JOIN GCCTaxCoding000 taxCode ON taxCode.TaxCode = bi.biTaxCode OR taxCode.TaxCode = bi.biOrginalTaxCode
		WHERE	([bi].[btBillType] = 1 OR [bi].[btBillType] = 3)
			AND [bi].[biReversChargeVal] = 0 
			AND [taxCode].[TaxCode] = 12
			AND (CAST([bi].[buDate] AS DATE) BETWEEN @DurationStartDate AND @DurationEndDate) 

		IF @IsSudiaGCCCountry = 0
		BEGIN 
			-- TR
			-- Entries
			INSERT	INTO #Result ([buDate], [buFormatedNumber], buNumber, [ceGuid], [ceParentGuid], [enNotes] , [cuGuid], [biNum], [biNetPrice], [biTaxValue], biIsAdjustment, 
				[BillType], [buReturnedBillNum], [buReturnedBillDate], OriginName, acGUID) 
			SELECT	[ce].[ceDate],
					CASE WHEN @lang <> 0 AND ISNULL([et].[etLatinAbbrev], '') <> '' THEN [et].[etLatinAbbrev] ELSE [et].[etAbbrev] END  + ': ' + CAST([py].[pyNumber] AS VARCHAR(250)),
					[py].[pyNumber],
					[ce].[ceGUID],
					[er].[erParentGUID],
					[en].[enNotes],
					[en].[enCustomerGUID],
					[en].[enNumber],
					ABS([en].[enDebit] - [en].[enCredit]) * 20 /*100 / 5*/,
					ABS([en].[enDebit] - [en].[enCredit]),
					0,
					CASE WHEN [en].[enDebit] > [en].[enCredit] THEN 1 ELSE 3 END,
					[en].[enGCCOriginNumber],
					[en].[enGCCOriginDate],
					CASE WHEN @lang <> 0 AND ISNULL([et].[etLatinName], '') <> '' THEN [et].[etLatinName] ELSE [et].[etName] END,
					en.enAccount
			  FROM	vwEn en 
					INNER JOIN vwCe [ce] ON [ce].[ceGUID] = [en].[enParent]
					INNER JOIN vwEr [er] ON [ce].[ceGUID] = [er].[erEntryGUID] 
					INNER JOIN vwPy [py] ON [py].[pyGUID] = [er].[erParentGUID] 
					INNER JOIN vwEt [et] ON [et].[etGUID] = [py].[pyTypeGUID] 
			 WHERE	[et].[etTaxType] <> 0
					AND CAST([en].[enDate] AS DATE) BETWEEN @DurationStartDate AND @DurationEndDate
					AND	[en].[enType] =  411 /*PY_TR*/
					AND (([en].[enGCCOriginDate] <= '1-1-2000') OR (CAST([en].[enGCCOriginDate] AS DATE) BETWEEN @DurationStartDate AND @DurationEndDate))

			-- Adjustments In Entries
			INSERT	INTO #Result ([buDate], [buFormatedNumber], buNumber, [ceGuid], [ceParentGuid], [enNotes] , [cuGuid], [biNum], [biNetPrice], [biTaxValue], biIsAdjustment, 
				[BillType], [buReturnedBillNum], [buReturnedBillDate], OriginName, acGUID) 
			SELECT	[ce].[ceDate],
					CASE WHEN @lang <> 0 AND ISNULL([et].[etLatinAbbrev], '') <> '' THEN [et].[etLatinAbbrev] ELSE [et].[etAbbrev] END  + ': ' + CAST([py].[pyNumber] AS VARCHAR(250)),
					[py].[pyNumber],
					[ce].[ceGUID],
					[er].[erParentGUID],
					[en].[enNotes],
					[en].[enCustomerGUID],
					[en].[enNumber],
					ABS([en].[enDebit] - [en].[enCredit]) * 20 /*100 / 5*/,
					ABS([en].[enDebit] - [en].[enCredit]),
					1,
					CASE WHEN [en].[enDebit] > [en].[enCredit] THEN 1 ELSE 3 END,
					[en].[enGCCOriginNumber],
					[en].[enGCCOriginDate],
					CASE WHEN @lang <> 0 AND ISNULL([et].[etLatinName], '') <> '' THEN [et].[etLatinName] ELSE [et].[etName] END,
					en.enAccount
			  FROM	vwEn en 
					INNER JOIN vwCe [ce] ON [ce].[ceGUID] = [en].[enParent]
					INNER JOIN vwEr [er] ON [ce].[ceGUID] = [er].[erEntryGUID] 
					INNER JOIN vwPy [py] ON [py].[pyGUID] = [er].[erParentGUID] 
					INNER JOIN vwEt [et] ON [et].[etGUID] = [py].[pyTypeGUID] 
			 WHERE	[et].[etTaxType] <> 0
					AND CAST([en].[enDate] AS DATE) BETWEEN @DurationStartDate AND @DurationEndDate
					AND	[en].[enType] =  411 /*PY_TR*/
					AND [en].[enGCCOriginDate] > '1-1-2000' 
					AND ((CAST([en].[enGCCOriginDate] AS DATE) < @DurationStartDate) OR (CAST([en].[enGCCOriginDate] AS DATE) > @DurationEndDate))
		END 
	END 
	ELSE IF @TaxDetailRecId = 12 -- Output_RC
	BEGIN
		INSERT INTO #Result ([buGuid], [buDate], [buType], [buFormatedNumber], buNumber, [ceGuid], [enNotes], [cuGuid], [biGuid], [biNum], [biQty], [biPrice], [biTotalPrice], [biDisc],
							 [biExtra], [biNetPrice], [biTaxValue], [biAdjustment], biIsAdjustment, biCustomsRate, [BillType], [buReturnedBillNum], [buReturnedBillDate], OriginName, acGUID, BiPurchaseVal) 
		SELECT 	[vw].[BuGuid],
				[bu].[buDate],
				[vw].[BtGuid],
				CASE WHEN @lang <> 0 AND ISNULL([bu].[buLatinFormatedNumber], '') <> '' THEN [bu].[buLatinFormatedNumber] ELSE [bu].[buFormatedNumber] END,
				[bu].[buNumber],
				[er].[erEntryGUID],
				[vw].[biNotes],
				[vw].[BuCustGUID],
				[vw].[BiGuid],
				[vw].[BiNumber],
				[vw].[BiBillQty],
				[vw].[BiPrice],
				[vw].[BiBillQty] * [vw].[BiPrice],
				[vw].[BiQty] * [vw].[BiUnitDiscount],
				[vw].[BiQty] * [vw].[BiUnitExtra],
				[vw].[BiNetPrice],
				CASE WHEN [vw].[BiTaxCode] <> 6 THEN [vw].[BiReversChargeVal] ELSE 0 END,
				CASE WHEN [vw].[BiTaxCode] = 6 THEN [vw].[BiReversChargeVal] ELSE 0 END,
				CASE WHEN [vw].[BiTaxCode] = 6 THEN 1 ELSE 0 END,
				vw.CustomsRate,
				[vw].[BillType],
				[bu].[ReturendBillNumber],
				[bu].[ReturendBillDate],
				vw.btLocalizedName,
				bu.buCustAcc,
				vw.BiPurchaseVal
		  FROM	vwGCCBillItemInfo vw INNER JOIN vwER [er] ON [vw].[BuGuid] = [er].[erParentGUID]
		  		INNER JOIN vwBu [bu] ON [bu].[buGUID] = [vw].[BuGuid]
		 WHERE	(vw.BillType IN (0, 1, 2, 3))
				AND [vw].[ImportViaCustoms] = 0
				AND vw.BiReversChargeVal <> 0
				AND (CAST(vw.BuDate AS DATE) BETWEEN @DurationStartDate AND @DurationEndDate)
				AND ([vw].[EnType] = 205 /*OR [vw].[EnType] = 207*/)

		-- Entries
		INSERT	INTO #Result ([buDate], [buFormatedNumber], buNumber, [ceGuid], [ceParentGuid], [enNotes] , [cuGuid], [biNum], [biNetPrice], [biTaxValue], biIsAdjustment, 
			[BillType], [buReturnedBillNum], [buReturnedBillDate], OriginName, acGUID) 
		SELECT	[ce].[ceDate],
				CASE WHEN @lang <> 0 AND ISNULL([et].[etLatinAbbrev], '') <> '' THEN [et].[etLatinAbbrev] ELSE [et].[etAbbrev] END  + ': ' + CAST([py].[pyNumber] AS VARCHAR(250)),
				[py].[pyNumber],
				[ce].[ceGUID],
				[er].[erParentGUID],
				[en].[enNotes],
				[en].[enCustomerGUID],
				[en].[enNumber],
				ABS([en].[enDebit] - [en].[enCredit]),
				ABS(([en].[enDebit] - [en].[enCredit]) * [en].[enAddedValue] / 100),
				0,
				CASE WHEN [en].[enDebit] > [en].[enCredit] THEN 0 ELSE 2 END,
				[en].[enGCCOriginNumber],
				[en].[enGCCOriginDate],
				CASE WHEN @lang <> 0 AND ISNULL([et].[etLatinName], '') <> '' THEN [et].[etLatinName] ELSE [et].[etName] END,
				en.enAccount
		  FROM	vwEn en 
				-- INNER JOIN vwEn [enVat] ON [en].[enGUID] = [enVat].[enParentVATGuid] 
				INNER JOIN vwCe [ce] ON [ce].[ceGUID] = [en].[enParent]
				INNER JOIN vwEr [er] ON [ce].[ceGUID] = [er].[erEntryGUID] 
				INNER JOIN vwPy [py] ON [py].[pyGUID] = [er].[erParentGUID] 
				INNER JOIN vwEt [et] ON [et].[etGUID] = [py].[pyTypeGUID] 
		 WHERE	[et].[etTaxType] != 0
				AND CAST([en].[enDate] AS DATE) BETWEEN @DurationStartDate AND @DurationEndDate
				AND	[en].[enType] = 402 /*PY_RC*/
				-- AND [enVat].[enType] = 202 /*VAT_RETURN*/
				AND ([en].[enDebit] > 0 OR (([en].[enGCCOriginDate] < '1-1-2000') OR (CAST([en].[enGCCOriginDate] AS DATE) BETWEEN @DurationStartDate AND @DurationEndDate)))
		
		-- Adjustments In Entries
		INSERT	INTO #Result ([buDate], [buFormatedNumber], buNumber, [ceGuid], [ceParentGuid], [enNotes] , [cuGuid], [biNum], [biNetPrice], [biTaxValue], biIsAdjustment, 
			[BillType], [buReturnedBillNum], [buReturnedBillDate], OriginName, acGUID)
		SELECT	[ce].[ceDate],
				CASE WHEN @lang <> 0 AND ISNULL([et].[etLatinAbbrev], '') <> '' THEN [et].[etLatinAbbrev] ELSE [et].[etAbbrev] END  + ': ' + CAST([py].[pyNumber] AS VARCHAR(250)),
				[py].[pyNumber],
				[ce].[ceGUID],
				[er].[erParentGUID],
				[en].[enNotes],
				[en].[enCustomerGUID],
				[en].[enNumber],
				ABS([en].[enDebit] - [en].[enCredit]),
				ABS(([en].[enDebit] - [en].[enCredit]) * [en].[enAddedValue] / 100),
				1,
				CASE WHEN [en].[enDebit] > [en].[enCredit] THEN 0 ELSE 2 END,
				[en].[enGCCOriginNumber],
				[en].[enGCCOriginDate],
				CASE WHEN @lang <> 0 AND ISNULL([et].[etLatinName], '') <> '' THEN [et].[etLatinName] ELSE [et].[etName] END,
				en.enAccount
		  FROM	vwEn en 
				-- INNER JOIN vwEn [enVat] ON [en].[enGUID] = [enVat].[enParentVATGuid] 
				INNER JOIN vwCe [ce] ON [ce].[ceGUID] = [en].[enParent]
				INNER JOIN vwEr [er] ON [ce].[ceGUID] = [er].[erEntryGUID] 
				INNER JOIN vwPy [py] ON [py].[pyGUID] = [er].[erParentGUID] 
				INNER JOIN vwEt [et] ON [et].[etGUID] = [py].[pyTypeGUID] 
		 WHERE	[et].[etTaxType] != 0
				AND CAST([en].[enDate] AS DATE) BETWEEN @DurationStartDate AND @DurationEndDate
				AND	[en].[enType] = 402 /*PY_RC*/
				-- AND	[enVat].[enType] = 202 /*VAT_RETURN*/
				AND [en].[enCredit] > 0 
				AND [en].[enGCCOriginDate] > '1-1-2000' 
				AND ((CAST([en].[enGCCOriginDate] AS DATE) < @DurationStartDate) OR (CAST([en].[enGCCOriginDate] AS DATE) > @DurationEndDate))
	END 
	ELSE IF @TaxDetailRecId = 13 -- Output_ZR
	BEGIN
		INSERT	INTO #Result ([buGuid], [buDate], [buType], [buFormatedNumber], buNumber, [ceGuid], [enNotes], [cuGuid], [biGuid], [biNum], [biQty], [biPrice], [biTotalPrice], [biDisc],
							 [biExtra], [biNetPrice], [biTaxValue], [biAdjustment], biIsAdjustment, biCustomsRate, [BillType], [buReturnedBillNum], [buReturnedBillDate], OriginName, acGUID) 
		SELECT 	[bi].[BuGuid],
				[bi].[buDate],
				[bi].[buType],
				CASE WHEN @lang <> 0 AND ISNULL([bi].[buLatinFormatedNumber], '') <> '' THEN [bi].[buLatinFormatedNumber] ELSE [bi].[buFormatedNumber] END,
				bi.buNumber,
				[er].[erEntryGUID],
				[bi].[biNotes],
				[bi].[buCustPtr],
				[bi].[biGUID],
				[bi].[biNumber],
				[bi].[BiBillQty],
				[bi].[BiPrice],
				[bi].[BiBillQty] * [bi].[BiPrice],
				[bi].[BiQty] * [bi].[biUnitDiscount],
				[bi].[BiQty] * [bi].[biUnitExtra],
				[bi].[biQty] * ([bi].[biUnitPrice] - [bi].[biUnitDiscount] + [bi].[biUnitExtra]),
				CASE WHEN [bi].[BiTaxCode] <> 6 THEN [bi].[BiVat] ELSE 0 END,
				CASE WHEN [bi].[BiTaxCode] = 6 THEN [bi].[BiVat] ELSE 0 END,
				CASE WHEN [bi].[BiTaxCode] = 6 THEN 1 ELSE 0 END,
				bi.biCustomsRate,
				[bi].[btBillType],
				[bi].[buReturendBillNumber],
				[bi].[buReturendBillDate],
				CASE @lang
					WHEN 0 THEN bi.btName 
					ELSE CASE bi.btLatinName WHEN '' THEN bi.btName ELSE bi.btLatinName END 
				END,
				bi.buCustAcc
		  FROM	vwExtended_bi [bi] INNER JOIN vwEr [er] ON [er].[erParentGUID] = [bi].[buGUID]
				RIGHT JOIN GCCTaxCoding000 taxCode ON taxCode.TaxCode = bi.biTaxCode OR taxCode.TaxCode = bi.biOrginalTaxCode
		 WHERE	([bi].[btBillType] = 1 OR [bi].[btBillType] = 3)
				AND [bi].[biReversChargeVal] = 0 
				AND [taxCode].[TaxCode] = 3 	
				AND (CAST([bi].[buDate] AS DATE) BETWEEN @DurationStartDate AND @DurationEndDate) 
	END 
	ELSE IF @TaxDetailRecId = 14 -- Output_EX
	BEGIN
		INSERT	INTO #Result ([buGuid], [buDate], [buType], [buFormatedNumber], buNumber, [ceGuid], [enNotes], [cuGuid], [biGuid], [biNum], [biQty], [biPrice], [biTotalPrice], [biDisc],
							 [biExtra], [biNetPrice], [biTaxValue], [biAdjustment], biIsAdjustment, biCustomsRate, [BillType], [buReturnedBillNum], [buReturnedBillDate], OriginName, acGUID) 
		SELECT 	[bi].[BuGuid],
				[bi].[buDate],
				[bi].[buType],
				CASE WHEN @lang <> 0 AND ISNULL([bi].[buLatinFormatedNumber], '') <> '' THEN [bi].[buLatinFormatedNumber] ELSE [bi].[buFormatedNumber] END,
				bi.buNumber,
				[er].[erEntryGUID],
				[bi].[biNotes],
				[bi].[buCustPtr],
				[bi].[biGUID],
				[bi].[biNumber],
				[bi].[BiBillQty],
				[bi].[BiPrice],
				[bi].[BiBillQty] * [bi].[BiPrice],
				[bi].[BiQty] * [bi].[biUnitDiscount],
				[bi].[BiQty] * [bi].[biUnitExtra],
				[bi].[biQty] * ([bi].[biUnitPrice] - [bi].[biUnitDiscount] + [bi].[biUnitExtra]),
				CASE WHEN [bi].[BiTaxCode] <> 6 THEN [bi].[BiVat] ELSE 0 END,
				CASE WHEN [bi].[BiTaxCode] = 6 THEN [bi].[BiVat] ELSE 0 END,
				CASE WHEN [bi].[BiTaxCode] = 6 THEN 1 ELSE 0 END,
				bi.biCustomsRate,
				[bi].[btBillType],
				[bi].[buReturendBillNumber],
				[bi].[buReturendBillDate],
				CASE @lang
					WHEN 0 THEN bi.btName 
					ELSE CASE bi.btLatinName WHEN '' THEN bi.btName ELSE bi.btLatinName END 
				END,
				bi.buCustAcc
		  FROM	vwExtended_bi bi INNER JOIN vwEr [er] ON [er].[erParentGUID] = [bi].[buGUID]
				RIGHT JOIN GCCTaxCoding000 taxCode ON [taxCode].[TaxCode] = [bi].[biTaxCode] OR taxCode.TaxCode = bi.biOrginalTaxCode
		 WHERE	([bi].[btBillType] = 1 OR [bi].[btBillType] = 3)
				AND [bi].[BiReversChargeVal] = 0
				AND (CAST([bi].[buDate] AS DATE) BETWEEN @DurationStartDate AND @DurationEndDate) 
				AND [taxCode].[TaxCode] = 4
	END 
	ELSE IF @TaxDetailRecId = 15 -- Output_IG
	BEGIN
		IF @IsSudiaGCCCountry = 0
		BEGIN 
			INSERT	INTO #Result ([buGuid], [buDate], [buType], [buFormatedNumber], buNumber, [ceGuid], [enNotes], [cuGuid], [biGuid], [biNum], [biQty], [biPrice], [biTotalPrice], [biDisc],
								 [biExtra], [biNetPrice], [biTaxValue], [biAdjustment], biIsAdjustment, biCustomsRate, [BillType], [buReturnedBillNum], [buReturnedBillDate], OriginName, acGUID) 
			SELECT 	[vw].[BuGuid],
					[bu].[buDate],
					[vw].[BtGuid],
					CASE WHEN @lang <> 0 AND ISNULL([bu].[buLatinFormatedNumber], '') <> '' THEN [bu].[buLatinFormatedNumber] ELSE [bu].[buFormatedNumber] END,
					bu.buNumber,
					[er].[erEntryGUID],
					[vw].[biNotes],
					[vw].[BuCustGUID],
					[vw].[BiGuid],
					[vw].[BiNumber],
					[vw].[BiBillQty],
					[vw].[BiPrice],
					[vw].[BiBillQty] * [vw].[BiPrice],
					[vw].[BiQty] * [vw].[BiUnitDiscount],
					[vw].[BiQty] * [vw].[BiUnitExtra],
					[vw].[BiNetPrice],
					CASE WHEN [vw].[BiTaxCode] <> 6 THEN [vw].[BiVat] ELSE 0 END,
					CASE WHEN [vw].[BiTaxCode] = 6 THEN [vw].[BiVat] ELSE 0 END,
					CASE WHEN [vw].[BiTaxCode] = 6 THEN 1 ELSE 0 END,
					vw.CustomsRate,
					[vw].[BillType],
					[bu].[ReturendBillNumber],
					[bu].[ReturendBillDate],
					vw.btLocalizedName,
					bu.buCustAcc
			  FROM	vwGCCBillItemInfo vw INNER JOIN vwER [er] ON [vw].[BuGuid] = [er].[erParentGUID]
					INNER JOIN vwBu [bu] ON [bu].[buGUID] = [vw].[BuGuid]
			 WHERE	(vw.BillType = 1 OR vw.BillType = 3)
					AND vw.BiReversChargeVal = 0
					AND vw.EnType <> 203 AND vw.EnType <> 204
					AND (CAST(vw.BuDate AS DATE) BETWEEN @DurationStartDate AND @DurationEndDate) 
					AND [vw].[BiTaxCode] = 5
		END ELSE BEGIN 
			INSERT	INTO #Result ([buGuid], [buDate], [buType], [buFormatedNumber], buNumber, [ceGuid], [enNotes], [cuGuid], [biGuid], [biNum], [biQty], [biPrice], [biTotalPrice], [biDisc],
								 [biExtra], [biNetPrice], [biTaxValue], [biAdjustment], biIsAdjustment, biCustomsRate, [BillType], [buReturnedBillNum], [buReturnedBillDate], OriginName, acGUID) 
			SELECT 	[bi].[BuGuid],
					[bi].[buDate],
					[bi].[buType],
					CASE WHEN @lang <> 0 AND ISNULL([bi].[buLatinFormatedNumber], '') <> '' THEN [bi].[buLatinFormatedNumber] ELSE [bi].[buFormatedNumber] END,
					bi.buNumber,
					[er].[erEntryGUID],
					[bi].[biNotes],
					[bi].[buCustPtr],
					[bi].[biGUID],
					[bi].[biNumber],
					[bi].[BiBillQty],
					[bi].[BiPrice],
					[bi].[BiBillQty] * [bi].[BiPrice],
					[bi].[BiQty] * [bi].[biUnitDiscount],
					[bi].[BiQty] * [bi].[biUnitExtra],
					[bi].[biQty] * ([bi].[biUnitPrice] - [bi].[biUnitDiscount] + [bi].[biUnitExtra]),
					CASE WHEN [bi].[BiTaxCode] <> 6 THEN [bi].[BiVat] ELSE 0 END,
					CASE WHEN [bi].[BiTaxCode] = 6 THEN [bi].[BiVat] ELSE 0 END,
					CASE WHEN [bi].[BiTaxCode] = 6 THEN 1 ELSE 0 END,
					bi.biCustomsRate,
					[bi].[btBillType],
					[bi].[buReturendBillNumber],
					[bi].[buReturendBillDate],
					CASE @lang
						WHEN 0 THEN bi.btName 
						ELSE CASE bi.btLatinName WHEN '' THEN bi.btName ELSE bi.btLatinName END 
					END,
					bi.buCustAcc
			  FROM	vwExtended_bi [bi] INNER JOIN vwEr [er] ON [er].[erParentGUID] = [bi].[buGUID]
					RIGHT JOIN GCCTaxCoding000 taxCode ON taxCode.TaxCode = bi.biTaxCode OR taxCode.TaxCode = bi.biOrginalTaxCode
			 WHERE	([bi].[btBillType] = 1 OR [bi].[btBillType] = 3)
					AND [bi].[biReversChargeVal] = 0 
					AND [taxCode].[TaxCode] = 13
					AND (CAST([bi].[buDate] AS DATE) BETWEEN @DurationStartDate AND @DurationEndDate) 
		END
	END
	ELSE IF @TaxDetailRecId = 16 -- Output_RC_Customs
	BEGIN
		INSERT INTO #Result ([buGuid], [buDate], [buType], [buFormatedNumber], buNumber, [ceGuid], [enNotes], [cuGuid], [biGuid], [biNum], [biQty], [biPrice], [biTotalPrice], [biDisc],
							 [biExtra], [biNetPrice], [biTaxValue], [biAdjustment], biIsAdjustment, biCustomsRate, [BillType], [buReturnedBillNum], [buReturnedBillDate], OriginName, acGUID) 
		SELECT 	[vw].[BuGuid],
				[bu].[buDate],
				[vw].[BtGuid],
				CASE WHEN @lang <> 0 AND ISNULL([bu].[buLatinFormatedNumber], '') <> '' THEN [bu].[buLatinFormatedNumber] ELSE [bu].[buFormatedNumber] END,
				[bu].[buNumber],
				[er].[erEntryGUID],
				[vw].[biNotes],
				[vw].[BuCustGUID],
				[vw].[BiGuid],
				[vw].[BiNumber],
				[vw].[BiBillQty],
				[vw].[BiPrice],
				[vw].[BiBillQty] * [vw].[BiPrice],
				[vw].[BiQty] * [vw].[BiUnitDiscount],
				[vw].[BiQty] * [vw].[BiUnitExtra],
				[vw].[BiNetPrice],
				CASE WHEN [vw].[BiTaxCode] <> 6 THEN [vw].[BiReversChargeVal] ELSE 0 END,
				CASE WHEN [vw].[BiTaxCode] = 6 THEN [vw].[BiReversChargeVal] ELSE 0 END,
				CASE WHEN [vw].[BiTaxCode] = 6 THEN 1 ELSE 0 END,
				vw.CustomsRate,
				[vw].[BillType],
				[bu].[ReturendBillNumber],
				[bu].[ReturendBillDate],
				vw.btLocalizedName,
				bu.buCustAcc
		  FROM	vwGCCBillItemInfo vw INNER JOIN vwER [er] ON [vw].[BuGuid] = [er].[erParentGUID]
		  		INNER JOIN vwBu [bu] ON [bu].[buGUID] = [vw].[BuGuid]
		 WHERE	(vw.BillType IN (0, 1, 2, 3))
				AND [vw].[ImportViaCustoms] != 0
				AND vw.BiReversChargeVal <> 0
				AND (CAST(vw.BuDate AS DATE) BETWEEN @DurationStartDate AND @DurationEndDate)
				AND ([vw].[EnType] = 207 /*OR [vw].[EnType] = 207*/)
	END
	ELSE IF @TaxDetailRecId = 17 -- Output_RC_Customs_Adjust
	BEGIN
		INSERT INTO #Result ([buGuid], [buDate], [buType], [buFormatedNumber], buNumber, [ceGuid], [enNotes], [cuGuid], [biGuid], [biNum], [biQty], [biPrice], [biTotalPrice], [biDisc],
			[biExtra], [biNetPrice], [biTaxValue], [biAdjustment], biIsAdjustment, biCustomsRate, [BillType], [buReturnedBillNum], [buReturnedBillDate], OriginName, acGUID, ValueDif, TaxDif)
		SELECT 	[vw].[BuGuid],
				[bu].[buDate],
				[vw].[BtGuid],
				CASE WHEN @lang <> 0 AND ISNULL([bu].[buLatinFormatedNumber], '') <> '' THEN [bu].[buLatinFormatedNumber] ELSE [bu].[buFormatedNumber] END,
				[bu].[buNumber],
				[er].[erEntryGUID],
				[vw].[biNotes],
				[vw].[BuCustGUID],
				[vw].[BiGuid],
				[vw].[BiNumber],
				[vw].[BiBillQty],
				[vw].[BiPrice],
				[vw].[BiBillQty] * [vw].[BiPrice],
				[vw].[BiQty] * [vw].[BiUnitDiscount],
				[vw].[BiQty] * [vw].[BiUnitExtra],
				[vw].[BiNetPrice],
				CASE WHEN [vw].[BiTaxCode] <> 6 THEN [vw].[BiReversChargeVal] ELSE 0 END,
				CASE WHEN [vw].[BiTaxCode] = 6 THEN [vw].[BiReversChargeVal] ELSE 0 END,
				CASE WHEN [vw].[BiTaxCode] = 6 THEN 1 ELSE 0 END,
				vw.CustomsRate,
				[vw].[BillType],
				[bu].[ReturendBillNumber],
				[bu].[ReturendBillDate],
				vw.btLocalizedName,
				bu.buCustAcc,
				[vw].[BiNetPrice] - vw.CustomsRate,
				CASE [vw].[BiReversChargeVal] WHEN 0 THEN 0 ELSE [vw].[BiNetPrice] * 0.05 END - [vw].[BiReversChargeVal] 
		  FROM	vwGCCBillItemInfo vw INNER JOIN vwER [er] ON [vw].[BuGuid] = [er].[erParentGUID]
		  		INNER JOIN vwBu [bu] ON [bu].[buGUID] = [vw].[BuGuid]
		 WHERE	(vw.BillType IN (0, 1, 2, 3))
				AND [vw].[ImportViaCustoms] != 0
				AND vw.BiReversChargeVal <> 0
				AND (CAST(vw.BuDate AS DATE) BETWEEN @DurationStartDate AND @DurationEndDate)
				AND ([vw].[EnType] = 207 /*OR [vw].[EnType] = 207*/)
	END

	------------------------------ INPUT	RESULT ------------------------------------------
	ELSE IF @TaxDetailRecId = 200 -- Input SR 
	BEGIN
		INSERT	INTO #Result ([buGuid], [buDate], [buType], [buFormatedNumber], buNumber, [ceGuid], [enNotes], [cuGuid], [biGuid], [biNum], [biQty], [biPrice], [biTotalPrice], [biDisc],
							 [biExtra], [biNetPrice], [biTaxValue], [biAdjustment], biIsAdjustment, biCustomsRate, [BillType], [buReturnedBillNum], [buReturnedBillDate], OriginName, acGUID) 
		SELECT	[vw].[BuGuid],
				[bu].[buDate],
				[vw].[BtGuid],
				CASE WHEN @lang <> 0 AND ISNULL([bu].[buLatinFormatedNumber], '') <> '' THEN [bu].[buLatinFormatedNumber] ELSE [bu].[buFormatedNumber] END,
				bu.buNumber,
				[er].[erEntryGUID],
				[vw].[biNotes],
				[vw].[BuCustGUID],
				[vw].[BiGuid],
				[vw].[BiNumber],
				[vw].[BiBillQty],
				[vw].[BiPrice],
				[vw].[BiBillQty] * [vw].[BiPrice],
				[vw].[BiQty] * [vw].[BiUnitDiscount],
				[vw].[BiQty] * [vw].[BiUnitExtra],
				[vw].[BiNetPrice],
				CASE WHEN [vw].[BiTaxCode] = 1 THEN [vw].[BiVat] ELSE 0 END,
				CASE WHEN [vw].[BiTaxCode] = 6 THEN [vw].[BiVat] ELSE 0 END,
				CASE WHEN [vw].[BiTaxCode] = 6 THEN 1 ELSE 0 END,
				vw.CustomsRate,
				[vw].[BillType],
				[bu].[ReturendBillNumber],
				[bu].[ReturendBillDate],
				vw.btLocalizedName,
				bu.buCustAcc
		  FROM 	vwGCCBillItemInfo [vw] INNER JOIN vwER [er] ON [vw].[BuGuid] = [er].[erParentGUID]
				INNER JOIN vwBu [bu] ON [bu].[buGUID] = [vw].[BuGuid]
		 WHERE	(([vw].[BillType] = 0 AND [vw].[BiTaxCode] = 1) OR ([vw].[BillType] = 2 AND ([vw].[BiTaxCode] = 1 OR [vw].[BiTaxCode] = 6))) 
				AND vw.BiReversChargeVal = 0
				AND vw.EnType <> 203 AND vw.EnType <> 204
				AND (CAST(vw.BuDate AS DATE) BETWEEN @DurationStartDate AND @DurationEndDate) 
		
		-- Entries
		INSERT	INTO #Result ([buDate], [buFormatedNumber], buNumber, [ceGuid], [ceParentGuid], [enNotes] , [cuGuid], [biNum], [biNetPrice], [biTaxValue], biIsAdjustment, 
			[BillType], [buReturnedBillNum], [buReturnedBillDate], OriginName, acGUID) 
		SELECT	[ce].[ceDate],
				CASE WHEN @lang <> 0 AND ISNULL([et].[etLatinAbbrev], '') <> '' THEN [et].[etLatinAbbrev] ELSE [et].[etAbbrev] END  + ': ' + CAST([py].[pyNumber] AS VARCHAR(250)),
				[py].[pyNumber],
				[ce].[ceGUID],
				[er].[erParentGUID],
				[en].[enNotes],
				[en].[enCustomerGUID],
				[en].[enNumber],
				ABS([en].[enDebit] - [en].[enCredit]),
				ABS([enVat].[enDebit] - [enVat].[enCredit]),
				0,
				CASE WHEN [en].[enDebit] > [en].[enCredit] THEN 0 ELSE 2 END,
				[en].[enGCCOriginNumber],
				[en].[enGCCOriginDate],
				CASE WHEN @lang <> 0 AND ISNULL([et].[etLatinName], '') <> '' THEN [et].[etLatinName] ELSE [et].[etName] END,
				en.enAccount
		  FROM	vwEn en INNER JOIN vwEn [enVat] ON [en].[enGUID] = [enVat].[enParentVATGuid] 
				INNER JOIN vwCe [ce] ON [ce].[ceGUID] = [en].[enParent]
				INNER JOIN vwEr [er] ON [ce].[ceGUID] = [er].[erEntryGUID] 
				INNER JOIN vwPy [py] ON [py].[pyGUID] = [er].[erParentGUID] 
				INNER JOIN vwEt [et] ON [et].[etGUID] = [py].[pyTypeGUID] 
		 WHERE	[et].[etTaxType] != 0
				AND CAST([en].[enDate] AS DATE) BETWEEN @DurationStartDate AND @DurationEndDate
				AND	[en].[enType] = 401 /*PY_SR*/
				AND	[enVat].[enType] = 202 /*VAT_RETURN*/
				AND ([en].[enDebit] > 0 OR (([en].[enGCCOriginDate] < '1-1-2000') OR (CAST([en].[enGCCOriginDate] AS DATE) BETWEEN @DurationStartDate AND @DurationEndDate)))
		
		-- Adjustments In Entries
		INSERT	INTO #Result ([buDate], [buFormatedNumber], buNumber, [ceGuid], [ceParentGuid], [enNotes] , [cuGuid], [biNum], [biNetPrice], [biTaxValue], biIsAdjustment, 
			[BillType], [buReturnedBillNum], [buReturnedBillDate], OriginName, acGUID)
		SELECT	[ce].[ceDate],
				CASE WHEN @lang <> 0 AND ISNULL([et].[etLatinAbbrev], '') <> '' THEN [et].[etLatinAbbrev] ELSE [et].[etAbbrev] END  + ': ' + CAST([py].[pyNumber] AS VARCHAR(250)),
				[py].[pyNumber],
				[ce].[ceGUID],
				[er].[erParentGUID],
				[en].[enNotes],
				[en].[enCustomerGUID],
				[en].[enNumber],
				ABS([en].[enDebit] - [en].[enCredit]),
				ABS([enVat].[enDebit] - [enVat].[enCredit]),
				1,
				CASE WHEN [en].[enDebit] > [en].[enCredit] THEN 0 ELSE 2 END,
				[en].[enGCCOriginNumber],
				[en].[enGCCOriginDate],
				CASE WHEN @lang <> 0 AND ISNULL([et].[etLatinName], '') <> '' THEN [et].[etLatinName] ELSE [et].[etName] END,
				en.enAccount
		  FROM	vwEn en INNER JOIN vwEn [enVat] ON [en].[enGUID] = [enVat].[enParentVATGuid] 
				INNER JOIN vwCe [ce] ON [ce].[ceGUID] = [en].[enParent]
				INNER JOIN vwEr [er] ON [ce].[ceGUID] = [er].[erEntryGUID] 
				INNER JOIN vwPy [py] ON [py].[pyGUID] = [er].[erParentGUID] 
				INNER JOIN vwEt [et] ON [et].[etGUID] = [py].[pyTypeGUID] 
		 WHERE	[et].[etTaxType] != 0
				AND CAST([en].[enDate] AS DATE) BETWEEN @DurationStartDate AND @DurationEndDate
				AND	[en].[enType] = 401 /*PY_SR*/
				AND	[enVat].[enType] = 202 /*VAT_RETURN*/
				AND [en].[enCredit] > 0 
				AND [en].[enGCCOriginDate] > '1-1-2000' 
				AND ((CAST([en].[enGCCOriginDate] AS DATE) < @DurationStartDate) OR (CAST([en].[enGCCOriginDate] AS DATE) > @DurationEndDate))

	END
	ELSE IF @TaxDetailRecId = 201 -- Input GoodsImportedIntoTheUAE
	BEGIN
		INSERT	INTO #Result ([buGuid], [buDate], [buType], [buFormatedNumber], buNumber, [ceGuid], [enNotes], [cuGuid], [biGuid], [biNum], [biQty], [biPrice], [biTotalPrice], [biDisc],
							 [biExtra], [biNetPrice], [biTaxValue], [biAdjustment], biIsAdjustment, biCustomsRate, [BillType], [buReturnedBillNum], [buReturnedBillDate], OriginName, acGUID) 
		SELECT	[vw].[BuGuid],
				[bu].[buDate],				
				[vw].[BtGuid],
				CASE WHEN @lang <> 0 AND ISNULL([bu].[buLatinFormatedNumber], '') <> '' THEN [bu].[buLatinFormatedNumber] ELSE [bu].[buFormatedNumber] END,
				[bu].[buNumber],
				[er].[erEntryGUID],
				[vw].[biNotes],
				[vw].[BuCustGUID],
				[vw].[BiGuid],
				[vw].[BiNumber],
				[vw].[BiBillQty],
				[vw].[BiPrice],
				[vw].[BiBillQty] * [vw].[BiPrice],
				[vw].[BiQty] * [vw].[BiUnitDiscount],
				[vw].[BiQty] * [vw].[BiUnitExtra],
				[vw].[BiNetPrice],
				CASE WHEN [vw].[BiTaxCode] <> 6 THEN [vw].[BiReversChargeVal] ELSE 0 END,
				CASE WHEN [vw].[BiTaxCode] = 6 THEN [vw].[BiReversChargeVal] ELSE 0 END,
				CASE WHEN [vw].[BiTaxCode] = 6 THEN 1 ELSE 0 END,				
				vw.CustomsRate,
				[vw].[BillType],
				[bu].[ReturendBillNumber],
				[bu].[ReturendBillDate],
				vw.btLocalizedName,
				bu.buCustAcc
		  FROM 	vwGCCBillItemInfo [vw] INNER JOIN vwER [er] ON [vw].[BuGuid] = [er].[erParentGUID]
				INNER JOIN vwBu [bu] ON [bu].[buGUID] = [vw].[BuGuid]
		 WHERE	([vw].[BillType] IN (0, 1, 2, 3))
				AND [vw].[BiReversChargeVal] <> 0
				AND (CAST([vw].[BuDate] AS DATE) BETWEEN @DurationStartDate AND @DurationEndDate) 
				AND [vw].[ImportViaCustoms] = 1
				AND [vw].[EnType] = 208
	END
	ELSE IF @TaxDetailRecId = 202 --Input_RC
	BEGIN
		INSERT	INTO #Result ([buGuid], [buDate], [buType], [buFormatedNumber], buNumber, [ceGuid], [enNotes], [cuGuid], [biGuid], [biNum], [biQty], [biPrice], [biTotalPrice], [biDisc],
							 [biExtra], [biNetPrice], [biTaxValue], [biAdjustment], biIsAdjustment, biCustomsRate, [BillType], [buReturnedBillNum], [buReturnedBillDate], OriginName, acGUID, BiPurchaseVal) 
		SELECT	[vw].[BuGuid],
				[bu].[buDate],
				[vw].[BtGuid],
				CASE WHEN @lang <> 0 AND ISNULL([bu].[buLatinFormatedNumber], '') <> '' THEN [bu].[buLatinFormatedNumber] ELSE [bu].[buFormatedNumber] END,
				[bu].[buNumber],
				[er].[erEntryGUID],
				[vw].[biNotes],
				[vw].[BuCustGUID],
				[vw].[BiGuid],
				[vw].[BiNumber],
				[vw].[BiBillQty],
				[vw].[BiPrice],
				[vw].[BiBillQty] * [vw].[BiPrice],
				[vw].[BiQty] * [vw].[BiUnitDiscount],
				[vw].[BiQty] * [vw].[BiUnitExtra],
				[vw].[BiNetPrice],
				CASE WHEN [vw].[BiTaxCode] <> 6 THEN [vw].[BiReversChargeVal] ELSE 0 END,
				CASE WHEN [vw].[BiTaxCode] = 6 THEN [vw].[BiReversChargeVal] ELSE 0 END,
				CASE WHEN [vw].[BiTaxCode] = 6 THEN 1 ELSE 0 END,				
				vw.CustomsRate,
				[vw].[BillType],
				[bu].[ReturendBillNumber],
				[bu].[ReturendBillDate],
				vw.btLocalizedName,
				bu.buCustAcc,
				vw.BiPurchaseVal
		  FROM 	vwGCCBillItemInfo [vw] INNER JOIN vwER [er] ON [vw].[BuGuid] = [er].[erParentGUID]
				INNER JOIN vwBu [bu] ON [bu].[buGUID] = [vw].[BuGuid]
		 WHERE	([vw].[BillType] IN (0, 1, 2, 3))
				AND ([vw].[BiReversChargeVal] <> 0)
				AND (CAST([vw].[BuDate] AS DATE) BETWEEN @DurationStartDate AND @DurationEndDate) 
				AND ((@IsSudiaGCCCountry != 0 AND [vw].[ImportViaCustoms] = 0) OR (@IsSudiaGCCCountry = 0)) 
				AND ([vw].[EnType] = 206 OR [vw].[EnType] = 208)

		-- Entries
		INSERT	INTO #Result ([buDate], [buFormatedNumber], buNumber, [ceGuid], [ceParentGuid], [enNotes] , [cuGuid], [biNum], [biNetPrice], [biTaxValue], biIsAdjustment, 
			[BillType], [buReturnedBillNum], [buReturnedBillDate], OriginName, acGUID) 
		SELECT	[ce].[ceDate],
				CASE WHEN @lang <> 0 AND ISNULL([et].[etLatinAbbrev], '') <> '' THEN [et].[etLatinAbbrev] ELSE [et].[etAbbrev] END  + ': ' + CAST([py].[pyNumber] AS VARCHAR(250)),
				[py].[pyNumber],
				[ce].[ceGUID],
				[er].[erParentGUID],
				[en].[enNotes],
				[en].[enCustomerGUID],
				[en].[enNumber],
				ABS([en].[enDebit] - [en].[enCredit]),
				ABS(([en].[enDebit] - [en].[enCredit]) * [en].[enAddedValue] / 100),
				0,
				CASE WHEN [en].[enDebit] > [en].[enCredit] THEN 0 ELSE 2 END,
				[en].[enGCCOriginNumber],
				[en].[enGCCOriginDate],
				CASE WHEN @lang <> 0 AND ISNULL([et].[etLatinName], '') <> '' THEN [et].[etLatinName] ELSE [et].[etName] END,
				en.enAccount
		  FROM	vwEn en 
				-- INNER JOIN vwEn [enVat] ON [en].[enGUID] = [enVat].[enParentVATGuid] 
				INNER JOIN vwCe [ce] ON [ce].[ceGUID] = [en].[enParent]
				INNER JOIN vwEr [er] ON [ce].[ceGUID] = [er].[erEntryGUID] 
				INNER JOIN vwPy [py] ON [py].[pyGUID] = [er].[erParentGUID] 
				INNER JOIN vwEt [et] ON [et].[etGUID] = [py].[pyTypeGUID] 
		 WHERE	[et].[etTaxType] != 0
				AND CAST([en].[enDate] AS DATE) BETWEEN @DurationStartDate AND @DurationEndDate
				AND	[en].[enType] = 402 /*PY_RC*/
				-- AND [enVat].[enType] = 202 /*VAT_RETURN*/
				AND ([en].[enDebit] > 0 OR (([en].[enGCCOriginDate] < '1-1-2000') OR (CAST([en].[enGCCOriginDate] AS DATE) BETWEEN @DurationStartDate AND @DurationEndDate)))
		
		-- Adjustments In Entries
		INSERT	INTO #Result ([buDate], [buFormatedNumber], buNumber, [ceGuid], [ceParentGuid], [enNotes] , [cuGuid], [biNum], [biNetPrice], [biTaxValue], biIsAdjustment, 
			[BillType], [buReturnedBillNum], [buReturnedBillDate], OriginName, acGUID)
		SELECT	[ce].[ceDate],
				CASE WHEN @lang <> 0 AND ISNULL([et].[etLatinAbbrev], '') <> '' THEN [et].[etLatinAbbrev] ELSE [et].[etAbbrev] END  + ': ' + CAST([py].[pyNumber] AS VARCHAR(250)),
				[py].[pyNumber],
				[ce].[ceGUID],
				[er].[erParentGUID],
				[en].[enNotes],
				[en].[enCustomerGUID],
				[en].[enNumber],
				ABS([en].[enDebit] - [en].[enCredit]),
				ABS(([en].[enDebit] - [en].[enCredit]) * [en].[enAddedValue] / 100),
				1,
				CASE WHEN [en].[enDebit] > [en].[enCredit] THEN 0 ELSE 2 END,
				[en].[enGCCOriginNumber],
				[en].[enGCCOriginDate],
				CASE WHEN @lang <> 0 AND ISNULL([et].[etLatinName], '') <> '' THEN [et].[etLatinName] ELSE [et].[etName] END,
				en.enAccount
		  FROM	vwEn en 
				-- INNER JOIN vwEn [enVat] ON [en].[enGUID] = [enVat].[enParentVATGuid] 
				INNER JOIN vwCe [ce] ON [ce].[ceGUID] = [en].[enParent]
				INNER JOIN vwEr [er] ON [ce].[ceGUID] = [er].[erEntryGUID] 
				INNER JOIN vwPy [py] ON [py].[pyGUID] = [er].[erParentGUID] 
				INNER JOIN vwEt [et] ON [et].[etGUID] = [py].[pyTypeGUID] 
		 WHERE	[et].[etTaxType] != 0
				AND CAST([en].[enDate] AS DATE) BETWEEN @DurationStartDate AND @DurationEndDate
				AND	[en].[enType] = 402 /*PY_RC*/
				-- AND	[enVat].[enType] = 202 /*VAT_RETURN*/
				AND [en].[enCredit] > 0 
				AND [en].[enGCCOriginDate] > '1-1-2000' 
				AND ((CAST([en].[enGCCOriginDate] AS DATE) < @DurationStartDate) OR (CAST([en].[enGCCOriginDate] AS DATE) > @DurationEndDate))
	END
	ELSE IF @TaxDetailRecId = 203 --Input_ZR
	BEGIN

		INSERT	INTO #Result ([buGuid], [buDate], [buType], [buFormatedNumber], buNumber, [ceGuid], [enNotes], [cuGuid], [biGuid], [biNum], [biQty], [biPrice], [biTotalPrice], [biDisc],
							 [biExtra], [biNetPrice], [biTaxValue], [biAdjustment], biIsAdjustment, biCustomsRate, [BillType], [buReturnedBillNum], [buReturnedBillDate], OriginName, acGUID) 
		SELECT	[vw].[BuGuid],
				vw.[buDate],
				vw.buType,
				CASE WHEN @lang <> 0 AND ISNULL(vw.[buLatinFormatedNumber], '') <> '' THEN vw.[buLatinFormatedNumber] ELSE vw.[buFormatedNumber] END,
				vw.[buNumber],
				[er].[erEntryGUID],
				[vw].[biNotes],
				[vw].buCustPtr,
				[vw].[BiGuid],
				[vw].[BiNumber],
				[vw].[BiBillQty],
				[vw].[BiPrice],
				[vw].[BiBillQty] * [vw].[BiPrice],
				[vw].[BiQty] * [vw].[BiUnitDiscount],
				[vw].[BiQty] * [vw].[BiUnitExtra],
				(vw.biQty * (vw.biUnitPrice - vw.biUnitDiscount + vw.biUnitExtra)),
				CASE WHEN [vw].[BiTaxCode] = 1 THEN [vw].[BiVat] ELSE 0 END,
				CASE WHEN [vw].[BiTaxCode] = 6 THEN [vw].[BiVat] ELSE 0 END,
				CASE WHEN [vw].[BiTaxCode] = 6 THEN 1 ELSE 0 END,
		
				vw.biCustomsRate,
				[vw].btBillType,
				vw.buReturendBillNumber,
				vw.buReturendBillDate,
				CASE @lang
					WHEN 0 THEN vw.btName 
					ELSE CASE vw.btLatinName WHEN '' THEN vw.btName ELSE vw.btLatinName END 
				END,
				vw.buCustAcc
		  FROM 
			vwExtended_bi vw 
			INNER JOIN vwEr [er] ON [er].[erParentGUID] = vw.[buGUID]
			RIGHT JOIN GCCTaxCoding000 taxCode ON taxCode.TaxCode = vw.biTaxCode OR taxCode.TaxCode = vw.biOrginalTaxCode
		WHERE 
			(vw.btBillType = 0 OR vw.btBillType = 2)
			AND vw.biReversChargeVal = 0 
			AND taxCode.TaxCode = 3 
			AND (CAST(vw.[buDate] AS DATE) BETWEEN @DurationStartDate AND @DurationEndDate) 

		-- Entries
		INSERT	INTO #Result ([buDate], [buFormatedNumber], buNumber, [ceGuid], [ceParentGuid], [enNotes] , [cuGuid], [biNum], [biNetPrice], biIsAdjustment, 
			[BillType], [buReturnedBillNum], [buReturnedBillDate], OriginName, acGUID) 
		SELECT	[ce].[ceDate],
				CASE WHEN @lang <> 0 AND ISNULL([et].[etLatinAbbrev], '') <> '' THEN [et].[etLatinAbbrev] ELSE [et].[etAbbrev] END  + ': ' + CAST([py].[pyNumber] AS VARCHAR(250)),
				[py].[pyNumber],
				[ce].[ceGUID],
				[er].[erParentGUID],
				[en].[enNotes],
				[en].[enCustomerGUID],
				[en].[enNumber],
				ABS([en].[enDebit] - [en].[enCredit]),
				0,
				CASE WHEN [en].[enDebit] > [en].[enCredit] THEN 0 ELSE 2 END,
				[en].[enGCCOriginNumber],
				[en].[enGCCOriginDate],
				CASE WHEN @lang <> 0 AND ISNULL([et].[etLatinName], '') <> '' THEN [et].[etLatinName] ELSE [et].[etName] END,
				en.enAccount
		  FROM	vwEn en 
				INNER JOIN vwCe [ce] ON [ce].[ceGUID] = [en].[enParent]
				INNER JOIN vwEr [er] ON [ce].[ceGUID] = [er].[erEntryGUID] 
				INNER JOIN vwPy [py] ON [py].[pyGUID] = [er].[erParentGUID] 
				INNER JOIN vwEt [et] ON [et].[etGUID] = [py].[pyTypeGUID] 
		 WHERE	[et].[etTaxType] <> 0
				AND CAST([en].[enDate] AS DATE) BETWEEN @DurationStartDate AND @DurationEndDate
				AND	[en].[enType] =  403 /*PY_ZR*/
				AND ([en].[enDebit] > 0 OR (([en].[enGCCOriginDate] < '1-1-2000') OR (CAST([en].[enGCCOriginDate] AS DATE) BETWEEN @DurationStartDate AND @DurationEndDate)))
	END
	ELSE IF @TaxDetailRecId = 204--Input_EX
	BEGIN

		INSERT	INTO #Result ([buGuid], [buDate], [buType], [buFormatedNumber], buNumber, [ceGuid], [enNotes], [cuGuid], [biGuid], [biNum], [biQty], [biPrice], [biTotalPrice], [biDisc],
							 [biExtra], [biNetPrice], [biTaxValue], [biAdjustment], biIsAdjustment, biCustomsRate, [BillType], [buReturnedBillNum], [buReturnedBillDate], OriginName, acGUID) 
		SELECT	[vw].[BuGuid],
				vw.[buDate],
				vw.buType,
				CASE WHEN @lang <> 0 AND ISNULL(vw.[buLatinFormatedNumber], '') <> '' THEN vw.[buLatinFormatedNumber] ELSE vw.[buFormatedNumber] END,
				vw.[buNumber],
				[er].[erEntryGUID],
				[vw].[biNotes],
				[vw].buCustPtr,
				[vw].[BiGuid],
				[vw].[BiNumber],
				[vw].[BiBillQty],
				[vw].[BiPrice],
				[vw].[BiBillQty] * [vw].[BiPrice],
				[vw].[BiQty] * [vw].[BiUnitDiscount],
				[vw].[BiQty] * [vw].[BiUnitExtra],
				(vw.biQty * (vw.biUnitPrice - vw.biUnitDiscount + vw.biUnitExtra)),
				CASE WHEN [vw].[BiTaxCode] = 1 THEN [vw].[BiVat] ELSE 0 END,
				CASE WHEN [vw].[BiTaxCode] = 6 THEN [vw].[BiVat] ELSE 0 END,
				CASE WHEN [vw].[BiTaxCode] = 6 THEN 1 ELSE 0 END,				
				vw.biCustomsRate,
				[vw].btBillType,
				vw.buReturendBillNumber,
				vw.buReturendBillDate,
				CASE @lang
					WHEN 0 THEN vw.btName 
					ELSE CASE vw.btLatinName WHEN '' THEN vw.btName ELSE vw.btLatinName END 
				END,
				vw.buCustAcc
		  FROM 
			vwExtended_bi vw 
			INNER JOIN vwEr [er] ON [er].[erParentGUID] = vw.[buGUID]
			RIGHT JOIN GCCTaxCoding000 taxCode ON taxCode.TaxCode = vw.biTaxCode OR taxCode.TaxCode = vw.biOrginalTaxCode
		WHERE 
			(vw.btBillType = 0 OR vw.btBillType = 2)
			AND vw.biReversChargeVal = 0 
			AND taxCode.TaxCode = 4 
			AND (CAST(vw.[buDate] AS DATE) BETWEEN @DurationStartDate AND @DurationEndDate) 

		-- Entries
		INSERT	INTO #Result ([buDate], [buFormatedNumber], buNumber, [ceGuid], [ceParentGuid], [enNotes] ,  [cuGuid], [biNum], [biNetPrice], biIsAdjustment, 
			[BillType], [buReturnedBillNum], [buReturnedBillDate], OriginName, acGUID) 
		SELECT	[ce].[ceDate],
				CASE WHEN @lang <> 0 AND ISNULL([et].[etLatinAbbrev], '') <> '' THEN [et].[etLatinAbbrev] ELSE [et].[etAbbrev] END  + ': ' + CAST([py].[pyNumber] AS VARCHAR(250)),
				[py].[pyNumber],
				[ce].[ceGUID],
				[er].[erParentGUID],
				[en].[enNotes],
				[en].[enCustomerGUID],
				[en].[enNumber],
				ABS([en].[enDebit] - [en].[enCredit]),
				0,
				CASE WHEN [en].[enDebit] > [en].[enCredit] THEN 0 ELSE 2 END,
				[en].[enGCCOriginNumber],
				[en].[enGCCOriginDate],
				CASE WHEN @lang <> 0 AND ISNULL([et].[etLatinName], '') <> '' THEN [et].[etLatinName] ELSE [et].[etName] END,
				en.enAccount
		  FROM	vwEn en
				INNER JOIN vwCe [ce] ON [ce].[ceGUID] = [en].[enParent]
				INNER JOIN vwEr [er] ON [ce].[ceGUID] = [er].[erEntryGUID] 
				INNER JOIN vwPy [py] ON [py].[pyGUID] = [er].[erParentGUID] 
				INNER JOIN vwEt [et] ON [et].[etGUID] = [py].[pyTypeGUID] 
		 WHERE	[et].[etTaxType] <> 0
				AND CAST([en].[enDate] AS DATE) BETWEEN @DurationStartDate AND @DurationEndDate
				AND	[en].[enType] =   404 /*PY_EX*/
				AND ([en].[enDebit] > 0 OR (([en].[enGCCOriginDate] < '1-1-2000') OR (CAST([en].[enGCCOriginDate] AS DATE) BETWEEN @DurationStartDate AND @DurationEndDate)))
	END

	SELECT 
		r.*,
		CASE WHEN [ce].[cePostDate] <> '1905-06-02' THEN [ce].[cePostDate] END AS [cePostDate],			
		CASE WHEN @lang <> 0 AND ISNULL([cu].[cuLatinName], '') <> '' THEN [cu].[cuLatinName] ELSE [cu].[cuCustomerName] END AS [cuName],				
		[bi].[biMatPtr],
		mt.mtCode + ' - ' + 
		CASE WHEN @lang <> 0 AND ISNULL([mt].[mtLatinName], '') <> '' THEN [mt].[mtLatinName] ELSE [mt].[mtName] END AS [mtName],				
		CASE [bi].[biUnity] WHEN 3 THEN [mt].[mtUnit3] WHEN 2 THEN [mt].[mtUnit2] ELSE [mt].[mtUnity] END AS [biUnity],
		CASE WHEN @lang <> 0 AND ISNULL([ac].[acLatinName], '') <> '' THEN [ac].[acLatinName] ELSE [ac].[acName] END AS [acName],
		CASE ISNULL(@UserGUID, 0x0) WHEN 0x0 THEN 1 ELSE 0 END AS [IsLocalDb]
	FROM 
		#Result r
		LEFT JOIN vwBi [bi] ON [bi].[biGUID] = [r].[biGuid]
		LEFT JOIN vwBt [bt] ON [bt].[btGUID] = [r].[buType]
		LEFT JOIN vwCe [ce] ON [ce].[ceGUID] = [r].[ceGuid]
		LEFT JOIN vwCu [cu] ON [cu].[cuGUID] = [r].[cuGuid]
		LEFT JOIN vwAc [ac] ON [ac].[acGUID] = [r].[acGuid]
		LEFT JOIN vwMt [mt] ON [mt].[mtGUID] = [bi].[biMatPtr]

##################################################################################
CREATE PROC repGCC_DetailedVATTaxReport
	@TaxDurationGUID	[UNIQUEIDENTIFIER],
	@TaxDetailRecId		[INT]
AS
	SET NOCOUNT ON 

	CREATE TABLE #EndResult (
		buGuid				[UNIQUEIDENTIFIER],
		buDate				[DATETIME],
		buType				[UNIQUEIDENTIFIER],
		buFormatedNumber	[NVARCHAR](250),
		buNumber			[INT],
		ceGuid				[UNIQUEIDENTIFIER],
		ceParentGuid		[UNIQUEIDENTIFIER],
		enNotes				[NVARCHAR](1000),
		cuGuid				[UNIQUEIDENTIFIER],
		biGuid				[UNIQUEIDENTIFIER],
		biNum				[INT],
		biQty				[FLOAT],
		biPrice				[FLOAT],
		biTotalPrice		[FLOAT],
		biDisc				[FLOAT],
		biExtra				[FLOAT],
		biNetPrice			[FLOAT],
		biTaxValue			[FLOAT],
		biAdjustment		[FLOAT],
		biIsAdjustment		[BIT],
		biCustomsRate		[FLOAT],
		billType			[INT],
		biTaxCode			[INT],
		buReturnedBillNum	[NVARCHAR](500),
		buReturnedBillDate	[DATETIME],
		OriginName			[NVARCHAR](1000),
		[acGUID]			[UNIQUEIDENTIFIER],
		ValueDif			FLOAT,
		TaxDif				FLOAT,
		BiPurchaseVal		FLOAT,
		cePostDate			DATE,
		cuName				[NVARCHAR](1000),
		[biMatPtr]			[UNIQUEIDENTIFIER],
		mtName				[NVARCHAR](1000),
		[biUnity]			[NVARCHAR](1000),
		acName				[NVARCHAR](1000),
		[IsLocalDb]			BIT)

	CREATE TABLE #TotalsResult
	(
		totalType			[INT],
		totalValue			[FLOAT],
		totalNetPrice		[FLOAT],
		totalAdjustment		[FLOAT],
		totalTax			[FLOAT],
		totalCustomsRate	[FLOAT]
	)

	CREATE TABLE #NotifyResult(ID INT) -- 0 before crossed, 1 before crossed and no prev file, 2 after crossed, 3 saved,

	IF ISNULL(@TaxDurationGUID, 0X0) = 0x0 
	BEGIN
		SELECT * FROM #NotifyResult
		SELECT * FROM #EndResult
		SELECT * FROM #TotalsResult

		RETURN 
	END 

	DECLARE 
		@language INT,
		@DurationStartDate DATE,
		@DurationEndDate DATE,
		@DurationState INT,
		@IsTransfered BIT,
		@DurationReportGUID UNIQUEIDENTIFIER,
		@IsCrossedDuration BIT		

	SET @language = [dbo].[fnConnections_getLanguage]()

	SELECT 
		@DurationStartDate = StartDate,
		@DurationEndDate = EndDate,
		@DurationState = [State],
		@IsTransfered = ISNULL([IsTransfered], 0),
		@DurationReportGUID = ISNULL(TaxVatReportGUID, 0x0)
	FROM GCCTaxDurations000 
	WHERE 
		GUID = @TaxDurationGUID

	SET @IsCrossedDuration = 0
	DECLARE @FPDate Date = (SELECT [dbo].[fnOption_get]('AmnCfg_FPDate', DEFAULT))
	IF (@IsTransfered = 1) AND (@DurationStartDate < @FPDate) AND (@DurationEndDate >= @FPDate)
	BEGIN
		SET @IsCrossedDuration = 1
		INSERT INTO #NotifyResult SELECT 0 -- before crossed
	END

	DECLARE @EPDate Date = (SELECT [dbo].[fnOption_get]('AmnCfg_EPDate', DEFAULT))
	IF (@DurationStartDate <= @EPDate) AND (@DurationEndDate > @EPDate)
		INSERT INTO #NotifyResult SELECT 2 -- after crossed

	IF @IsTransfered = 1 AND @IsCrossedDuration = 0
	BEGIN
		SELECT * FROM #NotifyResult
		SELECT * FROM #EndResult
		SELECT * FROM #TotalsResult

		RETURN 
	END 
	
	CREATE TABLE #DB(FOUND BIT)
	IF @IsCrossedDuration = 1
	BEGIN 
		DECLARE 
			@AllDatabases CURSOR,
			@currentDbName NVARCHAR(128),
			@currentFirstPeriodDate DATE,
			@currentEndPeriodDate DATE,
			@Statement NVARCHAR(MAX),
			@UserGUID UNIQUEIDENTIFIER

		SET @UserGUID = [dbo].[fnGetCurrentUserGUID]()

		SET @AllDatabases = CURSOR FOR				 
			SELECT [DatabaseName], [FirstPeriod], [EndPeriod] FROM dbo.fnGetOtherReportDataSources(@DurationStartDate, @DurationEndDate) ORDER BY FirstPeriod
		OPEN @AllDatabases	    
	
		FETCH NEXT FROM @AllDatabases INTO @currentDbName, @currentFirstPeriodDate, @currentEndPeriodDate;
		WHILE (@@FETCH_STATUS = 0)
		BEGIN
			IF NOT EXISTS(SELECT * FROM #DB)
			BEGIN 
				SET @Statement = N'IF EXISTS(SELECT * FROM [' + @currentDbName + '].[dbo].GCCTaxDurations000 WHERE GUID = ' +
					'''' + CONVERT(NVARCHAR(38), @TaxDurationGUID) + ''') INSERT INTO #DB(FOUND) SELECT 1'
				EXEC sp_executesql @Statement;
			
				SET @Statement =  N'INSERT INTO [#EndResult] EXEC [' + @currentDbName + '].[dbo].[repGCCDetailedValueAddedTaxReturn] ' +
					'''' + CONVERT(NVARCHAR(38), @TaxDurationGUID) + ''',' +
					CAST(@TaxDetailRecId AS NVARCHAR(10)) + ',' +
					'''' + CONVERT(NVARCHAR(38), @UserGUID) + ''''
				EXEC sp_executesql @Statement;
			END
			FETCH NEXT FROM @AllDatabases INTO @currentDbName, @currentFirstPeriodDate, @currentEndPeriodDate;
		END
	END 
	INSERT INTO [#EndResult] EXEC repGCCDetailedValueAddedTaxReturn @TaxDurationGUID, @TaxDetailRecId

	------------------------------ TOTALS	RESULT ------------------------------------------
	INSERT INTO #TotalsResult([totalType], totalValue, [totalNetPrice], [totalAdjustment], [totalTax], totalCustomsRate)
	SELECT 
		[BillType],
		SUM(
			CASE WHEN @TaxDetailRecId = 12 OR @TaxDetailRecId = 202 THEN 
				CASE [BillType] 
					WHEN 1 THEN 

						CASE BiPurchaseVal 
							WHEN 0 THEN ISNULL([biNetPrice], 0) 
							ELSE BiPurchaseVal 
						END 
					ELSE ISNULL([biNetPrice], 0)	
				END 
				ELSE (ISNULL([biNetPrice], 0)) 
			END),
		SUM(CASE ISNULL([biIsAdjustment], 0) WHEN 0 THEN 
			CASE WHEN @TaxDetailRecId = 12 OR @TaxDetailRecId = 202 THEN 
				CASE [BillType] 
					WHEN 1 THEN 

						CASE BiPurchaseVal 
							WHEN 0 THEN ISNULL([biNetPrice], 0) 
							ELSE BiPurchaseVal 
						END 
					ELSE ISNULL([biNetPrice], 0)	
				END 
				ELSE (ISNULL([biNetPrice], 0)) 
			END
		ELSE 0 END),
		SUM(CASE ISNULL([biIsAdjustment], 0) WHEN 0 THEN 0 ELSE 
			CASE WHEN @TaxDetailRecId = 12 OR @TaxDetailRecId = 202 THEN 
				CASE [BillType] 
					WHEN 1 THEN 

						CASE BiPurchaseVal 
							WHEN 0 THEN ISNULL([biNetPrice], 0) 
							ELSE BiPurchaseVal 
						END 
					ELSE ISNULL([biNetPrice], 0)	
				END 
				ELSE (ISNULL([biNetPrice], 0)) 
			END
		END),
		SUM(ISNULL([biTaxValue], 0) + ISNULL([biAdjustment], 0)),
		SUM(ISNULL(biCustomsRate, 0))
	FROM	[#EndResult]
	GROUP	BY [BillType]

	INSERT INTO #TotalsResult([totalType], totalValue, [totalNetPrice], [totalAdjustment], [totalTax], totalCustomsRate)
	SELECT	
		4,
		SUM(
			CASE WHEN @TaxDetailRecId = 12 OR @TaxDetailRecId = 202 /*RC whithout ImportViaCustoms*/
				THEN (CASE WHEN [totalType] = 0 THEN 1 ELSE -1 END) 
				ELSE (CASE WHEN [totalType] IN (0, 1) THEN 1 ELSE -1 END) 
			END * [totalValue]),

		SUM(
			CASE WHEN @TaxDetailRecId = 12 OR @TaxDetailRecId = 202 /*RC whithout ImportViaCustoms*/
				THEN (CASE WHEN [totalType] = 0 THEN 1 ELSE -1 END) 
				ELSE (CASE WHEN [totalType] IN (0, 1) THEN 1 ELSE -1 END) 
			END * [totalNetPrice]),
	
		SUM(
			CASE WHEN @TaxDetailRecId = 12 OR @TaxDetailRecId = 202 /*RC whithout ImportViaCustoms*/
				THEN (CASE WHEN [totalType] = 0 THEN 1 ELSE -1 END) 
				ELSE (CASE WHEN [totalType] IN (0, 1) THEN 1 ELSE -1 END) 
			END * [totalAdjustment]),
		
		SUM(
			CASE WHEN @TaxDetailRecId = 12 OR @TaxDetailRecId = 202 /*RC whithout ImportViaCustoms*/
				THEN (CASE WHEN [totalType] = 0 THEN 1 ELSE -1 END) 
				ELSE (CASE WHEN [totalType] IN (0, 1) THEN 1 ELSE -1 END) 
			END * [totalTax]),

		SUM(totalCustomsRate)
	FROM	#TotalsResult
	
	------------------------------ 
	IF @IsCrossedDuration > 0 AND NOT EXISTS(SELECT * FROM #DB)
		INSERT INTO #NotifyResult SELECT 1

	SELECT * FROM #NotifyResult
	------------------------------ FINAL	RESULT ------------------------------------------
	SELECT  
		ISNULL([r].[buGuid], 0x0) AS [buGuid],	
		[r].[buDate],			
		[r].[billType],										
		[r].[buFormatedNumber] AS [btName],
		[r].[buNumber],	
		[r].[ceGuid],	
		ISNULL([r].[ceParentGUID], 0x0) AS [ceParentGUID],	
		[r].[enNotes],
		[r].[cePostDate],		
		[r].[cuGUID],				
		[r].[cuName],				
		[r].[biMatPtr],
		[r].[mtName],				
		[r].[biGuid],				
		[r].[biNum] AS [biNumber],				
		ISNULL([r].[biQty], 0) AS [biQty],				
		[r].[biUnity],				
		ISNULL([r].[biPrice], 0) AS [biPrice],			
		ISNULL([r].[biTotalPrice], 0) AS [biTotalPrice],		
		ISNULL([r].[biDisc], 0) AS [biDisc],				
		ISNULL([r].[biExtra], 0) AS [biExtra],
		ISNULL([r].[biNetPrice], 0) AS [biNetPrice],				
		r.[biTaxValue],
		CASE ISNULL([r].[biIsAdjustment], 0) WHEN 0 THEN 0 ELSE 1 END AS [IsAdjustment],				
		r.biCustomsRate AS biCustomsRate,
		[r].[buReturnedBillDate] AS [ReturendBillDate],
		[r].[buReturnedBillNum] AS [ReturendBillNumber],
		[r].[OriginName] AS [OriginName],
		ISNULL([r].acGUID, 0x0) AS acGUID,
		ISNULL([r].[acName], '') AS acName,
		[IsLocalDb], 
		ISNULL(ValueDif, 0) AS ValueDif,
		ISNULL(TaxDif, 0) AS TaxDif,
		ISNULL(BiPurchaseVal, 0) AS biPurchaseVal
	FROM	
		#EndResult [r]
	ORDER BY 
		[r].[buDate],
		[r].[OriginName],
		[r].[buNumber],
		[r].[biNum]	
			
	SELECT	[totalType],
			ISNULL(totalValue, 0) AS totalValue,
			ISNULL([totalNetPrice], 0) AS totalNetPrice,		
			ISNULL([totalAdjustment], 0) AS [totalAdjustment],
			ISNULL([totalTax], 0) AS [totalTax],
			ISNULL([totalCustomsRate], 0) AS [totalCustomsRate]
	FROM	[#TotalsResult]
##################################################################################
#END
