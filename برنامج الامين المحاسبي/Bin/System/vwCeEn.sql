#########################################################
CREATE VIEW vwCeEn 
AS 
	SELECT 
		[ce].*,	
		[en].[enGUID], 
		[en].[enNumber], 
		[en].[enAccount], 
		[en].[enDate], 
		[en].[enDebit], 
		[en].[enCredit], 
		[en].[enNotes], 
		[en].[enCurrencyPtr], 
		[en].[enCurrencyVal], 
		[en].[enCostPoint], 
		[en].[enClass], 
		[en].[enNum1], 
		[en].[enNum2], 
		[en].[enVendor], 
		[en].[enSalesMan], 
		[en].[enContraAcc],
		[en].[enBiGUID],
		[en].[enLCGUID],
		[en].[enCustomerGUID]
	FROM 
		[vwCe] AS [ce] INNER JOIN [vwEn] AS [en]
		ON [en].[enParent] = [ce].[ceGUID]
#########################################################
#END
