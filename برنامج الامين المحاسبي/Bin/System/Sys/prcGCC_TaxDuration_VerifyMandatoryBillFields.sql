################################################################################
CREATE PROCEDURE prcGCC_TaxDuration_VerifyMandatoryBillFields
	@TaxDurationGUID UNIQUEIDENTIFIER
AS
	SET NOCOUNT ON
	
	DECLARE @Lang INT = (SELECT [dbo].[fnConnections_GetLanguage]())
	DECLARE @TaxDurationStartDate DATE
	DECLARE @TaxDurationEndDate   DATE

	SELECT 
		@TaxDurationStartDate = [StartDate], 
		@TaxDurationEndDate = EndDate
	FROM 
		GCCTaxDurations000 WHERE [GUID] =  @TaxDurationGUID

	-- FIrst result
	--SELECT DISTINCT 
	--	CASE @Lang WHEN 0 THEN BT.Name 
	--			   ELSE CASE BT.LatinName WHEN '' THEN BT.Name 
	--									  ELSE BT.LatinName END END    AS TypeName
	--FROM 
	--	bu000 BU INNER JOIN bt000 BT ON BU.TypeGUID = BT.[GUID]
	--WHERE  
	--	BT.bNoEntry = 0
	--	AND BT.BillType IN (1, 3)
	--	AND BT.Type = 1
	--	AND CAST(BU.[Date] AS DATE) BETWEEN @TaxDurationStartDate AND @TaxDurationEndDate
	--	AND BT.DefaultLocationGUID = 0x0

	-- Second result
	SELECT DISTINCT 
		BU.Guid AS BillGuid,
		CASE @Lang WHEN 0 THEN [bt].[Abbrev] 
				   ELSE CASE [bt].[LatinAbbrev] WHEN '' THEN [bt].[Abbrev]
						  ELSE [bt].[LatinAbbrev]END END + ': ' + CAST([bu].[Number] AS NVARCHAR)   AS TypeName

	FROM 
		bu000 BU INNER JOIN bt000 BT ON BU.TypeGUID = BT.[GUID]
	WHERE  
		BT.bNoEntry = 0
		AND BT.BillType IN (2, 3)
		AND BT.Type = 1
		AND CAST(BU.[Date] AS DATE) BETWEEN @TaxDurationStartDate AND @TaxDurationEndDate
		AND ((BU.ReturendBillNumber IN ('', '0')) OR BU.ReturendBillDate = '01-01-1980')

	-- Third result
	SELECT DISTINCT 
		CASE @Lang WHEN 0 THEN BT.Name 
				   ELSE CASE BT.LatinName WHEN '' THEN BT.Name 
						 ELSE BT.LatinName END END    AS TypeName
	FROM 
		bt000 BT
		JOIN cu000 AS CU ON CU.GUID = BT.CustAccGUID
		LEFT JOIN GCCCustomerTax000 T ON T.CustGUID = BT.CustAccGUID
	WHERE  
		BT.bNoEntry = 0
		AND BT.BillType IN (0, 1, 2, 3)
		AND BT.Type = 1
		--AND CAST(BU.[Date] AS DATE) BETWEEN @TaxDurationStartDate AND @TaxDurationEndDate
		AND 
		(
			cu.GCCLocationGUID = 0x
			OR
			T.GUID IS NULL
		)
##################################################################################
#END
