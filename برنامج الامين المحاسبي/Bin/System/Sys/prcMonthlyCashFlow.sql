##################################################################################
CREATE PROCEDURE MonthlyCashFlow
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
              Balance FLOAT
       )

	   CREATE TABLE #correctiveAccount
       (
              Classification INT,
              AccountName NVARCHAR(256),
              [Date] DATETIME,
              Balance FLOAT
       )
	   --------------------------------------
	   --------------------------------------
	   INSERT INTO #correctiveAccount (Classification, AccountName, Date, Balance)
       SELECT * FROM
       (
			SELECT 6 Class, AC.Name, [Date], SUM(CASE CAC.OperationalAffect WHEN 0 THEN Balance ELSE -1 * Balance END) Balance
            FROM 
				FACorrectiveAccount000 CAC INNER JOIN FABalanceSheetAccount000 AC ON CAC.AccountGuid = AC.AccountGUID
				AND CAC.CycleGuid = AC.CycleGuid
				INNER JOIN FABalanceSheetAccountBalance000 BAL ON BAL.AccountGuid = AC.AccountGUID
				AND CAC.CycleGuid = BAL.CycleGuid
			WHERE DATE BETWEEN @FromYear AND @ToYear
			GROUP BY AC.Name, DATE
       ) T
	   --------------------------------------
	   INSERT INTO #correctiveAccount (Classification, AccountName, Date, Balance)
       SELECT * FROM
       (
			SELECT 9 Class, AC.Name, [Date], SUM(CASE CAC.OperationalAffect WHEN 0 THEN -1 * Balance ELSE Balance END) Balance
            FROM 
				FACorrectiveAccount000 CAC INNER JOIN FABalanceSheetAccount000 AC ON CAC.AccountGuid = AC.AccountGUID
				AND CAC.CycleGuid = AC.CycleGuid
				INNER JOIN FABalanceSheetAccountBalance000 BAL ON BAL.AccountGuid = AC.AccountGUID
				AND CAC.CycleGuid = BAL.CycleGuid
			WHERE CAC.Destination = 0 AND DATE BETWEEN @FromYear AND @ToYear
			GROUP BY AC.Name, DATE
       ) T
	   --------------------------------------
	   INSERT INTO #correctiveAccount (Classification, AccountName, Date, Balance)
       SELECT * FROM
       (
			SELECT 15 Class, AC.Name, [Date], SUM(CASE CAC.OperationalAffect WHEN 0 THEN -1 * Balance ELSE Balance END) Balance
            FROM 
				FACorrectiveAccount000 CAC INNER JOIN FABalanceSheetAccount000 AC ON CAC.AccountGuid = AC.AccountGUID
				AND CAC.CycleGuid = AC.CycleGuid
				INNER JOIN FABalanceSheetAccountBalance000 BAL ON BAL.AccountGuid = AC.AccountGUID
				AND CAC.CycleGuid = BAL.CycleGuid
			WHERE CAC.Destination = 1 AND DATE BETWEEN @FromYear AND @ToYear
			GROUP BY AC.Name, DATE
       ) T
	   --------------------------------------
	   --------------------------------------
       INSERT INTO #result (Classification, Date, Balance)
       SELECT * FROM
       (
              SELECT IncomeType Classification, [Date], SUM(Balance) Balance
              FROM FABalanceSheetAccount000 AC
              INNER JOIN FABalanceSheetAccountBalance000 BAL ON BAL.AccountGuid = AC.AccountGUID
              AND AC.CycleGuid = BAL.CycleGuid
              WHERE IncomeType BETWEEN 10 AND 18 AND DATE BETWEEN @FromYear AND @ToYear
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
              WHERE IncomeType BETWEEN 10 AND 18 AND DATE BETWEEN @FromYear AND @ToYear
              GROUP BY IncomeType, CD.Name, Date
       ) T
       --------------------------------------
       UPDATE #result SET Classification = 
               CASE WHEN Classification = 14 THEN 3
					WHEN Classification = 15 THEN 4
					WHEN Classification = 18 THEN 5
                    WHEN Classification = 13 THEN 8
					WHEN Classification = 10 THEN 11
					WHEN Classification = 11 THEN 12
					WHEN Classification = 12 THEN 13
                    WHEN Classification = 17 THEN 14
					WHEN Classification = 16 THEN 17
                    ELSE Classification
              END    
       ---------------------------------------------------
	   ---- «·—»Õ
	   INSERT INTO #result (Classification, Date, Balance)
       SELECT * FROM
       (
			  SELECT 1 Class, [Date], SUM(Balance) Balance
              FROM FABalanceSheetAccount000 AC
              INNER JOIN FABalanceSheetAccountBalance000 BAL ON BAL.AccountGuid = AC.AccountGUID
              AND AC.CycleGuid = BAL.CycleGuid
              WHERE FSType = 1 AND DATE BETWEEN @FromYear AND @ToYear
              GROUP BY Date
       ) T
	   ---------------------------------------------------
	   ----  ”ÊÌ« 
	   INSERT INTO #result (Classification, Date, Balance)
       values(2, @ToYear, NULL)
	   ---------------------------------------------------
	   INSERT INTO #result (Classification, Date, Balance)
       SELECT * FROM
       (
			  SELECT Classification, Date, SUM(Balance) Balance FROM #correctiveAccount
              GROUP BY Classification, Date
       ) T
	   ---------------------------------------------------
	   INSERT INTO #result (Classification, ClassificationDetails, Date, Balance)
       SELECT * FROM
       (
			  SELECT Classification, AccountName, Date, Balance 
			  FROM #correctiveAccount
       ) T
	   ---------------------------------------------------
       INSERT INTO #result (Classification, Date, Balance)
       SELECT * FROM
       (
              SELECT 7 Class, [Date], SUM(Balance) Bal
              FROM #result
              WHERE Classification BETWEEN 1 AND 6 AND ClassificationDetails IS NULL
              GROUP BY Date
       ) T
	   ---------------------------------------------------
       INSERT INTO #result (Classification, Date, Balance)
       SELECT * FROM
       (
              SELECT 10 Class, [Date], SUM(Balance) Bal
              FROM #result
              WHERE Classification BETWEEN 8 AND 9 AND ClassificationDetails IS NULL
              GROUP BY Date
       ) T
	   ---------------------------------------------------
       INSERT INTO #result (Classification, Date, Balance)
       SELECT * FROM
       (
              SELECT 16 Class, [Date], SUM(Balance) Bal
              FROM #result
              WHERE Classification BETWEEN 11 AND 15 AND ClassificationDetails IS NULL
              GROUP BY Date
       ) T
	   ---------------------------------------------------
	   INSERT INTO #result (Classification, Date, Balance)
	   SELECT 19 Classification, Date, -1 * SUM(Balance) OVER (PARTITION BY Classification ORDER BY Date) accbalance	
	   FROM #result 
	   WHERE Classification = 17 AND ClassificationDetails IS NULL
	   ---------------------------------------------------
	   INSERT INTO #result (Classification, Date, Balance)
       SELECT * FROM
       (
              SELECT 18 Class, [Date], SUM(Balance) Bal
              FROM #result
              WHERE Classification IN(17, 19) AND ClassificationDetails IS NULL
              GROUP BY Date
       ) T
	   ---------------------------------------------------
	   INSERT INTO #result (Classification, Date, Balance)
       values(1, @ToYear, 0), (2, @ToYear, 0), (3, @ToYear, 0), (4, @ToYear, 0),
		 (5, @ToYear, 0), (6, @ToYear, 0), (7, @ToYear, 0), (8, @ToYear, 0), 
		 (9, @ToYear, 0), (10, @ToYear, 0), (11, @ToYear, 0), (12, @ToYear, 0),
		 (13, @ToYear, 0), (14, @ToYear, 0), (15, @ToYear, 0), (16, @ToYear, 0),
		 (17, @ToYear, 0), (18, @ToYear, 0), (19, @ToYear, 0);
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
       SELECT Classification, Date, CASE Classification WHEN 17 THEN 1 ELSE -1 END * Balance as Balance FROM #result 
       WHERE ClassificationDetails IS NULL AND DAY(Date) <> 1
       ORDER BY Classification, Date
	   -------------------------------
       SELECT Classification, ClassificationDetails, Date, CASE Classification WHEN 17 THEN 1 ELSE -1 END * Balance as Balance FROM #result 
       WHERE ClassificationDetails IS NOT NULL AND DAY(Date) <> 1
       ORDER BY Classification, Date     
	    -------------------------------
       SELECT DATE ChartDate, ISNULL(-1 * [7], 0) OPERATING, ISNULL(-1 * [10], 0) INVESTING, ISNULL(-1 * [16], 0) FINANCING, ISNULL([17], 0) CASHFLOW
       FROM
       (
              SELECT Classification, DATE, Balance
              FROM #result
			  WHERE ClassificationDetails IS NULL AND DAY(Date) <> 1
			  ) AS SourceTable
              PIVOT
              (
              SUM(balance)
              FOR classification IN ([7], [10], [16], [17])
       ) AS PivotTable
       ORDER BY DATE;
##################################################################################
#END