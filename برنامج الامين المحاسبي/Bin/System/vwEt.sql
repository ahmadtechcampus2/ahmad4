#########################################################
CREATE VIEW vtEt
AS
	SELECT * FROM [et000]

#########################################################
CREATE VIEW vbEt
AS
	SELECT [v].*
	FROM [vtEt] AS [v] INNER JOIN [fnBranch_GetCurrentUserReadMask](DEFAULT) AS [f] ON [v].[branchMask] & [f].[Mask] <> 0
	
#########################################################
CREATE VIEW vcEt
AS
	SELECT * FROM [vbEt]

#########################################################
CREATE VIEW vcEt0
AS
	SELECT *
	FROM [vcEt]
	WHERE [EntryType] = 0
#########################################################
CREATE VIEW vcEt2
AS
	SELECT *
	FROM [vcEt]
	WHERE [EntryType] = 2
#########################################################
CREATE VIEW vdEt
AS
	SELECT * FROM [vbEt]

#########################################################
CREATE VIEW vwEt  
AS 
	SELECT 
		[GUID] AS [etGUID], 
		[EntryGroup] AS [etEntryGroup], 
		[EntryType] AS [etEntryType], 
		[Name] AS [etName], 
		[LatinName] AS [etLatinName], 
		[Abbrev] AS [etAbbrev], 
		[LatinAbbrev] AS [etLatinAbbrev], 
		[DbTerm] AS [etDbTerm], 
		[CrTerm] AS [etCrTerm], 
		[Color1] AS [etColor1], 
		[Color2] AS [etColor2], 
		[DefAccGUID] AS [etDefAccGUID], 
		[bAcceptCostAcc] AS [etbAcceptCostAcc], 
		[bAutoPost] AS [etbAutoPost], 
		[bDetailed] AS [etbDetailed], 
		[FldAccName] AS [etFldAccName], 
		[FldDebit] AS [etFldDebit], 
		[FldCredit] AS [etFldCredit], 
		[FldNotes] AS [etFldNotes], 
		[FldCurName] AS [etFldCurName], 
		[FldCurVal] AS [etFldCurVal], 
		[FldStat] AS [etFldStat], 
		[FldCostPtr] AS [etFldCostPtr], 
		[FldDate] AS [etFldDate], 
		[FldVendor] AS [etFldVendor], 
		[FldSalesMan] AS [etFldSalesMan], 
		[FldAccParent] AS [etFldAccParent], 
		[FldAccFinal] AS [etFldAccFinal], 
		[FldAccCredit] AS [etFldAccCredit], 
		[FldAccDebit] AS [etFldAccDebit], 
		[FldAccBalance] AS [etFldAccBalance],
		[branchMask] AS [etBranchMask],
		UseReverseCharges AS etUseReverseCharges,
		ReverseChargesAccGUID AS etReverseChargesAccGUID, 
		ReverseChargesContraAccGUID AS etReverseChargesContraAccGUID,
		[TaxType] AS [etTaxType]
	FROM 
		[vbEt]

#########################################################
#END