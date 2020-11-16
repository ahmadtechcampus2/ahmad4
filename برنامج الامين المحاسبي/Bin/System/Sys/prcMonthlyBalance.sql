##################################################################################
CREATE PROCEDURE MonthlyBalance
(
	@FromYear		DATETIME = '1-1-2013',
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
              SELECT IncomeType Classification, [Date], SUM(Balance) Balance
              FROM FABalanceSheetAccount000 AC
              INNER JOIN FABalanceSheetAccountBalance000 BAL ON BAL.AccountGuid = AC.AccountGUID
              AND AC.CycleGuid = BAL.CycleGuid
              WHERE FSType = 3 AND DATE BETWEEN @FromYear AND @ToYear AND (DAY(Date) <> 1 or YEAR(date) = YEAR(@FromYear))
              GROUP BY IncomeType, Date
       ) T
       --------------------------------------
       INSERT INTO #result (Classification, ClassificationDetails, Date, Balance)
       SELECT * FROM
       (
              SELECT IncomeType Classification, CD.Name ClassificationDetails, [Date], SUM(Balance) Balance
              FROM FABalanceSheetAccount000 AC
              INNER JOIN FABalanceSheetAccountBalance000 BAL ON BAL.AccountGuid = AC.AccountGUID
              AND AC.CycleGuid = BAL.CycleGuid
              Inner JOIN BalSheet000 CD ON CD.[GUID] = AC.ClassificationGuid
              WHERE FSType = 3 AND DATE BETWEEN @FromYear AND @ToYear AND (DAY(Date) <> 1 or YEAR(date) = YEAR(@FromYear))
              GROUP BY IncomeType, CD.Name, Date
       ) T
       --------------------------------------
       UPDATE #result SET Classification = 
              CASE 
					WHEN Classification = 13 THEN 12
					WHEN Classification = 14 THEN 13
					WHEN Classification = 17 THEN 18
                    WHEN Classification = 18 THEN 19
                    ELSE Classification
              END

       INSERT INTO #result (Classification, Date, Balance)
       SELECT * FROM
       (
              SELECT 11 Class, [Date], SUM(balance) Bal
              FROM #result
              WHERE Classification BETWEEN 12 AND 13 AND ClassificationDetails IS NULL
              GROUP BY Date
       ) T
	   ----------------------------------------
       INSERT INTO #result (Classification, Date, Balance)
       SELECT * FROM
       (
              SELECT 14 Class, [Date],  SUM(Balance) Bal
              FROM #result
              WHERE Classification BETWEEN 15 AND 16 AND ClassificationDetails IS NULL
              GROUP BY Date
       ) T
	   ---------------------------------------------------
       INSERT INTO #result (Classification, Date, Balance)
       SELECT * FROM
       (
              SELECT 17 Class, [Date], SUM(Balance) Bal
              FROM #result
              WHERE (Classification  = 11 OR Classification = 14) AND ClassificationDetails IS NULL
              GROUP BY Date
       ) T
       ---------------------------------------------------
       INSERT INTO #result (Classification, Date, Balance)
       SELECT * FROM
       (
              SELECT 20 Class, [Date], SUM(Balance) Bal
              FROM #result
              WHERE Classification BETWEEN 18 AND 19 AND ClassificationDetails IS NULL
              GROUP BY Date
       ) T
       ---------------------------------------------------
       INSERT INTO #result (Classification, Date, Balance)
       SELECT * FROM
       (
			  SELECT 21 Class, [Date], SUM(Balance) Balance
              FROM FABalanceSheetAccount000 AC
              INNER JOIN FABalanceSheetAccountBalance000 BAL ON BAL.AccountGuid = AC.AccountGUID
              AND AC.CycleGuid = BAL.CycleGuid
              WHERE (FSType = 1 OR FSType = 2) AND DATE BETWEEN @FromYear AND @ToYear AND (DAY(Date) <> 1 or YEAR(date) = YEAR(@FromYear))
              GROUP BY Date
       ) T
       ---------------------------------------------------
       INSERT INTO #result (Classification, Date, Balance)
       SELECT * FROM
       (
              SELECT 22 Class, [Date],  SUM(Balance) Bal
              FROM #result
              WHERE Classification BETWEEN 20 AND 21 AND ClassificationDetails IS NULL
              GROUP BY Date
       ) T;
	   ---------------------------------------------------
	   INSERT INTO #result (Classification, Date, Balance)
       values (11, @ToYear, 0), (12, @ToYear, 0), (13, @ToYear, 0), (14, @ToYear, 0), 
			(15, @ToYear, 0), (16, @ToYear, 0), (17, @ToYear, 0), (18, @ToYear, 0), 
			(19, @ToYear, 0), (20, @ToYear, 0), (21, @ToYear, 0), (22, @ToYear, 0);
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
       SELECT Classification, Date, CASE WHEN Classification IN(11, 12, 14, 15, 16, 17) THEN Balance ELSE -1 * Balance END Balance FROM #result 
       WHERE ClassificationDetails IS NULL
       ORDER BY Classification, Date
	   -------------------------------
       SELECT Classification, ClassificationDetails, Date, CASE WHEN Classification IN(11, 12, 14, 15, 16, 17) THEN Balance ELSE -1 * Balance END Balance FROM #result 
       WHERE ClassificationDetails IS NOT NULL
       ORDER BY Classification, Date
	   -------------------------------
	   SELECT DATE ChartDate, ISNULL([11], 0) Assets, ISNULL([14], 0) CurrrentAssets, ISNULL([20], 0) Liabilities, ISNULL([21], 0) OwnerEquty
       FROM
       (
              SELECT Classification, DATE, Balance
              FROM #result
			  WHERE ClassificationDetails IS NULL) AS SourceTable
              PIVOT
              (
              SUM(balance)
              FOR classification IN ([11], [14], [20], [21])
       ) AS PivotTable
       ORDER BY DATE;
	   -------------------------------
       SELECT DATE ChartDate, ISNULL([14], 0) CurrrentAssetes, -1 * ISNULL([19], 0) CurrrentLiabilities, ISNULL([20], 0) Liabilities, ISNULL([14], 0) + ISNULL([20], 0) Capital
       FROM
       (
              SELECT Classification, DATE, Balance
              FROM #result
			  WHERE ClassificationDetails IS NULL) AS SourceTable
              PIVOT
              (
              SUM(balance)
              FOR classification IN ([14], [19], [20])
       ) AS PivotTable
       ORDER BY DATE;
##################################################################################
#END