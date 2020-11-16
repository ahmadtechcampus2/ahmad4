##################################################################################
CREATE PROCEDURE MonthlyOwnersEquity
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
       );
	----------------------------------------
       INSERT INTO #result (Classification, Date, Balance)
       SELECT * FROM
       (
              SELECT IncomeType Classification, [Date], SUM(Balance) Balance
              FROM FABalanceSheetAccount000 AC
              INNER JOIN FABalanceSheetAccountBalance000 BAL ON BAL.AccountGuid = AC.AccountGUID
              AND AC.CycleGuid = BAL.CycleGuid
              WHERE FSType = 2
			  AND (DAY(Date) <> 1 OR YEAR(date) = YEAR(@FromYear) or IncomeType in (9))
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
              WHERE FSType = 2
			  AND (DAY(Date) <> 1 OR YEAR(date) = YEAR(@FromYear) OR IncomeType in (9))
              GROUP BY IncomeType, CD.Name, Date
       ) T
       --------------------------------------
       UPDATE #result SET Classification = 
              CASE WHEN Classification = 11 THEN 13
				   WHEN Classification = 12 THEN 14
                   ELSE Classification
              END
       -----------------------------------------
       INSERT INTO #result (Classification, Date, Balance)
       SELECT * FROM
       (
			  SELECT 11 Class, [Date], SUM(Balance) Balance
              FROM FABalanceSheetAccount000 AC
              INNER JOIN FABalanceSheetAccountBalance000 BAL ON BAL.AccountGuid = AC.AccountGUID
              AND AC.CycleGuid = BAL.CycleGuid
              WHERE FSType = 1
			  AND (DAY(Date) <> 1 OR YEAR(date) = YEAR(@FromYear))
              GROUP BY Date
       ) T
       ---------------------------------------------------
	   -- ⁄œÌ· ’«›Ì «·—»Õ Ê«·√—»«Õ Ê«·Œ”«∆— «·„œÊ—… Ê«· Ê“Ì⁄«  ·≈⁄ÿ«¡ ‰ «∆Ã  —«ﬂ„Ì… ’ÕÌÕ… ›Ì «· ﬁ—Ì—
	   
	   --  ⁄œÌ· «·√—»«Õ Ê«·Œ”«∆— «·„œÊ—…
	   UPDATE r SET r.Balance = r.Balance - prev.Balance
	   FROM #result r INNER JOIN #result prev ON r.date = DATEADD(year, +1, prev.Date)
	   AND r.Classification = prev.Classification
	   WHERE r.Classification = 9 AND r.Date <> @FromYear
	   
	    --  ⁄œÌ· «· Ê“Ì⁄« 
		----------------------------------
	   DECLARE @prevDividendsBalance TABLE
	   (
		 Date DATETIME,
		 Balance FLOAT
	   )
	   
	   INSERT INTO @prevDividendsBalance 
	   SELECT DATEFROMPARTS(YEAR(date), 1, 1) d, SUM(balance) 
	   FROM #result
	   WHERE Classification = 13
	   GROUP BY YEAR(date)

	   INSERT INTO #result (Classification, Date, Balance)
       SELECT * FROM
       (
             SELECT 13 Class, DATEADD(year, +1, Date) DATE, -1 * Balance Bal
             FROM @prevDividendsBalance
			 WHERE DATEADD(year, +1, Date) <> @FromYear
       ) T

	   --  ⁄œÌ· ’«›Ì «·—»Õ
	   ------------------------------
	   INSERT INTO #result (Classification, Date, Balance)
       SELECT * FROM
       (
              SELECT 11 Class, [Date], -1 * Balance Bal
              FROM #result
			  WHERE Classification = 9 AND DATE <> @FromYear
       ) T 

	   INSERT INTO #result (Classification, Date, Balance)
       SELECT * FROM
       (
             SELECT 11 Class, DATEADD(year, +1, Date) DATE, Balance Bal
             FROM @prevDividendsBalance
			 WHERE DATEADD(year, +1, Date) <> @FromYear
		) T
	   ---------------------------------------------------------------------
	   --- ≈Ã„«·Ì «” À„«—«  ÕﬁÊﬁ «·„·ﬂÌ…
	   INSERT INTO #result (Classification, Date, Balance)
       SELECT * FROM
       (
              SELECT 12 Class, [Date], SUM(Balance) Bal
              FROM #result
              WHERE Classification BETWEEN 8 AND 11 AND ClassificationDetails IS NULL
              GROUP BY Date
       ) T
       ---------------------------------------------------
	   --- ’«›Ì ÕﬁÊﬁ «·„·ﬂÌ…
       INSERT INTO #result (Classification, Date, Balance)
       SELECT * FROM
       (
              SELECT 15 Class, [Date], SUM(Balance) Bal
              FROM #result
              WHERE Classification BETWEEN 12 AND 14 AND ClassificationDetails IS NULL
              GROUP BY Date
       ) T
	   ---------------------------------------------------
	   INSERT INTO #result (Classification, Date, Balance)
       values(8, @ToYear, 0), (9, @ToYear, 0), (10, @ToYear, 0), (11, @ToYear, 0),
		 (12, @ToYear, 0), (13, @ToYear, 0), (14, @ToYear, 0), (15, @ToYear, 0);
	    ---------------------------------------------------
	   -- Insert empty value to full all monthes
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
       SELECT Classification, Date, CASE WHEN Classification IN(13, 14) THEN Balance ELSE -1 * Balance END Balance FROM #result 
       WHERE ClassificationDetails IS NULL AND DATE BETWEEN @FromYear AND @ToYear
       ORDER BY Classification, Date
	   -------------------------------
	    SELECT Classification, ClassificationDetails, Date, -1 * Balance Balance FROM #result 
       WHERE ClassificationDetails IS NOT NULL AND DATE BETWEEN @FromYear AND @ToYear
       ORDER BY Classification, Date
	   -------------------------------
       SELECT DATE ChartDate, ISNULL(-1 * [8], 0) Capital, ISNULL(-1 * [9], 0) PreviousYearsResults, ISNULL(-1 * [10], 0) AdditionsOnCapital, ISNULL(-1 * [11], 0) Oeprofitnet
       FROM
       (
              SELECT Classification, DATE, Balance
              FROM #result
			  WHERE ClassificationDetails IS NULL AND DATE BETWEEN @FromYear AND @ToYear) AS SourceTable
              PIVOT
              (
				SUM(balance)
				FOR classification IN ([8], [9], [10], [11])
       ) AS PivotTable
       ORDER BY DATE;
##################################################################################
#END