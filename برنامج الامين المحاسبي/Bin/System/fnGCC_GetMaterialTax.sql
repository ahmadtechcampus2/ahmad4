###############################################################################
CREATE FUNCTION fnGCC_GetMaterialTax_VAT (@mtGUID UNIQUEIDENTIFIER)
	RETURNS TABLE
AS 
	RETURN (
		SELECT TOP 1
			VAT.TaxType					AS mtVAT_TaxType, 
			VAT.TaxCode					AS mtVAT_TaxCode, 
			VAT.Ratio					AS mtVAT_Ratio, 
			VAT.ProfitMargin			AS ProfitMargin, 
			mt.IsCalcTaxForPUTaxCode	AS IsCalcTaxForPUTaxCode
		FROM 
			mt000 mt 
			INNER JOIN	GCCMaterialTax000 VAT	ON mt.GUID = VAT.MatGUID AND VAT.TaxType = 1
		WHERE mt.GUID = @mtGUID)
###############################################################################
CREATE FUNCTION fnGCC_GetMaterialTax (@mtGUID UNIQUEIDENTIFIER)
	RETURNS TABLE
AS 
	RETURN (
		SELECT TOP 1
			VAT.TaxType					AS mtVAT_TaxType, 
			VAT.TaxCode					AS mtVAT_TaxCode, 
			VAT.Ratio					AS mtVAT_Ratio, 
			VAT.ProfitMargin			AS ProfitMargin, 
			ISNULL(EXC.TaxType, 0)		AS mtExcise_TaxType,
			ISNULL(EXC.TaxCode, 0)		AS mtExcise_TaxCode,
			ISNULL(EXC.Ratio, 0)		AS mtExcise_Ratio,
			mt.IsCalcTaxForPUTaxCode	AS IsCalcTaxForPUTaxCode
		FROM 
			mt000 mt 
			INNER JOIN	GCCMaterialTax000 VAT	ON mt.GUID = VAT.MatGUID AND VAT.TaxType = 1
			LEFT JOIN	GCCMaterialTax000 EXC	ON mt.GUID = EXC.MatGUID AND EXC.TaxType = 2
		WHERE mt.GUID = @mtGUID)
###################################################################################
#END
