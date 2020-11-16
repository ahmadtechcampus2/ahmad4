################################################################################
CREATE PROCEDURE prcGCC_TaxDuration_VerifyClosingDuration
	@TaxDurationGUID UNIQUEIDENTIFIER
AS
	SET NOCOUNT ON

	IF NOT EXISTS(SELECT * FROM GCCTaxDurations000 WHERE [GUID] = @TaxDurationGUID)
		RETURN

	DECLARE 
		@DurationStartDate DATE,
		@DurationEndDate DATE,
		@DurationState INT,
		@IsTransfered BIT,
		@DurationReportGUID UNIQUEIDENTIFIER,
		@IsBeforeCrossedDuration BIT, 
		@IsAfterCrossedDuration BIT, 
		@FPDate DATE,
		@EPDate DATE

	SELECT 
		@DurationStartDate = StartDate,
		@DurationEndDate = EndDate,
		@DurationState = [State],
		@IsTransfered = ISNULL([IsTransfered], 0),
		@DurationReportGUID = ISNULL(TaxVatReportGUID, 0x0)
	FROM GCCTaxDurations000 
	WHERE GUID = @TaxDurationGUID

	SET @FPDate = (SELECT [dbo].[fnOption_get]('AmnCfg_FPDate', DEFAULT))
	SET @EPDate = (SELECT [dbo].[fnOption_get]('AmnCfg_EPDate', DEFAULT))

	SET @IsBeforeCrossedDuration = 0
	IF (@DurationStartDate < @FPDate) AND (@DurationEndDate >= @FPDate)
		SET @IsBeforeCrossedDuration = 1

	SET @IsAfterCrossedDuration = 0
	IF (@DurationEndDate > @EPDate)
		SET @IsAfterCrossedDuration = 1
	
	CREATE TABLE #Result([Value] INT)
	-- 	
	IF ISNULL(@DurationState, 0) != 0
		INSERT INTO #Result SELECT 1
	--

	IF ISNULL(@IsAfterCrossedDuration, 0) != 0 AND ISNULL(@DurationState, 0) = 0
		INSERT INTO #Result SELECT 2

	IF ISNULL(@IsBeforeCrossedDuration, 0) = 0 AND 
		EXISTS(SELECT * FROM GCCTaxDurations000 WHERE EndDate < @DurationEndDate AND ISNULL([State], 0) = 0)
	BEGIN 
		INSERT INTO #Result SELECT 3
	END 

	IF ISNULL(@IsBeforeCrossedDuration, 0) != 0 AND 
		EXISTS(SELECT * FROM GCCTaxDurations000 WHERE EndDate < @DurationEndDate AND ISNULL([State], 0) = 0)
	BEGIN 
		INSERT INTO #Result SELECT 4
	END 

	IF ISNULL(@IsBeforeCrossedDuration, 0) != 0
	BEGIN 
		DECLARE 
			@AllDatabases CURSOR,
			@currentDbName NVARCHAR(128),
			@currentFirstPeriodDate DATE,
			@currentEndPeriodDate DATE,
			@Statement NVARCHAR(MAX),
			@UserGUID UNIQUEIDENTIFIER
		
		SET @UserGUID = [dbo].[fnGetCurrentUserGUID]() 

		CREATE TABLE #Duration(StartDate DATE, EndDate DATE)

		SET @AllDatabases = CURSOR FOR				 
			SELECT [DatabaseName], [FirstPeriod], [EndPeriod] FROM dbo.fnGetOtherReportDataSources(@DurationStartDate, @DurationEndDate) ORDER BY FirstPeriod
		OPEN @AllDatabases	    
	
		FETCH NEXT FROM @AllDatabases INTO @currentDbName, @currentFirstPeriodDate, @currentEndPeriodDate;
		WHILE (@@FETCH_STATUS = 0)
		BEGIN
			SET @Statement =  N'INSERT INTO #Duration(StartDate, EndDate) SELECT StartDate, EndDate FROM [' + @currentDbName + '].[dbo].[GCCTaxDurations000] 
				WHERE GUID = ''' + CONVERT(NVARCHAR(38), @TaxDurationGUID) + ''''
			EXEC sp_executesql @Statement;
			

			FETCH NEXT FROM @AllDatabases INTO @currentDbName, @currentFirstPeriodDate, @currentEndPeriodDate;
		END

		IF NOT EXISTS(SELECT * FROM #Duration)
			INSERT INTO #Result SELECT 5

		IF EXISTS (SELECT * FROM #Duration WHERE StartDate != @DurationStartDate OR EndDate != @DurationEndDate)
			INSERT INTO #Result SELECT 6
	END 
	
	IF (@IsTransfered = 1) AND @DurationEndDate < @FPDate
		INSERT INTO #Result SELECT 7

	SELECT * FROM #Result ORDER BY [Value]
##################################################################################
#END
