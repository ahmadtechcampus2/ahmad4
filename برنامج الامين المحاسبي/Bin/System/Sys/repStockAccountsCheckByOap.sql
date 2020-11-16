#################################################################
CREATE PROC repStockAccountsCheckByOap
	@EndDate		DATE,
	@IgnoredVarianceValue FLOAT
AS
	SET NOCOUNT ON;

	CREATE TABLE #Result
	(
		Date		DATE,
		MatGuid		UNIQUEIDENTIFIER,
		Qty			FLOAT DEFAULT(0),
		Cost		FLOAT DEFAULT(0),
		Value		FLOAT DEFAULT(0),
		MatSecurity	INT
	);

	DECLARE  
		@SOMonth		DATE,
		@EOMonth		DATE,
		@ProblemFound	BIT = 0; 
	SET @SOMonth = CAST(dbo.fnOption_Get('AmnCfg_FPDate', '') AS DATE);
	SET @EndDate = DATEADD(D, -1, DATEADD(M, DATEDIFF(M, 0, @EndDate) + 1, 0));
	SET @EOMonth = DATEADD(D, -1, DATEADD(M, DATEDIFF(M, 0, @SOMonth) + 1, 0));
	WHILE @EOMonth <= @EndDate
	BEGIN
		EXEC prcTakeStockByOap @SOMonth, @EOMonth;
		
		UPDATE A
		SET 
			Date = @EOMonth, 
			Value = ISNULL((SELECT SUM(Debit - Credit) FROM en000 WHERE AccountGUID = A.acGUID AND Date <= @EOMonth), 0)
		FROM #Accounts A;
		DECLARE @Invent FLOAT = (SELECT SUM(Value) FROM #Result)  
		DECLARE @AccBalance FLOAT = (SELECT SUM(Value) FROM #Accounts)
		INSERT INTO  #EndResult VALUES   (@EOMonth , @Invent , @AccBalance , ABS(@Invent - @AccBalance))
		IF  ABS( @Invent  - @AccBalance ) > @IgnoredVarianceValue  BREAK ;

		SET @SOMonth = DATEADD(M, 1, @SOMonth);
		SET @EOMonth = DATEADD(D, -1, DATEADD(M, DATEDIFF(M, 0, @SOMonth) + 1, 0));
	END
#################################################################
CREATE PROC prcTakeStockByOap
	@StartDate	DATE,
	@EndDate	DATE
AS
	SET NOCOUNT ON;
	
	DECLARE  
		@MatGuid		UNIQUEIDENTIFIER, 
		@PrevMatGuid	UNIQUEIDENTIFIER = 0x, 
		@Qty			FLOAT, 
		@AggQty			FLOAT = 0, 
		@Bonus			FLOAT, 
		@Direction		INT,
		@MatSecurity	INT; 

	DECLARE C CURSOR FAST_FORWARD FOR 
		SELECT 
			B.biMatPtr, B.biQty, B.biBonusQnt, B.btDirection, M.mtSecurity
		FROM 
			vwExtended_bi B JOIN #MatTbl M ON B.biMatPtr = M.MatGuid
		WHERE 
			B.buIsPosted > 0 AND B.buDate BETWEEN @StartDate AND @EndDate
		ORDER BY 
			B.buDate, B.btDirection DESC, B.biMatPtr; 

	OPEN C; 
	
	FETCH NEXT FROM C INTO @MatGuid, @Qty, @Bonus, @Direction, @MatSecurity; 

	WHILE @@FETCH_STATUS = 0 
	BEGIN
		IF @MatGuid <> @PrevMatGuid
		BEGIN
			IF EXISTS(SELECT 1 FROM #Result WHERE MatGuid = @MatGuid)
				SELECT @AggQty = Qty FROM #Result WHERE MatGuid = @MatGuid;
			ELSE
				SELECT @AggQty = 0;
		END

		SET @AggQty += @Direction * (@Qty + @Bonus);
		IF EXISTS(SELECT 1 FROM #Result WHERE MatGuid = @MatGuid)
			UPDATE #Result SET Qty = @AggQty WHERE MatGuid = @MatGuid;
		ELSE
			INSERT INTO #Result(MatGuid, Qty, MatSecurity) VALUES(@MatGuid, @AggQty, @MatSecurity);

		SET @PrevMatGuid = @MatGuid; 
		 
		FETCH NEXT FROM C INTO @MatGuid, @Qty, @Bonus, @Direction, @MatSecurity;
	END
	
	CLOSE C;
	DEALLOCATE C;

	UPDATE R 
	SET Date = @EndDate, Value = Qty * dbo.fnGetOutbalanceAveragePrice(R.MatGuid, @StartDate)
	FROM #Result R;
#################################################################
#END