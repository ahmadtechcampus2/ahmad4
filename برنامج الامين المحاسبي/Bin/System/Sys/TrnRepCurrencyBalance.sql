###########################
CREATE proc TrnRepCurrencyBalance
		@SourceRepGuid UNIQUEIDENTIFIER, 
		@FromDate DateTime,
		@ToDate	DateTime,
		@Currency uniqueidentifier = 0x0
		--@JustExchangeTypeAccs int = 1, 	
		--@WithCost int = 0
as
	
set nocount on 

	Create table #FinalResult(CurrencyGuid uniqueidentifier, ExTypeGuid uniqueidentifier,
				SumDebit float, SumCredit float, Balance float)

	create Table #result (SumDebit float, SumCredit float, Balance Float, CurrencyGuid uniqueidentifier,
			 AccountGuid uniqueidentifier,ExchangeType uniqueidentifier)
	
	insert into  #result
	select
		sum(en.debit/en.currencyval) as debit,
		sum(en.credit/en.currencyval) as credit,
		sum(en.debit/en.currencyval) - sum(en.credit/en.currencyval) as balance,
		en.currencyguid,		
		0x0,--en.accountguid,
		t.guid

	from en000 as en
	inner join ce000 as ce on  ce.guid = en.parentguid
	INNER JOIN TrnExchange000 AS ex on ex.entryguid = ce.guid
	INNER JOIN TrnExchangeTypes000 AS t on t.guid = ex.typeguid
	inner join RepSrcs as s on s.IdType = t.guid 
	where  
		IdTbl = @SourceRepGuid AND (@Currency = 0x0 OR (en.CurrencyGuid = @Currency))
		AND ex.Date between @FromDate AND @ToDate
	group by t.guid, en.currencyguid--, en.AccountGuid

	select r.*, m.[name] as Currencyname, t.[name] as typename--, Ac.[name]
	from #result as r 
		inner join my000 as m on m.guid = r.currencyguid
		inner join trnExchangetypes000 as t on t.guid = r.ExchangeType
		--inner join ac000 as ac on ac.guid = r.accountguid
	order by m.number, t.sortnum
#####################
#END