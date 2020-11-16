################################################################################
CREATE PROCEDURE prcGCC_TaxDuration_VerifyEntry
	@TaxDurationGUID UNIQUEIDENTIFIER
AS
	SET NOCOUNT ON
	/*
	TODO:
		7- Â«„‘ «·—»Õ ø 
		9- »«·‰”»… ··ÿ·»Ì«  ø
		10- «–« ﬂ«‰  «—ÌŒ «·›« Ê—… «·√’·Ì… ﬁ»· 2018 «· Õﬁﬁ „‰ √‰Â ·« ÌÊÃœ ⁄·ÌÂ« ÷—Ì»…
	*/
	DECLARE @Lang INT = (SELECT [dbo].[fnConnections_GetLanguage]())
	DECLARE @TaxDurationStartDate DATE
	DECLARE @TaxDurationEndDate   DATE	
	DECLARE @IgnoredValue FLOAT
	SET @IgnoredValue = 0.01

	SELECT 
		@TaxDurationStartDate = [StartDate],
		@TaxDurationEndDate = [EndDate]		
	FROM GCCTaxDurations000 WHERE [GUID] = @TaxDurationGUID

	DECLARE @OpenEntyTypeGUID UNIQUEIDENTIFIER
	SET @OpenEntyTypeGUID = 'EA69BA80-662D-4FA4-90EE-4D2E1988A8EA'

	-- FIRST RESULT --
	--Check bills tax Codes and values
	EXEC prcGCCResetBillsTaxes 2, 1, @TaxDurationGUID

	SELECT DISTINCT
		BI.ParentGUID AS BillGUID,
		B.BuNumber AS Bill,
		CASE WHEN B.ErrNumber <> 0 THEN B.ErrNumber
			ELSE CASE WHEN BI.TaxCode <> NBI.VATTaxCode THEN 100
				ELSE CASE WHEN ABS(BI.VAT - NBI.Vat) > @IgnoredValue THEN 101
					ELSE CASE WHEN BI.VATRatio <> NBI.VatRatio THEN 102
						ELSE CASE WHEN ABS(BI.ExciseTaxVal - NBI.Excise) > @IgnoredValue THEN 103
							ELSE CASE WHEN BI.ExciseTaxPercent <> NBI.ExciseRatio THEN 104
								ELSE CASE WHEN BI.ExciseTaxCode <> NBI.ExciseTaxCode THEN 105
									ELSE CASE WHEN (B.IsPurchaseRePurchase = 1 AND (ABS(BI.PurchaseVal - NBI.PurchaseVal) > @IgnoredValue)) THEN 106
										ELSE CASE WHEN (B.IsPurchaseRePurchase = 1 AND (ABS(BI.ReversChargeVal - NBI.ReversCharge) > @IgnoredValue)) THEN 107
											ELSE 0 END
										END
									END
								END
							END
						END
					END
				END
			END AS ErrorNumber,
			B.[buDate],
			B.[buNumber]
	INTO #B
	FROM
		bi000 AS BI
		JOIN ##BillsItems AS NBI ON BI.GUID = NBI.BiGuid
		JOIN ##Bills AS B ON B.BuGUID = BI.ParentGUID
	WHERE 
		BI.TaxCode <> NBI.VATTaxCode
		OR ABS(BI.VAT - NBI.Vat) > @IgnoredValue
		OR BI.VATRatio <> NBI.VatRatio
		OR ABS(BI.ExciseTaxVal - NBI.Excise) > @IgnoredValue
		OR BI.ExciseTaxPercent <> NBI.ExciseRatio
		OR BI.ExciseTaxCode <> NBI.ExciseTaxCode
		OR (B.IsPurchaseRePurchase = 1 AND (ABS(BI.PurchaseVal - NBI.PurchaseVal) > @IgnoredValue))
		OR (B.IsPurchaseRePurchase = 1 AND (ABS(BI.ReversChargeVal - NBI.ReversCharge) > @IgnoredValue))
		OR B.ErrNumber > 0
	ORDER BY B.[buDate],B.[buNumber]

	SELECT * FROM #B
	WHERE 
		-- ≈·€«¡ „Ì“… «· Õﬁﬁ „‰ «· —„Ì“ «·÷—Ì»Ì ›Ì «· Õﬁﬁ« 
		ErrorNumber <> 100

	-- SECOND RESULT --
	-- Bill in tax duration and  generated entry
	SELECT 
		BU.[GUID] AS BillGUID,
		CAST(BU.Number AS NVARCHAR(250)) + ' - ' +
		CASE @Lang WHEN 0 THEN BT.Name 
				   ELSE CASE BT.LatinName WHEN '' THEN BT.Name 
										  ELSE BT.LatinName END END AS Bill 
	FROM 
		bu000 BU 
		INNER JOIN bt000 BT ON BU.TypeGUID = BT.[GUID]
		LEFT  JOIN er000 ER ON BU.[GUID] = ER.ParentGUID
	WHERE 
		BT.bNoEntry = 0
		AND BT.BillType IN (0, 1, 2, 3)
		AND BT.[Type] = 1
		AND	CAST(BU.[Date] AS DATE) BETWEEN @TaxDurationStartDate AND @TaxDurationEndDate
		AND ER.ParentGUID IS NULL
		AND Not exists ( SELECT * FROM bi000 BI WHERE ParentGuid = BU.GUID AND Price = 0 )

	--Bill in tax duration and does not generated entry
		SELECT 
		BU.[GUID] AS BillGUID,
		CAST(BU.Number AS NVARCHAR(250)) + ' - ' +
		CASE @Lang WHEN 0 THEN BT.Name 
				   ELSE CASE BT.LatinName WHEN '' THEN BT.Name 
										  ELSE BT.LatinName END END AS Bill 
	FROM 
		bu000 BU 
		INNER JOIN bt000 BT ON BU.TypeGUID = BT.[GUID]
		LEFT  JOIN er000 ER ON BU.[GUID] = ER.ParentGUID
	WHERE 
		BT.bNoEntry = 0
		AND BT.BillType IN (0, 1, 2, 3)
		AND BU.Total = 0
		AND BT.[Type] = 1
		AND	CAST(BU.[Date] AS DATE) BETWEEN @TaxDurationStartDate AND @TaxDurationEndDate
		AND ER.ParentGUID IS NULL

	-- THIRD RESULT --
	-- Bill in tax duration with incorrect VAT account generated entry
	--- TODO: 
	-- ÌÃ»  ›’Ì· «·Œÿ√ Â· «·Õ”«» €Ì— „ÊÃÊœ ÷„‰ «·Õ”«»«  «·«› —«÷Ì… √„ €Ì— „ÿ«»ﬁ ·Õ”«»«  «·„Êﬁ⁄
	;WITH BU AS
	(
		SELECT 
			BU.[GUID] AS BillGUID,
			CAST(BU.Number AS NVARCHAR(250)) + ' - ' +
			CASE @Lang WHEN 0 THEN BT.Name 
					   ELSE CASE BT.LatinName WHEN '' THEN BT.Name 
											  ELSE BT.LatinName END END AS Bill,
			BU.IsTaxPayedByAgent,
			CASE WHEN Cl.Classification = 0 THEN (CASE ISNULL(BU.GCCLocationGUID, 0x0) WHEN 0x0 THEN CL.VATAccGUID ELSE BL.VATAccGUID END) ELSE CL.VATAccGUID END AS VATAccGUID,
			CASE WHEN Cl.Classification = 0 THEN (CASE ISNULL(BU.GCCLocationGUID, 0x0) WHEN 0x0 THEN CL.ReturnAccGUID ELSE BL.ReturnAccGUID END) ELSE CL.ReturnAccGUID END AS ReturnAccGUID,
			BU.VATAccGUID AS VATAgentAccGUID
		FROM 
			bu000 BU 
			INNER JOIN bt000 AS BT ON BU.TypeGUID  = BT.[GUID]
			JOIN cu000 AS CU ON CU.GUID = BU.CustGUID
			JOIN GCCCustLocations000 AS CL ON CL.GUID = CU.GCCLocationGUID
			LEFT JOIN GCCCustLocations000 AS L ON L.GUID = bt.DefaultLocationGUID
			LEFT JOIN GCCCustLocations000 AS BL ON BL.GUID = BU.GCCLocationGUID
		WHERE 
			BT.bNoEntry = 0
			AND BT.BillType IN (0, 1, 2, 3)
			AND BT.[Type] = 1
			AND	CAST(BU.[Date] AS DATE) BETWEEN @TaxDurationStartDate AND @TaxDurationEndDate
	)
	SELECT DISTINCT
		BU.BillGUID,
		BU.Bill
	FROM 
		BU
		LEFT  JOIN er000 ER ON BU.BillGUID	= ER.ParentGUID
		LEFT  JOIN ce000 CE ON ER.EntryGUID = CE.[GUID]
		LEFT  JOIN en000 EN ON CE.[GUID]	= EN.ParentGUID
	WHERE 
		(
			CE.IsPosted = 0
			OR (EN.[Type] = 201 AND En.AccountGUID NOT IN (SELECT VATAccGUID FROM GCCTaxAccounts000) AND BU.IsTaxPayedByAgent <> 1) 
			OR (EN.[Type] = 202 AND En.AccountGUID NOT IN (SELECT ReturnAccGUID FROM GCCTaxAccounts000) AND BU.IsTaxPayedByAgent <> 1)
			OR (EN.[Type] = 201 AND ((En.AccountGUID <> BU.VATAccGUID AND BU.IsTaxPayedByAgent = 0) OR (BU.IsTaxPayedByAgent = 1 AND En.AccountGUID <> BU.VATAgentAccGUID) ))
			OR (EN.[Type] = 202 AND ((En.AccountGUID <> BU.ReturnAccGUID AND BU.IsTaxPayedByAgent = 0) OR (BU.IsTaxPayedByAgent = 1 AND En.AccountGUID <> BU.VATAgentAccGUID) ))
		)

	--FOURTH RESULT
	-- Bill in tax duration with incorrect generated entry
	SELECT 
		BU.[GUID] AS BillGUID,
		CAST(BU.Number AS NVARCHAR(250)) + ' - ' +
		CASE @Lang WHEN 0 THEN BT.Name 
				   ELSE CASE BT.LatinName WHEN '' THEN BT.Name 
										  ELSE BT.LatinName END END    AS Bill 
	FROM 
		bu000 BU 
		INNER JOIN bt000 BT ON BU.TypeGUID  = BT.[GUID]
		LEFT  JOIN er000 ER ON BU.[GUID]	= ER.ParentGUID
		LEFT  JOIN ce000 CE ON ER.EntryGUID = CE.[GUID]
		LEFT  JOIN en000 EN ON CE.[GUID]	= EN.ParentGUID
	WHERE 
		BT.bNoEntry = 0
		AND BT.BillType IN (0, 1, 2, 3)
		AND BT.[Type] = 1
		AND	CAST(BU.[Date] AS DATE) BETWEEN @TaxDurationStartDate AND @TaxDurationEndDate
		AND	
		(
			CE.IsPosted = 0
			OR (EN.[Type] = 203 AND (En.AccountGUID NOT IN (SELECT ExciseTaxAccGUID FROM GCCTaxAccounts000)))
			OR (EN.[Type] = 204 AND (En.AccountGUID NOT IN (SELECT ReturnExciseTaxAccGUID FROM GCCTaxAccounts000)))
			OR (EN.[Type] = 205 AND (En.AccountGUID NOT IN (SELECT ReverseChargesAccGUID FROM GCCTaxAccounts000)))
			OR (EN.[Type] = 206 AND (En.AccountGUID NOT IN (SELECT ReturnReverseChargesAccGUID FROM GCCTaxAccounts000)) AND En.AccountGUID <> BU.ReversChargeReturn)
			OR (EN.[Type] = 203 AND En.AccountGUID <> BT.ExciseAccGUID)
			OR (EN.[Type] = 204 AND En.AccountGUID <> BT.ExciseContraAccGUID)
			OR (EN.[Type] = 205 AND En.AccountGUID <> BT.ReverseChargesAccGUID)
			OR (EN.[Type] = 206 AND En.AccountGUID <> BT.ReverseChargesContraAccGUID AND En.AccountGUID <> BU.ReversChargeReturn)
		)

	-----------------------------------------------------
	-----------------------------------------------------
	-- ÷—Ì»… «·”‰œ« 
	-- ›Ì ‰„ÿ «·”‰œ Ì” Œœ„ ÷—Ì»… ÌÃ» √‰ ÌﬂÊ‰ ﬂ· Õ”«» Ì” Œœ„ ÷—Ì»… „ Õ—ﬂ „⁄ “»Ê‰

	DECLARE 
		@PaymentsSubscriptionDate DATE,
		@NoDate DATE 
	SET @PaymentsSubscriptionDate = ISNULL((SELECT TOP 1 PaymentsSubscriptionDate FROM GCCTaxSettings000),'01-01-1980' )
	SET @NoDate = '01-01-1980'

	SELECT DISTINCT
		py.GUID AS PayGUID,
		CASE @Lang WHEN 0 THEN ET.Name 
				   ELSE CASE ET.LatinName WHEN '' THEN ET.Name 
										  ELSE ET.LatinName END 
		END + ': ' + CAST(py.Number AS NVARCHAR(250)) AS PayNumber 
	FROM 
		ac000 ac
		INNER JOIN en000 en ON en.AccountGUID = ac.GUID 
		INNER JOIN ce000 ce ON en.ParentGUID = ce.GUID 
		INNER JOIN er000 er ON er.EntryGUID = ce.GUID 
		INNER JOIN py000 py ON er.ParentGUID = py.GUID 
		INNER JOIN et000 et ON py.TypeGUID = et.GUID 
		LEFT JOIN cu000 cu ON en.CustomerGUID = cu.GUID
	WHERE 
		ISNULL(et.TaxType, 0) != 0 
		AND 
		ISNULL(ac.IsUsingAddedValue, 0) <> 0
		AND 
		CAST(en.[Date] AS DATE) BETWEEN @TaxDurationStartDate AND @TaxDurationEndDate 
		AND 
		CAST(en.[Date] AS DATE) >= @PaymentsSubscriptionDate
		AND 
		@PaymentsSubscriptionDate != @NoDate
		AND 
		ISNULL(cu.GUID, 0x0) = 0x0
		AND 
		en.Type != 450

	-- ›Ì ‰„ÿ «·”‰œ Ì” Œœ„ «·÷—Ì»… ÌÃ» √‰ ÌﬂÊ‰ Õ”«»«  «·—”Ê„ «·⁄ﬂ”Ì… „Õœœ…
	SELECT DISTINCT
		py.GUID AS PayGUID,
		CASE @Lang WHEN 0 THEN ET.Name 
				   ELSE CASE ET.LatinName WHEN '' THEN ET.Name 
										  ELSE ET.LatinName END 
		END + ': ' + CAST(py.Number AS NVARCHAR(250)) AS PayNumber 
	FROM 
		ac000 ac
		INNER JOIN en000 en ON en.AccountGUID = ac.GUID 
		INNER JOIN ce000 ce ON en.ParentGUID = ce.GUID 
		INNER JOIN er000 er ON er.EntryGUID = ce.GUID 
		INNER JOIN py000 py ON er.ParentGUID = py.GUID 
		INNER JOIN et000 et ON py.TypeGUID = et.GUID 
	WHERE 
		ISNULL(et.TaxType, 0) != 0 
		AND
		ISNULL(et.UseReverseCharges, 0) = 1 
		AND
		(ISNULL(et.ReverseChargesAccGUID, 0x0) = 0x0 OR ISNULL(et.ReverseChargesContraAccGUID, 0x0) = 0x0)
		AND 
		CAST(en.[Date] AS DATE) BETWEEN @TaxDurationStartDate AND @TaxDurationEndDate
		AND 
		CAST(en.[Date] AS DATE) >= @PaymentsSubscriptionDate
		AND 
		@PaymentsSubscriptionDate != @NoDate
		AND 
		en.Type != 450

	-- ÊÃÊœ ‰„ÿ ”‰œ ·« Ì” Œœ„ «·÷—Ì»… ⁄·ÌÂ Õ—ﬂ«  ÷„‰ «·› —… »Õ”«»«   ” Œœ„ «·÷—Ì»… »«” À‰«¡ «·ﬁÌœ «·«›  «ÕÌ
	SELECT DISTINCT
		py.GUID AS PayGUID,
		CASE @Lang WHEN 0 THEN ET.Name 
				   ELSE CASE ET.LatinName WHEN '' THEN ET.Name 
										  ELSE ET.LatinName END 
		END + ': ' + CAST(py.Number AS NVARCHAR(250)) AS PayNumber 
	FROM 
		ac000 ac
		INNER JOIN en000 en ON en.AccountGUID = ac.GUID 
		INNER JOIN ce000 ce ON en.ParentGUID = ce.GUID 
		INNER JOIN er000 er ON er.EntryGUID = ce.GUID 
		INNER JOIN py000 py ON er.ParentGUID = py.GUID 
		INNER JOIN et000 et ON py.TypeGUID = et.GUID 
	WHERE 
		ISNULL(et.TaxType, 0) = 0
		AND
		ISNULL(et.GUID, 0x0) != @OpenEntyTypeGUID
		AND 
		ISNULL(ac.IsUsingAddedValue, 0) <> 0
		AND 
		CAST(en.[Date] AS DATE) BETWEEN @TaxDurationStartDate AND @TaxDurationEndDate
		AND 
		CAST(en.[Date] AS DATE) >= @PaymentsSubscriptionDate
		AND 
		@PaymentsSubscriptionDate != @NoDate

	SELECT DISTINCT
		ce.GUID AS EntryGUID,
		CAST(ce.Number AS NVARCHAR(250)) AS EntryNumber 
	FROM 
		ac000 ac
		INNER JOIN en000 en ON en.AccountGUID = ac.GUID 
		INNER JOIN ce000 ce ON en.ParentGUID = ce.GUID 
		LEFT JOIN er000 er ON er.EntryGUID = ce.GUID 
		LEFT JOIN py000 py ON er.ParentGUID = py.GUID 
		LEFT JOIN et000 et ON py.TypeGUID = et.GUID 
	WHERE 
		ISNULL(et.TaxType, 0) = 0 
		AND
		ISNULL(et.GUID, 0x0) != @OpenEntyTypeGUID
		AND 
		ISNULL(ac.IsUsingAddedValue, 0) <> 0
		AND 
		CAST(en.[Date] AS DATE) BETWEEN @TaxDurationStartDate AND @TaxDurationEndDate
		AND 
		CAST(en.[Date] AS DATE) >= @PaymentsSubscriptionDate
		AND 
		@PaymentsSubscriptionDate != @NoDate
		AND 
		en.Type != 450
		AND 
		NOT EXISTS(SELECT 1 FROM ch000 ch INNER JOIN er000 er ON er.ParentGUID = ch.GUID 
			INNER JOIN ce000 c ON c.GUID = er.EntryGUID WHERE c.GUID = ce.GUID)

	-- “»Ê‰ ··÷—Ì»… »œÊ‰  ÕœÌœ „⁄·Ê„«  «·÷—«∆»
	SELECT DISTINCT
		py.GUID AS PayGUID,
		CASE @Lang WHEN 0 THEN ET.Name 
				   ELSE CASE ET.LatinName WHEN '' THEN ET.Name 
										  ELSE ET.LatinName END 
		END + ': ' + CAST(py.Number AS NVARCHAR(250)) AS PayNumber 
	FROM 
		ac000 ac
		INNER JOIN en000 en ON en.AccountGUID = ac.GUID 
		INNER JOIN ce000 ce ON en.ParentGUID = ce.GUID 
		INNER JOIN er000 er ON er.EntryGUID = ce.GUID 
		INNER JOIN py000 py ON er.ParentGUID = py.GUID 
		INNER JOIN et000 et ON py.TypeGUID = et.GUID 
		INNER JOIN cu000 cu ON en.CustomerGUID = cu.GUID
		LEFT JOIN GCCCustomerTax000 ct ON ct.CustGUID = cu.GUID AND ct.TaxType = 1
	WHERE 
		ISNULL(et.TaxType, 0) != 0 
		AND 
		ISNULL(ac.IsUsingAddedValue, 0) <> 0
		AND 
		CAST(en.[Date] AS DATE) BETWEEN @TaxDurationStartDate AND @TaxDurationEndDate
		AND 
		CAST(en.[Date] AS DATE) >= @PaymentsSubscriptionDate
		AND 
		@PaymentsSubscriptionDate != @NoDate
		AND 
		en.Type != 450
		AND 
		ct.GUID IS NULL

	-- “»Ê‰ ··÷—Ì»… »œÊ‰  ÕœÌœ «·„Êﬁ⁄
	SELECT DISTINCT
		py.GUID AS PayGUID,
		CASE @Lang WHEN 0 THEN ET.Name 
				   ELSE CASE ET.LatinName WHEN '' THEN ET.Name 
										  ELSE ET.LatinName END 
		END + ': ' + CAST(py.Number AS NVARCHAR(250)) AS PayNumber 
	FROM 
		ac000 ac
		INNER JOIN en000 en ON en.AccountGUID = ac.GUID 
		INNER JOIN ce000 ce ON en.ParentGUID = ce.GUID 
		INNER JOIN er000 er ON er.EntryGUID = ce.GUID 
		INNER JOIN py000 py ON er.ParentGUID = py.GUID 
		INNER JOIN et000 et ON py.TypeGUID = et.GUID 
		INNER JOIN cu000 cu ON en.CustomerGUID = cu.GUID
		LEFT JOIN GCCCustLocations000 cl ON cu.GCCLocationGUID = cl.GUID
	WHERE 
		ISNULL(et.TaxType, 0) != 0 
		AND 
		ISNULL(ac.IsUsingAddedValue, 0) <> 0
		AND 
		CAST(en.[Date] AS DATE) BETWEEN @TaxDurationStartDate AND @TaxDurationEndDate
		AND 
		CAST(en.[Date] AS DATE) >= @PaymentsSubscriptionDate
		AND 
		@PaymentsSubscriptionDate != @NoDate
		AND 
		en.Type != 450
		AND 
		cl.GUID IS NULL

	-- ”‰œ ÷—«∆» ›ÌÂ Õ”«» ÷—Ì»… Ê »«·œ«∆‰ »œÊ‰  ÕœÌœ —ﬁ„ «·√’·
	SELECT DISTINCT
		py.GUID AS PayGUID,
		CASE @Lang WHEN 0 THEN ET.Name 
				   ELSE CASE ET.LatinName WHEN '' THEN ET.Name 
										  ELSE ET.LatinName END 
		END + ': ' + CAST(py.Number AS NVARCHAR(250)) AS PayNumber 
	FROM 
		ac000 ac
		INNER JOIN en000 en ON en.AccountGUID = ac.GUID 
		INNER JOIN ce000 ce ON en.ParentGUID = ce.GUID 
		INNER JOIN er000 er ON er.EntryGUID = ce.GUID 
		INNER JOIN py000 py ON er.ParentGUID = py.GUID 
		INNER JOIN et000 et ON py.TypeGUID = et.GUID 
	WHERE 
		ISNULL(et.TaxType, 0) != 0 
		AND 
		ISNULL(ac.IsUsingAddedValue, 0) <> 0
		AND 
		CAST(en.[Date] AS DATE) BETWEEN @TaxDurationStartDate AND @TaxDurationEndDate
		AND 
		CAST(en.[Date] AS DATE) >= @PaymentsSubscriptionDate
		AND 
		@PaymentsSubscriptionDate != @NoDate
		AND 
		en.Credit > 0 
		AND 
		en.Type != 450
		AND 
		ISNULL(en.GCCOriginNumber, '') = ''

	-- account used tax, customer has tax type, and entry not have tax 
	SELECT DISTINCT
		py.GUID AS PayGUID,
		CASE @Lang WHEN 0 THEN ET.Name 
				   ELSE CASE ET.LatinName WHEN '' THEN ET.Name 
										  ELSE ET.LatinName END 
		END + ': ' + CAST(py.Number AS NVARCHAR(250)) AS PayNumber 
	FROM 
		ac000 ac
		INNER JOIN en000 en ON en.AccountGUID = ac.GUID 
		INNER JOIN ce000 ce ON en.ParentGUID = ce.GUID 
		INNER JOIN er000 er ON er.EntryGUID = ce.GUID 
		INNER JOIN py000 py ON er.ParentGUID = py.GUID 
		INNER JOIN et000 et ON py.TypeGUID = et.GUID 
		INNER JOIN cu000 cu ON en.CustomerGUID = cu.GUID
		INNER JOIN GCCCustomerTax000 ct ON ct.CustGUID = cu.GUID AND ct.TaxType = 1
	WHERE 
		ISNULL(et.TaxType, 0) != 0 
		AND 
		ISNULL(ac.IsUsingAddedValue, 0) <> 0
		AND 
		CAST(en.[Date] AS DATE) BETWEEN @TaxDurationStartDate AND @TaxDurationEndDate 
		AND 
		CAST(en.[Date] AS DATE) >= @PaymentsSubscriptionDate
		AND 
		@PaymentsSubscriptionDate != @NoDate
		AND 
		ct.TaxCode = 1
		AND 
		en.Type != 401
##################################################################################
#END
