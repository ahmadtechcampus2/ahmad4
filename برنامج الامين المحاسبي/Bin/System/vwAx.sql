#########################################################
CREATE VIEW vcAx AS
	SELECT * FROM [ax000]

#########################################################
CREATE VIEW vwAx
AS 
	SELECT
		[Number] AS [axNumber],
		[Type] AS [axType],
		[GUID] AS [axGUID],
		[AdGUID] AS [axAssDetailGUID],
		[AccGuid] AS [axAccGuid],
		[CustomerGUID] AS [axCustomerGUID],
		[Notes] AS [axNotes],
		[Spec] AS [axSpec],
		[Value] AS [axValue],
		[CurrencyGUID] AS [axCurrencyGUID],
		[CurrencyVal] AS [axCurrencyVal],
		[Date] AS [axDate],
		[EntryGUID] AS [axEntryGUID],
		[EntryNum] AS [axEntryNum],
		[EntryDate] AS [axEntryDate],
		[Security] AS [axSecurity],
		[Number] AS [Number],
		[GUID] AS [GUID],
		[CostGuid] AS [axCostGuid],
		[BranchGuid] AS [axBranchGuid],
		[EntryTypeGUID]	AS [axEntryTypeGUID]
	FROM 
		[vcAx]

#########################################################
CREATE VIEW vwAssAdded AS
	SELECT * FROM [vwAx] WHERE [axType] = 0

#########################################################
CREATE VIEW vwAssDeduct AS
	SELECT * FROM [vwAx] WHERE [axType] = 1

#########################################################
CREATE VIEW vwAssMainten AS
	SELECT * FROM [vwAx] WHERE [axType] = 2
#########################################################
CREATE VIEW vtassetExclude
AS
	SELECT * FROM assetExclude000
#########################################################
CREATE VIEW vbassetExclude
AS
	SELECT * FROM vtassetExclude
#########################################################
CREATE VIEW vtAX
AS
	SELECT * FROM ax000
#########################################################
CREATE VIEW vbAX
AS
	SELECT * FROM vtAx
#########################################################
CREATE VIEW vwAddedAssBr
AS
	SELECT vwAssAdded.* FROM vwAssAdded 
	JOIN vbax ON vwAssAdded.axBranchGuid = vbax.BranchGuid
#########################################################
CREATE VIEW vwADeductAssBr
AS
	SELECT vwAssDeduct.* FROM vwAssDeduct
	JOIN vbax ON vwAssDeduct.axBranchGuid = vbax.BranchGuid
#########################################################
CREATE VIEW vwMaintenAssBr
AS
	SELECT vwAssMainten.* FROM vwAssMainten
	JOIN vbax ON vwAssMainten.axBranchGuid = vbax.BranchGuid
#########################################################
#END