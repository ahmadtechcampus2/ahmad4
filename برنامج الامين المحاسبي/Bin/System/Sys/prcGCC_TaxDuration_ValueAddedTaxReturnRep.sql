##################################################################################
CREATE FUNCTION fnGCCGetBillTypeValuesAddedTaxReturnByTaxCode(@BillType [INT], @TaxDurationGuid [UNIQUEIDENTIFIER] = 0x0,  @LocationGuid [UNIQUEIDENTIFIER] = 0x0, @TaxCode [INT] = 0, @OrginalTaxCode [INT] = 0)
RETURNS @Result TABLE (
	[TaxGuid] UNIQUEIDENTIFIER,
	[TaxCode] INT,
	[Title] NVARCHAR(250),
	[Amount] FLOAT,
	[VatAmount]	FLOAT)
AS BEGIN
	DECLARE @language [INT] = [dbo].[fnConnections_getLanguage]() ;
	DECLARE @DurationStartDate Date = (SELECT [dbo].[fnOption_get]('AmnCfg_FPDate', DEFAULT))
	DECLARE @DurationEndDate Date = (SELECT [dbo].[fnOption_get]('AmnCfg_EPDate', DEFAULT))
	
	IF @TaxDurationGuid <> 0x0 
	BEGIN 
		SET @DurationStartDate = (SELECT StartDate FROM GCCTaxDurations000 WHERE GUID = @TaxDurationGuid)
		SET @DurationEndDate = (SELECT EndDate FROM GCCTaxDurations000 WHERE GUID = @TaxDurationGuid)
	END 

	INSERT INTO @Result
	SELECT 
		vw.BiTaxCodingGuid,
		vw.BiTaxCode,
		CASE WHEN @language <> 0 THEN vw.BiTaxCodingLatinName ELSE vw.BiTaxCodingName END,
		ISNULL (SUM(vw.BiNetPrice), 0 ),
		ISNULL (CASE WHEN vw.BillTypeIsOutput = 1 THEN SUM(vw.EnCredit) ELSE SUM(vw.EnDebit) END, 0)
	FROM 
		vwGCCBillItemInfo vw
	WHERE 
		vw.BillType = @BillType
		AND vw.BiTaxCode = CASE WHEN @TaxCode = 0 THEN vw.BiTaxCode  ELSE @TaxCode END
		AND ((@TaxCode != 6 /*OA*/) OR ((@TaxCode = 6) AND (@OrginalTaxCode != 0) AND (@OrginalTaxCode = BiOrginalTaxCode)))
		AND (CAST(vw.BuDate AS DATE) BETWEEN @DurationStartDate AND @DurationEndDate) 
		AND vw.LocationGuid = CASE WHEN @LocationGuid = 0x0 THEN vw.LocationGuid ELSE @LocationGuid END
		AND vw.BiReversChargeVal = 0
		AND vw.EnType <> 203 
		AND vw.EnType <> 204
	GROUP by 
		vw.BiTaxCode,
		vw.BiTaxCodingGuid,
		vw.BillTypeIsOutput,
		vw.BiTaxCodingLatinName,
		vw.BiTaxCodingName
	ORDER BY 
		vw.BiTaxCode

	RETURN
END
##################################################################################
CREATE FUNCTION fnGCCGetBillTypeValuesAddedOAByTaxCode(@BillType [INT], @TaxDurationGuid [UNIQUEIDENTIFIER] = 0x0, @OrginalTaxCode [INT] = 0)
RETURNS @Result TABLE (
	[TaxGuid] UNIQUEIDENTIFIER,
	[TaxCode] INT,
	[Title] NVARCHAR(250),
	[Amount] FLOAT,
	[VatAmount]	FLOAT)
AS BEGIN
	DECLARE @language [INT] = [dbo].[fnConnections_getLanguage]() ;
	DECLARE @DurationStartDate Date = (SELECT [dbo].[fnOption_get]('AmnCfg_FPDate', DEFAULT))
	DECLARE @DurationEndDate Date = (SELECT [dbo].[fnOption_get]('AmnCfg_EPDate', DEFAULT))
	
	IF @TaxDurationGuid <> 0x0 
	BEGIN 
		SET @DurationStartDate = (SELECT StartDate FROM GCCTaxDurations000 WHERE GUID = @TaxDurationGuid)
		SET @DurationEndDate = (SELECT EndDate FROM GCCTaxDurations000 WHERE GUID = @TaxDurationGuid)
	END 

	INSERT INTO @Result
	SELECT 
		taxCode.[GUID],
		bi.BiTaxCode,
		CASE WHEN @language <> 0 THEN taxCode.LatinName ELSE taxCode.Name END,
		ISNULL(SUM(bi.biQty * (bi.biUnitPrice - bi.biUnitDiscount + bi.biUnitExtra)), 0 ),
		0
	 FROM	
		vwExtended_bi [bi] 
		INNER JOIN vwEr [er] ON [er].[erParentGUID] = [bi].[buGUID]
		RIGHT JOIN GCCTaxCoding000 taxCode ON taxCode.TaxCode = bi.biTaxCode
	WHERE 
		bi.btBillType = @BillType AND bi.btType = 1
		AND bi.BiTaxCode = 6 /*OA*/
		AND bi.BiOrginalTaxCode = @OrginalTaxCode
		AND (CAST(bi.BuDate AS DATE) BETWEEN @DurationStartDate AND @DurationEndDate) 
		AND bi.biReversChargeVal = 0
	GROUP by 
		bi.BiTaxCode,
		taxCode.[GUID],
		bi.btIsOutput,
		taxCode.LatinName,
		taxCode.Name
	ORDER BY 
		bi.BiTaxCode

	RETURN
END
##################################################################################
CREATE FUNCTION fnGCCGetBillTypeValuesAddedTaxReturnByLocation(@BillType [INT], @TaxDurationGuid [UNIQUEIDENTIFIER] = 0x0,  @LocationGuid [UNIQUEIDENTIFIER] = 0x0, @TaxCode [INT] = 0, @OrginalTaxCode [INT] = 0)
	
	RETURNS @Result TABLE 
	(
	[LocationGUID] UNIQUEIDENTIFIER,
	[LocationNumber] INT,
	[Title] NVARCHAR(250),
	[Amount] FLOAT,
	[VatAmount]	FLOAT
	)

AS BEGIN

	DECLARE @language [INT] = [dbo].[fnConnections_getLanguage]() ;
	DECLARE @DurationStartDate Date = (SELECT [dbo].[fnOption_get]('AmnCfg_FPDate', DEFAULT))
	DECLARE @DurationEndDate Date = (SELECT [dbo].[fnOption_get]('AmnCfg_EPDate', DEFAULT))
	
	IF @TaxDurationGuid <> 0x0 
	BEGIN 
	SET @DurationStartDate = (SELECT StartDate FROM GCCTaxDurations000 WHERE GUID  = @TaxDurationGuid )
	SET @DurationEndDate = (SELECT EndDate FROM GCCTaxDurations000 WHERE GUID  = @TaxDurationGuid )
	END 

	INSERT INTO @Result
	SELECT 
		vw.LocationGuid,
		vw.LocationNumber,
		CASE WHEN @language <> 0 THEN vw.LocationLatinName ELSE vw.LocationName END,
		ISNULL (SUM(vw.BiNetPrice), 0 ),
		ISNULL (CASE WHEN vw.BillTypeIsOutput = 1 THEN SUM(vw.EnCredit) ELSE SUM(vw.EnDebit) END, 0)
	FROM 
		vwGCCBillItemInfo vw
	WHERE 
		vw.BillType = @BillType
		AND vw.BiTaxCode = CASE WHEN @TaxCode = 0 THEN vw.BiTaxCode  ELSE @TaxCode END
		AND ((@TaxCode != 6 /*OA*/) OR ((@TaxCode = 6) AND (@OrginalTaxCode != 0) AND (@OrginalTaxCode = BiOrginalTaxCode)))
		AND (CAST(vw.BuDate AS DATE) BETWEEN @DurationStartDate AND @DurationEndDate) 
		AND vw.LocationGuid = CASE WHEN @LocationGuid = 0x0 THEN vw.LocationGuid ELSE @LocationGuid END
		AND vw.BiReversChargeVal = 0
		AND vw.EnType <> 203 
		AND vw.EnType <> 204
	GROUP by 
		vw.LocationGuid,
		vw.LocationNumber,
		vw.BillTypeIsOutput,
		vw.LocationLatinName,
		vw.LocationName
	ORDER BY 
		vw.LocationNumber

	RETURN
