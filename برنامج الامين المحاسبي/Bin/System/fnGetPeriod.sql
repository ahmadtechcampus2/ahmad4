###############################################################################
CREATE FUNCTION fnGetPeriod(
					@PeriodType [INT], 
					@StartDate [DATETIME], 
					@EndDate [DATETIME]) 
	RETURNS @t Table([Period] [INT], [SubPeriodCounter] [INT], [SubPeriodRun] [INT], [StartDate] [DATETIME], [EndDate] [DATETIME]) 
AS BEGIN 
/*  
@PeriodType:   
	1: Daily  
	2: Weekly  
	3: Monthly  
	4: Quarterly  
	5: Yearly  
in each record of result:  
	-SubPeriod  is:  
		- the day number of StartPeriod, ranging from 1 to 31. 
		- the week number of StartPeriod, ranging from 1 to 5, and resets to 1 at start of month.  
		- the month number of StartPeriod, ranging from 1 to 12, and resets to 1 at start of  each year.  
		- the querter number of StartPeriod, ranging from 1 to 4, and resets to 1 at start of each year.  
		- the year of StartPeriod. 
*/  
	DECLARE  
		@PeriodCounter		[INT],  
		@SubPeriod			[INT],  
		@SubPeriodRun		[INT],  
		@PeriodStart		[DATETIME],  
		@PeriodEnd			[DATETIME],
		@StartDayOfWeek     [INT] ,
		@PeriodStartWeekDay [INT], 
		@Diff [INT]
	SET @PeriodCounter 		= 1  
	SELECT @StartDayOfWeek = value FROM op000 WHERE name = 'AmnCfg_StartOfWeekDay'
	IF @StartDayOfWeek = 0
		SET @StartDayOfWeek = 7
	SET @Diff = 0
	SET @SubPeriod 	= 1  
	SET @SubPeriodRun	 	= 1  
	SET @PeriodStart 		= @StartDate  
	IF @PeriodType = 2 -- weekly 
	BEGIN
		SET @PeriodStartWeekDay = DATEPART(WEEKDAY, @PeriodStart)
		WHILE(@PeriodStartWeekDay != @StartDayOfWeek) --Calc first period
		BEGIN
			if(@PeriodStartWeekDay + 1 > 7)
				Set @PeriodStartWeekDay = 1
			ELSE
				Set @PeriodStartWeekDay = @PeriodStartWeekDay + 1
			Set @Diff = @Diff + 1
		END
		SET @PeriodEnd = DATEADD(day, @Diff, @PeriodStart)
		SET @SubPeriod = DATEPART(week, @PeriodStart) - DATEPART(week, CAST((CAST(MONTH(@PeriodStart) AS [NVARCHAR](50)) + '/1/' + CAST(YEAR(@PeriodStart) AS [NVARCHAR](50))) AS [DATETIME])) + 1 
		SET @SubPeriodRun = DATEPART(ww, @PeriodStart) 
    	INSERT INTO @t VALUES(@PeriodCounter, @SubPeriod, @SubPeriodRun, @PeriodStart, @PeriodEnd)
		SET @PeriodStart = DATEADD(day, 1, @PeriodEnd)
		SET @PeriodCounter = @PeriodCounter + 1 
	END 
	WHILE @PeriodStart <= @EndDate  
	BEGIN  
		IF @PeriodType = 1 -- daily 
		BEGIN  
			SET @PeriodEnd = DATEADD(day, 1 , @PeriodStart)  
			SET @SubPeriod = DAY(@PeriodStart)  
			SET @SubPeriodRun  =  DATEPART(dy, @PeriodStart) 
		END  
		IF @PeriodType = 2 -- weekly 
		BEGIN
			SET @PeriodEnd = DATEADD(week, 1, @PeriodStart)
			SET @SubPeriod = DATEPART(week, @PeriodStart) - DATEPART(week, CAST((CAST(MONTH(@PeriodStart) AS [NVARCHAR](50)) + '/1/' + CAST(YEAR(@PeriodStart) AS [NVARCHAR](50))) AS [DATETIME])) + 1 
			SET @SubPeriodRun = DATEPART(ww, @PeriodStart) 
		END  
		IF @PeriodType = 3 -- monthly 
		BEGIN  
			SET @PeriodEnd = DATEADD(month, 1, @PeriodStart) 
			SET @SubPeriod = MONTH(@PeriodStart)  
			SET @SubPeriodRun = MONTH(@PeriodStart)  
		END  
		IF @PeriodType = 4 -- quarterly 
		BEGIN  
			SET @PeriodEnd = DATEADD(quarter, 1, @PeriodStart) 
			SET @SubPeriod = DATEPART(quarter, @PeriodStart)  
			SET @SubPeriodRun = @SubPeriod 
		END  
		IF @PeriodType = 5 -- yearly 
		BEGIN  
			SET @PeriodEnd = DATEADD(year, 1, @PeriodStart)  
			SET @SubPeriod = YEAR(@PeriodStart)  
			SET @SubPeriodRun = @SubPeriod 
		END  
		SET @PeriodEnd = DATEADD(day, -1, @PeriodEnd)  
		IF @PeriodEnd > @EndDate SET @PeriodEnd = @EndDate  
		INSERT INTO @t VALUES(@PeriodCounter, @SubPeriod, @SubPeriodRun, @PeriodStart, @PeriodEnd)  
		SET @PeriodStart = DATEADD(day, 1, @PeriodEnd)  
		SET @PeriodCounter = @PeriodCounter + 1  
	END  
	 
	IF @PeriodType <> 1 
		UPDATE @t SET EndDate = DATEADD(SECOND, -1, DATEADD(day, 1, EndDate)) WHERE Period <> ( SELECT MAX(Period) FROM @t) 
	ELSE 
		UPDATE @t SET EndDate = DATEADD(SECOND, -1, DATEADD(day, 1, EndDate))  
		 
	RETURN  
END 
/* 
select *from us000 
prcConnections_add '5133A956-022D-44BF-85BC-FE57228AE960' 
select datepart( week, '2/1/2003') 
SELECT * FROM dbo.fnGetPeriod( 2, '3/1/2003', '4/25/2003')
*/ 

###############################################################################
#END