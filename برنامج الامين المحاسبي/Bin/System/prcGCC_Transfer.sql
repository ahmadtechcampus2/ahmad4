################################################################################
CREATE PROCEDURE prcGCC_Transfer
	@DestDb NVARCHAR(250)
AS  
	SET NOCOUNT ON  

	IF SUBSTRING(@DestDb, 1, 1) != '['
		SET @DestDb = '[' + @DestDb + ']'

	DECLARE 
		@CmdText			NVARCHAR(MAX), 
		@DurationTable		NVARCHAR(250), 
		@NextPeriodTypes	INT
			
	SET @DurationTable =			@DestDb + '..GCCTaxDurations000'

	SET @CmdText =				' UPDATE ' + @DurationTable + ' SET IsTransfered = 1 '
	SET @CmdText = @CmdText +	' UPDATE ' + @DestDb + '..GCCTaxSettings000 SET IsTransfered = 1 '

	EXEC sp_executesql @CmdText
	-----------------------------------------------------------------------------------
	-----------------------------------------------------------------------------------
	SET @NextPeriodTypes = ISNULL((SELECT TOP 1 NextPeriodsType FROM GCCTaxSettings000), 0)
	IF @NextPeriodTypes = 0
		RETURN
	-----------------------------------------------------------------------------------
	-----------------------------------------------------------------------------------
	DECLARE 
		@StartDate			[DATETIME],
		@EndDate			[DATETIME],		
		@EndFilePeriodDate	[DATETIME]

	SELECT 
		@StartDate =	MIN(StartDate),
		@EndDate =		MAX(EndDate)
	FROM GCCTaxDurations000

	SET @StartDate =	ISNULL(@StartDate,	'1980-01-01')
	SET @EndDate =		ISNULL(@EndDate,	'1980-01-01')

	CREATE TABLE [#FilePeriod] (EndFilePeriodDate [DATETIME])		
	SET @CmdText = 'INSERT INTO [#FilePeriod] (EndFilePeriodDate) SELECT [dbo].[fnDate_Amn2Sql]([Value]) FROM ' + @DestDb + '..[op000] WHERE [Name] = ''AmnCfg_EPDate''' 
	
	EXEC sp_executesql @CmdText

	SELECT TOP 1 
		@EndFilePeriodDate = EndFilePeriodDate 
	FROM [#FilePeriod]

	IF @EndFilePeriodDate IS NULL
		RETURN 
	-----------------------------------------------------------------------------------
	-----------------------------------------------------------------------------------
	DECLARE 
		@StartNewDurationDate	[DATETIME],
		@EndNewDurationDate		[DATETIME]

	SET @StartNewDurationDate =  
		CASE @EndDate 
			WHEN '1980-01-01' THEN (SELECT TOP 1 SubscriptionDate FROM GCCTaxSettings000)
			ELSE DATEADD(DAY, 1 , @EndDate) 
		END
									
	SET @EndNewDurationDate =	
		CASE @NextPeriodTypes 
			WHEN 1 THEN DATEADD(DAY, -1, DATEADD(MONTH, 1, @StartNewDurationDate))
			ELSE DATEADD(DAY, -1, DATEADD(MONTH, 3 , @StartNewDurationDate)) 
		END

	DECLARE
		@Number			[INT],
		@DurationNumber	[INT],
		@Year			[INT],
		@Code			NVARCHAR(250),
		@Name			NVARCHAR(250),
		@LatinName		NVARCHAR(250),
		@ReachYearEnd	[BIT] = 0

	SET @DurationNumber = ISNULL((SELECT MAX(NUMBER) FROM GCCTaxDurations000), 0) + 1

	DECLARE @CurrentDurationData TABLE (
		DurationNumber			[INT],
		SubscriptionStartDate	[DATE],
		SubscriptionEndDate		[DATE],
		DurationYear			[INT],
		LastDurationEndDate		[DATE])	
	
	INSERT INTO @CurrentDurationData (DurationNumber, SubscriptionStartDate, SubscriptionEndDate, DurationYear, LastDurationEndDate)
	SELECT DurationNumber, SubscriptionStartDate, SubscriptionEndDate, DurationYear, LastDurationEndDate 
	FROM dbo.fn_GCCGetCurrentDurationData (@StartNewDurationDate, @EndFilePeriodDate)

	SELECT TOP 1 
		@Number = DurationNumber,
		@Year = DurationYear
	FROM 
		@CurrentDurationData

	IF @EndDate > (SELECT TOP 1 SubscriptionStartDate FROM @CurrentDurationData)
		SET @Year = YEAR((SELECT TOP 1 SubscriptionStartDate FROM @CurrentDurationData)) + 1
					
	WHILE @StartNewDurationDate <= @EndFilePeriodDate
	BEGIN	
		BEGIN
			IF ((@Number > 12 AND @NextPeriodTypes = 1) OR (@Number > 4 AND @NextPeriodTypes = 2))
			BEGIN
				SET @ReachYearEnd = 1
				SET @Number = 1
				SET @Year = (SELECT TOP 1 DurationYear FROM @CurrentDurationData) + 1
			END

			SET @Code = ((CAST(@Year AS NVARCHAR(10))) + CASE WHEN @Number < 10 THEN '-0' ELSE '-' END + CAST(@Number AS [NVARCHAR](255))) 
			SET @Name = (dbo.fn_IntegerToWord(@Number, (CAST(@Year AS NVARCHAR(10))), 'Ar'))
			SET @LatinName = (dbo.fn_IntegerToWord(@Number, (CAST(@Year AS NVARCHAR(10))), 'En'))

			SET @CmdText = 'INSERT INTO ' + @DurationTable + ' (Number, Code, Name, LatinName, StartDate, EndDate) 
			VALUES (''' + CAST (@DurationNumber AS NVARCHAR (255)) + ''', ''' + @Code + ''', ''' + @Name + ''', ''' + @LatinName + ''', ''' + CAST(@StartNewDurationDate AS NVARCHAR(255)) + ''', ''' + CAST(@EndNewDurationDate AS NVARCHAR(255)) + ''' )'
			EXEC sp_executesql @CmdText
		END

		SET @StartNewDurationDate = DATEADD(DAY, 1 , @EndNewDurationDate)
		SET @EndNewDurationDate = 
			CASE @NextPeriodTypes 
				WHEN 1 THEN DATEADD(DAY, -1, DATEADD(MONTH, 1 , @StartNewDurationDate))
				ELSE DATEADD(DAY, -1, DATEADD(MONTH, 3 , @StartNewDurationDate)) 
			END
		SET @Number = @Number + 1
		SET @DurationNumber = @DurationNumber + 1
	END

	-----------------------------------------------------------------------------------
	-----------------------------------------------------------------------------------
	CREATE TABLE [#VATReportGUIDS] (TaxVatReportGUID [UNIQUEIDENTIFIER])

	SET @CmdText = 'INSERT INTO [#VATReportGUIDS] SELECT TaxVatReportGUID FROM ' + @DurationTable + ' WHERE DATEDIFF (YEAR, EndDate, (SELECT MAX (EndDate) FROM ' + @DurationTable + ')) > 5 '
	EXEC sp_executesql @CmdText

	SET @CmdText = 'DELETE FROM ' + @DurationTable + ' WHERE DATEDIFF (YEAR, EndDate, (SELECT MAX (EndDate) FROM ' + @DurationTable + ')) > 5 '
	EXEC sp_executesql @CmdText
	
	SET @CmdText = 'DELETE FROM ' + @DestDb + '..GCCTaxVatReports000 WHERE GUID IN (SELECT * FROM [#VATReportGUIDS] ) ' 
	EXEC sp_executesql @CmdText
	
	SET @CmdText = 'DELETE FROM ' + @DestDb + '..GCCTaxVatReportDetails000 WHERE ParentGUID IN (SELECT * FROM [#VATReportGUIDS] ) ' 	
	EXEC sp_executesql @CmdText
################################################################################
#END
