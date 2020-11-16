##############################################################################
CREATE Proc prcTrnRepCurrencyAvg
		@FromDate DateTime,
		@ToDate DateTime,
		@SortBy int
		
AS
	set nocount on
	
	CREATE TABLE #CurrAvg
	(currency uniqueidentifier, Debit Float, Credit Float, 
	Balance float, currencyval float)
		
	insert into #CurrAvg
	select guid,0,0,0,0 from my000

	declare	@c_debit float,
		@c_credit float,
		@c_currency uniqueidentifier,
		@c_currencyval float,
		@c_NewAvg float,
		@c_CurBalance float,
		@c_kind int,
		@Balance float,
		@Avg float,
		@Debit float,
		@Credit float,
		@AvgEffect INT



	CREATE TABLE #Entries
	(
		ExTypeGuid 	uniqueidentifier,
		CurrencyGuid 	uniqueidentifier,
		CurrencyVal 	FLOAT,
		Debit  		FLOAT,
		Credit 		FLOAT,
		Date 		DateTime,
		CeNumber	INT,
		EnNumber	INT,
		AvgEffect INT
	)
	
	INSERT INTO #Entries
	SELECT 
		ExTypeGuid,
		CurrencyGuid,
		CurrencyVal,
		Debit / CurrencyVal,
		Credit / CurrencyVal,
		Date,
		CeNumber,
		EnNumber,
		AvgEffect
	FROM FnTrnExCurrEntries(0x0, 0x0, @FromDate, @ToDate, 0, 0x0) 
	WHERE (Debit / CurrencyVal) > 1 OR (Credit / CurrencyVal) > 1

	ORDER BY [Date], CeNumber, EnNumber
	
	DECLARE balcursor CURSOR FORWARD_ONLY FOR
	SELECT
		CurrencyGuid,
		CurrencyVal,
		Debit,
		Credit,
		AvgEffect
	FROM #Entries
	ORDER BY [Date], CeNumber, EnNumber
		
	
	OPEN balcursor 
	FETCH NEXT FROM balcursor INTO 
		@c_currency,
		@c_currencyval,
		@c_debit,
		@c_credit,
		@AvgEffect

	WHILE @@FETCH_STATUS = 0 
	BEGIN  
		select	@avg = isNull(CurrencyVal, 0),
			@Balance = IsNull(Balance, 0) 
		from #CurrAvg
		where currency = @c_currency

		if (@c_debit > 0) -- purchase
		begin	
			IF (@AvgEffect <> 0)
			BEGIN
				Set @c_NewAvg = (@c_debit * @c_currencyval + @Balance * @Avg)
				Set @c_NewAvg = @c_NewAvg / (@c_debit + @Balance)
 				set @c_CurBalance =  @c_debit + @Balance
				update #CurrAvg
				set balance = @c_CurBalance,
				Debit = Debit + @c_debit,
				currencyval =  @c_NewAvg
				where currency = @c_currency
			END
			ELSE -- not effect avg
			BEGIN
				update #CurrAvg
				set Debit = Debit + @c_debit
				where currency = @c_currency
			END
				
			
		end
		else
		begin
			select @c_CurBalance = isNull(balance, 0) - @c_credit
			from #CurrAvg where  currency = @c_currency
			if (@c_CurBalance < 0)
				set @c_CurBalance = 0
			update #CurrAvg
			set balance = @c_CurBalance,
			Credit = Credit + @c_credit
			where currency = @c_currency	
		END

	FETCH NEXT FROM balcursor INTO 
		@c_currency,
		@c_currencyval,
		@c_debit,
		@c_credit,
		@AvgEffect
	END


	CLOSE balcursor 
	DEALLOCATE balcursor

	
	CREATE TABLE #RESULT
	(
		ExTypeGuid uniqueidentifier,
		CurrencyGuid uniqueidentifier,
		Debit 	FLOAT,
		Credit 	FLOAT,
		--BALANCE FLOAT,
		CurrencyAvg FLOAT
	)
	
	INSERT INTO #RESULT
	SELECT 
		ISNULL(ExTypeGuid, 0X0),
		ISNULL(CurrencyGuid, 0X0),
		Sum(Debit), 
		Sum(Credit),
		0 --CurrencyAvg
	FROM #Entries AS En
	Group By CurrencyGuid, ExTypeGuid WITH ROLLUP
	--HAVING CurrencyGuid IS NOT NULL	--and ExTypeGuid is null

	--INNER JOIN #CurrAvg AS CurAvg on CurAvg.
	UPDATE #RESULT
		SET CurrencyAvg = Cur.CurrencyVal
	FROM #CurrAvg AS Cur 
	INNER JOIN #RESULT AS Res ON Res.CurrencyGuid = Cur.Currency

	WHERE ExTypeGuid = 0X0

	IF (@SortBy = 0)
		SELECT 
			ExType.[NAME] AS ExTypeName, 
			MY.[myNAME] AS CurrencyName,
			MY.[myCODE] AS CurrencyCode,
			R.ExTypeGuid,
			R.CurrencyGuid,
			R.Debit,
			R.Credit,
			R.CurrencyAvg
		FROM 
			#RESULT AS R
			LEFT JOIN VwTrnExchangeTypes AS ExType ON R.ExTypeGuid = ExType.GUID
			INNER JOIN VwMy as my on my.myGuid = R.CurrencyGuid
		ORDER BY ExType.Type,ExType.SortNum, my.myNumber
	ELSE
		SELECT 
			ExType.[NAME] AS ExTypeName, 
			MY.[myNAME] AS CurrencyName,
			MY.[myCODE] AS CurrencyCode,
			R.ExTypeGuid,
			R.CurrencyGuid,
			R.Debit,
			R.Credit,
			R.CurrencyAvg
		FROM 
			#RESULT AS R
			LEFT JOIN VwTrnExchangeTypes AS ExType ON R.ExTypeGuid = ExType.GUID
			INNER JOIN VwMy as my on my.myGuid = R.CurrencyGuid
		ORDER BY my.myNumber, ExType.Type,ExType.SortNum 
##############################################################################
#END