END
##################################################################################
CREATE FUNCTION fnGCCGetBillTypeReverseChargeValuesAddedTaxReturn(
	@IsReturned [INT],
	@TaxDurationGuid [UNIQUEIDENTIFIER] = 0x0,
	@ISPreviousTaxPeriods [INT] = 0,
	@Type [INT] = 0, -- 0: RC, 1: ImportViaCustomsType, 2: Adjust, -1: All
	@IsRefund [BIT] = 0)
		RETURNS @Result TABLE(
			[Amount] FLOAT,
			[VatAmount]	FLOAT)
AS BEGIN
	
	DECLARE @language [INT] = [dbo].[fnConnections_getLanguage]() ;
	DECLARE @DurationStartDate Date = (SELECT [dbo].[fnOption_get]('AmnCfg_FPDate', DEFAULT))
	DECLARE @DurationEndDate Date = (SELECT [dbo].[fnOption_get]('AmnCfg_EPDate', DEFAULT))
	
	IF @TaxDurationGuid <> 0x0 
	BEGIN 
		SET @DurationStartDate = (SELECT StartDate FROM GCCTaxDurations000 WHERE GUID = @TaxDurationGuid )
		SET @DurationEndDate = (SELECT EndDate FROM GCCTaxDurations000 WHERE GUID = @TaxDurationGuid )
	END 

	INSERT INTO @Result
	SELECT 
		ISNULL(SUM(
			CASE @Type 
				WHEN 1 THEN vw.CustomsRate 
				WHEN 2 THEN vw.BiNetPrice - vw.CustomsRate 
				ELSE 
					CASE vw.BillType 
						WHEN 1 THEN CASE vw.BiPurchaseVal WHEN 0 THEN vw.BiNetPrice ELSE vw.BiPurchaseVal END 
						ELSE vw.BiNetPrice 
					END
			END), 0),
		ISNULL(SUM(
			CASE @Type 
				WHEN -1 THEN 
					CASE ISNULL(vw.ImportViaCustoms, 0) 
						WHEN 0 THEN vw.BiReversChargeVal 
						ELSE vw.BiNetPrice * 0.05 * (CASE vw.BiReversChargeVal WHEN 0 THEN 0 ELSE 1 END) 
					END 
				WHEN 2 THEN vw.BiNetPrice * 0.05 * (CASE vw.BiReversChargeVal WHEN 0 THEN 0 ELSE 1 END) - vw.BiReversChargeVal
				ELSE vw.BiReversChargeVal
			END), 0)
	FROM 
		vwGCCBillItemInfo vw
	WHERE 
		(
			((@IsReturned = 0) AND vw.BillType IN (0, 3)) 
			OR 
			((@IsReturned = 1) AND vw.BillType IN (1, 2))
		)
		AND vw.BiReversChargeVal <> 0
		AND vw.BiTaxCode = CASE WHEN @ISPreviousTaxPeriods = 0 AND vw.BiTaxCode <> 6 THEN vw.BiTaxCode WHEN @ISPreviousTaxPeriods = 1 THEN 6 END
		AND (CAST(vw.BuDate AS DATE) BETWEEN @DurationStartDate AND @DurationEndDate)
		AND ((@Type = -1) OR ((@Type = 2) AND (vw.ImportViaCustoms = 1)) OR (vw.ImportViaCustoms = @Type))
		AND 
			((@IsRefund = 0 AND (vw.enType = 205 OR vw.enType = 207))
			OR
			(@IsRefund = 1 AND (vw.enType = 206 OR vw.enType = 208)))

	RETURN
END
##################################################################################
CREATE PROCEDURE prcGCCValueAddedTaxReturnRep
	@TaxDurationGUID UNIQUEIDENTIFIER,
	@IsForOtherDB BIT = 0
