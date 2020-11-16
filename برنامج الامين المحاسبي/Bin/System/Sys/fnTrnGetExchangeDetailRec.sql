#################################
CREATE   Function fnTrnGetExchangeDetailRec
	(
		@ExchangeGuid uniqueidentifier
	)
returns Table
	 
As
Return
	select 
		d.CurrencyGuid,
		d.CurrencyVal,
		d.CurrencyAvg,
		d.Amount, 
		d.AccGuid,
		d.Type	
From
	TrnExchange000 as ex
	INNER JOIN trnExchangeDetail000 As d on (d.ExchangeGuid = ex.guid)
where ex.guid = @ExchangeGuid
##################################
#END