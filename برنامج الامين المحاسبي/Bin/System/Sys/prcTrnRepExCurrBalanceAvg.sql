########################################################
CREATE Proc prcTrnRepExCurrBalanceAvg
AS 
	set nocount ON 

	SELECT 
		my.[name]AS Name, 
		my.Guid AS Currency,
		SUM(fn.Debit / fn.CurrencyVal) AS debit,
		SUM(Credit / fn.CurrencyVal) AS Credit,
		SUM((Debit - Credit)/fn.CurrencyVal)AS Balance,
		dbo.FnTrnGetSystemCurCostVal(fn.CurrencyGuid, '2100')As CurrencyVal
	FROM my000 AS my
	INNER JOIN FnTrnExCurrEntries(0x0, 0x0, '', '2100', 0, 0x0) AS fn ON fn.CurrencyGuid = my.GUID
	GROUP BY my.[name],my.Guid,dbo.FnTrnGetSystemCurCostVal(fn.CurrencyGuid, '2100')
	
GO
########################################################
#END