AS
	SET NOCOUNT ON

	IF @TaxDurationGuid = 0x0 
		RETURN 
	
	IF @IsForOtherDB = 1
	BEGIN 
		DECLARE @UserGUID UNIQUEIDENTIFIER
		SET @UserGUID = (SELECT TOP 1 GUID FROM us000 WHERE bAdmin = 1 AND [Type] = 0)
		EXEC prcConnections_Add @UserGUID
	END

	DECLARE 
		@language INT,
		@DurationStartDate DATE,
		@DurationEndDate DATE,
		@DurationState INT,
		@IsTransfered BIT,
		@DurationReportGUID UNIQUEIDENTIFIER,
		@IsCrossedDuration BIT, 
		@FPDate DATE

	SET @language = [dbo].[fnConnections_getLanguage]()

	SELECT 
		@DurationStartDate = StartDate,
		@DurationEndDate = EndDate,
		@DurationState = [State],
		@IsTransfered = ISNULL([IsTransfered], 0),
		@DurationReportGUID = ISNULL(TaxVatReportGUID, 0x0),
		@IsCrossedDuration = ISNULL(IsCrossed, 0)
	FROM GCCTaxDurations000 
	WHERE GUID  = @TaxDurationGuid

	SET @FPDate = (SELECT [dbo].[fnOption_get]('AmnCfg_FPDate', DEFAULT))

	DECLARE @Adjustment FLOAT = 0.0
	DECLARE @AdjustmentValue FLOAT = 0.0

	DECLARE @IsSudiaGCCCountry BIT 
	SET @IsSudiaGCCCountry = CASE dbo.fnOption_GetInt('AmnCfg_GCCTaxSystemCountry', '0') WHEN 1 THEN 1 ELSE 0 END

	CREATE TABLE [#RESULT] (
		[RecID] INT, -- 1 SR Local Location, 11 Output Tax Refunds Provided To Tourists, 
		[Title] NVARCHAR (250) DEFAULT(''),
		[Amount] FLOAT DEFAULT(0),
		[VatAmount]	FLOAT DEFAULT(0),
		[Adjustment] FLOAT DEFAULT(0),
		[AdjustmentValue] FLOAT DEFAULT(0),
		[Type]	INT, -- 1 Output, 2 Input , 3 NetVATDue
		[LocationGuid] UNIQUEIDENTIFIER DEFAULT(0x0),
		[LocationNumber] INT DEFAULT(0),
		[TaxCodingGuid] UNIQUEIDENTIFIER DEFAULT(0x0),
		[TaxCode] INT DEFAULT(0),
		[Number] INT DEFAULT(0),
		[Code] NVARCHAR(10) DEFAULT(''))

	-- Insert SR Local Locations
	INSERT INTO  [#RESULT] (RecID, LocationGuid,LocationNumber,Title,Amount,VatAmount, Type, Code)
	SELECT 
		1,
		loc.GUID,
		loc.Number,
		CASE WHEN @language <> 0 THEN loc.LatinName ELSE loc.Name END,
		ISNULL(sell.Amount,0) - ISNULL(retSell.Amount,0),
		ISNULL(sell. VatAmount,0) - ISNULL(retSell.VatAmount,0),
		1, -- Output		
		'1.' +  CAST(ROW_NUMBER() OVER(ORDER BY loc.Number) AS NVARCHAR(10))
	FROM 
		dbo.fnGCCGetBillTypeValuesAddedTaxReturnByLocation(1, @TaxDurationGUID, 0x0, 1, 0) sell
		FULL JOIN dbo.fnGCCGetBillTypeValuesAddedTaxReturnByLocation(3, @TaxDurationGUID, 0x0, 1, 0) retSell ON sell.LocationGUID = retSell.LocationGUID
		RIGHT JOIN  GCCCustLocations000 loc ON loc.GUID = COALESCE(sell.LocationGUID, retSell.LocationGUID)
	WHERE 
		loc.Classification = 0 
		AND 
		NOT EXISTS(SELECT GUID FROM GCCCustLocations000 WHERE ParentLocationGUID = loc.GUID)

	UPDATE res
	SET 
		res.Adjustment = ISNULL(oaTaxCode.VatAmount, 0),
		res.AdjustmentValue = ISNULL(oaTaxCode.Amount, 0)
	FROM 
		[#RESULT] res
		LEFT JOIN dbo.fnGCCGetBillTypeValuesAddedTaxReturnByLocation(3, @TaxDurationGUID, 0x0, 6, 1/*SR*/) oaTaxCode ON oaTaxCode.LocationGUID = res.LocationGuid
	WHERE 
		res.LocationGuid <> 0x0 AND RecID = 1
	
	-- for PU 
	INSERT INTO  [#RESULT] (RecID, LocationGuid, LocationNumber, Title, Amount, VatAmount, Type)
	SELECT 
		-100,
		loc.GUID,
		loc.Number,
		CASE WHEN @language <> 0 THEN loc.LatinName ELSE loc.Name END,
		ISNULL(sell.Amount,0) - ISNULL(retSell.Amount,0),
		ISNULL(sell. VatAmount,0) - ISNULL(retSell.VatAmount,0),
		1 -- Output		
	FROM 
		dbo.fnGCCGetBillTypeValuesAddedTaxReturnByLocation(1, @TaxDurationGUID, 0x0, 1 /*PU*/, 0) sell
		FULL JOIN dbo.fnGCCGetBillTypeValuesAddedTaxReturnByLocation(3, @TaxDurationGUID, 0x0, 1 /*PU*/, 0) retSell ON sell.LocationGUID = retSell.LocationGUID
		RIGHT JOIN  GCCCustLocations000 loc ON loc.GUID = COALESCE(sell.LocationGUID, retSell.LocationGUID)
	WHERE 
		loc.Classification = 3 

	UPDATE res
	SET 
		res.Adjustment = ISNULL(oaTaxCode.VatAmount, 0),
		res.AdjustmentValue = ISNULL(oaTaxCode.Amount, 0)
	FROM 
		[#RESULT] res
		LEFT JOIN dbo.fnGCCGetBillTypeValuesAddedTaxReturnByLocation(3, @TaxDurationGUID, 0x0, 6, 1 /*PU*/ ) oaTaxCode ON oaTaxCode.LocationGUID = res.LocationGuid
	WHERE 
		RecID = -100

	DECLARE @MinLocationNumber INT 
	SET @MinLocationNumber = (SELECT TOP 1 LocationNumber FROM [#RESULT] WHERE RecID = 1 ORDER BY LocationNumber)
	
	UPDATE [#RESULT] 
	SET 
		Amount = Amount + (SELECT ISNULL(Amount, 0) FROM [#RESULT] WHERE RecID = -100),
		VatAmount = VatAmount + (SELECT ISNULL(VatAmount, 0) FROM [#RESULT] WHERE RecID = -100),
		Adjustment = Adjustment + (SELECT ISNULL(Adjustment, 0) FROM [#RESULT] WHERE RecID = -100),
		AdjustmentValue = AdjustmentValue + (SELECT ISNULL(AdjustmentValue, 0) FROM [#RESULT] WHERE RecID = -100)
	WHERE 
		RecID = 1 AND LocationNumber = @MinLocationNumber	

	DELETE [#RESULT] WHERE RecID = -100
	
	--Output_TaxRefundsProvidedToTouristsUnderTheTaxRefundsForTouristsScheme
	IF @IsSudiaGCCCountry = 0
	BEGIN 
		INSERT INTO [#RESULT] (RecID, Type, Code)
		SELECT 11, 1, '2' -- Output
	END ELSE BEGIN
		INSERT INTO [#RESULT] (RecID, TaxCodingGUID, TaxCode, Amount, Type, Code)
		SELECT 		
			11,
			MAX(taxCode.GUID),
			MAX(taxCode.TaxCode),
			ISNULL(SUM ( (CASE bi.btIsOutput WHEN 1 THEN 1 ELSE -1 END) * (bi.biQty * (bi.biUnitPrice - bi.biUnitDiscount + bi.biUnitExtra))), 0),
			1, -- Output	
			'2'
		FROM 
			vwExtended_bi bi 
			RIGHT JOIN GCCTaxCoding000 taxCode ON taxCode.TaxCode = bi.biTaxCode
		WHERE 
			(bi.btBillType = 1 OR bi.btBillType = 3)
			-- AND bi.buIsPosted = 1
			AND bi.biReversChargeVal = 0 
			AND taxCode.TaxCode = 12 
			AND (CAST([bi].[buDate] AS DATE) BETWEEN @DurationStartDate AND @DurationEndDate) 

		SELECT	
			@Adjustment = ISNULL(VatAmount, 0),
			@AdjustmentValue = ISNULL(Amount, 0)
		FROM 
			dbo.fnGCCGetBillTypeValuesAddedOAByTaxCode(3, @TaxDurationGUID, 12/*PU*/)

		UPDATE [#RESULT] 
		SET 
			Adjustment = @Adjustment,
			AdjustmentValue = @AdjustmentValue
		WHERE 
			RecID = 11
	END
	SET @Adjustment = 0
	SET @AdjustmentValue = 0

	DECLARE @RCAmount FLOAT, @RCVatAmount FLOAT, @RCRetAmount FLOAT, @RCRetVatAmount FLOAT, @RCAdjustment FLOAT, @RCAdjustmentValue FLOAT
	SET @RCAmount = 0
	SET @RCVatAmount = 0
	SET @RCRetAmount = 0
	SET @RCRetVatAmount = 0
	SET @RCAdjustment = 0
	SET @RCAdjustmentValue = 0

	-- PY Entries
	DECLARE @PyInputSRAmount FLOAT = 0
	DECLARE @PyInputRCAmount FLOAT = 0
	DECLARE @PyInputZRAmount FLOAT = 0
	DECLARE @PyInputEXAmount FLOAT = 0
	DECLARE @PyInputPUAmount FLOAT = 0
	DECLARE @PyInputXPAmount FLOAT = 0
	DECLARE @PyInputTRAmount FLOAT = 0
	DECLARE @PyInputRCVat FLOAT = 0
	DECLARE @PyInputVat FLOAT = 0

	DECLARE @PySRAdjustment FLOAT = 0
	DECLARE @PyRCAdjustment FLOAT = 0
	DECLARE @PyZRAdjustment FLOAT = 0
	DECLARE @PyEXAdjustment FLOAT = 0
	DECLARE @PyPUAdjustment FLOAT = 0
	DECLARE @PyXPAdjustment FLOAT = 0
	DECLARE @PyTRAdjustment FLOAT = 0
	DECLARE @PyRCAdjustmentVat FLOAT = 0
	DECLARE @PyAdjustment FLOAT = 0

	SELECT 
		@PyInputSRAmount = ISNULL(SUM(CASE en.Type WHEN 401 THEN en.Debit - en.Credit ELSE 0 END), 0),
		@PyInputRCAmount = ISNULL(SUM(CASE en.Type WHEN 402 THEN en.Debit - en.Credit ELSE 0 END), 0),
		@PyInputZRAmount = ISNULL(SUM(CASE en.Type WHEN 403 THEN en.Debit - en.Credit ELSE 0 END), 0),
		@PyInputEXAmount = ISNULL(SUM(CASE en.Type WHEN 404 THEN en.Debit - en.Credit ELSE 0 END), 0),
		@PyInputPUAmount = ISNULL(SUM(CASE en.Type WHEN 408 THEN en.Debit - en.Credit ELSE 0 END), 0),
		@PyInputXPAmount = ISNULL(SUM(CASE en.Type WHEN 409 THEN en.Debit - en.Credit ELSE 0 END), 0),
		@PyInputTRAmount = ISNULL(SUM(CASE en.Type WHEN 411 THEN en.Debit - en.Credit ELSE 0 END), 0),
		@PyInputRCVat = ISNULL(SUM((CASE en.Type WHEN 402 THEN en.Debit - en.Credit ELSE 0 END) * ISNULL(en.AddedValue, 0) / 100), 0),
		@PyInputVat = ISNULL(SUM(CASE en.Type WHEN 202 THEN en.Debit - en.Credit ELSE 0 END), 0)
	FROM 
		en000 en 
		INNER JOIN ce000 ce ON ce.GUID = en.ParentGUID 
		INNER JOIN er000 er ON ce.GUID = er.EntryGUID 
		INNER JOIN py000 py ON py.GUID = er.ParentGUID 
		INNER JOIN et000 et ON et.GUID = py.TypeGUID 
	WHERE 
		et.TaxType != 0
		AND
		CAST(en.Date AS DATE) BETWEEN @DurationStartDate AND @DurationEndDate
		AND
		en.Type IN(202 /*VAT_RETURN*/, 401 /*PY_SR*/, 402 /*PY_RC*/, 403 /*PY_ZR*/, 404 /*PY_EX*/, 408 /*GCC_PY_PU*/, 409/*GCC_PY_XP*/, 411 /*GCC_PY_TR*/)
		AND
		(
			(((en.Credit > 0) OR ((en.Type = 411) AND (en.Debit > 0)))
			AND 
			((en.GCCOriginDate < '1-1-2000') OR (CAST(en.GCCOriginDate AS DATE) BETWEEN @DurationStartDate AND @DurationEndDate)))
			OR
			((en.Debit > 0) OR ((en.Type = 411) AND (en.Credit > 0)))
		)
		AND ((en.Type != 401) OR ((en.Type = 401) AND EXISTS(SELECT 1 FROM ce000 ce1 INNER JOIN en000 en1 ON ce1.GUID = en1.ParentGUID 
			WHERE ce1.GUID = en.ParentGUID AND en1.Type = 202)))

	SELECT 
		@PySRAdjustment = ISNULL(SUM(CASE en.Type WHEN 401 THEN en.Credit - en.Debit ELSE 0 END), 0),
		@PyRCAdjustment = ISNULL(SUM(CASE en.Type WHEN 402 THEN en.Credit - en.Debit ELSE 0 END), 0),
		@PyZRAdjustment = ISNULL(SUM(CASE en.Type WHEN 403 THEN en.Credit - en.Debit ELSE 0 END), 0),
		@PyEXAdjustment = ISNULL(SUM(CASE en.Type WHEN 404 THEN en.Credit - en.Debit ELSE 0 END), 0),
		@PyPUAdjustment = ISNULL(SUM(CASE en.Type WHEN 408 THEN en.Credit - en.Debit ELSE 0 END), 0),
		@PyXPAdjustment = ISNULL(SUM(CASE en.Type WHEN 409 THEN en.Credit - en.Debit ELSE 0 END), 0),
		@PyTRAdjustment = ISNULL(SUM(CASE en.Type WHEN 411 THEN en.Debit - en.Credit ELSE 0 END), 0),
		@PyRCAdjustmentVat = ISNULL(SUM((CASE en.Type WHEN 402 THEN en.Debit - en.Credit ELSE 0 END) * ISNULL(en.AddedValue, 0) / 100 ), 0),
		@PyAdjustment = ISNULL(SUM(CASE en.Type WHEN 202 THEN en.Credit - en.Debit ELSE 0 END), 0)
	FROM 
		en000 en 
		INNER JOIN ce000 ce ON ce.GUID = en.ParentGUID 
		INNER JOIN er000 er ON ce.GUID = er.EntryGUID 
		INNER JOIN py000 py ON py.GUID = er.ParentGUID 
		INNER JOIN et000 et ON et.GUID = py.TypeGUID 
	WHERE 
		et.TaxType != 0
		AND
		CAST(en.Date AS DATE) BETWEEN @DurationStartDate AND @DurationEndDate
		AND
		en.Type IN(202 /*VAT_RETURN*/, 401 /*PY_SR*/, 402 /*PY_RC*/, 403 /*PY_ZR*/, 404 /*PY_EX*/, 408 /*GCC_PY_PU*/, 409/*GCC_PY_XP*/, 411 /*GCC_PY_TR*/)
		AND
		((en.Credit > 0) OR ((en.Type = 411) AND (en.Debit > 0)))
		AND
		en.GCCOriginDate > '1-1-2000'
		AND 
		(CAST(en.GCCOriginDate AS DATE) < @DurationStartDate OR CAST(en.GCCOriginDate AS DATE) > @DurationEndDate)
		AND ((en.Type != 401) OR ((en.Type = 401) AND EXISTS(SELECT 1 FROM ce000 ce1 INNER JOIN en000 en1 ON ce1.GUID = en1.ParentGUID 
			WHERE ce1.GUID = en.ParentGUID AND en1.Type = 202)))

	--Output_RC
	IF @IsSudiaGCCCountry = 0
	BEGIN 
		INSERT INTO [#RESULT] (RecID, Type, Code)
		SELECT 12, 1, '3' -- Output

		SELECT 
			@RCAmount = ISNULL(SUM(fn.Amount), 0), 
			@RCVatAmount = ISNULL(SUM(fn.VatAmount), 0)
		FROM dbo.fnGCCGetBillTypeReverseChargeValuesAddedTaxReturn(0, @TaxDurationGUID, 0, 0, 1) fn

		SELECT 
			@RCRetAmount = ISNULL(SUM(fn.Amount), 0), 
			@RCRetVatAmount = ISNULL(SUM(fn.VatAmount), 0)
		FROM dbo.fnGCCGetBillTypeReverseChargeValuesAddedTaxReturn(1, @TaxDurationGUID, 0, 0, 1) fn

		SELECT 
			@RCAdjustment = ISNULL(SUM(fn.VatAmount), 0), 
			@RCAdjustmentValue = ISNULL(SUM(fn.Amount), 0)
		FROM dbo.fnGCCGetBillTypeReverseChargeValuesAddedTaxReturn(1, @TaxDurationGUID, 1, 0, 1) fn
		
		UPDATE [#RESULT]
		SET  
			Adjustment = @RCAdjustment + @PyRCAdjustmentVat,
			AdjustmentValue = @RCAdjustmentValue + @PyRCAdjustment,
			Amount = @RCAmount - @RCRetAmount + @PyInputRCAmount, 
			VatAmount = @RCVatAmount - @RCRetVatAmount + @PyInputRCVat
		WHERE RecID = 12
	END 
	
	-- ZR 
	INSERT INTO [#RESULT] (RecID, TaxCodingGuid, TaxCode, Amount, Type, Code)
	SELECT 		
		13,
		MAX(taxCode.GUID),
		MAX(taxCode.TaxCode),
		ISNULL(SUM ( CASE WHEN bi.btIsOutput = 1 THEN (bi.biQty * (bi.biUnitPrice - bi.biUnitDiscount + bi.biUnitExtra)) ELSE (-1 * (bi.biQty * (bi.biUnitPrice - bi.biUnitDiscount + bi.biUnitExtra))) END), 0),
		1, -- Output	
		'4'
	FROM 
		vwExtended_bi bi 
		RIGHT JOIN GCCTaxCoding000 taxCode ON taxCode.TaxCode = bi.biTaxCode
	WHERE 
		(bi.btBillType = 1 OR bi.btBillType = 3)
		AND bi.biReversChargeVal = 0 
		AND taxCode.TaxCode = 3 
		AND (CAST([bi].[buDate] AS DATE) BETWEEN @DurationStartDate AND @DurationEndDate) 

	SELECT	
		@Adjustment = ISNULL(VatAmount, 0),
		@AdjustmentValue = ISNULL(Amount, 0)
	FROM 
		dbo.fnGCCGetBillTypeValuesAddedOAByTaxCode(3, @TaxDurationGUID, 3/*ZR*/)

	UPDATE [#RESULT] 
	SET 
		Adjustment = @Adjustment,
		AdjustmentValue = @AdjustmentValue
	WHERE 
		RecID = 13

	SET @Adjustment = 0
	SET @AdjustmentValue = 0

	-- EX
	INSERT INTO [#RESULT] (RecID, TaxCodingGuid, TaxCode, Amount, Type, Code)
	SELECT 		
		14,
		MAX(taxCode.GUID),
		MAX(taxCode.TaxCode),
		ISNULL(SUM ( CASE WHEN bi.btIsOutput = 1 THEN (bi.biQty * (bi.biUnitPrice - bi.biUnitDiscount + bi.biUnitExtra)) ELSE (-1 * (bi.biQty * (bi.biUnitPrice - bi.biUnitDiscount + bi.biUnitExtra))) END), 0),
		1, -- Output	
		'5'
	FROM 
		vwExtended_bi bi 
		RIGHT JOIN GCCTaxCoding000 taxCode ON taxCode.TaxCode = bi.biTaxCode
	WHERE 
		(bi.btBillType = 1 OR bi.btBillType = 3)
		AND bi.biReversChargeVal = 0 
		AND taxCode.TaxCode = 4 
		AND (CAST([bi].[buDate] AS DATE) BETWEEN @DurationStartDate AND @DurationEndDate) 

	SELECT	
		@Adjustment = ISNULL(VatAmount, 0),
		@AdjustmentValue = ISNULL(Amount, 0)
	FROM 
		dbo.fnGCCGetBillTypeValuesAddedOAByTaxCode(3, @TaxDurationGUID, 4/*EX*/)

	UPDATE [#RESULT] 
	SET 
		Adjustment = @Adjustment,
		AdjustmentValue = @AdjustmentValue
	WHERE 
		RecID = 14

	SET @Adjustment = 0
	SET @AdjustmentValue = 0

	-- IG
	IF @IsSudiaGCCCountry != 0
	--BEGIN 
	--	INSERT INTO [#RESULT] (RecID,TaxCodingGuid,TaxCode,Title,Amount,VatAmount,Type)
	--	SELECT 
	--		15,
	--		taxCode.GUID,
	--		taxCode.TaxCode,
	--		'',
	--		ISNULL(sell.Amount,0) - ISNULL(retSell.Amount,0),
	--		ISNULL(sell. VatAmount,0) - ISNULL(retSell.VatAmount,0),
	--		1 -- Output
	--	FROM 
	--		dbo.fnGCCGetBillTypeValuesAddedTaxReturnByTaxCode(1, @TaxDurationGUID, 0x0, 0, 0) sell
	--		FULL JOIN dbo.fnGCCGetBillTypeValuesAddedTaxReturnByTaxCode(3, @TaxDurationGUID, 0x0, 0, 0) retSell ON sell.TaxCode = retSell.TaxCode
	--		RIGHT JOIN GCCTaxCoding000 taxCode ON taxCode.TaxCode = COALESCE(sell.[TaxCode] ,retSell.[TaxCode])
	--	WHERE taxCode.TaxCode = 5
	--END ELSE 
	BEGIN
		--  ’œÌ—
		INSERT INTO [#RESULT] (RecID, TaxCodingGUID, TaxCode, Amount, Type)
		SELECT 		
			15,
			MAX(taxCode.GUID),
			MAX(taxCode.TaxCode),
			ISNULL(SUM ( (CASE bi.btIsOutput WHEN 1 THEN 1 ELSE -1 END) * (bi.biQty * (bi.biUnitPrice - bi.biUnitDiscount + bi.biUnitExtra))), 0),
			1 -- Output	
		FROM 
			vwExtended_bi bi 
			RIGHT JOIN GCCTaxCoding000 taxCode ON taxCode.TaxCode = bi.biTaxCode
		WHERE 
			(bi.btBillType = 1 OR bi.btBillType = 3)
			-- AND bi.buIsPosted = 1
			AND bi.biReversChargeVal = 0 
			AND taxCode.TaxCode = 13 
			AND (CAST([bi].[buDate] AS DATE) BETWEEN @DurationStartDate AND @DurationEndDate) 

		SELECT	
			@Adjustment = ISNULL(VatAmount, 0),
			@AdjustmentValue = ISNULL(Amount, 0)
		FROM 
			dbo.fnGCCGetBillTypeValuesAddedOAByTaxCode(3, @TaxDurationGUID, 13/*XP*/)

		UPDATE [#RESULT] 
		SET 
			Adjustment = @Adjustment,
			AdjustmentValue = @AdjustmentValue
		WHERE 
			RecID = 15
	END
	SET @Adjustment = 0
	SET @AdjustmentValue = 0
	
	IF @IsSudiaGCCCountry = 0
	BEGIN 
		-- Output_GoodsImportedIntoTheUAE
		INSERT INTO [#RESULT] (RecID, Type, Code)
		SELECT 
		16,
		1, -- Output
		'6'

		SELECT @RCAmount = ISNULL(SUM(fn.Amount), 0), @RCVatAmount = ISNULL(SUM(fn.VatAmount), 0)
		FROM dbo.fnGCCGetBillTypeReverseChargeValuesAddedTaxReturn(0, @TaxDurationGUID, 0, 1, 1) fn

		SELECT @RCRetAmount = ISNULL(SUM(fn.Amount), 0), @RCRetVatAmount = ISNULL(SUM(fn.VatAmount), 0)
		FROM dbo.fnGCCGetBillTypeReverseChargeValuesAddedTaxReturn(1, @TaxDurationGUID, 0, 1, 1) fn

		SELECT @RCAdjustment = ISNULL(SUM(fn.VatAmount), 0), @RCAdjustmentValue = ISNULL(SUM(fn.Amount), 0)
		FROM dbo.fnGCCGetBillTypeReverseChargeValuesAddedTaxReturn(1, @TaxDurationGUID, 1, 1, 1) fn
		
		UPDATE [#RESULT]
		SET  
			Adjustment = @RCAdjustment,
			AdjustmentValue = @RCAdjustmentValue,
			Amount = @RCAmount - @RCRetAmount, 
			VatAmount = @RCVatAmount - @RCRetVatAmount
		WHERE RecID = 16

		-- Output_AdjustmentsAndAdditionsToGoodsImportedIntoTheUAE
		INSERT INTO [#RESULT] (RecID, Type, Code)
		SELECT 
		17,
		1, -- Output
		'7'
		SELECT @RCAmount = ISNULL(SUM(fn.Amount), 0), @RCVatAmount = ISNULL(SUM(fn.VatAmount), 0)
		FROM dbo.fnGCCGetBillTypeReverseChargeValuesAddedTaxReturn(0, @TaxDurationGUID, 0, 2, 1) fn

		SELECT @RCRetAmount = ISNULL(SUM(fn.Amount), 0), @RCRetVatAmount = ISNULL(SUM(fn.VatAmount), 0)
		FROM dbo.fnGCCGetBillTypeReverseChargeValuesAddedTaxReturn(1, @TaxDurationGUID, 0, 2, 1) fn

		SELECT @RCAdjustment = ISNULL(SUM(fn.VatAmount), 0), @RCAdjustmentValue = ISNULL(SUM(fn.Amount), 0)
		FROM dbo.fnGCCGetBillTypeReverseChargeValuesAddedTaxReturn(1, @TaxDurationGUID, 1, 2, 1) fn
		
		UPDATE [#RESULT]
		SET  
			Adjustment = @RCAdjustment,
			AdjustmentValue = @RCAdjustmentValue,
			Amount = @RCAmount - @RCRetAmount, 
			VatAmount = @RCVatAmount - @RCRetVatAmount
		WHERE RecID = 17
	END

	---------------------------------------------------------------------------
	------------------------------------------- Input ID: 200, 201, 202, 203, 204
	INSERT INTO [#RESULT] (RecID, TaxCodingGuid, TaxCode, Title, Amount, VatAmount, Type, Code)
	SELECT 
		200,
		taxCode.GUID,
		taxCode.TaxCode,
		'',
		ISNULL(purchase.Amount,0) - ISNULL(retPurchase.Amount,0),
		ISNULL(purchase. VatAmount,0) - ISNULL(retPurchase.VatAmount,0),
		2, -- Input 
		'9'
	FROM 
		dbo.fnGCCGetBillTypeValuesAddedTaxReturnByTaxCode(0, @TaxDurationGUID, 0x0, 1, 0) purchase
		FULL JOIN dbo.fnGCCGetBillTypeValuesAddedTaxReturnByTaxCode(2, @TaxDurationGUID, 0x0, 1, 0) retPurchase ON purchase.TaxCode = retPurchase.TaxCode
		RIGHT JOIN GCCTaxCoding000 taxCode ON taxCode.TaxCode = COALESCE(purchase.[TaxCode] ,retPurchase.[TaxCode])
	WHERE taxCode.taxCode = 1

	SELECT	
		@Adjustment = ISNULL(VatAmount, 0),
		@AdjustmentValue = ISNULL(Amount, 0)
	FROM 
		dbo.fnGCCGetBillTypeValuesAddedTaxReturnByTaxCode(2, @TaxDurationGUID, 0x0, 6, 1/*SR*/)

	UPDATE [#RESULT] 
	SET 
		Adjustment = @Adjustment,
		AdjustmentValue = @AdjustmentValue
	WHERE 
		RecID = 200 AND taxCode = 1

	SET @Adjustment = 0
	SET @AdjustmentValue = 0
	UPDATE [#RESULT] 
	SET 
		Amount = Amount + ISNULL(@PyInputTRAmount * 20 /*100 / 5*/, 0),
		VatAmount = VatAmount + ISNULL(@PyInputTRAmount, 0),
		[AdjustmentValue] = [AdjustmentValue] + ISNULL(@PyTRAdjustment * 20 /*100 / 5*/, 0),
		Adjustment = Adjustment + ISNULL(@PyTRAdjustment, 0)
	WHERE 
		RecID = 11 /*TR*/ AND [Type] = 1 /*output*/

	UPDATE [#RESULT] 
	SET 
		Amount = Amount + ISNULL(@PyInputSRAmount, 0),
		VatAmount = VatAmount + ISNULL(@PyInputVat, 0),
		[AdjustmentValue] = [AdjustmentValue] + ISNULL(@PySRAdjustment, 0),
		Adjustment = Adjustment + ISNULL(@PyAdjustment, 0)
	WHERE 
		RecID = 200 AND taxCode = 1

	IF @IsSudiaGCCCountry != 0
	BEGIN 
		--Input_GoodsImportedIntoTheUAE
		INSERT INTO [#RESULT] (RecID, Type)
		SELECT 
			201,
			2 -- Input

		SELECT  @RCAmount = ISNULL(SUM(fn.Amount), 0), @RCVatAmount = ISNULL(SUM(fn.VatAmount), 0)
		FROM dbo.fnGCCGetBillTypeReverseChargeValuesAddedTaxReturn(0, @TaxDurationGUID, 0, 1, 0) fn

		SELECT  @RCRetAmount = ISNULL(SUM(fn.Amount),0), @RCRetVatAmount= ISNULL(SUM(fn.VatAmount), 0)
		FROM dbo.fnGCCGetBillTypeReverseChargeValuesAddedTaxReturn(1, @TaxDurationGUID, 0, 1, 0) fn

		SELECT  @RCAdjustment = ISNULL(SUM(fn.VatAmount), 0), @RCAdjustmentValue = ISNULL(SUM(fn.Amount), 0)
		FROM dbo.fnGCCGetBillTypeReverseChargeValuesAddedTaxReturn(1, @TaxDurationGUID, 1, 1, 0) fn

		UPDATE [#RESULT]
		SET 
			Adjustment = @RCAdjustment,
			AdjustmentValue = @RCAdjustmentValue,
			Amount = @RCAmount - @RCRetAmount, 
			VatAmount = @RCVatAmount - @RCRetVatAmount
		WHERE RecID = 201
	END 

	--Input_RC
	INSERT INTO [#RESULT] (RecID, Type, Code)
	SELECT 202, 2, '10' -- Input 

	IF @IsSudiaGCCCountry != 0
	BEGIN 
		SELECT  @RCAmount = ISNULL(SUM(fn.Amount), 0), @RCVatAmount = 0
		FROM dbo.fnGCCGetBillTypeReverseChargeValuesAddedTaxReturn(0, @TaxDurationGUID, 0, 0, 0) fn

		SELECT  @RCRetAmount = ISNULL(SUM(fn.Amount),0), @RCRetVatAmount = 0
		FROM dbo.fnGCCGetBillTypeReverseChargeValuesAddedTaxReturn(1, @TaxDurationGUID, 0, 0, 0) fn

		SELECT  @RCAdjustmentValue = ISNULL(SUM(fn.Amount), 0), @RCAdjustment = 0
		FROM dbo.fnGCCGetBillTypeReverseChargeValuesAddedTaxReturn(1, @TaxDurationGUID, 1, 0, 0) fn
	END ELSE BEGIN 
		SELECT  @RCAmount = ISNULL(SUM(fn.Amount), 0), @RCVatAmount = ISNULL(SUM(fn.VatAmount), 0)
		FROM dbo.fnGCCGetBillTypeReverseChargeValuesAddedTaxReturn(0, @TaxDurationGUID, 0, -1, 0) fn

		SELECT  @RCRetAmount = ISNULL(SUM(fn.Amount),0), @RCRetVatAmount= ISNULL(SUM(fn.VatAmount), 0)
		FROM dbo.fnGCCGetBillTypeReverseChargeValuesAddedTaxReturn(1, @TaxDurationGUID, 0, -1, 0) fn

		SELECT  @RCAdjustmentValue = ISNULL(SUM(fn.Amount), 0), @RCAdjustment = ISNULL(SUM(fn.VatAmount), 0)
		FROM dbo.fnGCCGetBillTypeReverseChargeValuesAddedTaxReturn(1, @TaxDurationGUID, 1, -1, 0) fn
	END 
	UPDATE [#RESULT]
	SET 
		Adjustment = @RCAdjustment + @PyRCAdjustmentVat, 
		AdjustmentValue = @RCAdjustmentValue + @PyRCAdjustment, 
		Amount = @RCAmount - @RCRetAmount + @PyInputRCAmount, 
		VatAmount = @RCVatAmount - @RCRetVatAmount + @PyInputRCVat
	WHERE RecID = 202

	IF @IsSudiaGCCCountry != 0
	BEGIN 
		-- Input ZR 
		INSERT INTO [#RESULT] (RecID,TaxCodingGuid,TaxCode,Amount,Type)
		SELECT 		
			203,
			MAX(taxCode.GUID),
			MAX(taxCode.TaxCode),
			ISNULL(SUM ( CASE WHEN bi.btIsOutput = 0 THEN (bi.biQty * (bi.biUnitPrice - bi.biUnitDiscount + bi.biUnitExtra)) ELSE (-1 * (bi.biQty * (bi.biUnitPrice - bi.biUnitDiscount + bi.biUnitExtra))) END), 0),
			2 -- Input	
		FROM 
			vwExtended_bi bi 
			RIGHT JOIN GCCTaxCoding000 taxCode ON taxCode.TaxCode = bi.biTaxCode
		WHERE 
			(bi.btBillType = 0 OR bi.btBillType = 2)
			AND bi.biReversChargeVal = 0 
			AND taxCode.TaxCode = 3 
			AND (CAST([bi].[buDate] AS DATE) BETWEEN @DurationStartDate AND @DurationEndDate) 

		SELECT	
			@Adjustment = ISNULL(VatAmount, 0),
			@AdjustmentValue = ISNULL(Amount, 0)
		FROM 
			dbo.fnGCCGetBillTypeValuesAddedOAByTaxCode(2, @TaxDurationGUID, 3/*ZR*/)

		UPDATE [#RESULT] 
		SET 
			Adjustment = @Adjustment,
			AdjustmentValue = @AdjustmentValue
		WHERE 
			RecID = 203

		SET @Adjustment = 0
		SET @AdjustmentValue = 0

		-- EX
		INSERT INTO [#RESULT] (RecID,TaxCodingGuid,TaxCode,Amount,Type)
		SELECT 		
			204,
			MAX(taxCode.GUID),
			MAX(taxCode.TaxCode),
			ISNULL(SUM ( CASE WHEN bi.btIsOutput = 0 THEN (bi.biQty * (bi.biUnitPrice - bi.biUnitDiscount + bi.biUnitExtra)) ELSE (-1 * (bi.biQty * (bi.biUnitPrice - bi.biUnitDiscount + bi.biUnitExtra))) END), 0),
			2 -- Input	
		FROM 
			vwExtended_bi bi 
			RIGHT JOIN GCCTaxCoding000 taxCode ON taxCode.TaxCode = bi.biTaxCode
		WHERE 
			(bi.btBillType = 0 OR bi.btBillType = 2)
			AND bi.biReversChargeVal = 0 
			AND taxCode.TaxCode = 4 
			AND (CAST([bi].[buDate] AS DATE) BETWEEN @DurationStartDate AND @DurationEndDate) 

		SELECT	
			@Adjustment = ISNULL(VatAmount, 0),
			@AdjustmentValue = ISNULL(Amount, 0)
		FROM 
			dbo.fnGCCGetBillTypeValuesAddedOAByTaxCode(2, @TaxDurationGUID, 4/*EX*/)

		UPDATE [#RESULT] 
		SET 
			Adjustment = @Adjustment,
			AdjustmentValue = @AdjustmentValue
		WHERE 
			RecID = 204
	END

	--Input_ZR
	IF ISNULL(@PyInputZRAmount, 0) != 0 OR ISNULL(@PyZRAdjustment, 0) != 0
	BEGIN
		IF NOT EXISTS(SELECT 1 FROM [#RESULT] WHERE RecID = 203)
		BEGIN
			INSERT INTO [#RESULT] (RecID, Amount, [AdjustmentValue], Type)
			SELECT 203, ISNULL(@PyInputZRAmount, 0), ISNULL(@PyZRAdjustment, 0), 2 -- Input 
		END
		ELSE
		BEGIN
			UPDATE [#RESULT] 
			SET 
				Amount = Amount + ISNULL(@PyInputZRAmount, 0),
				[AdjustmentValue] = [AdjustmentValue] + ISNULL(@PyZRAdjustment, 0)
			WHERE 
				RecID = 203
		END
	END

	--Input_EX
	IF ISNULL(@PyInputEXAmount, 0) != 0 OR ISNULL(@PyEXAdjustment, 0) != 0
	BEGIN
		IF NOT EXISTS(SELECT 1 FROM [#RESULT] WHERE RecID = 204)
		BEGIN
			INSERT INTO [#RESULT] (RecID, Amount, [AdjustmentValue], Type)
			SELECT 204, ISNULL(@PyInputEXAmount, 0), ISNULL(@PyEXAdjustment, 0), 2 -- Input 
		END
		ELSE
		BEGIN
			UPDATE [#RESULT] 
			SET 
				Amount = Amount + ISNULL(@PyInputEXAmount, 0),
				[AdjustmentValue] = [AdjustmentValue] + ISNULL(@PyEXAdjustment, 0)
			WHERE 
				RecID = 204
		END
	END

	-- Output_Total
	INSERT INTO [#RESULT] (RecID, Amount, VatAmount, Adjustment, AdjustmentValue, Type, Code)
	SELECT 
		199,
		SUM( CASE WHEN @IsSudiaGCCCountry = 0 AND RecID = 11 THEN -1 ELSE 1 END * Amount),
		SUM( CASE WHEN @IsSudiaGCCCountry = 0 AND RecID = 11 THEN -1 ELSE 1 END * VatAmount),
		SUM(Adjustment),
		SUM(AdjustmentValue),
		1, -- Output
		'8'
	FROM [#RESULT] WHERE [Type] = 1

	-- Input_Total
	INSERT INTO [#RESULT] (RecID, Amount, VatAmount, Adjustment, AdjustmentValue, Type, Code)
	SELECT 
		299,
		SUM(Amount),
		SUM(VatAmount),
		SUM(Adjustment),
		SUM(AdjustmentValue),
		2, -- Input
		'11'
	FROM [#RESULT] WHERE [Type] = 2

	------------------------------------------- NetVATDue ID: 300,301,302
	INSERT INTO [#RESULT] (RecID, Amount, Type, Code)
	SELECT 
		300,
		VatAmount - Adjustment,
		3, -- NetVATDue 
		'12'
	FROM [#RESULT]
	WHERE RecID = 199 --total output

	INSERT INTO [#RESULT] (RecID, Amount, Type, Code)
	SELECT 
		301,
		ISNULL(VatAmount - Adjustment, 0),
		3, -- NetVATDue 
		'13'
	FROM [#RESULT]
	WHERE RecID = 299 --total input

	DECLARE @NetVatPayable [FLOAT] =  (
		SELECT(r1.Amount - r2.Amount )
		FROM 
			[#RESULT]  r1  
			CROSS JOIN [#RESULT] r2 
		WHERE  r1.RecID = 300 AND r2.RecID = 301)

	INSERT INTO [#RESULT] (RecID, Amount, Type, Code)
	SELECT 
		302,
		ISNULL((@NetVatPayable),0),
		3, -- NetVATDue 
		'14'

	UPDATE [#RESULT] SET Number = RecID

	IF @IsSudiaGCCCountry = 1
	BEGIN 
		UPDATE [#RESULT] SET VatAmount = VatAmount - Adjustment
		UPDATE [#RESULT] SET Number = 14 WHERE RecID = 15
		UPDATE [#RESULT] SET Number = 15 WHERE RecID = 14
	END
	
	-- SELECT DISTINCT [Type] FROM [#RESULT] 
	SELECT * FROM [#RESULT] ORDER BY Number, LocationNumber
##################################################################################
CREATE PROCEDURE prcGCC_VATTaxReport_Save
	@TaxDurationGUID UNIQUEIDENTIFIER
AS
	SET NOCOUNT ON

	IF ISNULL(@TaxDurationGUID, 0X0) = 0x0 
		RETURN 

	DECLARE 
		@DurationStartDate DATE,
		@DurationEndDate DATE,
		@DurationState INT,
		@IsTransfered BIT,
		@DurationReportGUID UNIQUEIDENTIFIER,
		@IsCrossedDuration BIT		

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
		SET @IsCrossedDuration = 1

	CREATE TABLE [#EndResult] (
		[RecID] INT, -- 1 SR Local Location, 11 Output Tax Refunds Provided To Tourists, 
		[Title] NVARCHAR (250) DEFAULT(''),
		[Amount] FLOAT DEFAULT(0),
		[VatAmount]	FLOAT DEFAULT(0),
		[Adjustment] FLOAT DEFAULT(0),
		[AdjustmentValue] FLOAT DEFAULT(0),
		[Type]	INT, -- 1 Output, 2 Input , 3 NetVATDue
		[LocationGUID] UNIQUEIDENTIFIER DEFAULT(0x0),
		[LocationNumber] INT DEFAULT(0),
		[TaxCodingGUID] UNIQUEIDENTIFIER DEFAULT(0x0),
		[TaxCode] INT DEFAULT(0),
		[Number] INT DEFAULT(0), 
		[Code] NVARCHAR(10) DEFAULT(''))
	
	IF @IsCrossedDuration = 1 -- AND @DurationState = 0
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
			SET @Statement =  N'INSERT INTO [#EndResult] EXEC [' + @currentDbName + '].[dbo].[prcGCCValueAddedTaxReturnRep] ' +
				'''' + CONVERT(NVARCHAR(38), @TaxDurationGUID) + ''', 1' 
			EXEC sp_executesql @Statement;

			SET @Statement =  N'UPDATE [' + @currentDbName + '].[dbo].[GCCTaxDurations000] SET [State] = 1, [CloseDate] = GETDATE(), ' +
				' CloseUserGUID = ''' + CONVERT(NVARCHAR(38), @UserGUID) + ''' WHERE GUID = ''' + CONVERT(NVARCHAR(38), @TaxDurationGUID) + '''' +
				' AND [State] != 1 '
			EXEC sp_executesql @Statement;

			FETCH NEXT FROM @AllDatabases INTO @currentDbName, @currentFirstPeriodDate, @currentEndPeriodDate;
		END
	END 
	INSERT INTO [#EndResult] EXEC prcGCCValueAddedTaxReturnRep @TaxDurationGUID

	IF NOT EXISTS (SELECT * FROM [#EndResult])
		RETURN 

	IF EXISTS(SELECT * FROM GCCTaxDurations000 WHERE GUID = @TaxDurationGUID AND ISNULL(TaxVatReportGUID, 0x0) != 0x0)
	BEGIN 
		DELETE GCCTaxVatReports000 WHERE GUID = (SELECT TOP 1 TaxVatReportGUID FROM GCCTaxDurations000 WHERE GUID = @TaxDurationGUID)
		DELETE GCCTaxVatReportDetails000 WHERE ParentGUID = (SELECT TOP 1 TaxVatReportGUID FROM GCCTaxDurations000 WHERE GUID = @TaxDurationGUID)
	END 

	DECLARE @ReportGUID UNIQUEIDENTIFIER
	SET @ReportGUID = NEWID()

	INSERT INTO GCCTaxVatReports000([Number], [GUID], [CreateDate], [CreateUserGUID])
	SELECT 
		ISNULL((SELECT MAX(Number) FROM GCCTaxVatReports000), 0) + 1,
		@ReportGUID, GETDATE(), [dbo].[fnGetCurrentUserGUID]()

	INSERT INTO GCCTaxVatReportDetails000(
		[GUID], [ParentGUID], [RecID], [Amount], [VatAmount], [Adjustment], [AdjustmentValue],
		[Type], [LocationGuid], [LocationNumber], [TaxCodingGuid], [TaxCode], [Number])
	SELECT 
		NEWID(),
		@ReportGUID,
		[RecID],
		SUM(ISNULL([Amount], 0)),
		SUM(ISNULL([VatAmount], 0)),
		SUM(ISNULL([Adjustment], 0)),
		SUM(ISNULL([AdjustmentValue], 0)),
		[Type],
		ISNULL([LocationGUID], 0x0),
		ISNULL([LocationNumber], 0),
		ISNULL([TaxCodingGUID], 0x0),
		ISNULL([TaxCode], ''),
		[Number]
	FROM [#EndResult]
	GROUP BY
		[RecID],
		[Type],
		[LocationGUID],
		[LocationNumber],
		[TaxCodingGUID],
		[TaxCode],
		[Number]
	ORDER BY Number, LocationNumber

	UPDATE GCCTaxDurations000 SET TaxVatReportGUID = @ReportGUID WHERE GUID = @TaxDurationGUID
##################################################################################
CREATE PROCEDURE repGCC_VATTaxReport
	@TaxDurationGUID UNIQUEIDENTIFIER,
	@IsCalcReportFromDetails BIT = 1,
	@ReturnForXml Bit = 0
AS
	SET NOCOUNT ON

	CREATE TABLE [#EndResult] (
		[RecID] INT, -- 1 SR Local Location, 11 Output Tax Refunds Provided To Tourists, 
		[Title] NVARCHAR (250) DEFAULT(''),
		[Amount] FLOAT DEFAULT(0),
		[VatAmount]	FLOAT DEFAULT(0),
		[Adjustment] FLOAT DEFAULT(0),
		[AdjustmentValue] FLOAT DEFAULT(0),
		[Type]	INT, -- 1 Output, 2 Input , 3 NetVATDue
		[LocationGUID] UNIQUEIDENTIFIER DEFAULT(0x0),
		[LocationNumber] INT DEFAULT(0),
		[TaxCodingGUID] UNIQUEIDENTIFIER DEFAULT(0x0),
		[TaxCode] INT DEFAULT(0),
		[Number] INT DEFAULT(0),
		[Code] NVARCHAR(10) DEFAULT(''))
	
	CREATE TABLE #NotifyResult (ID INT) -- 0 before crossed, 1 before crossed and no prev file, 2 after crossed, 3 saved,

	IF ISNULL(@TaxDurationGUID, 0X0) = 0x0 
	BEGIN
		IF @ReturnForXml = 0
		BEGIN 
			SELECT * FROM #NotifyResult
			SELECT DISTINCT [Type] FROM [#EndResult]
			SELECT * FROM [#EndResult]
		END
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

	IF (@DurationReportGUID != 0x0) AND @IsCalcReportFromDetails = 0 AND @DurationState = 1 AND @ReturnForXml = 0 AND
		EXISTS (SELECT * FROM GCCTaxVatReportDetails000 WHERE ParentGUID = @DurationReportGUID)
	BEGIN 
		INSERT INTO #NotifyResult SELECT 3 -- saved
		SELECT * FROM #NotifyResult

		SELECT DISTINCT [Type] FROM GCCTaxVatReportDetails000 WHERE ParentGUID = @DurationReportGUID
		
		SELECT d.*, ISNULL((CASE WHEN @language <> 0 THEN loc.LatinName ELSE loc.Name END), '') AS [Title] 
		FROM 
			GCCTaxVatReportDetails000 d 
			LEFT JOIN GCCCustLocations000 loc ON loc.GUID = d.LocationGUID 
		WHERE 
			ParentGUID = @DurationReportGUID 
		ORDER BY 
			Number, LocationNumber

		RETURN
	END

	IF @IsTransfered = 1 AND @DurationState = 0 AND @IsCrossedDuration = 0 AND @ReturnForXml = 0
	BEGIN
		SELECT * FROM #NotifyResult
		SELECT DISTINCT [Type] FROM [#EndResult]
		SELECT * FROM [#EndResult]

		RETURN 
	END 

	CREATE TABLE #DB(FOUND BIT)
	IF @IsCrossedDuration = 1 -- AND @IsCalcReportFromDetails = 1
	BEGIN 
		DECLARE 
			@AllDatabases CURSOR,
			@currentDbName NVARCHAR(128),
			@currentFirstPeriodDate DATE,
			@currentEndPeriodDate DATE,
			@Statement NVARCHAR(MAX)

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

				SET @Statement =  N'INSERT INTO [#EndResult] EXEC [' + @currentDbName + '].[dbo].[prcGCCValueAddedTaxReturnRep] ' +
					'''' + CONVERT(NVARCHAR(38), @TaxDurationGUID) + ''', 1' 
				EXEC sp_executesql @Statement;
			END
			FETCH NEXT FROM @AllDatabases INTO @currentDbName, @currentFirstPeriodDate, @currentEndPeriodDate;
		END
	END 
	INSERT INTO [#EndResult] EXEC prcGCCValueAddedTaxReturnRep @TaxDurationGUID

	------------------------------ 
	IF (@ReturnForXml = 0)
	BEGIN 
		IF @IsCrossedDuration > 0 AND NOT EXISTS(SELECT * FROM #DB)
			INSERT INTO #NotifyResult SELECT 1

		SELECT * FROM #NotifyResult
		------------------------------ 
		SELECT DISTINCT [Type] FROM [#EndResult]
		------------------------------ 
		SELECT 
			[RecID], -- 1 SR Local Location, 11 Output Tax Refunds Provided To Tourists, 
			[Title],
			SUM([Amount]) AS [Amount],
			SUM([VatAmount]) AS [VatAmount],
			SUM([Adjustment]) AS [Adjustment],
			SUM([AdjustmentValue]) AS [AdjustmentValue],
			[Type],
			[LocationGUID],
			[LocationNumber],
			-- ISNULL([TaxCodingGUID], 0x0) AS [TaxCodingGUID],
			ISNULL([TaxCode], 0) AS [TaxCode],
			[Number],
			[Code]
		FROM 
			[#EndResult]
		GROUP BY
			[RecID],
			[Title],
			[Type],
			[LocationGUID],
			[LocationNumber],
			-- [TaxCodingGUID],
			[TaxCode],
			[Number],
			[Code]
		ORDER BY Number, LocationNumber
	END ELSE BEGIN 
		--outputSales
		SELECT * 
		FROM [#EndResult]
		WHERE 
			[RecID] = 1 
			OR [RecID] = 11
			OR [RecID] = 12
			OR [RecID] = 13 
			OR [RecID] = 14
			OR [RecID] = 15  
			OR [RecID] = 199 -- total output 
		ORDER BY RecID, LocationNumber  
			
		--inputPurchases
		SELECT * 
		FROM [#EndResult]
		WHERE 
			[RecID] = 200
			OR [RecID] = 202 
			OR [RecID] = 299 -- total input 
		ORDER BY RecID  

		--goodsTransferedGCC
		SELECT 
			0 AS [Amount]
			,0 AS [VatAmount]
			,0 AS [Adjustment]
			,GUID AS [LocationGuid]		
		FROM 
			GCCCustLocations000 loc
		WHERE 
			Classification = 1
			AND ParentLocationGUID <> 0x0
		ORDER BY Number	

		--vataPaidViaAgent
		SELECT 
			0 AS [Amount]
			,0 AS [VatAmount]
			,0 AS [Adjustment]
			,GUID AS [LocationGuid]		
		FROM 
			GCCCustLocations000 loc
		WHERE 
			Classification = 1
			AND ParentLocationGUID <> 0x0
		ORDER BY Number	

		--transportOwnGoodsGCC
		SELECT 
			0 AS [Amount]
			,0 AS [VatAmount]
			,0 AS [Adjustment]
			,GUID AS [LocationGuid]		
		FROM 
			GCCCustLocations000 loc
		WHERE 
			Classification = 1
			AND ParentLocationGUID <> 0x0
		ORDER BY Number	

		--recoverableVATPaidGCC
		SELECT 
			0 AS [Amount]
			,0 AS [VatAmount]
			,0 AS [Adjustment]
			,GUID AS [LocationGuid]		
		FROM 
			GCCCustLocations000 loc
		WHERE 
			Classification = 1
			AND ParentLocationGUID <> 0x0
		ORDER BY Number	

		--touristRefund
		SELECT 
			0 AS [Amount]
			,0 AS [VatAmount]
			,0 AS [Adjustment]
			,GUID AS [LocationGuid]		
		FROM 
			GCCCustLocations000 loc
		WHERE 
			Classification = 0
			AND ParentLocationGUID <> 0x0
		ORDER BY Number	
	END
##################################################################################
#END
