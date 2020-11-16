###################################################################################
CREATE FUNCTION fnDate_AddEx( @StartDate AS [DATETIME], @AddType [INT], @Value [INT])
	RETURNS [DATETIME]
AS BEGIN 
/*
this function
	- return a date after adding @Value according to @addType
	- takes:
		- @startDate
		- @addType:
			2. adds number of days(from @Value) to @startDate
			3. sets the day of @startDate to @Value
			4. sets the day of @startDate to @Value for the next month
			5. sets the day of @startDate to a week day found in @Value
			6. sets the day of @startDate to a next week day found in @Value
			7. sets the day of @startDate to the end of month
			8. sets the day of @startDate to the end of next month
			
*/
	DECLARE @DateResult AS [DATETIME], @s AS [NVARCHAR](40), @DiffDay AS [INT]

	IF @AddType = 2 -- Add number of days
		SET @DateResult = @StartDate + @Value

	ELSE IF @AddType = 3 -- in day of this month
	BEGIN
		SET @s = CAST( MONTH( @StartDate) AS [NVARCHAR](5)) + '/' + CAST( @Value AS [NVARCHAR](5))+ '/' + CAST( YEAR( @StartDate) AS [NVARCHAR](10))
		SET @DateResult = CAST ( @s AS [datetime])
	END

	ELSE IF @AddType = 4 -- in day of next month
	BEGIN
		DECLARE 
			@TempDate AS [DATETIME],
			@DaysInMonth INT;
		SET @TempDate = DATEADD( month, 1, @StartDate)
		SET @DaysInMonth = DATEDIFF(DAY, @TempDate, DATEADD(MONTH, 1, @TempDate));
		IF @Value > @DaysInMonth
			SET @Value = @DaysInMonth;
		SET @s = CAST( YEAR( @TempDate) AS [NVARCHAR](10)) + RIGHT('00' + CAST( MONTH( @TempDate) AS [NVARCHAR](5)), 2)+ RIGHT('00' + CAST( @Value AS [NVARCHAR](5)), 2)
		SET @DateResult = CAST ( @s AS [datetime])
	END

	ELSE IF @AddType = 5 -- in day of this week
	BEGIN
		SET @DiffDay =  @Value + 1 - DATEPART( dw, @StartDate)
		IF @DiffDay < 0
			SET @DiffDay = 7 + @DiffDay
		SET @DateResult = DATEADD( day, @DiffDay , @StartDate)
	END

	ELSE IF @AddType = 6 -- in day of next week
	BEGIN
		SET @DiffDay =  @Value + 1 - DATEPART( dw, @StartDate)
		IF @DiffDay < 0
			SET @DiffDay = 7 + @DiffDay
		SET @DateResult = DATEADD( day, @DiffDay , @StartDate)
		SET @DateResult = DATEADD( week, 1, @DateResult)
	END

	ELSE IF @AddType = 7 -- in end of this month
		SET @DateResult = DATEADD( month, 1, @StartDate - day(@StartDate)+1) -1

	ELSE --  @addType = 8 (in end of next month)
		SET @DateResult = DATEADD( month, 2, @StartDate - day(@StartDate)+1) -1

	RETURN @DateResult
END
###################################################################################
#END