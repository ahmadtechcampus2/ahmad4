##################################################################################
CREATE PROC prcGCC_FAFAuditReportData_VAT
	@FromDate DATE,
	@ToDate DATE
AS
	SET NOCOUNT ON

	--- supplier table
	SELECT 
		cuCustomerName AS Name,
		AC.Code AS GL_ID,
		CU.GCCCountry,
		CU.VATTaxNumber AS TRN,
		CU.ReverseCharges
	FROM 
		vwCu AS CU
		INNER JOIN ac000 AS AC ON CU.cuAccount = AC.GUID
	WHERE EXISTS(SELECT 1 FROM vwbu WHERE buCustPtr = CU.cuGUID AND btType = 1 AND btBillType = 0)
	---end supplier table

	--- customer table
	SELECT 
		cuCustomerName AS Name,
		AC.Code AS GL_ID,
		CU.GCCCountry,
		CU.VATTaxNumber AS TRN
	FROM 
		vwCu AS CU
		INNER JOIN ac000 AS AC ON CU.cuAccount = AC.GUID
	WHERE EXISTS(SELECT 1 FROM vwbu WHERE buCustPtr = CU.cuGUID AND btType = 1 AND btBillType = 1)
	--- end customer table 

	---- ›Ê« Ì— «·‘—«¡
	SELECT 
		buCust_Name AS SupplierName,
		CU.VATTaxNumber AS SupplierTRN,
		BI.buDate AS InvoiceDate,
		BI.buNumber AS InvoiceNo,
		0 AS PermitNo,
		BI.biNumber + 1 AS [LineNo],
		BI.mtCode + '-' + BI.mtName AS ProductDescription,
		(BI.biUnitPrice * BI.biQty) - Bi.biDiscount - BI.biTotalDiscountPercent + Bi.biExtra + BI.biTotalExtraPercent AS PurchaseValueAED,
		BI.biVAT AS VATValueAED,
		BI.biTaxCode AS TaxCode,
		MY.Code AS FCYCode,
		CASE WHEN BI.buCurrencyVal = 1 THEN 0 ELSE ((BI.biUnitPrice * BI.biQty) - Bi.biDiscount - BI.biTotalDiscountPercent + Bi.biExtra + BI.biTotalExtraPercent) / BI.buCurrencyVal END AS PurchaseFCY,
		CASE WHEN BI.buCurrencyVal = 1 THEN 0 ELSE BI.biVAT / BI.buCurrencyVal END AS AEDFCY
	INTO #Purchases
	FROM 
		vwExtended_bi BI
		JOIN my000 MY ON MY.GUID = BI.buCurrencyPtr
		JOIN bt000 BT ON BI.buType = BT.GUID
		JOIN vwCu CU ON CU.cuGUID = BI.buCustPtr
	WHERE 
		-- ›Ê« Ì— «·‘—«¡
		btType = 1 AND btBillType = 0 
		AND BT.IsPriceOfferBill = 0
		AND CAST(BI.buDate AS DATE) BETWEEN @FromDate AND @ToDate

	SELECT * FROM #Purchases
	SELECT SUM(PurchaseValueAED) AS PurchaseTotalAED, SUM(VATValueAED) AS VATTotalAED, COUNT(*) AS TransactionCountTotal FROM #Purchases	

	---- ›Ê« Ì— «·„»Ì⁄
	SELECT 
		buCust_Name AS CustomerName,
		CU.VATTaxNumber AS CustomerTRN,
		BI.buDate AS InvoiceDate,
		BI.buNumber AS InvoiceNo,
		0 AS PermitNo,
		BI.biNumber + 1 AS [LineNo],
		BI.mtCode + '-' + BI.mtName AS ProductDescription,
		(BI.biUnitPrice * BI.biQty) - Bi.biDiscount - BI.biTotalDiscountPercent + Bi.biExtra + BI.biTotalExtraPercent AS SupplyValueAED,
		BI.biVAT AS VATValueAED,
		BI.biTaxCode AS TaxCode,
		MY.Code AS FCYCode,
		N'' AS Country,
		CASE WHEN BI.buCurrencyVal = 1 THEN 0 ELSE ((BI.biUnitPrice * BI.biQty) - Bi.biDiscount - BI.biTotalDiscountPercent + Bi.biExtra + BI.biTotalExtraPercent) / BI.buCurrencyVal END AS SupplyFCY,
		CASE WHEN BI.buCurrencyVal = 1 THEN 0 ELSE BI.biVAT / BI.buCurrencyVal END AS AEDFCY
	INTO #Sales
	FROM 
		vwExtended_bi BI
		JOIN my000 MY ON MY.GUID = BI.buCurrencyPtr
		JOIN bt000 BT ON BI.buType = BT.GUID
		JOIN vwCu CU ON CU.cuGUID = BI.buCustPtr
	WHERE 
		-- ›Ê« Ì— «·„»Ì⁄
		btType = 1 AND btBillType = 1 
		AND BT.IsPriceOfferBill = 0
		AND CAST(BI.buDate AS DATE) BETWEEN @FromDate AND @ToDate

	SELECT * FROM #Sales
	SELECT ISNULL(SUM(SupplyValueAED), 0) AS SupplyTotalAED, ISNULL(SUM(VATValueAED), 0) AS VATTotalAED, COUNT(*) AS TransactionCountTotal FROM #Sales	


	---- œ› — √” «–
	SELECT 
		EN.enDate AS TransactionDate,
		EN.acCode AS AccountID,
		EN.acName AS AccountName,
		EN.enNotes AS TransactionDescription,
		N'' AS Name,
		EN.ceNumber AS TransactionID,
		EN.ceGUID,
		ER.ParentGUID,
		ER.ParentType,
		EN.enDebit AS Debit,
		En.enCredit AS Credit,
		EN.enDebit - En.enCredit AS Balance
	INTO #GL
	FROM
		vwExtended_en AS EN
		LEFT JOIN er000 AS ER ON EN.ceGUID = ER.EntryGUID
	WHERE 
		CAST(EN.enDate AS DATE) BETWEEN @FromDate AND @ToDate
	ORDER BY EN.enDate

	SELECT * FROM #GL
	SELECT ISNULL(SUM(Debit), 0) AS TotalDebit, ISNULL(SUM(Credit), 0) AS TotalCredit, COUNT(*) AS TransactionCountTotal, (SELECT Code FROM my000 WHERE GUID = dbo.fnGetDefaultCurr()) AS GLTCurrency FROM #GL	

	-- mat file
	SELECT
		Code + ' - ' + Name AS Name,
		Spec,
		GCC.TaxCode
	FROM 
		mt000 AS MT
		INNER JOIN GCCMaterialTax000 AS GCC ON MT.GUID = GCC.MatGUID AND TaxType = 1
	-- end mat file
