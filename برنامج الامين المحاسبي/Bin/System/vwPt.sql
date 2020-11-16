######################################################
CREATE VIEW vwPt
	AS 
	SELECT 
		[GUID] AS [ptGUID],
		[Type] AS [ptType],
		[RefGUID] AS [ptRefGUID],
		[Term] AS [ptTerm],
		[Days] AS [ptDays],
		[Disable] AS [ptDisable],
		[CalcOptions] AS [ptCalcOptions],
		[CustAcc]	AS [ptCustAcc],
		[DueDate]	AS [ptDueDate],
		[Debit]	AS [ptDebit],
		[Credit]	AS [ptCredit],
		[TypeGuid]	AS [ptTypeGuid],
		[IsTransfered]	AS [ptTransfered] , 
		[TransferedInfo] AS [ptTransferedInfo]		
	FROM 
		[pt000]
######################################################
#END
