################################################################################
CREATE PROCEDURE prcGCC_TaxDuration_VerifyCustomers
	@TaxDurationGUID UNIQUEIDENTIFIER
AS
	SET NOCOUNT ON

	/*
	TODO:
	1- ãÚÇáÌÉ ÇáÍÇáÇÊ ÇáÃÎíÑÉ ÇáãáÛíÉ 4¡5¡6 Úáì ÇáÅÌÑÇÆíÉ ÈÇáäÓÈÉ ááÒÈÇÆä æ Úáì ÇáÓæÑÓ
	*/
	DECLARE @Lang INT = (SELECT [dbo].[fnConnections_GetLanguage]())

	DECLARE @TaxDurationStartDate DATE
	DECLARE @TaxDurationEndDate   DATE
	SELECT 
		@TaxDurationStartDate = [StartDate], 
		@TaxDurationEndDate = EndDate
	FROM 
		GCCTaxDurations000 WHERE [GUID] = @TaxDurationGUID

	-----------------------------------------------------------------------------------------
	-- 1: cust not assigned
	SELECT 
		BU.[GUID] AS [GUID]
	FROM 
		bu000 BU 
		INNER JOIN bt000 BT ON BU.TypeGUID = BT.[GUID]
	WHERE 
		BU.CustGUID = 0x0
		AND BT.bNoEntry = 0
		AND BT.BillType IN (0, 1, 2, 3) 
		AND BT.[Type] = 1
		AND CAST(BU.[Date] AS DATE) BETWEEN @TaxDurationStartDate AND @TaxDurationEndDate
	ORDER BY BT.SortNum, BU.Number

	-----------------------------------------------------------------------------------------
	-----------------------------------------------------------------------------------------
	SELECT DISTINCT BU.CustGUID AS CustGUID
	INTO #customers
	FROM 
		bu000 BU 
		INNER JOIN bt000 BT ON BU.TypeGUID = BT.[GUID]
	WHERE 
		BT.bNoEntry = 0
		AND BT.BillType IN (0, 1, 2, 3) 
		AND BT.[Type] = 1
		AND CAST(BU.[Date] AS DATE) BETWEEN @TaxDurationStartDate AND @TaxDurationEndDate

	-----------------------------------------------------------------------------------------
	--2: cust without vat tax
	SELECT DISTINCT 
		C.CustGUID AS CustomerGUID
	FROM 
		#customers C
		INNER JOIN cu000 cu ON C.CustGUID = cu.[GUID]
		LEFT JOIN [GCCCustomerTax000] t ON cu.GUID = t.[CustGUID] AND t.TaxType = 1 /*VAT*/
	WHERE 
		t.GUID IS NULL

	-----------------------------------------------------------------------------------------
	--3: cust without location
	SELECT DISTINCT 
		C.CustGUID AS CustomerGUID
	FROM 
		#customers C
		INNER JOIN cu000 cu ON C.CustGUID = cu.[GUID]
		LEFT JOIN [GCCCustLocations000] cl ON cu.GCCLocationGUID = cl.GUID 
	WHERE 
		(cu.GCCLocationGUID = 0x0 OR cl.GUID IS NULL)
	

	-----------------------------------------------------------------------------------------
	-- 4: there is tax in customers and these tax is not used 
	SELECT DISTINCT 
		CU.GUID AS CustomerGUID
	FROM 
		cu000 CU
		INNER JOIN #customers M ON M.CustGUID = CU.[GUID]
		INNER JOIN [GCCCustomerTax000] T ON CU.GUID = T.CustGUID
		INNER JOIN GCCTaxTypes000 TT ON TT.[Type] = T.[TaxType] 
		INNER JOIN GCCTaxCoding000 TC ON T.[TaxCode] = TC.[TaxCode] AND T.[TaxType] = TC.TaxType 
	WHERE 
		TT.IsUsed = 0

	-------------------------------------------------------------------------------------------
	---- 5: there is missed tax type or tax code 
	SELECT DISTINCT  
		CU.GUID AS CustomerGUID
	FROM 
		cu000 CU
		INNER JOIN #customers M ON M.CustGUID = CU.[GUID]
		INNER JOIN [GCCCustomerTax000] T ON CU.GUID = T.CustGUID
	WHERE 
		(ISNULL(T.[TaxType], 0) = 0) OR (ISNULL(T.[TaxCode], 0) = 0)

	-----------------------------------------------------------------------------------------	
	-- 6: there are doublicate tax for same type 
	SELECT DISTINCT  
		T.CustomerGUID AS CustomerGUID
		
	FROM 
		( SELECT DISTINCT
			CU.GUID AS CustomerGUID
		FROM
			cu000 CU
			INNER JOIN #customers M ON M.CustGUID = CU.[GUID]
			INNER JOIN [GCCCustomerTax000] T ON CU.GUID = T.CustGUID
		GROUP BY
			CU.GUID,
			T.[TaxType]
		HAVING COUNT(*) > 1 ) T INNER JOIN cu000 CU ON CU.GUID = T.CustomerGUID
##################################################################################
#END