##################################################################################
CREATE PROC prcGCC_FAFAuditReportData_EXCISE
	@FromDate DATE,
	@ToDate DATE
AS
	SET NOCOUNT ON

	--- supplier table
	SELECT 
		cuCustomerName AS Name,
		AC.Code AS GL_ID,
		CU.GCCCountry,
		CU.ExciseTaxNumber AS TRN,
		CU.ReverseCharges
	FROM 
		vwCu AS CU
		INNER JOIN ac000 AS AC ON CU.cuAccount = AC.GUID
	WHERE 
		EXISTS(SELECT 1 FROM vwbu WHERE buCustPtr = CU.cuGUID AND btType = 1 AND btBillType = 0)
		AND CU.ExciseTaxCode <> 0
	---end supplier table

	--- customer table
	SELECT 
		cuCustomerName AS Name,
		AC.Code AS GL_ID,
		CU.GCCCountry,
		CU.ExciseTaxNumber AS TRN
	FROM 
		vwCu AS CU
		INNER JOIN ac000 AS AC ON CU.cuAccount = AC.GUID
	WHERE 
		EXISTS(SELECT 1 FROM vwbu WHERE buCustPtr = CU.cuGUID AND btType = 1 AND btBillType = 1)
		AND CU.ExciseTaxCode <> 0
	--- end customer table 

	---- ›Ê« Ì— «·‘—«¡
	SELECT 
		buCust_Name AS SupplierName,
		CU.ExciseTaxNumber AS SupplierTRN,
		BI.buDate AS InvoiceDate,
		BI.buNumber AS InvoiceNo,
		0 AS PermitNo,
		BI.biNumber + 1 AS [LineNo],
		BI.mtCode + '-' + BI.mtName AS ProductDescription,
		(BI.biUnitPrice * BI.biQty) - Bi.biDiscount - BI.biTotalDiscountPercent + Bi.biExtra + BI.biTotalExtraPercent AS PurchaseValueAED,
		BI.biExciseTaxVal AS ExciseTaxValueAED,
		BI.biExciseTaxCode AS TaxCode,
		MY.Code AS FCYCode,
		CASE WHEN BI.buCurrencyVal = 1 THEN 0 ELSE ((BI.biUnitPrice * BI.biQty) - Bi.biDiscount - BI.biTotalDiscountPercent + Bi.biExtra + BI.biTotalExtraPercent) / BI.buCurrencyVal END AS PurchaseFCY,
		CASE WHEN BI.buCurrencyVal = 1 THEN 0 ELSE BI.biExciseTaxVal / BI.buCurrencyVal END AS ExciseTaxFCY
	INTO #Purchases
	FROM 
		vwExtended_bi BI
		JOIN my000 MY ON MY.GUID = BI.buCurrencyPtr
		JOIN bt000 BT ON BI.buType = BT.GUID
		JOIN vwCu CU ON CU.cuGUID = BI.buCustPtr
	WHERE 
		-- ›Ê« Ì— «·‘—«¡
		btType = 1 AND btBillType = 0 
		AND BT.IsPriceOfferBill = 0
		AND CAST(BI.buDate AS DATE) BETWEEN @FromDate AND @ToDate
		AND BI.biExciseTaxCode <> 0

	SELECT * FROM #Purchases
	SELECT ISNULL(SUM(PurchaseValueAED), 0) AS PurchaseTotalAED, ISNULL(SUM(ExciseTaxValueAED), 0) AS ExciseTaxTotalAED, COUNT(*) AS TransactionCountTotal FROM #Purchases	

	---- ›Ê« Ì— «·„»Ì⁄
	SELECT 
		buCust_Name AS CustomerName,
		CU.ExciseTaxNumber AS CustomerTRN,
		BI.buDate AS InvoiceDate,
		BI.buNumber AS InvoiceNo,
		0 AS PermitNo,
		BI.biNumber + 1 AS [LineNo],
		BI.mtCode + '-' + BI.mtName AS ProductDescription,
		(BI.biUnitPrice * BI.biQty) - Bi.biDiscount - BI.biTotalDiscountPercent + Bi.biExtra + BI.biTotalExtraPercent AS SupplyValueAED,
		BI.biExciseTaxVal AS ExciseTaxValueAED,
		BI.biExciseTaxCode AS TaxCode,
		MY.Code AS FCYCode,
		N'' AS Country,
		CASE WHEN BI.buCurrencyVal = 1 THEN 0 ELSE ((BI.biUnitPrice * BI.biQty) - Bi.biDiscount - BI.biTotalDiscountPercent + Bi.biExtra + BI.biTotalExtraPercent) / BI.buCurrencyVal END AS SupplyFCY,
		CASE WHEN BI.buCurrencyVal = 1 THEN 0 ELSE BI.biExciseTaxVal / BI.buCurrencyVal END AS ExciseTaxFCY
	INTO #Sales
	FROM 
		vwExtended_bi BI
		JOIN my000 MY ON MY.GUID = BI.buCurrencyPtr
		JOIN bt000 BT ON BI.buType = BT.GUID
		JOIN vwCu CU ON CU.cuGUID = BI.buCustPtr
	WHERE 
		-- ›Ê« Ì— «·„»Ì⁄
		btType = 1 AND btBillType = 1 
		AND BT.IsPriceOfferBill = 0
		AND CAST(BI.buDate AS DATE) BETWEEN @FromDate AND @ToDate
		AND BI.biExciseTaxCode <> 0

	SELECT * FROM #Sales
	SELECT ISNULL(SUM(SupplyValueAED), 0) AS SupplyTotalAED, ISNULL(SUM(ExciseTaxValueAED), 0) AS ExciseTaxTotalAED, COUNT(*) AS TransactionCountTotal FROM #Sales	

	---- œ› — √” «–
	SELECT 
		EN.enDate AS TransactionDate,
		EN.acCode AS AccountID,
		EN.acName AS AccountName,
		EN.enNotes AS TransactionDescription,
		N'' AS Name,
		EN.ceNumber AS TransactionID,
		EN.ceGUID,
		ER.ParentGUID,
		ER.ParentType,
		EN.enDebit AS Debit,
		En.enCredit AS Credit,
		EN.enDebit - En.enCredit AS Balance
	INTO #GL
	FROM
		vwExtended_en AS EN
		LEFT JOIN er000 AS ER ON EN.ceGUID = ER.EntryGUID
	WHERE 
		CAST(EN.enDate AS DATE) BETWEEN @FromDate AND @ToDate
	ORDER BY EN.enDate

	SELECT * FROM #GL
	SELECT ISNULL(SUM(Debit), 0) AS TotalDebit, ISNULL(SUM(Credit), 0) AS TotalCredit, COUNT(*) AS TransactionCountTotal, (SELECT Code FROM my000 WHERE GUID = dbo.fnGetDefaultCurr()) AS GLTCurrency FROM #GL	

	-- mat file
	SELECT
		Code + ' - ' + Name AS Name,
		Spec,
		GCC.TaxCode
	FROM 
		mt000 AS MT
		INNER JOIN GCCMaterialTax000 AS GCC ON MT.GUID = GCC.MatGUID AND TaxType = 2
	-- end mat file
##################################################################################
#END
