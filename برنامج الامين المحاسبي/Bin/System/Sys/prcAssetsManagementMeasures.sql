##################################################################################
CREATE PROCEDURE prcAssetsManagementMeasures
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
	   DECLARE @inventoryClassificationDetails UNIQUEIDENTIFIER = 
			(SELECT [Value] FROM op000 WHERE [Name] ='FACfg_InventoryClassificationDetails') 
	   DECLARE @supplierClassificationDetails UNIQUEIDENTIFIER = 
			(SELECT [Value] FROM op000 WHERE [Name] ='FACfg_SupplierClassificationDetails') 
	   DECLARE @customerClassificationDetails UNIQUEIDENTIFIER = 
			(SELECT [Value] FROM op000 WHERE [Name] ='FACfg_CustomerClassificationDetails') 

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
			  SELECT IncomeType Classification, [Date], CASE WHEN IncomeType IN (1) THEN -1 * SUM(Balance) ELSE SUM(Balance) END Balance
              FROM FABalanceSheetAccount000 AC
              INNER JOIN FABalanceSheetAccountBalance000 BAL ON BAL.AccountGuid = AC.AccountGUID
              AND AC.CycleGuid = BAL.CycleGuid
              WHERE IncomeType IN (1, 2, 4, 13, 14, 15, 16) AND DATE BETWEEN @FromYear AND @ToYear
              GROUP BY IncomeType, Date
       ) T
       --------------------------------------
       UPDATE #result SET Classification = 
               CASE WHEN Classification = 4 THEN 3
                    ELSE Classification
              END    
		---------------------------------------------------
	   INSERT INTO #result (Classification, Date, Balance)
       SELECT * FROM
       (
              SELECT 0 Class, [Date], SUM(Balance) Balance
              FROM FABalanceSheetAccount000 AC
              INNER JOIN FABalanceSheetAccountBalance000 BAL ON BAL.AccountGuid = AC.AccountGUID
              AND AC.CycleGuid = BAL.CycleGuid AND AC.ClassificationGuid = @inventoryClassificationDetails
			  WHERE DATE BETWEEN @FromYear AND @ToYear
              GROUP BY Date
       ) T
	   ---------------------------------------------------
	   INSERT INTO #result (Classification, Date, Balance)
       SELECT * FROM
       (
              SELECT 4 Class, [Date], SUM(Balance) Balance
              FROM FABalanceSheetAccount000 AC
              INNER JOIN FABalanceSheetAccountBalance000 BAL ON BAL.AccountGuid = AC.AccountGUID
              AND AC.CycleGuid = BAL.CycleGuid AND AC.ClassificationGuid = @customerClassificationDetails
			  WHERE DATE BETWEEN @FromYear AND @ToYear
              GROUP BY Date
       ) T
	    ---------------------------------------------------
	   INSERT INTO #result (Classification, Date, Balance)
       SELECT * FROM
       (
              SELECT 5 Class, [Date], -1 * SUM(Balance) Balance
              FROM FABalanceSheetAccount000 AC
              INNER JOIN FABalanceSheetAccountBalance000 BAL ON BAL.AccountGuid = AC.AccountGUID
              AND AC.CycleGuid = BAL.CycleGuid AND AC.ClassificationGuid = @supplierClassificationDetails
			  WHERE DATE BETWEEN @FromYear AND @ToYear
              GROUP BY Date
       ) T
	   ---------------------------------------------------
	   INSERT INTO #result (Classification, Date, Balance)
       SELECT * FROM
       (
              SELECT 6 Class, [Date], SUM(balance) Bal
              FROM #result
              WHERE Classification BETWEEN 13 AND 16
              GROUP BY Date
       ) T
	   ------------------------------------------------------
	   INSERT INTO #result (Classification, Date, Balance)
       SELECT * FROM
       (
              SELECT 7 Class, [Date], DATEDIFF(DAY, DATEFROMPARTS(year(date), month(date), 1), date) + 1 bal
              FROM #result
			  WHERE Date <> @FromYear
			  GROUP BY Date
       ) T
	    ---------------------------------------------------
	   INSERT INTO #result (Classification, Date, Balance)
       SELECT * FROM
       (
              SELECT Classification Class, @closePrevYear Date, Balance Bal
              FROM #result
              WHERE Date = @FromYear
       ) T
	   ---------------------------------------------------
	   DELETE #result WHERE Classification > 7
	   ---------------------------------------------------
	   INSERT INTO #result (Classification, Date, Balance)
       values(0, @ToYear, 0), (1, @ToYear, 0), (2, @ToYear, 0), (3, @ToYear, 0), 
			(4, @ToYear, 0), (5, @ToYear, 0), (6, @ToYear, 0), (7, @ToYear, 0), 
			(8, @ToYear, 0), (9, @ToYear, 0), (10, @ToYear, 0), (11, @ToYear, 0), 
			(12, @ToYear, 0), (13, @ToYear, 0), (14, @ToYear, 0), (15, @ToYear, 0),
			(16, @ToYear, 0), (17, @ToYear, 0), (18, @ToYear, 0), (19, @ToYear, 0),
			(20, @ToYear, 0), (21, @ToYear, 0), (22, @ToYear, 0), (23, @ToYear, 0)
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
	  ---------------------------------------------------
	  ---------------------------------------------------
       SELECT Classification, Date, Balance FROM #result 
       WHERE DAY(Date) <> 1
       ORDER BY Classification, Date
	  ---------------------------------------------------
	  ---------------------------------------------------

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
		WHERE Classification IN (0, 4, 5, 6) AND DAY(Date) <> 1
	    ----------------------------------------------------
		INSERT INTO #avgresult
		SELECT Classification, Date, Balance
		FROM #chartResult 
		WHERE Classification IN (1, 2, 3, 7) AND DAY(Date) <> 1

		INSERT INTO #avgresult
		SELECT Classification, Date,
		AVG(accbalance) OVER (PARTITION BY Classification ORDER BY Date ROWS BETWEEN 1 PRECEDING AND CURRENT ROW) avg
		FROM #accresult ORDER BY Classification, date
	   ------------------------------------------------------------------
	    CREATE TABLE #turnover
	    (
			ChartDate DATETIME,
			InventoryTurnover FLOAT,
			ARTurnover FLOAT,
			APTurnover FLOAT,
			AssetsTurnover FLOAT,
			Days INT
	    )

	    INSERT INTO #turnover
		SELECT DATE ChartDate, CASE ISNULL([0], 0) WHEN 0 THEN 0 ELSE ISNULL([3], 0) / ISNULL([0], 1) END InventoryTurnover,
			CASE ISNULL([4], 0) WHEN 0 THEN 0 ELSE (ISNULL([1], 0) - ISNULL([2], 0)) / ISNULL([4], 1) END ARTurnover,
			CASE ISNULL([5], 0) WHEN 0 THEN 0 ELSE ISNULL([3], 0) / ISNULL([5], 1) END APTurnover,
			CASE ISNULL([6], 0) WHEN 0 THEN 0 ELSE (ISNULL([1], 0) - ISNULL([2], 0)) / ISNULL([6], 1) END AssetsTurnover,
			ISNULL([7], 0) Days
		FROM
		(
              SELECT Classification, DATE, avg
              FROM #avgresult
			  WHERE YEAR(DATE) BETWEEN YEAR(@FromYear) AND YEAR(@ToYear) ) AS SourceTable
              PIVOT
              (
              SUM(avg)
              FOR classification IN ([0], [1], [2], [3], [4], [5], [6], [7])
		) AS PivotTable
		ORDER BY DATE

		SELECT * FROM #turnover
		----------------------------------------------------------
		SELECT ChartDate, 
			CASE InventoryTurnover WHEN 0 THEN 0 ELSE Days / InventoryTurnover END +
				CASE ARTurnover WHEN 0 THEN 0 ELSE Days / ARTurnover END OperatingCycle,
			CASE InventoryTurnover WHEN 0 THEN 0 ELSE Days / InventoryTurnover END +
				CASE ARTurnover WHEN 0 THEN 0 ELSE Days / ARTurnover END -
				CASE APTurnover WHEN 0 THEN 0 ELSE Days / APTurnover END CashCycle 
		FROM #turnover
##################################################################################
#END