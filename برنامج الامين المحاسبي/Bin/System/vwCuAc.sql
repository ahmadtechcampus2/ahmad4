#########################################################
CREATE VIEW vwCuAc
AS
	SELECT
		[cuGUID],
		[cuNumber],
		[cuCustomerName],
		[cuNationality],
		[cuAddress],
		[cuPhone1],
		[cuPhone2],
		[cuFAX],
		[cuTELEX],
		[cuNotes],
		[cuUseFlag],
		[cuPicture],
		[cuAccount],
		[cuCheckDate],
		[cuSecurity],
		[cuType],
		[cuDiscRatio],
		[cuDefPrice],
		[cuState],
		[cuArea],
		[cuCity],
		[cuStreet],
		[acGUID],
		[acNumber],
		[acName],
		[acCode],
		[acCDate],
		[acParent],
		[acFinal],
		[acNSons],
		[acDebit],
		[acCredit],
		[acInitDebit],
		[acInitCredit],
		[acUseFlag],
		[acMaxDebit],
		[acNotes],
		[acCurrencyVal],
		[acCurrencyPtr],
		[acWarn],
		[acCheckDate],
		[acSecurity],
		[acDebitOrCredit],
		[acType],
		[acState],
		[acNum1],
		[acNum2],
		[acBranchGUID],
		[acBranchMask]
	FROM
		[vwCu] AS [cu] INNER JOIN [vwAc] AS [ac]
		ON [ac].[acGUID] = [cu].[cuAccount]

#########################################################
#END