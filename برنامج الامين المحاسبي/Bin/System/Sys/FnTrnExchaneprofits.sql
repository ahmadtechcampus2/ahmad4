#####################################
CREATE   FunctiON FnTrnExchaneprofits
	(
		@SourceRepGuid UNIQUEIDENTIFIER, 
		@FromDate DATETIME,
		@ToDate	DATETIME,
		@Currency UNIQUEIDENTIFIER = 0x0
	)
RETURNS @Res TABLE
		(
			ExTypeGuid UNIQUEIDENTIFIER,
			ExTypeName NVARCHAR(250)	COLLATE ARABIC_CI_AI,
			Currency UNIQUEIDENTIFIER,
			ExGuid UNIQUEIDENTIFIER,
			CeGuid UNIQUEIDENTIFIER,
			[Date] DATETIME,
			ExNumber INT,
			CeNumber INT,
			BaseCurrAmount FLOAT,
			sellsAmount FLOAT,
			SellsCostAmount FLOAT,
			CurrVal FLOAT,
			CurrAvg FLOAT,
			profit	FLOAT
		)
AS
BEGIN
	INSERT INTO @Res 
	SELECT 
		Exch.typeguid, 
		t.[Name], 
		Exch.paycurrency, 
		Exch.guid, 
		ce.guid, 
		Exch.[date], 
		Exch.number, 
		Ce.number, 
		en.Credit / en.CurrencyVal,
		0,
		0,
		Exch.payCurrencyVal, 
		en.CurrencyVal,
		(Exch.PayCurrencyVal - en.CurrencyVal) * (en.Credit / en.CurrencyVal)
	FROM  
		(
			SELECT 
					ISNULL(d.CurrencyGuid, TrnExch.PayCurrency) AS PayCurrency,
					TrnExch.EntryGuid,
					ISNULL(d.CurrencyVal, TrnExch.PayCurrencyVal) AS PayCurrencyVal,
					ISNULL(d.Amount, TrnExch.PayAmount / TrnExch.PayCurrencyVal) AS PayAmount,
					ISNULL(d.AccGuid, TrnExch.PayAcc) AS PayAcc,
					TrnExch.TypeGuid,
					ISNULL(d.CurrencyGuid, TrnExch.PayCurrency) AS PayCurrency1,
					TrnExch.[Date],
					TrnExch.Guid,
					TrnExch.Number
				FROM 
					TrnExchange000 AS TrnExch
					LEFT JOIN trnExchangeDetail000 AS d ON d.exchangeGuid = TrnExch.Guid AND d.type = 1  
				WHERE 
					TrnExch.CancelEntryGuid = 0x0
		)	AS Exch		
		INNER JOIN my000 AS my ON my.guid = Exch.PayCurrency
		INNER JOIN TrnExchangeTypes000 AS t ON t.guid = Exch.typeGuid 
		INNER JOIN RepSrcs AS s ON s.IdType = t.guid 
		INNER JOIN ce000 AS ce ON Exch.entryguid = ce.guid 
		INNER JOIN en000 AS en ON en.ParentGuid = ce.GUID
				AND en.AccountGuid = Exch.PayAcc AND en.CurrencyGuid = Exch.PayCurrency1 AND en.Credit > 0		
		WHERE Exch.Date BETWEEN @FromDate AND @ToDate  
		AND IdTbl = @SourceRepGuid  
		AND (@Currency = 0X0 OR my.guid = @Currency) 						
	ORDER by  my.number, t.sortnum, Exch.date  
RETURN 
END	
#####################################
#END