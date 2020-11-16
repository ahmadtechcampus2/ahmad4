#########################################################
CREATE FUNCTION fn_GCCGetCurrentDurationData (@DurationStartDate [DATE], @EndPeriodDate [DATE])
RETURNS @Result TABLE (
	DurationNumber			[INT],
	SubscriptionStartDate	[DATE],
	SubscriptionEndDate		[DATE],
	DurationYear			[INT],
	LastDurationEndDate		[DATE])	
AS
BEGIN
	DECLARE
		 @SubscriptionStartDate		[DATE],
		 @SubscriptionEndDate		[DATE],
		 @NewSubscriptionStartDate	[DATE],
		 @NewSubscriptionEndDate	[DATE],
		 @StartPeriodtDate			[DATE],
		 @DurationEndDate			[DATE],
		 @NextPeriodsType			[INT],
		 @DurationYear				[INT],
		 @FirstDurationNumber		[INT]

	SELECT TOP 1
		@SubscriptionStartDate = SubscriptionDate,
		@NextPeriodsType = NextPeriodsType
	FROM GCCTaxSettings000
	SET @StartPeriodtDate = DATEADD (DAY, 1, DATEADD (YEAR, -1, @EndPeriodDate))
	SET @SubscriptionEndDate = DATEADD (DAY, -1, DATEADD (YEAR, 1, @SubscriptionStartDate))

	WHILE @SubscriptionEndDate < @StartPeriodtDate AND @SubscriptionEndDate NOT BETWEEN @StartPeriodtDate AND @EndPeriodDate
	BEGIN
		SET @SubscriptionEndDate = DATEADD (YEAR, 1, @SubscriptionEndDate)
		SET @SubscriptionStartDate = DATEADD (YEAR, 1, @SubscriptionStartDate)
	END
			
	SET @NewSubscriptionEndDate = DATEADD (YEAR, 1, @SubscriptionEndDate)
	SET @NewSubscriptionStartDate = DATEADD (YEAR, 1, @SubscriptionStartDate)

	SET @DurationEndDate = CASE WHEN @NextPeriodsType = 1 THEN DATEADD(DAY, -1, DATEADD (MONTH, 1, @DurationStartDate))
								  ELSE DATEADD(DAY, -1, DATEADD (MONTH, 3, @DurationStartDate)) END
	WHILE @DurationStartDate <= @EndPeriodDate
	BEGIN
		SET @DurationEndDate = CASE WHEN @NextPeriodsType = 1 THEN DATEADD(DAY, -1, DATEADD (MONTH, 1, @DurationStartDate))
									  ELSE DATEADD(DAY, -1, DATEADD (MONTH, 3, @DurationStartDate)) END
		SET @DurationStartDate = DATEADD (DAY, 1, @DurationEndDate)
	END
	SET @FirstDurationNumber = (
		SELECT 
			COUNT (*) 
		FROM 
			GCCTaxDurations000
		WHERE 
			StartDate >= @SubscriptionStartDate
			AND StartDate <= @SubscriptionEndDate
			AND @DurationStartDate BETWEEN @NewSubscriptionStartDate AND @NewSubscriptionEndDate) + 1

	SET @DurationYear = YEAR(@SubscriptionEndDate) 
	
	INSERT INTO @Result VALUES (@FirstDurationNumber, @SubscriptionStartDate, @SubscriptionEndDate, @DurationYear, @DurationEndDate)
	RETURN
END
#########################################################
#end