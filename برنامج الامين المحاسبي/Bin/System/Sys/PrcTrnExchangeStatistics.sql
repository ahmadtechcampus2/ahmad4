############################################
CREATE PROCEDURE PrcTrnExchangeStatistics 
	--EXEC PrcTrnExchangeStatistics 3, '3-1-2010' 
	@AggregationType	INT = 0,--0 without Agg, 1 by Day,  2 by Day,Currency,  3 by Currency,Day 
	@FromDate			DateTime = '1-1-1900',
	@ToDate				DateTime = '1-1-2100'
AS
BEGIN
	SET NOCOUNT ON
	CREATE TABLE #Result
	(
		CurrencyName			NVARCHAR(100) COLLATE ARABIC_CI_AI,
		exTypeName				NVARCHAR(100) COLLATE ARABIC_CI_AI,
		Date					DateTime,
		CashCount				INT,
		TotalCash				FLOAT,
		EquivilantTotalCash		FLOAT,
		AvgCashVal				FLOAT,
		payCount				INT,
		Totalpay				FLOAT,
		EquivilantTotalpay		FLOAT,
		AvgpayVal				FLOAT,
		Level					INT
	)
	CREATE TABLE #CashStatistics
	(
		CurrencyName			NVARCHAR(100) COLLATE ARABIC_CI_AI,
		exTypeName				NVARCHAR(100) COLLATE ARABIC_CI_AI,
		Date					DateTime,
		CashCount				INT,
		TotalCash				FLOAT,
		EquivilantTotalCash		FLOAT,
		AvgCashVal				FLOAT
	)
	CREATE TABLE #PayStatistics
	(
		CurrencyName			NVARCHAR(100) COLLATE ARABIC_CI_AI,
		exTypeName				NVARCHAR(100) COLLATE ARABIC_CI_AI,
		Date					DateTime,
		payCount				INT,
		Totalpay				FLOAT,
		EquivilantTotalpay		FLOAT,
		AvgpayVal				FLOAT
	)
	CREATE TABLE #ExchangeStatistics
	(
		CurrencyName			NVARCHAR(100) COLLATE ARABIC_CI_AI,
		exTypeName				NVARCHAR(100) COLLATE ARABIC_CI_AI,
		Date					DateTime, 
		CashCount				INT,
		TotalCash				FLOAT,
		EquivilantTotalCash		FLOAT,
		AvgCashVal				FLOAT,
		payCount				INT,
		Totalpay				FLOAT,
		EquivilantTotalpay		FLOAT,
		AvgpayVal				FLOAT
	)
	/*
	Algorithm:
	Part 1 : CashStatistics
	Part 2 : PayStatistics
	Part 3 : ExchangeStatistics(CashStatistics + PayStatistics)
	Part 4 : Aggregation(without Agg,  by Day,  by Day+Currency, by Currency+Day )
	*/
	-------------------------------------------------------------------------------------------------------------------
	-------------------------------P A R T 1 : C A S H S T A T I S T I C S---------------------------------------------
	-------------------------------------------------------------------------------------------------------------------
	
	--------------------------SimpleCashStatistics----------------------------------------
	SELECT CashCurrency.Name AS CurrencyName, exType.Name AS exTypeName, DATEADD(D, 0, DATEDIFF(D, 0, ex.Date )) AS Date ,Count(ex.CashAmount) As CashCount, SUM(ex.CashAmount/ex.CashCurrencyVal) As TotalCash, SUM(ex.CashAmount) As EquivilantTotalCash, SUM(ex.CashAmount) / SUM(ex.CashAmount/ex.CashCurrencyVal) As AvgCashVal
	INTO #SimpleCashStatistics
	FROM TrnExchange000 ex
	INNER JOIN TrnExchangeTypes000 exType ON ex.TypeGUID = exType.GUID 
	INNER JOIN MY000 CashCurrency ON ex.CashCurrency = CashCurrency.GUID
	WHERE ex.bSimple = 1 AND (ex.Date BETWEEN @FromDate AND @ToDate )
	GROUP BY CashCurrency.Name, DATEADD(D, 0, DATEDIFF(D, 0, ex.Date )), exType.Name
	
	--------------------------DetailCashStatistics----------------------------------------
	SELECT CashCurrency.Name AS CurrencyName, exType.Name AS exTypeName, DATEADD(D, 0, DATEDIFF(D, 0, ex.Date )) AS Date ,Count(exDetail.Amount) As CashCount, SUM(exDetail.Amount/exDetail.CurrencyVal) As TotalCash, SUM(exDetail.Amount) As EquivilantTotalCash, SUM(exDetail.Amount) / SUM(exDetail.Amount/exDetail.CurrencyVal) As AvgCashVal
	INTO #DetailCashStatistics
	FROM TrnExchange000 ex
	INNER JOIN TrnExchangeDetail000 exDetail ON ex.GUID = exDetail.ExchangeGUID AND exDetail.Type = 0
	INNER JOIN TrnExchangeTypes000 exType ON ex.TypeGUID = exType.GUID 
	INNER JOIN MY000 CashCurrency ON exDetail.CurrencyGUID = CashCurrency.GUID
	WHERE ex.bSimple = 0 AND (ex.Date BETWEEN @FromDate AND @ToDate )
	GROUP BY CashCurrency.Name, DATEADD(D, 0, DATEDIFF(D, 0, ex.Date )), exType.Name
	--------------------------------------------------------------------------------------
	-----------------------------CashStatistics-------------------------------------------
	--------------------------------------------------------------------------------------
	INSERT INTO #CashStatistics
	SELECT SimpleCash.CurrencyName, SimpleCash.exTypeName, SimpleCash.Date ,SimpleCash.CashCount + DetailCash.CashCount AS CashCount, SimpleCash.TotalCash + DetailCash.TotalCash AS TotalCash, SimpleCash.EquivilantTotalCash + DetailCash.EquivilantTotalCash AS EquivilantTotalCash, (SimpleCash.EquivilantTotalCash + DetailCash.EquivilantTotalCash) / (SimpleCash.TotalCash + DetailCash.TotalCash) AS AvgCashVal
	FROM #SimpleCashStatistics SimpleCash
	INNER JOIN #DetailCashStatistics DetailCash ON SimpleCash.CurrencyName = DetailCash.CurrencyName AND SimpleCash.exTypeName = DetailCash.exTypeName AND SimpleCash.Date = DetailCash.Date
	
	UNION SELECT * FROM #SimpleCashStatistics
	UNION SELECT * FROM #DetailCashStatistics
	
	----------------------Now Filtering #CashStatistics by deleting CalculatedCash_records-----------------------------------
	DECLARE @CurrencyName NVARCHAR(100), @exTypeName NVARCHAR(100), @Date Datetime, @Count INT
	DECLARE CalculatedCash_records CURSOR FOR
	SELECT SimpleCash.CurrencyName, SimpleCash.exTypeName, SimpleCash.Date, SimpleCash.CashCount + DetailCash.CashCount
	FROM #SimpleCashStatistics SimpleCash
	INNER JOIN #DetailCashStatistics DetailCash ON SimpleCash.CurrencyName = DetailCash.CurrencyName AND SimpleCash.exTypeName = DetailCash.exTypeName AND SimpleCash.Date = DetailCash.Date
	
	OPEN CalculatedCash_records
	FETCH NEXT FROM CalculatedCash_records INTO
	@CurrencyName,
	@exTypeName, 
	@Date,
	@Count
	WHILE @@FETCH_STATUS = 0 
	BEGIN
		DELETE FROM #CashStatistics
		WHERE CurrencyName = @CurrencyName AND exTypeName = @exTypeName AND Date = @Date AND CashCount <> @Count
		FETCH NEXT FROM CalculatedCash_records INTO
		@CurrencyName,
		@exTypeName, 
		@Date,
		@Count
	END
	CLOSE CalculatedCash_records
	DEALLOCATE CalculatedCash_records
	-----------------------------------------------------------------------------------------------------------------
	
	
	
	-------------------------------------------------------------------------------------------------------------------
	-------------------------------P A R T 2 : P A Y S T A T I S T I C S---------------------------------------------
	-------------------------------------------------------------------------------------------------------------------
	
	--------------------------SimplePayStatistics----------------------------------------
	SELECT PayCurrency.Name AS CurrencyName, exType.Name AS exTypeName, DATEADD(D, 0, DATEDIFF(D, 0, ex.Date )) AS Date ,Count(ex.PayAmount) As PayCount, SUM(ex.PayAmount/ex.PayCurrencyVal) As TotalPay, SUM(ex.PayAmount) As EquivilantTotalPay, SUM(ex.PayAmount) / SUM(ex.PayAmount/ex.PayCurrencyVal) As AvgPayVal
	INTO #SimplePayStatistics
	FROM TrnExchange000 ex
	INNER JOIN TrnExchangeTypes000 exType ON ex.TypeGUID = exType.GUID 
	INNER JOIN MY000 PayCurrency ON ex.PayCurrency = PayCurrency.GUID
	WHERE ex.bSimple = 1 AND (ex.Date BETWEEN @FromDate AND @ToDate )
	GROUP BY PayCurrency.Name, DATEADD(D, 0, DATEDIFF(D, 0, ex.Date )), exType.Name
	
	--------------------------DetailPayStatistics----------------------------------------
	SELECT PayCurrency.Name AS CurrencyName, exType.Name AS exTypeName, DATEADD(D, 0, DATEDIFF(D, 0, ex.Date )) AS Date ,Count(exDetail.Amount) As PayCount, SUM(exDetail.Amount/exDetail.CurrencyVal) As TotalPay, SUM(exDetail.Amount) As EquivilantTotalPay, SUM(exDetail.Amount) / SUM(exDetail.Amount/exDetail.CurrencyVal) As AvgPayVal
	INTO #DetailPayStatistics
	FROM TrnExchange000 ex
	INNER JOIN TrnExchangeDetail000 exDetail ON ex.GUID = exDetail.ExchangeGUID AND exDetail.Type = 1
	INNER JOIN TrnExchangeTypes000 exType ON ex.TypeGUID = exType.GUID 
	INNER JOIN MY000 PayCurrency ON exDetail.CurrencyGUID = PayCurrency.GUID
	WHERE ex.bSimple = 0 AND (ex.Date BETWEEN @FromDate AND @ToDate )
	GROUP BY PayCurrency.Name, DATEADD(D, 0, DATEDIFF(D, 0, ex.Date )), exType.Name
	--------------------------------------------------------------------------------------
	-----------------------------PayStatistics-------------------------------------------
	--------------------------------------------------------------------------------------
	INSERT INTO #PayStatistics
	SELECT SimplePay.CurrencyName, SimplePay.exTypeName, SimplePay.Date ,SimplePay.PayCount + DetailPay.PayCount AS PayCount, SimplePay.TotalPay + DetailPay.TotalPay AS TotalPay, SimplePay.EquivilantTotalPay + DetailPay.EquivilantTotalPay AS EquivilantTotalPay, (SimplePay.EquivilantTotalPay + DetailPay.EquivilantTotalPay) / (SimplePay.TotalPay + DetailPay.TotalPay) AS AvgPayVal
	FROM #SimplePayStatistics SimplePay
	INNER JOIN #DetailPayStatistics DetailPay ON SimplePay.CurrencyName = DetailPay.CurrencyName AND SimplePay.exTypeName = DetailPay.exTypeName AND SimplePay.Date = DetailPay.Date
	
	UNION SELECT * FROM #SimplePayStatistics
	UNION SELECT * FROM #DetailPayStatistics
	
	----------------------Now Filtering #PayStatistics by deleting CalculatedPay_records-----------------------------------
	DECLARE CalculatedPay_records CURSOR FOR
	SELECT Simplepay.CurrencyName, Simplepay.exTypeName, Simplepay.Date, Simplepay.payCount + Detailpay.payCount
	FROM #SimplepayStatistics Simplepay
	INNER JOIN #DetailpayStatistics Detailpay ON Simplepay.CurrencyName = Detailpay.CurrencyName AND Simplepay.exTypeName = Detailpay.exTypeName AND Simplepay.Date = Detailpay.Date
	
	--Reset Variables
	SET @CurrencyName = ''
	SET @exTypeName = '' 
	SET @Date = '1-1-1900'
	SET @Count = 0
	
	OPEN CalculatedPay_records
	FETCH NEXT FROM CalculatedPay_records INTO
	@CurrencyName,
	@exTypeName, 
	@Date,
	@Count
	WHILE @@FETCH_STATUS = 0 
	BEGIN
		DELETE FROM #payStatistics
		WHERE CurrencyName = @CurrencyName AND exTypeName = @exTypeName AND Date = @Date AND payCount <> @Count
		FETCH NEXT FROM CalculatedPay_records INTO
		@CurrencyName,
		@exTypeName, 
		@Date,
		@Count
	END
	CLOSE CalculatedPay_records
	DEALLOCATE CalculatedPay_records


	-----------------------------------------------------------------------------------------------------------------
	
	-------------------------------------------------------------------------------------------------------------------
	-------------------------------P A R T 3 : E X C H A N G E   S T A T I S T I C S-----------------------------------
	-------------------------------------------------------------------------------------------------------------------
	INSERT INTO #ExchangeStatistics
	SELECT Cash.*, ISNULL(Pay.PayCount, 0), ISNULL(Pay.TotalPay, 0), ISNULL(Pay.EquivilantTotalPay, 0), ISNULL(Pay.AvgPayVal, 0)
	FROM #CashStatistics Cash
	LEFT JOIN #payStatistics Pay ON Cash.CurrencyName = Pay.CurrencyName AND Cash.exTypeName = Pay.exTypeName AND Cash.Date = Pay.Date
	
	UNION
	
	SELECT Pay.CurrencyName, Pay.exTypeName, Pay.Date, 0, 0, 0, 0, Pay.PayCount, Pay.TotalPay, Pay.EquivilantTotalPay, Pay.AvgPayVal
	FROM #payStatistics Pay
	
	----------------------Now Filtering #ExhangeStatistics by deleting Calculated_records-----------------------------------
	DECLARE Calculated_records CURSOR FOR
	SELECT Cash.CurrencyName, Cash.exTypeName, Cash.Date
	FROM #CashStatistics Cash
	INNER JOIN #payStatistics Pay ON Cash.CurrencyName = Pay.CurrencyName AND Cash.exTypeName = Pay.exTypeName AND Cash.Date = Pay.Date
	
	--Reset Variables
	SET @CurrencyName = ''
	SET @exTypeName = '' 
	SET @Date = '1-1-1900'
	
	OPEN Calculated_records
	FETCH NEXT FROM Calculated_records INTO
	@CurrencyName,
	@exTypeName, 
	@Date
	
	WHILE @@FETCH_STATUS = 0 
	BEGIN
		DELETE FROM #ExchangeStatistics
		WHERE CurrencyName = @CurrencyName AND exTypeName = @exTypeName AND Date = @Date AND TotalCash = 0
		FETCH NEXT FROM Calculated_records INTO
		@CurrencyName,
		@exTypeName, 
		@Date
	END
	CLOSE Calculated_records
	DEALLOCATE Calculated_records
	---------------------------------------------------------------------------------------------------------------------------
	
	-------------------------------------------------------------------------------------------------------------------
	-------------------------------P A R T 4 : A G G R E G A T I O N --------------------------------------------------
	-------------------------------------------------------------------------------------------------------------------
	IF (@AggregationType = 0)
	BEGIN
		INSERT INTO #Result
		SELECT *, 0 FROM #ExchangeStatistics ORDER BY CurrencyName, exTypeName,Date
	END
	
	ELSE IF (@AggregationType = 1/*by Day*/)
	BEGIN 
		--Aggregation records by DAy
		INSERT INTO #Result
		SELECT '-', '-', Date, SUM(CashCount), -1, SUM(EquivilantTotalCash), -1, SUM(PayCount), -1, SUM(EquivilantTotalPay), -1, 0
		FROM #ExchangeStatistics
		GROUP BY Date
		Order By Date
		
		--Details records
		INSERT INTO #Result SELECT *, 1 FROM #ExchangeStatistics Order By Date
	END
	
	ELSE IF (@AggregationType = 2/*by Day+Currency*/)
	BEGIN 
		--Aggregation records by day
		INSERT INTO #Result
		SELECT '-', '-', Date, SUM(CashCount), -1, SUM(EquivilantTotalCash), -1, SUM(PayCount), -1, SUM(EquivilantTotalPay), -1, 0
		FROM #ExchangeStatistics
		GROUP BY Date
		Order By Date
		
		--Aggregation records by Day+Currency
		INSERT INTO #Result
		SELECT CurrencyName, '-', Date, SUM(CashCount), SUM(TotalCash), SUM(EquivilantTotalCash), (CASE WHEN SUM(TotalCash) <> 0 THEN SUM(EquivilantTotalCash)/SUM(TotalCash) ELSE 0 END), SUM(PayCount), SUM(TotalPay), SUM(EquivilantTotalPay), (CASE WHEN SUM(TotalPay) <> 0 THEN SUM(EquivilantTotalPay)/SUM(TotalPay) ELSE 0 END), 1
		FROM #ExchangeStatistics
		GROUP BY CurrencyName, Date
		Order By CurrencyName, Date
		
		--Details records
		INSERT INTO #Result SELECT *, 2 FROM #ExchangeStatistics Order By CurrencyName, Date
	END
	
	ELSE IF (@AggregationType = 3/*by Currency+Day*/)
	BEGIN 
		--Aggregation records by Currency
		INSERT INTO #Result
		SELECT CurrencyName, '-', '1-1-1900', SUM(CashCount), SUM(TotalCash), SUM(EquivilantTotalCash), (CASE WHEN SUM(TotalCash) <> 0 THEN SUM(EquivilantTotalCash)/SUM(TotalCash) ELSE 0 END), SUM(PayCount), SUM(TotalPay), SUM(EquivilantTotalPay), (CASE WHEN SUM(TotalPay) <> 0 THEN SUM(EquivilantTotalPay)/SUM(TotalPay) ELSE 0 END), 0
		FROM #ExchangeStatistics
		GROUP BY CurrencyName
		Order By CurrencyName
		
		--Aggregation records by Currency+Day
		INSERT INTO #Result
		SELECT CurrencyName, '-', Date, SUM(CashCount), SUM(TotalCash), SUM(EquivilantTotalCash), (CASE WHEN SUM(TotalCash) <> 0 THEN SUM(EquivilantTotalCash)/SUM(TotalCash) ELSE 0 END), SUM(PayCount), SUM(TotalPay), SUM(EquivilantTotalPay), (CASE WHEN SUM(TotalPay) <> 0 THEN SUM(EquivilantTotalPay)/SUM(TotalPay) ELSE 0 END), 1
		FROM #ExchangeStatistics
		GROUP BY CurrencyName, Date
		Order By CurrencyName, Date
		
		--Details records
		INSERT INTO #Result SELECT *, 2 FROM #ExchangeStatistics Order By CurrencyName, Date
	END
	
	-------------------------------------------------------------------------------------------------------------
	----------------------------------------Final result---------------------------------------------------------
	-------------------------------------------------------------------------------------------------------------
	IF (@AggregationType = 3)--by Currency then Day
		SELECT * 
		FROM #Result 
		ORDER BY CurrencyName, Date, Level
	ELSE
		SELECT * 
		FROM #Result 
		ORDER BY Date, CurrencyName, Level
END
############################################
#END