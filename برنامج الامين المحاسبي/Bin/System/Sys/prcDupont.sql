##################################################################################
CREATE PROCEDURE prcDupont
(
	@DPYear			int = 2000,
	@DPQuarter		int = 0,
	@DPMonth		int = 0
)
AS
	   SET NOCOUNT ON
	   DECLARE @closePrevYear DATETIME = (SELECT DATEADD(day, -1, DATEFROMPARTS(@DPYear, 1, 1)))
	   ---------------------------------------------------------
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
              WHERE IncomeType IN (1, 2, 13, 14, 15, 16) AND YEAR(Date) = @DPYear
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
              WHERE FSType = 1 AND YEAR(Date) = @DPYear
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
              WHERE (FSType = 1 OR FSType = 2) AND YEAR(Date) = @DPYear
              GROUP BY Date
       ) T
	   ---------------------------------------------------
	   DELETE #result WHERE Classification > 4
	   ---------------------------------------------------
	   INSERT INTO #result (Classification, Date, Balance)
       values(5, DATEFROMPARTS(@DPYear, 1, 31), 0), (6, DATEFROMPARTS(@DPYear, 1, 31), 0), (7, DATEFROMPARTS(@DPYear, 1, 31), 0),
		 (8, DATEFROMPARTS(@DPYear, 1, 31), 0), (9, DATEFROMPARTS(@DPYear, 1, 31), 0),
		 (10, DATEFROMPARTS(@DPYear, 1, 31), 0), (11, DATEFROMPARTS(@DPYear, 1, 31), 0)
       ---------------------------------------------------
	   INSERT INTO #result (Classification, Date, Balance)
       SELECT * FROM
       (
              SELECT Classification Class, @closePrevYear Date, Balance Bal
              FROM #result
			  WHERE DATE = DATEFROMPARTS(@DPYear, 1, 1)
       ) T
	   ---------------------------------------------------
	   ---------------------------------------------------
	   ---Insert empty value to full all month

	   DECLARE @month DATETIME = DATEFROMPARTS(@DPYear, 1, 31)

	   WHILE @month < DATEFROMPARTS(@DPYear, 12, 31)
	   BEGIN
			INSERT INTO #zeroResult (Classification, Date, Balance)
			VALUES (0, @month, 0), (1, @month, 0), (2, @month, 0), (3, @month, 0), (4, @month, 0)
			
			SET @month = EOMONTH(DATEADD(MONTH, 1, @month))
	   END
	 
	   INSERT INTO #result
	   SELECT t.class, t.Date, 0 
	   FROM
			(SELECT zr.Classification class, zr.Date
			 FROM #zeroResult zr LEFT JOIN #result r ON zr.Classification = r.Classification AND zr.Date = r.Date 
			 WHERE r.Classification IS NULL OR r.Date IS NULL) T
	  -------------------------------------------
	  -------------------------------------------
	--  select * from #chartResult
		IF (@DPMonth > 0) -- Monthly
		BEGIN
			INSERT INTO #chartResult SELECT * FROM #result
		END
	--  select * from #chartResult
		IF(@DPQuarter > 0) -- Quarterly
		BEGIN
			INSERT INTO #chartResult
			SELECT * FROM 
				(SELECT Classification class, EOMONTH(DATEFROMPARTS(DATEPART(YEAR, date), DATEPART(QUARTER, date) * 3, 1)) date, SUM(balance) bal 
				FROM #result
				WHERE DAY(Date) <> 1
				GROUP BY Classification, EOMONTH(DATEFROMPARTS(DATEPART(YEAR, date), DATEPART(QUARTER, date) * 3, 1))) T
		END
	--select * from #chartResult
		IF(@DPQuarter < 1 AND @DPMonth < 1) -- Yearly
		BEGIN
			INSERT INTO #chartResult
			SELECT * FROM 
				(SELECT Classification class, EOMONTH(DATEFROMPARTS(DATEPART(YEAR, date),12, 1)) date, SUM(balance) bal 
				FROM #result
				WHERE DAY(Date) <> 1
				GROUP BY Classification, EOMONTH(DATEFROMPARTS(DATEPART(YEAR, date),12, 1))) T
		END
	--	select * from #chartResult
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
		SELECT Classification, Date, accbalance
		FROM #accresult 
		WHERE Classification IN (3, 4)

		INSERT INTO #avgresult 
		SELECT Classification + 2, Date,
		AVG(accbalance) OVER (PARTITION BY Classification ORDER BY Date ROWS BETWEEN 1 PRECEDING AND CURRENT ROW) avg
		FROM #accresult ORDER BY Classification, date
	   ------------------------------------------------------------------
	   
	--  select * from #avgresult

       CREATE TABLE #dupont
       (
			  Date DATETIME,
              Profit FLOAT,
			  Sales FLOAT,
			  Assets FLOAT,
			  OwnersEquity FLOAT,
			  ProfitMargin FLOAT,
			  ROA FLOAT,
			  ROE FLOAT,
			  AssetsTurnover FLOAT,
			  EquityMultiplier FLOAT
       )

	    INSERT INTO #dupont
		SELECT DATE ChartDate,
			ISNULL([0], 0) Profit, 
			ISNULL([1], 0) SalesRevenues,
			ISNULL([3], 0) AssetsAverage,
			ISNULL([4], 0) OwnersEquityAverage,
			CASE (ISNULL([1], 0) - ISNULL([2], 0)) WHEN 0 THEN 0 ELSE ISNULL([0], 0) / (ISNULL([1], 0) - ISNULL([2], 0)) END ProfitMargin,
			CASE ISNULL([5], 0) WHEN 0 THEN 0 ELSE ISNULL([0], 0) / ISNULL([5], 1) END ROA,
			CASE ISNULL([6], 0) WHEN 0 THEN 0 ELSE ISNULL([0], 0) / ISNULL([6], 1) END ROE,
			CASE ISNULL([5], 0) WHEN 0 THEN 0 ELSE (ISNULL([1], 0) - ISNULL([2], 0)) / ISNULL([5], 0) END AssetsTurnover,
			CASE ISNULL([6], 0) WHEN 0 THEN 0 ELSE ISNULL([5], 0) / ISNULL([6], 1) END EquityMultiplier
		FROM
		(
              SELECT Classification, DATE, avg
              FROM #avgresult
			  WHERE YEAR(Date) = @DPYear
				AND (@DPQuarter < 1 OR DATEPART(QUARTER, Date) = @DPQuarter)
				AND (@DPMonth < 1 OR DATEPART(MONTH, Date) = @DPMonth)) AS SourceTable
              PIVOT
              (
              SUM(avg)
              FOR classification IN ([0], [1], [2], [3], [4], [5], [6])
		) AS PivotTable
		ORDER BY DATE

	--	select * from #dupont
		SELECT 
			CASE Classification 
				WHEN 'Profit' THEN 6
				WHEN 'Sales' THEN 7
				WHEN 'Assets' THEN 8
				WHEN 'OwnersEquity' THEN 9
				WHEN 'ProfitMargin' THEN 4
				WHEN 'ROA' THEN 2
				WHEN 'ROE' THEN 1
				WHEN 'AssetsTurnover' THEN 5
				WHEN 'EquityMultiplier' THEN 3 END KeyField 
			, [Value]
FROM 
   (SELECT * FROM #dupont) p
UNPIVOT
   (Value FOR Classification IN 
      (
              Profit ,
			  Sales ,
			  Assets ,
			  OwnersEquity ,
			  ProfitMargin ,
			  ROA ,
			  ROE ,
			  AssetsTurnover ,
			  EquityMultiplier )
)AS unpvt;
---------------------------------------------
CREATE TABLE #relation
(
	[from] INT,
	[to] INT
)

INSERT INTO #relation VALUES
(1, 2), (1, 3),
(2, 4), (2, 5), (3, 8), (3, 9),
(4, 6), (4, 7), (5, 7), (5, 8)

SELECT * FROM #relation

##################################################################################
#END