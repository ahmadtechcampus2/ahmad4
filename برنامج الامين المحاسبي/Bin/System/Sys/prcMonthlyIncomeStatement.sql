##################################################################################
CREATE PROCEDURE MonthlyIncomeStatement
(
	@FromYear		DATETIME = '1-1-2005',
	@ToYear			DATETIME = '1-1-2018'
)
AS
	   DECLARE @lastDate DATETIME = (SELECT MAX(Date) FROM FABalanceSheetAccountBalance000)
	   
	   IF @ToYear > @lastDate
	   		SET @ToYear = @lastDate
	   
	   IF DATEDIFF(YEAR, @FromYear, @ToYear) > 8
			SET @FromYear = DATEADD(YEAR, -8, DATEFROMPARTS(YEAR(@TOYEAR), 1, 1))

       CREATE TABLE #result
       (
              Classification INT,
              ClassificationDetails NVARCHAR(256),
              [Date] DATETIME,
              Balance       FLOAT,
              Note NVARCHAR(256),
       )

       INSERT INTO #result (Classification, Date, Balance)
       SELECT * FROM
       (
              SELECT IncomeType Classification, [Date], SUM(CASE WHEN IncomeType IN(1, 7) THEN -1 * Balance ELSE Balance END) Balance
              FROM FABalanceSheetAccount000 AC
              INNER JOIN FABalanceSheetAccountBalance000 BAL ON BAL.AccountGuid = AC.AccountGUID
              AND AC.CycleGuid = BAL.CycleGuid
              WHERE FSType = 1 AND DATE BETWEEN @FromYear AND @ToYear
              GROUP BY IncomeType, Date
       ) T
       --------------------------------------
       INSERT INTO #result (Classification, ClassificationDetails, Date, Balance)
       SELECT * FROM
       (
              SELECT IncomeType Classification, CD.Name ClassificationDetails, [Date], SUM(CASE WHEN IncomeType IN(1, 7) THEN -1 * Balance ELSE Balance END) Balance
              FROM FABalanceSheetAccount000 AC
              INNER JOIN FABalanceSheetAccountBalance000 BAL ON BAL.AccountGuid = AC.AccountGUID
              AND AC.CycleGuid = BAL.CycleGuid
              Inner JOIN BalSheet000 CD ON CD.[GUID] = AC.ClassificationGuid
              WHERE FSType = 1 AND DATE BETWEEN @FromYear AND @ToYear
              GROUP BY IncomeType, CD.Name, Date
       ) T
       --------------------------------------
       UPDATE #result SET Classification = 
              CASE WHEN Classification = 4 THEN 5
                     WHEN Classification = 5 THEN 7
                     WHEN Classification = 6 THEN 8
                     WHEN Classification = 7 THEN 11
                     else Classification
              END
       -----------------------------------------
       INSERT INTO #result (Classification, Date, Balance)
       SELECT * FROM
       (
              SELECT 4 Class, [Date], SUM(CASE Classification WHEN 1 THEN Balance ELSE -1 * Balance END) Bal
              FROM #result
              WHERE Classification BETWEEN 1 AND 3 AND ClassificationDetails IS NULL
              GROUP BY Date
       ) T
       ---------------------------------------------------
       INSERT INTO #result (Classification, Date, Balance)
       SELECT * FROM
       (
              SELECT 6 Class, [Date], SUM(CASE Classification WHEN 4 THEN Balance ELSE -1 * Balance END) Bal
              FROM #result
              WHERE Classification BETWEEN 4 AND 5 AND ClassificationDetails IS NULL
              GROUP BY Date
       ) T
       ---------------------------------------------------
       INSERT INTO #result (Classification, Date, Balance)
       SELECT * FROM
       (
              SELECT 9 Class, [Date], SUM(Balance) Bal
              FROM #result
              WHERE Classification BETWEEN 7 AND 8 AND ClassificationDetails IS NULL
              GROUP BY Date
       ) T
       ---------------------------------------------------
       INSERT INTO #result (Classification, Date, Balance)
       SELECT * FROM
       (
              SELECT 10 Class, [Date],  SUM(CASE Classification WHEN 6 THEN Balance ELSE -1 * Balance END) Bal
              FROM #result
              WHERE Classification = 6 OR Classification = 9 AND ClassificationDetails IS NULL
              GROUP BY Date
       ) T
       ---------------------------------------------------
       INSERT INTO #result (Classification, Date, Balance)
       SELECT * FROM
       (
              SELECT 12 Class, [Date],  SUM(Balance) Bal
              FROM #result
              WHERE Classification BETWEEN 10 AND 11 AND ClassificationDetails IS NULL
              GROUP BY Date
       ) T
	   ---------------------------------------------------
	   INSERT INTO #result (Classification, Date, Balance)
       values(1, @ToYear, 0), (2, @ToYear, 0), (3, @ToYear, 0), (4, @ToYear, 0),
		 (5, @ToYear, 0), (6, @ToYear, 0), (7, @ToYear, 0), (8, @ToYear, 0), 
		 (9, @ToYear, 0), (10, @ToYear, 0), (11, @ToYear, 0), (12, @ToYear, 0);
	   ---------------------------------------------------
	   ---Insert empty value to full all monthes

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
       ---------------------------------------------------
       SELECT Classification, Date, Balance FROM #result 
       WHERE ClassificationDetails IS NULL
       ORDER BY Classification, Date
	   -------------------------------
       SELECT Classification, ClassificationDetails, Date, Balance FROM #result 
       WHERE ClassificationDetails IS NOT NULL
       ORDER BY Classification, Date
	   -------------------------------
       SELECT DATE ChartDate, ISNULL([1], 0) Sales, ISNULL([12], 0) Profit,
			CASE ISNULL([1], 0) WHEN 0 THEN 0 ELSE ISNULL([12], 0) / [1] END Margin
       FROM
       (
              SELECT Classification, DATE, Balance
              FROM #result) AS SourceTable
              PIVOT
              (
              SUM(balance)
              FOR classification IN ([1], [12])
       ) AS PivotTable
       ORDER BY DATE;
	   -------------------------------
       SELECT Classification, Date ChartDate, Balance FROM #result 
       WHERE ClassificationDetails IS NULL AND Classification IN(2, 3, 5, 7, 8, 11)
       ORDER BY Classification, Date
##################################################################################
#END