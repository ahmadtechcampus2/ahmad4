##################################################################################
CREATE PROC repGCC_NotAssignmentTax
	@TaxDurationGUID	[UNIQUEIDENTIFIER]
AS

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

	CREATE TABLE #Result(
		buGuid				[UNIQUEIDENTIFIER],
		buDate				[DATETIME],
		buType				[UNIQUEIDENTIFIER],
		buFormatedNumber	[NVARCHAR](250),
		ceGuid				[UNIQUEIDENTIFIER],
		ceParentGuid		[UNIQUEIDENTIFIER],
		enNotes				[NVARCHAR](1000) DEFAULT '',
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
		biCustomsRate		[FLOAT],
		billType			[INT],
		biTaxCode			[INT],
		OriginName			[NVARCHAR](1000)
	)

	CREATE TABLE #TotalsResult
	(
		totalType			[INT],
		totalValue			[FLOAT],
		totalNetPrice		[FLOAT],
		totalAdjustment		[FLOAT],
		totalTax			[FLOAT],
		totalCustomsRate	[FLOAT])

	------------------------------ NA ------------------------------------------
	INSERT	INTO #Result ([buGuid], [buDate], [buType], [buFormatedNumber], [ceGuid], [enNotes], [cuGuid], [biGuid], [biNum], [biQty], [biPrice], [biTotalPrice], [biDisc],
							[biExtra], [biNetPrice], [biTaxValue], biCustomsRate, [BillType], OriginName) 
	SELECT 	[bi].[BuGuid],
			[bi].[buDate],
			[bi].[buType],
			CASE WHEN @lang <> 0 AND ISNULL([bi].[buLatinFormatedNumber], '') <> '' THEN [bi].[buLatinFormatedNumber] ELSE [bi].[buFormatedNumber] END,
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
			[bi].[BiVat],
			bi.biCustomsRate,
			[bi].[btBillType],
			CASE @lang
				WHEN 0 THEN bi.btName 
				ELSE CASE bi.btLatinName WHEN '' THEN bi.btName ELSE bi.btLatinName END 
			END 
		FROM	
			vwExtended_bi [bi] 
			INNER JOIN vwEr [er] ON [er].[erParentGUID] = [bi].[buGUID]
			RIGHT JOIN GCCTaxCoding000 taxCode ON taxCode.TaxCode = bi.biTaxCode OR taxCode.TaxCode = bi.biOrginalTaxCode
		WHERE	
			([bi].[btBillType] IN (0, 1, 2, 3))
			AND ([bi].[btType] = 1)
			AND ([taxCode].[TaxCode] = 14 OR [taxCode].[TaxCode] = 15)
			AND (CAST([bi].[buDate] AS DATE) BETWEEN @DurationStartDate AND @DurationEndDate) 

	------------------------------ Bills without GCC Tax ------------------------------------------
	INSERT	INTO #Result ([buGuid], [buDate], [buType], [buFormatedNumber], [ceGuid], [enNotes], [cuGuid], [biGuid], [biNum], [biQty], [biPrice], [biTotalPrice], [biDisc],
							[biExtra], [biNetPrice], [biTaxValue], biCustomsRate, [BillType], OriginName) 
	SELECT 	[bi].[BuGuid],
			[bi].[buDate],
			[bi].[buType],
			CASE WHEN @lang <> 0 AND ISNULL([bi].[buLatinFormatedNumber], '') <> '' THEN [bi].[buLatinFormatedNumber] ELSE [bi].[buFormatedNumber] END,
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
			[bi].[BiVat],
			bi.biCustomsRate,
			[bi].[btBillType],
			CASE @lang
				WHEN 0 THEN bi.btName 
				ELSE CASE bi.btLatinName WHEN '' THEN bi.btName ELSE bi.btLatinName END 
			END 
		FROM	
			vwExtended_bi [bi] 
			INNER JOIN vwEr [er] ON [er].[erParentGUID] = [bi].[buGUID]
		WHERE	
			([bi].[btBillType] IN (0, 1, 2, 3))
			AND ([bi].[btType] = 1)
			AND bi.biTaxCode = 0
			AND (CAST([bi].[buDate] AS DATE) BETWEEN @DurationStartDate AND @DurationEndDate) 

		-- Entries
		INSERT	INTO #Result ([buDate], [buFormatedNumber], [ceGuid], [ceParentGuid], [enNotes], [cuGuid], [biNum], [biNetPrice], [biTaxValue], [BillType], OriginName) 
		SELECT	[ce].[ceDate],
				CASE WHEN @lang <> 0 AND ISNULL([et].[etLatinAbbrev], '') <> '' THEN [et].[etLatinAbbrev] ELSE [et].[etAbbrev] END  + ': ' + CAST([py].[pyNumber] AS VARCHAR(250)),
				[ce].[ceGUID],
				[er].[erParentGUID],
				[en].[enNotes],
				[en].[enCustomerGUID],
				[en].[enNumber],
				ABS([en].[enDebit] - [en].[enCredit]),
				0, -- ABS([enVat].[enDebit] - [enVat].[enCredit]),
				CASE WHEN [en].[enDebit] > [en].[enCredit] THEN 0 ELSE 2 END,
				CASE WHEN @lang <> 0 AND ISNULL([et].[etLatinName], '') <> '' THEN [et].[etLatinName] ELSE [et].[etName] END 		 
		  FROM	
				vwEn en 
				-- INNER JOIN vwEn [enVat] ON [en].[enGUID] = [enVat].[enParentVATGuid] 
				INNER JOIN vwCe [ce] ON [ce].[ceGUID] = [en].[enParent]
				INNER JOIN vwEr [er] ON [ce].[ceGUID] = [er].[erEntryGUID] 
				INNER JOIN vwPy [py] ON [py].[pyGUID] = [er].[erParentGUID] 
				INNER JOIN vwEt [et] ON [et].[etGUID] = [py].[pyTypeGUID] 
		 WHERE	[et].[etTaxType] != 0
				AND CAST([en].[enDate] AS DATE) BETWEEN @DurationStartDate AND @DurationEndDate
				AND	[en].[enType] = 410 /*GCC_PY_NA*/
				-- AND [enVat].[enType] = 202 /*VAT_RETURN*/
				AND ([en].[enDebit] > 0 OR (([en].[enGCCOriginDate] < '1-1-2000') OR (CAST([en].[enGCCOriginDate] AS DATE) BETWEEN @DurationStartDate AND @DurationEndDate)))

		INSERT	INTO #Result ([buDate], [buFormatedNumber], [ceGuid], [ceParentGuid], [enNotes], [cuGuid], [biNum], [biNetPrice], [biTaxValue], [BillType], OriginName) 
		SELECT	[ce].[ceDate],
				CASE WHEN @lang <> 0 AND ISNULL([et].[etLatinAbbrev], '') <> '' THEN [et].[etLatinAbbrev] ELSE [et].[etAbbrev] END  + ': ' + CAST([py].[pyNumber] AS VARCHAR(250)),
				[ce].[ceGUID],
				[er].[erParentGUID],
				[en].[enNotes],
				[en].[enCustomerGUID],
				[en].[enNumber],
				ABS([en].[enDebit] - [en].[enCredit]),
				0, -- ABS([enVat].[enDebit] - [enVat].[enCredit]),
				CASE WHEN [en].[enDebit] > [en].[enCredit] THEN 0 ELSE 2 END,
				CASE WHEN @lang <> 0 AND ISNULL([et].[etLatinName], '') <> '' THEN [et].[etLatinName] ELSE [et].[etName] END 		 
		FROM	
				vwEn en 
				-- INNER JOIN vwEn [enVat] ON [en].[enGUID] = [enVat].[enParentVATGuid] 
				INNER JOIN vwCe [ce] ON [ce].[ceGUID] = [en].[enParent]
				INNER JOIN vwEr [er] ON [ce].[ceGUID] = [er].[erEntryGUID] 
				INNER JOIN vwPy [py] ON [py].[pyGUID] = [er].[erParentGUID] 
				INNER JOIN vwEt [et] ON [et].[etGUID] = [py].[pyTypeGUID] 
		WHERE	[et].[etTaxType] != 0
				AND CAST([en].[enDate] AS DATE) BETWEEN @DurationStartDate AND @DurationEndDate
				AND	[en].[enType] = 450 /*GCC_PY_NOTAX*/
				-- AND [enVat].[enType] = 202 /*VAT_RETURN*/
				AND ([en].[enDebit] > 0 OR (([en].[enGCCOriginDate] < '1-1-2000') OR (CAST([en].[enGCCOriginDate] AS DATE) BETWEEN @DurationStartDate AND @DurationEndDate)))
		
		-- Adjustments In Entries
		INSERT	INTO #Result ([buDate], [buFormatedNumber], [ceGuid], [ceParentGuid], [enNotes], [cuGuid], [biNum], [biNetPrice], [biAdjustment], [BillType], OriginName)
		SELECT	[ce].[ceDate],
				CASE WHEN @lang <> 0 AND ISNULL([et].[etLatinAbbrev], '') <> '' THEN [et].[etLatinAbbrev] ELSE [et].[etAbbrev] END  + ': ' + CAST([py].[pyNumber] AS VARCHAR(250)),
				[ce].[ceGUID],
				[er].[erParentGUID],
				[en].[enNotes],
				[en].[enCustomerGUID],
				[en].[enNumber],
				ABS([en].[enDebit] - [en].[enCredit]),
				0, -- ABS([enVat].[enDebit] - [enVat].[enCredit]),
				CASE WHEN [en].[enDebit] > [en].[enCredit] THEN 0 ELSE 2 END,
				CASE WHEN @lang <> 0 AND ISNULL([et].[etLatinName], '') <> '' THEN [et].[etLatinName] ELSE [et].[etName] END 		  				 
		  FROM	vwEn en 
				-- INNER JOIN vwEn [enVat] ON [en].[enGUID] = [enVat].[enParentVATGuid] 
				INNER JOIN vwCe [ce] ON [ce].[ceGUID] = [en].[enParent]
				INNER JOIN vwEr [er] ON [ce].[ceGUID] = [er].[erEntryGUID] 
				INNER JOIN vwPy [py] ON [py].[pyGUID] = [er].[erParentGUID] 
				INNER JOIN vwEt [et] ON [et].[etGUID] = [py].[pyTypeGUID] 
		 WHERE	[et].[etTaxType] != 0
				AND CAST([en].[enDate] AS DATE) BETWEEN @DurationStartDate AND @DurationEndDate
				AND	[en].[enType] = 410 /*GCC_PY_NA*/
				AND [en].[enCredit] > 0 
				AND [en].[enGCCOriginDate] > '1-1-2000' 
				AND ((CAST([en].[enGCCOriginDate] AS DATE) < @DurationStartDate) OR (CAST([en].[enGCCOriginDate] AS DATE) > @DurationEndDate))

		-- Adjustments In Entries
		INSERT	INTO #Result ([buDate], [buFormatedNumber], [ceGuid], [ceParentGuid], [enNotes], [cuGuid], [biNum], [biNetPrice], [biAdjustment], [BillType], OriginName)
		SELECT	[ce].[ceDate],
				CASE WHEN @lang <> 0 AND ISNULL([et].[etLatinAbbrev], '') <> '' THEN [et].[etLatinAbbrev] ELSE [et].[etAbbrev] END  + ': ' + CAST([py].[pyNumber] AS VARCHAR(250)),
				[ce].[ceGUID],
				[er].[erParentGUID],
				[en].[enNotes],
				[en].[enCustomerGUID],
				[en].[enNumber],
				ABS([en].[enDebit] - [en].[enCredit]),
				0, -- ABS([enVat].[enDebit] - [enVat].[enCredit]),
				CASE WHEN [en].[enDebit] > [en].[enCredit] THEN 0 ELSE 2 END,
				CASE WHEN @lang <> 0 AND ISNULL([et].[etLatinName], '') <> '' THEN [et].[etLatinName] ELSE [et].[etName] END 		  				 
		  FROM	vwEn en 
				-- INNER JOIN vwEn [enVat] ON [en].[enGUID] = [enVat].[enParentVATGuid] 
				INNER JOIN vwCe [ce] ON [ce].[ceGUID] = [en].[enParent]
				INNER JOIN vwEr [er] ON [ce].[ceGUID] = [er].[erEntryGUID] 
				INNER JOIN vwPy [py] ON [py].[pyGUID] = [er].[erParentGUID] 
				INNER JOIN vwEt [et] ON [et].[etGUID] = [py].[pyTypeGUID] 
		 WHERE	[et].[etTaxType] != 0
				AND CAST([en].[enDate] AS DATE) BETWEEN @DurationStartDate AND @DurationEndDate
				AND	[en].[enType] = 450 /*GCC_PY_NA*/
				-- AND	[enVat].[enType] = 202 /*VAT_RETURN*/
				AND [en].[enCredit] > 0 
				AND [en].[enGCCOriginDate] > '1-1-2000' 
				AND ((CAST([en].[enGCCOriginDate] AS DATE) < @DurationStartDate) OR (CAST([en].[enGCCOriginDate] AS DATE) > @DurationEndDate))

	------------------------------ TOTALS	RESULT ------------------------------------------
	INSERT	INTO #TotalsResult([totalType], totalValue, [totalNetPrice], [totalAdjustment], [totalTax], totalCustomsRate)
	SELECT	[BillType],
		SUM(ISNULL([biNetPrice], 0)),
		SUM(CASE ISNULL([biAdjustment], 0) WHEN 0 THEN (ISNULL([biNetPrice], 0)) ELSE 0 END),
		SUM(CASE ISNULL([biAdjustment], 0) WHEN 0 THEN 0 ELSE (ISNULL([biNetPrice], 0)) END),
		SUM(ISNULL([biTaxValue], 0) + ISNULL([biAdjustment], 0)),
		SUM(ISNULL(biCustomsRate, 0))
	FROM	#Result
	GROUP	BY [BillType]

	INSERT	INTO #TotalsResult([totalType], totalValue, [totalNetPrice], [totalAdjustment], [totalTax], totalCustomsRate)
	SELECT	4,
		SUM((CASE WHEN [totalType] IN (0, 1) THEN 1 ELSE -1 END) * [totalValue]),
		SUM((CASE WHEN [totalType] IN (0, 1) THEN 1 ELSE -1 END) * [totalNetPrice]),
		SUM((CASE WHEN [totalType] IN (0, 1) THEN 1 ELSE -1 END) * [totalAdjustment]),
		SUM((CASE WHEN [totalType] IN (0, 1) THEN 1 ELSE -1 END) * [totalTax]),			
		SUM(totalCustomsRate)
	FROM	#TotalsResult

	------------------------------ FINAL	RESULT ------------------------------------------
	SELECT  ISNULL([r].[buGuid], 0x0) AS [buGuid],	
			[r].[buDate],			
			[r].[billType],										
			[r].[buFormatedNumber] AS [btName],	
			[r].[ceGuid],	
			ISNULL([r].[ceParentGUID], 0x0) AS [ceParentGUID],	
			[r].[enNotes],
			CASE WHEN [ce].[cePostDate] <> '1905-06-02' THEN [ce].[cePostDate] END AS [cePostDate],			
			[cu].[cuGUID],				
			CASE WHEN @lang <> 0 AND ISNULL([cu].[cuLatinName], '') <> '' THEN [cu].[cuLatinName] ELSE [cu].[cuCustomerName] END AS [cuName],				
			[bi].[biMatPtr],
			mt.mtCode + ' - ' + 
			CASE WHEN @lang <> 0 AND ISNULL([mt].[mtLatinName], '') <> '' THEN [mt].[mtLatinName] ELSE [mt].[mtName] END AS [mtName],				
			[r].[biGuid],				
			[r].[biNum] AS [biNumber],				
			ISNULL([r].[biQty], 0) AS [biQty],				
			CASE [bi].[biUnity] WHEN 3 THEN [mt].[mtUnit3] WHEN 2 THEN [mt].[mtUnit2] ELSE [mt].[mtUnity] END AS [biUnity],				
			ISNULL([r].[biPrice], 0) AS [biPrice],			
			ISNULL([r].[biTotalPrice], 0) AS [biTotalPrice],		
			ISNULL([r].[biDisc], 0) AS [biDisc],				
			ISNULL([r].[biExtra], 0) AS [biExtra],
			ISNULL([r].[biNetPrice], 0) AS [biNetPrice],				
			CASE ISNULL([r].[biTaxValue], 0) WHEN 0 THEN ISNULL([r].[biAdjustment], 0) ELSE ISNULL([r].[biTaxValue], 0) END AS [biTaxValue],			
			CASE ISNULL([r].[biAdjustment], 0) WHEN 0 THEN 0 ELSE 1 END AS [IsAdjustment],	
			r.biCustomsRate AS biCustomsRate,
			[r].[OriginName] AS [OriginName]
	  FROM	#Result [r]
			LEFT JOIN vwBi [bi] ON [bi].[biGUID] = [r].[biGuid]
			LEFT JOIN vwBt [bt] ON [bt].[btGUID] = [r].[buType]
			LEFT JOIN vwCe [ce] ON [ce].[ceGUID] = [r].[ceGuid]
			LEFT JOIN vwCu [cu] ON [cu].[cuGUID] = [r].[cuGuid]
			LEFT JOIN vwMt [mt] ON [mt].[mtGUID] = [bi].[biMatPtr]
	ORDER BY 
		[r].[buDate],
		[r].[buFormatedNumber],
		[r].[biNum]	
			
	SELECT	[totalType],
			totalValue,
			[totalNetPrice],		
			[totalAdjustment],
			[totalTax],
			ISNULL([totalCustomsRate], 0) AS [totalCustomsRate]
	  FROM	[#TotalsResult]

##################################################################################
#END
