#########################################################
CREATE VIEW vwExtended_en
AS 
	SELECT 
		[ce].*, 
		[ac].[acNumber], 
		[ac].[acName], 
		[ac].[acCode], 
		[ac].[acParent], 
		[ac].[acFinal], 
		[ac].[acSecurity], 
		[ac].[acNSons], 
		[ac].[acType], 
		[ac].[acMaxDebit], 
		[ac].[acWarn], 
		[ac].[acNotes], 
		[ac].[acUseFlag], 
		[ac].[acCurrencyPtr], 
		[ac].[acCurrencyVal], 
		[ac].[acDebitOrCredit], 
		[ac].[acGUID], 
		[ac].[acLatinName] 
	FROM 
		[vwCeEn] AS [ce] INNER JOIN [vwAc] AS [ac] 
		ON [ce].[enAccount] = [ac].[acGUID]

#########################################################
#END