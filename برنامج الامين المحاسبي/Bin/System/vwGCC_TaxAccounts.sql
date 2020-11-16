#########################################################
CREATE VIEW vwGCC_Tax_TaxAcc
AS
	SELECT 
		*
	FROM 
		[vbAc]
###########################################################################
CREATE VIEW vwGCC_Tax_VATAcc 
AS
	SELECT * FROM vwGCC_Tax_TaxAcc
	WHERE GUID in (SELECT [VATAccGUID] FROM GCCTaxAccounts000)
###########################################################################
CREATE VIEW vwGCC_Tax_ReturnAcc
AS
	SELECT * FROM vwGCC_Tax_TaxAcc
	WHERE GUID in (SELECT [ReturnAccGUID] FROM GCCTaxAccounts000)
###########################################################################
CREATE VIEW vwGCC_Tax_ReverseChargesAcc
AS
	SELECT * FROM vwGCC_Tax_TaxAcc
	WHERE GUID in (SELECT [ReverseChargesAccGUID] FROM GCCTaxAccounts000)
###########################################################################
CREATE VIEW vwGCC_Tax_ReturnReverseChargesAcc
AS
	SELECT * FROM vwGCC_Tax_TaxAcc
	WHERE GUID in (SELECT [ReturnReverseChargesAccGUID] FROM GCCTaxAccounts000)
###########################################################################
CREATE VIEW vwGCC_Tax_ExciseTaxAcc
AS
	SELECT * FROM vwGCC_Tax_TaxAcc
	WHERE GUID in (SELECT [ExciseTaxAccGUID] FROM GCCTaxAccounts000)
###########################################################################
CREATE VIEW vwGCC_Tax_ReturnExciseTaxAcc
AS
	SELECT * FROM vwGCC_Tax_TaxAcc
	WHERE GUID in (SELECT [ReturnExciseTaxAccGUID] FROM GCCTaxAccounts000)
###########################################################################
#END