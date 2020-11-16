################################################################################
CREATE PROCEDURE prcGCC_TaxDuration_VerifyAccounts
	@TaxDurationGUID UNIQUEIDENTIFIER
AS
	SET NOCOUNT ON
	/*
	TODO:
	DONE 1- «” À‰«¡ «·”‰œ«  «·„Ê·œ… ⁄‰ ⁄„·Ì… «·≈€·«ﬁ ‰›”Â« „‰ ⁄„·Ì… «· ‘ÌÌﬂ ⁄·Ï «·«” Œœ«„ «·Õ”«»« 
	DONE 2-  ‘ÌÌﬂ «·Õ”«»«  «·«› —«÷Ì… ‰›”Â« √‰Â« €Ì— —∆Ì”Ì… Ê €Ì— „ ﬂ——… ⁄·Ï „” ÊÏ «·ÃœÊ· √Ê ⁄·Ï „” ÊÏ «” Œœ«„ ›Ì „ﬂ«‰ „« €Ì— «·÷—«∆»
	DONE 3-  ‘ÌÌﬂ √‰ «·Õ”«»«  «·„— »ÿ… »«·„Ê«ﬁ⁄ „— »ÿ… »«·Õ”«»«  «·«› —«÷Ì… «·’ÕÌÕ…
	DONE 4-  ‘ÌÌﬂ √‰ «·Õ”«»«  «·„— »ÿ… »√‰„«ÿ «·›Ê« Ì— „‰ «·Õ”«»«  «·«› —«÷Ì… «·’ÕÌÕ…
	DONE 5- ›Ì Õ«· «·›« Ê—… ﬂ«‰  ›Ì ŒÌ«— «·„“Ìœ „œ›Ê⁄… „‰ ﬁ»· «·ÊﬂÌ· «” À‰«¡Â« „‰ «·Õ”«»« 
	*/

	DECLARE @Lang INT = (SELECT [dbo].[fnConnections_GetLanguage]())
	DECLARE @VATAccountsBalance						TABLE ([Type] INT, [GUID] UNIQUEIDENTIFIER, Balance FLOAT)
	DECLARE @ReturnAccountsBalance					TABLE ([Type] INT, [GUID] UNIQUEIDENTIFIER, Balance FLOAT)
	DECLARE @ExciseAccountsBalance					TABLE ([Type] INT, [GUID] UNIQUEIDENTIFIER, Balance FLOAT)
	DECLARE @ReturnExciseAccountsBalance			TABLE ([Type] INT, [GUID] UNIQUEIDENTIFIER, Balance FLOAT)
	DECLARE @ReverseChargesAccountsBalance			TABLE ([Type] INT, [GUID] UNIQUEIDENTIFIER, Balance FLOAT)
	DECLARE @ReturnReverseChargesAccountsBalance	TABLE ([Type] INT, [GUID] UNIQUEIDENTIFIER, Balance FLOAT)

	DECLARE @AccBalanceNotEqualZero TABLE ([Type] INT, [GUID] UNIQUEIDENTIFIER, Balance FLOAT)
	
	DECLARE @TaxDurationStartDate DATE
	SELECT @TaxDurationStartDate = DATEADD(DAY, -1, [StartDate]) FROM GCCTaxDurations000 WHERE [GUID] =  @TaxDurationGUID

	DECLARE @TaxDurationEndDate   DATE	
	SELECT 
		@TaxDurationEndDate = [EndDate]		
	FROM GCCTaxDurations000 WHERE [GUID] = @TaxDurationGUID

	DECLARE @OpenEntyTypeGUID UNIQUEIDENTIFIER
	SET @OpenEntyTypeGUID = 'EA69BA80-662D-4FA4-90EE-4D2E1988A8EA'

	SELECT VATAccGUID					INTO #VATAccounts					FROM GCCTaxAccounts000 WHERE ISNULL(VATAccGUID, 0x0) != 0x0
	SELECT ReturnAccGUID				INTO #ReturnAccounts				FROM GCCTaxAccounts000 WHERE ISNULL(ReturnAccGUID, 0x0) != 0x0
	SELECT ExciseTaxAccGUID				INTO #ExciseAccounts				FROM GCCTaxAccounts000 WHERE ISNULL(ExciseTaxAccGUID, 0x0) != 0x0
	SELECT ReturnExciseTaxAccGUID		INTO #ReturnExciseAccounts			FROM GCCTaxAccounts000 WHERE ISNULL(ReturnExciseTaxAccGUID, 0x0) != 0x0
	SELECT ReverseChargesAccGUID		INTO #ReverseChargesAccounts		FROM GCCTaxAccounts000 WHERE ISNULL(ReverseChargesAccGUID, 0x0) != 0x0
	SELECT ReturnReverseChargesAccGUID	INTO #ReturnReverseChargesAccounts	FROM GCCTaxAccounts000 WHERE ISNULL(ReturnReverseChargesAccGUID, 0x0) != 0x0

	--SELECT
	--	SUM([e].[debit]) - SUM([e].[credit]) 
	--FROM 
	--	[en000] [e] 
	--	INNER JOIN [ce000] [c] ON [e].[parentGuid] = [c].[guid]
	--WHERE 
	--	[c].[isPosted] <> 0 AND CAST ([e].[Date] AS DATE) >= @TaxDurationStartDate

	INSERT INTO @VATAccountsBalance 
	SELECT 201, VAT.VATAccGUID, fn.Bal
	FROM 
		#VATAccounts VAT 
		CROSS APPLY 
		(SELECT [dbo].[fnAccount_getBalance](VAT.VATAccGUID, DEFAULT, DEFAULT, @TaxDurationStartDate, DEFAULT) AS Bal) AS fn

	INSERT INTO @ReturnAccountsBalance 
	SELECT 202, RE.ReturnAccGUID, fn.Bal
	FROM 
		#ReturnAccounts RE
		CROSS APPLY 
		(SELECT [dbo].[fnAccount_getBalance](RE.ReturnAccGUID, DEFAULT, DEFAULT, @TaxDurationStartDate, DEFAULT) AS Bal) AS fn

	INSERT INTO @ExciseAccountsBalance 
	SELECT 203, Excise.ExciseTaxAccGUID, fn.Bal
	FROM 
		#ExciseAccounts Excise
		CROSS APPLY 
		(SELECT [dbo].[fnAccount_getBalance](Excise.ExciseTaxAccGUID, DEFAULT, DEFAULT, @TaxDurationStartDate, DEFAULT) AS Bal ) AS fn

	INSERT INTO @ReturnExciseAccountsBalance 
	SELECT 204, Excise.ReturnExciseTaxAccGUID, fn.Bal
	FROM 
		#ReturnExciseAccounts Excise
		CROSS APPLY 
		(SELECT [dbo].[fnAccount_getBalance](Excise.ReturnExciseTaxAccGUID, DEFAULT, DEFAULT, @TaxDurationStartDate, DEFAULT) AS Bal ) AS fn

	INSERT INTO @ReverseChargesAccountsBalance 
	SELECT 205, ReverseCharges.ReverseChargesAccGUID, fn.Bal
	FROM 
		#ReverseChargesAccounts ReverseCharges
		CROSS APPLY 
		(SELECT [dbo].[fnAccount_getBalance](ReverseCharges.ReverseChargesAccGUID, DEFAULT, DEFAULT, @TaxDurationStartDate, DEFAULT) AS Bal) AS fn

	INSERT INTO @ReturnReverseChargesAccountsBalance 
	SELECT 206, ReverseCharges.ReturnReverseChargesAccGUID, fn.Bal
	FROM 
		#ReturnReverseChargesAccounts ReverseCharges
		CROSS APPLY 
		(SELECT [dbo].[fnAccount_getBalance](ReverseCharges.ReturnReverseChargesAccGUID, DEFAULT, DEFAULT, @TaxDurationStartDate, DEFAULT) AS Bal) AS fn

	INSERT INTO @AccBalanceNotEqualZero 
	SELECT * FROM @VATAccountsBalance WHERE ABS(Balance) > 0.1
	UNION ALL
	SELECT * FROM @ReturnAccountsBalance WHERE ABS(Balance) > 0.1
	UNION ALL
	SELECT * FROM @ExciseAccountsBalance WHERE ABS(Balance) > 0.1
	UNION ALL
	SELECT * FROM @ReturnExciseAccountsBalance WHERE ABS(Balance) > 0.1
	UNION ALL
	SELECT * FROM @ReverseChargesAccountsBalance WHERE ABS(Balance) > 0.1
	UNION ALL
	SELECT * FROM @ReturnReverseChargesAccountsBalance WHERE ABS(Balance) > 0.1

	-- FIRT RESULT --
	-- Check tax accounts balance are equal zero in start date duration		   
	SELECT
		 DISTINCT [GUID]
	FROM 
		@AccBalanceNotEqualZero

	-- SECOND RESULT --
	-- Check tax accounts are not used outside bill types
	------------------------------------------------------
	SELECT VATAcc.*, EN.ParentGUID AS EntryGUID 
	INTO #AccType 
	FROM 
		@VATAccountsBalance VATAcc 
		INNER JOIN en000 EN ON VATAcc.[GUID] = EN.AccountGUID 
		INNER JOIN ce000 CE ON CE.GUID = EN.ParentGUID
	WHERE EN.[Type] <> 201 AND EN.[Type] <> 210 AND EN.[Type] <> 211
	AND CE.TypeGUID != @OpenEntyTypeGUID
	AND	CAST(EN.[Date] AS DATE) BETWEEN @TaxDurationStartDate AND @TaxDurationEndDate

	INSERT INTO #AccType
	SELECT ReturnAcc.*, EN.ParentGUID AS EntryGUID
	FROM 
		@ReturnAccountsBalance ReturnAcc 
		INNER JOIN en000 EN ON ReturnAcc.[GUID] = EN.AccountGUID 
		INNER JOIN ce000 CE ON CE.GUID = EN.ParentGUID
	WHERE EN.[Type] <> 202 AND EN.[Type] <> 210 AND EN.[Type] <> 211
	AND CE.TypeGUID != @OpenEntyTypeGUID
	AND	CAST(EN.[Date] AS DATE) BETWEEN @TaxDurationStartDate AND @TaxDurationEndDate

	INSERT INTO #AccType
	SELECT ExciseAcc.*, EN.ParentGUID AS EntryGUID
	FROM @ExciseAccountsBalance ExciseAcc INNER JOIN en000 EN ON ExciseAcc.[GUID] = EN.AccountGUID 
	INNER JOIN ce000 CE ON CE.GUID = EN.ParentGUID
	WHERE EN.[Type] <> 203 AND EN.[Type] <> 210 AND EN.[Type] <> 211
	AND CE.TypeGUID != @OpenEntyTypeGUID
	AND	CAST(EN.[Date] AS DATE) BETWEEN @TaxDurationStartDate AND @TaxDurationEndDate

	INSERT INTO #AccType
	SELECT ExciseAcc.*, EN.ParentGUID AS EntryGUID
	FROM @ReturnExciseAccountsBalance ExciseAcc INNER JOIN en000 EN ON ExciseAcc.[GUID] = EN.AccountGUID 
	INNER JOIN ce000 CE ON CE.GUID = EN.ParentGUID
	WHERE EN.[Type] <> 204 AND EN.[Type] <> 210 AND EN.[Type] <> 211
	AND CE.TypeGUID != @OpenEntyTypeGUID
	AND	CAST(EN.[Date] AS DATE) BETWEEN @TaxDurationStartDate AND @TaxDurationEndDate

	INSERT INTO #AccType
	SELECT ReverseAcc.*, EN.ParentGUID AS EntryGUID
	FROM 
		@ReverseChargesAccountsBalance ReverseAcc 
		INNER JOIN en000 EN ON ReverseAcc.[GUID] = EN.AccountGUID 
		INNER JOIN ce000 CE ON CE.GUID = EN.ParentGUID
	WHERE 
		EN.[Type] NOT IN(205, 210, 211, 407, 207)
		AND CE.TypeGUID != @OpenEntyTypeGUID
		AND	CAST(EN.[Date] AS DATE) BETWEEN @TaxDurationStartDate AND @TaxDurationEndDate
		 /*—”Ê„ ⁄ﬂ”Ì… ›Ì ÷—Ì»… «·”‰œ« */

	INSERT INTO #AccType
	SELECT ReverseAcc.*, EN.ParentGUID AS EntryGUID
	FROM @ReturnReverseChargesAccountsBalance ReverseAcc INNER JOIN en000 EN ON ReverseAcc.[GUID] = EN.AccountGUID 
	INNER JOIN ce000 CE ON CE.GUID = EN.ParentGUID
	WHERE 
		EN.[Type] NOT IN(206, 210, 211, 407, 208)
		AND CE.TypeGUID != @OpenEntyTypeGUID
		AND	CAST(EN.[Date] AS DATE) BETWEEN @TaxDurationStartDate AND @TaxDurationEndDate
		 /*—”Ê„ ⁄ﬂ”Ì… ›Ì ÷—Ì»… «·”‰œ« */

	SELECT 
		DISTINCT [GUID]
	FROM 
		#AccType

	-- THIRD RESULT --
	-- Check if accounts are main accounts
	------------------------------------------------------
	SELECT
		V.[GUID]
	FROM
		@VATAccountsBalance AS V
		JOIN ac000 AS AC ON AC.ParentGuid = V.[GUID]
	UNION ALL
	SELECT
		V.[GUID]
	FROM
		@ReturnAccountsBalance AS V
		JOIN ac000 AS AC ON AC.ParentGuid = V.[GUID]
	UNION ALL
	SELECT
		V.[GUID]
	FROM
		@ExciseAccountsBalance AS V
		JOIN ac000 AS AC ON AC.ParentGuid = V.[GUID]
	UNION ALL
	SELECT
		V.[GUID]
	FROM
		@ReturnExciseAccountsBalance AS V
		JOIN ac000 AS AC ON AC.ParentGuid = V.[GUID]
	UNION ALL
	SELECT
		V.[GUID]
	FROM
		@ReverseChargesAccountsBalance AS V
		JOIN ac000 AS AC ON AC.ParentGuid = V.[GUID]
	UNION ALL
	SELECT
		DISTINCT V.[GUID]
	FROM
		@ReturnReverseChargesAccountsBalance AS V
		JOIN ac000 AS AC ON AC.ParentGuid = V.[GUID]

	-- FOURTH RESULT --
	-- Check if accounts are used
	------------------------------------------------------
	SELECT
		V.[GUID]
	FROM @VATAccountsBalance AS V
	WHERE [dbo].[fnAccount_IsUsed](V.[GUID], DEFAULT) = 1
	UNION ALL
	SELECT
		V.[GUID]
	FROM
		@ReturnAccountsBalance AS V
	WHERE [dbo].[fnAccount_IsUsed](V.[GUID], DEFAULT) = 1
	UNION ALL
	SELECT
		V.[GUID]
	FROM
		@ExciseAccountsBalance AS V
	WHERE [dbo].[fnAccount_IsUsed](V.[GUID], DEFAULT) = 1
	UNION ALL
	SELECT
		V.[GUID]
	FROM
		@ReturnExciseAccountsBalance AS V
	WHERE [dbo].[fnAccount_IsUsed](V.[GUID], DEFAULT) = 1
	UNION ALL
	SELECT
		V.[GUID]
	FROM
		@ReverseChargesAccountsBalance AS V
	WHERE [dbo].[fnAccount_IsUsed](V.[GUID], DEFAULT) = 1
	UNION ALL
	SELECT
		DISTINCT V.[GUID]
	FROM
		@ReturnReverseChargesAccountsBalance AS V
	WHERE [dbo].[fnAccount_IsUsed](V.[GUID], DEFAULT) = 1
	-- FIFTH RESULT --
	-- Check if accounts are linked correctly with dedault accounts
	------------------------------------------------------

	--VAT
	SELECT G.VATAccGUID AS [GUID]
	FROM 
		GCCCustLocations000 AS G
	WHERE 
		G.ParentLocationGUID <> 0x
		AND NOT EXISTS(SELECT * FROM @VATAccountsBalance AS B WHERE B.GUID = G.VATAccGUID)
	UNION ALL
	--Return VAT
	SELECT G.ReturnAccGUID AS [GUID]
	FROM 
		GCCCustLocations000 AS G
	WHERE 
		G.ParentLocationGUID <> 0x
		AND NOT EXISTS(SELECT * FROM @ReturnAccountsBalance AS B WHERE B.GUID = G.ReturnAccGUID)
	UNION ALL
	-- Excise
	SELECT G.ExciseAccGUID AS [GUID]
	FROM 
		bt000 AS G
	WHERE 
		NOT EXISTS(SELECT * FROM @ExciseAccountsBalance AS B WHERE B.GUID = G.ExciseAccGUID)
		AND G.ExciseAccGUID <> 0x
	UNION ALL
	-- Return Excise
	SELECT G.ExciseContraAccGUID AS [GUID]
	FROM 
		bt000 AS G
	WHERE 
		NOT EXISTS(SELECT * FROM @ReturnExciseAccountsBalance AS B WHERE B.GUID = G.ExciseContraAccGUID)
		AND G.ExciseContraAccGUID <> 0x
	UNION ALL
	-- ReversCharge
	SELECT G.ReverseChargesAccGUID AS [GUID]
	FROM 
		bt000 AS G
	WHERE 
		NOT EXISTS(SELECT * FROM @ReverseChargesAccountsBalance AS B WHERE B.GUID = G.ReverseChargesAccGUID)
		AND G.ReverseChargesAccGUID <> 0x
	UNION ALL
	-- Return ReversCharge
	SELECT G.ReverseChargesContraAccGUID AS [GUID]
	FROM 
		bt000 AS G
	WHERE 
		NOT EXISTS(SELECT * FROM @ReturnReverseChargesAccountsBalance AS B WHERE B.GUID = G.ReverseChargesContraAccGUID)
		AND G.ReverseChargesContraAccGUID <> 0x

	-- ›Ì Õ«· ÊÃÊœ √Ì Õ”«» Ì” Œœ„ «·÷—Ì»… Ê „— »ÿ »“»«∆‰
	SELECT 
		DISTINCT(ac.[GUID]) AS [GUID] 
	FROM 
		ac000 ac
		INNER JOIN cu000 cu ON cu.AccountGUID = ac.GUID 
	WHERE 
		ISNULL(ac.IsUsingAddedValue, 0) <> 0
##################################################################################
#END
