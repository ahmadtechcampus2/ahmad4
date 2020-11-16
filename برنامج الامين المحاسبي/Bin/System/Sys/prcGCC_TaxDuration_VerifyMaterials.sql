################################################################################
CREATE PROCEDURE prcGCC_TaxDuration_VerifyMaterials
	@TaxDurationGUID UNIQUEIDENTIFIER
AS
	SET NOCOUNT ON
	
	DECLARE @Lang INT = (SELECT [dbo].[fnConnections_GetLanguage]())

	DECLARE @TaxDurationStartDate DATE
	DECLARE @TaxDurationEndDate DATE
	SELECT 
		@TaxDurationStartDate = [StartDate], 
		@TaxDurationEndDate = EndDate
	FROM 
		GCCTaxDurations000 WHERE [GUID] = @TaxDurationGUID

	SELECT DISTINCT BI.MatGUID AS MatGUID
	INTO #MaterialsInBills
	FROM 
		bi000 BI 
		INNER JOIN bu000 BU ON BI.ParentGUID = BU.[GUID]
		INNER JOIN bt000 BT ON BU.TypeGUID = BT.[GUID]
	WHERE 
		BT.bNoEntry = 0
		AND BT.BillType IN (0, 1, 2, 3) 
		AND BT.[Type] = 1
		AND CAST(BU.[Date] AS DATE) BETWEEN @TaxDurationStartDate AND @TaxDurationEndDate
	
	-- 1: used materials without vat tax
	SELECT  
		MT.GUID AS MaterialGUID,
		MT.Code + ' - ' +
		CASE @Lang WHEN 0 THEN MT.Name 
				   ELSE CASE MT.LatinName WHEN '' THEN MT.Name 
										  ELSE MT.LatinName END END    AS Material
	FROM 
		mt000 MT
		INNER JOIN #MaterialsInBills M ON M.MatGUID = MT.[GUID]
		LEFT JOIN [GCCMaterialTax000] T ON MT.GUID = T.[MatGUID] AND T.TaxType = 1 /*VAT*/
	WHERE 
		T.GUID IS NULL

	-- 2: same tax ratio in materials
	SELECT DISTINCT  
		MT.GUID AS MaterialGUID,
		MT.Code + ' - ' +
		CASE @Lang WHEN 0 THEN MT.Name 
				   ELSE CASE MT.LatinName WHEN '' THEN MT.Name 
										  ELSE MT.LatinName END END AS Material
	FROM 
		mt000 MT
		INNER JOIN #MaterialsInBills M ON M.MatGUID = MT.[GUID]
		INNER JOIN [GCCMaterialTax000] T ON MT.GUID = T.[MatGUID]
		INNER JOIN GCCTaxTypes000 TT ON TT.[Type] = T.[TaxType] 
		INNER JOIN GCCTaxCoding000 TC ON T.[TaxCode] = TC.[TaxCode] AND T.[TaxType] = TC.TaxType 
	WHERE 
		TC.TaxRatio <> T.Ratio

	-- 3: there is tax in materials and these tax is not used 
	SELECT DISTINCT 
		MT.GUID AS MaterialGUID,
		MT.Code + ' - ' +
		CASE @Lang WHEN 0 THEN MT.Name 
				   ELSE CASE MT.LatinName WHEN '' THEN MT.Name 
										  ELSE MT.LatinName END END AS Material
	FROM 
		mt000 MT
		INNER JOIN #MaterialsInBills M ON M.MatGUID = MT.[GUID]
		INNER JOIN [GCCMaterialTax000] T ON MT.GUID = T.[MatGUID]
		INNER JOIN GCCTaxTypes000 TT ON TT.[Type] = T.[TaxType] 
		INNER JOIN GCCTaxCoding000 TC ON T.[TaxCode] = TC.[TaxCode] AND T.[TaxType] = TC.TaxType 
	WHERE 
		TT.IsUsed = 0

	-- 4: there is missed tax type or tax code 
	SELECT DISTINCT  
		MT.GUID AS MaterialGUID,
		MT.Code + ' - ' +
		CASE @Lang WHEN 0 THEN MT.Name 
				   ELSE CASE MT.LatinName WHEN '' THEN MT.Name 
										  ELSE MT.LatinName END END AS Material
	FROM 
		mt000 MT
		INNER JOIN #MaterialsInBills M ON M.MatGUID = MT.[GUID]
		INNER JOIN [GCCMaterialTax000] T ON MT.GUID = T.[MatGUID]
	WHERE 
		(ISNULL(T.[TaxType], 0) = 0) OR (ISNULL(T.[TaxCode], 0) = 0)
	
	-- 5: there are doublicate tax for same type 
	SELECT DISTINCT  
		MT.GUID AS MaterialGUID,
		MT.Code + ' - ' +
		CASE @Lang WHEN 0 THEN MT.Name 
				   ELSE CASE MT.LatinName WHEN '' THEN MT.Name 
										  ELSE MT.LatinName END END AS Material
	FROM 
		( SELECT DISTINCT
			MT.GUID AS MatGUID
		FROM
			mt000 MT
			INNER JOIN #MaterialsInBills M ON M.MatGUID = MT.[GUID]
			INNER JOIN [GCCMaterialTax000] T ON MT.GUID = T.[MatGUID]
		GROUP BY
			MT.GUID,
			T.[TaxType]
		HAVING COUNT(*) > 1 ) T INNER JOIN mt000 MT ON MT.GUID = T.MatGUID
##################################################################################
#END