##################################################################################
CREATE PROCEDURE prcProfitabilityMeasures
(
	@FromYear		DATETIME = '1-1-1980',
	@ToYear			DATETIME = '1-1-9999',
	@ShowQuarterly	BIT = 0,
	@ShowMonthly    BIT = 0
)
AS
	   DECLARE @lastDate DATETIME = (SELECT MAX(Date) FROM FABalanceSheetAccountBalance000)
	   
	   IF @ToYear > @lastDate
	   		SET @ToYear = @lastDate
	   
	   IF DATEDIFF(YEAR, @FromYear, @ToYear) > 8
	   		SET @FromYear = DATEADD(YEAR, -8, DATEFROMPARTS(YEAR(@TOYEAR), 1, 1))

	   DECLARE @closePrevYear DATETIME = (SELECT DATEADD(day, -1, @FromYear))

       CREATE TABLE #result
       (
              Classification INT,
              [Date] DATETIME,
              Balance FLOAT
       )

	    CREATE TABLE #zeroResult
       (
              Classification INT,
              [Date] DATETIME,
              Balance FLOAT
       )

	   CREATE TABLE #chartResult
       (
              Classification INT,
              [Date] DATETIME,
              Balance FLOAT
       )

	   CREATE TABLE #accresult
       (
              Classification INT,
              [Date] DATETIME,
              Balance FLOAT,
			  accbalance float
       )

	    CREATE TABLE #avgresult
       (
              Classification INT,
              [Date] DATETIME,
              avg FLOAT
       )

       INSERT INTO #result (Classification, Date, Balance)
       SELECT * FROM
       (
			  SELECT IncomeType Classification, [Date], CASE IncomeType WHEN 1 THEN -1 * SUM(Balance) ELSE SUM(Balance) END Balance
              FROM FABalanceSheetAccount000 AC
              INNER JOIN FABalanceSheetAccountBalance000 BAL ON BAL.AccountGuid = AC.AccountGUID
              AND AC.CycleGuid = BAL.CycleGuid
              WHERE IncomeType IN (1, 2, 13, 14, 15, 16) AND DATE BETWEEN @FromYear AND @ToYear
              GROUP BY IncomeType, Date
       ) T
       --------------------------------------
       UPDATE #result SET Classification = 
               CASE WHEN Classification = 1 THEN 1
					WHEN Classification = 2 THEN 2
                    ELSE Classification
              END    
	   ---------------------------------------------------
	   INSERT INTO #result (Classification, Date, Balance)
       SELECT * FROM
       (
			  SELECT 0 class, [Date], -1 * SUM(Balance) Balance
              FROM FABalanceSheetAccount000 AC
              INNER JOIN FABalanceSheetAccountBalance000 BAL ON BAL.AccountGuid = AC.AccountGUID
              AND AC.CycleGuid = BAL.CycleGuid
              WHERE FSType = 1 AND DATE BETWEEN @FromYear AND @ToYear
              GROUP BY Date
       ) T
	   ---------------------------------------------------
	    ---------------------------------------------------
	   INSERT INTO #result (Classification, Date, Balance)
       SELECT * FROM
       (
              SELECT 3 Class, [Date], SUM(balance) Bal
              FROM #result
              WHERE Classification BETWEEN 13 AND 16
              GROUP BY Date
       ) T
	    ---------------------------------------------------
	   INSERT INTO #result (Classification, Date, Balance)
       SELECT * FROM
       (
			  SELECT 4 class, [Date], -1 * SUM(Balance) Balance
              FROM FABalanceSheetAccount000 AC
              INNER JOIN FABalanceSheetAccountBalance000 BAL ON BAL.AccountGuid = AC.AccountGUID
              AND AC.CycleGuid = BAL.CycleGuid
              WHERE (FSType = 1 OR FSType = 2) AND DATE BETWEEN @FromYear AND @ToYear
              GROUP BY Date
       ) T
	   ---------------------------------------------------
	   DELETE #result WHERE Classification > 4
	    ---------------------------------------------------
	   INSERT INTO #result (Classification, Date, Balance)
       values(0, @ToYear, 0), (1, @ToYear, 0), (2, @ToYear, 0), (3, @ToYear, 0), 
			(4, @ToYear, 0), (5, @ToYear, 0), (6, @ToYear, 0), (7, @ToYear, 0), 
			(8, @ToYear, 0), (9, @ToYear, 0), (10, @ToYear, 0), (11, @ToYear, 0)
       ---------------------------------------------------
	   ---------------------------------------------------
	   ---Insert empty value to full all month

	    CREATE TABLE #classifications(Classification INT)
	    INSERT INTO #classifications
	    SELECT DISTINCT Classification FROM #result;

	    With CTE AS
		(
			SELECT EOMONTH(@FromYear) [DATE]
			UNION ALL
			SELECT EOMONTH(DATEADD(Month, 1, [DATE])) FROM CTE
			WHERE [DATE] < @ToYear
		)
		INSERT INTO #RESULT (Classification, Date, Balance)
		SELECT DISTINCT C.Classification, cte.date, 0
		FROM 
			CTE cte CROSS JOIN #classifications C 
			LEFT JOIN #result R ON R.Date = cte.DATE AND R.Classification = C.Classification
		WHERE R.Date IS NULL AND cte.[DATE] < @ToYear
	  -------------------------------------------
	  INSERT INTO #result (Classification, Date, Balance)
       SELECT * FROM
       (
              SELECT Classification Class, @closePrevYear Date, Balance Bal
              FROM #result
              WHERE Date = @FromYear
       ) T
	   ---------------------------------------------------
       SELECT Classification, Date, Balance FROM #result 
       WHERE DAY(Date) <> 1
       ORDER BY Classification, Date
	  ----------------------------------------------------
	  ----------------------------------------------------

		IF (@ShowMonthly = 1)
		BEGIN
			INSERT INTO #chartResult SELECT * FROM #result
		END
		ELSE IF(@ShowQuarterly = 1)
		BEGIN
			INSERT INTO #chartResult
			SELECT * FROM 
				(SELECT Classification class, EOMONTH(DATEFROMPARTS(DATEPART(YEAR, date), DATEPART(QUARTER, date) * 3, 1)) date, SUM(balance) bal 
				FROM #result
				WHERE DAY(Date) <> 1
				GROUP BY Classification, EOMONTH(DATEFROMPARTS(DATEPART(YEAR, date), DATEPART(QUARTER, date) * 3, 1))) T
		END
		ELSE
		BEGIN
			INSERT INTO #chartResult
			SELECT * FROM 
				(SELECT Classification class, EOMONTH(DATEFROMPARTS(DATEPART(YEAR, date),12, 1)) date, SUM(balance) bal 
				FROM #result
				WHERE DAY(Date) <> 1
				GROUP BY Classification, EOMONTH(DATEFROMPARTS(DATEPART(YEAR, date),12, 1))) T
		END
		---------------------------------------------------
		INSERT INTO #accresult
		SELECT Classification, Date, Balance, SUM(Balance) OVER (PARTITION BY Classification ORDER BY Date) accbalance	
		FROM #chartResult 
		WHERE Classification IN (3, 4) AND DAY(Date) <> 1
	    ----------------------------------------------------
		INSERT INTO #avgresult
		SELECT Classification, Date, Balance
		FROM #chartResult 
		WHERE Classification IN (0, 1, 2) AND DAY(Date) <> 1

		INSERT INTO #avgresult
		SELECT Classification, Date,
		AVG(accbalance) OVER (PARTITION BY Classification ORDER BY Date ROWS BETWEEN 1 PRECEDING AND CURRENT ROW) avg
		FROM #accresult ORDER BY Classification, date
	   ------------------------------------------------------------------
		SELECT DATE ChartDate, 
			ISNULL([1], 0) SalesRevenues,
			ISNULL([3], 0) AssetsAverage,
			ISNULL([4], 0) OwnersEquityAverage,
			CASE (ISNULL([1], 0) - ISNULL([2], 0)) WHEN 0 THEN 0 ELSE ISNULL([0], 0) / (ISNULL([1], 0) - ISNULL([2], 0)) END ProfitMargin,
			CASE ISNULL([3], 0) WHEN 0 THEN 0 ELSE ISNULL([0], 0) / ISNULL([3], 1) END ROA,
			CASE ISNULL([4], 0) WHEN 0 THEN 0 ELSE ISNULL([0], 0) / ISNULL([4], 1) END ROE
		FROM
		(
              SELECT Classification, DATE, avg
              FROM #avgresult
			  WHERE YEAR(DATE) BETWEEN YEAR(@FromYear) AND YEAR(@ToYear) ) AS SourceTable
              PIVOT
              (
              SUM(avg)
              FOR classification IN ([0], [1], [2], [3], [4])
		) AS PivotTable
		ORDER BY DATE
##################################################################################
#END