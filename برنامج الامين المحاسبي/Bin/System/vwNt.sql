#########################################################
CREATE VIEW vtNt
AS
	SELECT * FROM [Nt000]

#########################################################
CREATE VIEW vbNt
AS
	SELECT [v].*
	FROM [vtNt] AS [v] INNER JOIN [fnBranch_GetCurrentUserReadMask](DEFAULT) AS [f] ON [v].[branchMask] & [f].[Mask] <> 0

#########################################################
CREATE VIEW vcNt
AS
	SELECT * FROM [vbNt]

#########################################################
CREATE VIEW vdNt
AS
	SELECT DISTINCT * FROM [vbNt]

#########################################################
CREATE VIEW vwNt 
AS 
	SELECT 
		[GUID] AS [ntGUID], 
		[NoteGroup] AS [ntNoteGroup], 
		[NoteType] AS [ntNoteType], 
		[Name] AS [ntName], 
		[LatinName] AS [ntLatinName], 
		[Abbrev] AS [ntAbbrev], 
		[LatinAbbrev] AS [ntLatinAbbrev], 
		[DefPayAccGUID] AS [ntDefPayAcc], 
		[DefRecAccGUID] AS [ntDefRecAcc], 
		[DefColAccGUID] AS [ntDefColAcc], 
		[DefColRatio] AS [ntDefColRatio], 
		[BankGUID] AS [ntBankGUID], 
		[bNoEntry] AS [ntbNoEntry], 
		[bAutoEntry] AS [ntbAutoEntry], 
		[bAutoPost] AS [ntbAutoPost], 
		[State] AS [ntState], 
		[CostGUID] AS [ntCostPtr],
		[branchMask] AS [ntBranchMask],
		[bCanCollect]   AS [ntCanCollect],
		[bCanEndorse]   AS [ntCanEndorse],
		[bCanDiscount]  AS [ntCanDiscount],
		[bCanGenColEnt] AS [ntCanGenColEnt],
		[bCanGenEndEnt] AS [ntCanGenEndEnt],
		[bCanGenDisEnt] AS [ntCanGenDisEnt],
		[bManualCollect] AS [ntManualCollect],
		[bManualEndorse] AS [ntManualEndorse],
		[bManualDiscount] AS [ntManualDiscount],
		[bManualGenEntry] AS [ntManualGenEntry],
		[bManualRecOrPay] AS [ntManualRecOrPay],
		[bCanRecOrPay] AS [ntCanRecOrPay],
		[bCanGenRecOrPayEnt] AS [ntCanGenRecOrPayEnt],
		[DefRecOrPayAccGUID] AS [ntDefRecOrPayAccGUID],
		[DefUnderDisAccGUID] AS [ntDefUnderDisAccGUID],
		[DefComAccGUID] AS [ntDefComAccGUID],
		[DefChargAccGUID] AS [ntDefChargAccGUID],
		[DefEndorseAccGUID] AS [ntDefEndorseAccGUID],
		[bCanReturn] AS [ntCanReturn],
		[bCanGenReturnEnt] AS [ntCanGenReturnEnt],
		[bPayDeliveryGenEnt] AS [ntPayDeliveryGenEnt],
		[bCanFinishing] AS [ntCanFinishing],
		[ForceDistenationBank] AS [ntForceDistenationBank],
		[ForceDefaultAccounts] AS [ntDefaultAccounts],
		[DefDisAccGUID] AS [ntDefDisAccGUID],
		[ExchangeRatesAccGUID] AS [ntExchangeRatesAccGUID],
		[bTransfer] AS [bTransfer]
	FROM 
		[vbNt]
#########################################################
#END