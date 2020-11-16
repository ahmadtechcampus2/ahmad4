##############################
CREATE PROC repGetSiteCost
	@SiteGUID		UNIQUEIDENTIFIER,  
	@StartDate		DATETIME,  
	@EndDate		DATETIME
AS  
SET NOCOUNT ON 
	DECLARE @Price FLOAT, 
			@Hourly INT

	SET @Price = 0 
	
	SELECT 
		@Price = t.Price,
		@Hourly = t.PricePolicy   
	FROM   
		hosSite000 AS S 
		INNER JOIN hosSiteType000 AS T ON S.TypeGuid = T.Guid  
	WHERE S.Guid = @SiteGUID 

	DECLARE @num FLOAT, @temp FLOAT
	
	IF (@Hourly = 1)	 -- by  hour
	BEGIN	
		SET @temp = DATEDIFF(mi, @StartDate, @EndDate) + 1 -- add one minutes
		SET @num =  @temp/60 
	END
	ELSE	
	IF (@Hourly = 0) -- by day	
	BEGIN

		DECLARE @BaseOnBeginDay BIT
		
		SELECT 	@BaseOnBeginDay = CAST([VALUE] AS BIT)
		FROM op000 WHERE [Name] = 'HosCfg_BaseOnBeginDay'
		SET @BaseOnBeginDay = ISNULL(@BaseOnBeginDay, 0)
			
		SET @num = DATEDIFF(day, @StartDate, @EndDate)
		IF (@BaseOnBeginDay <> 0)
		BEGIN

			DECLARE @BeginDay_Hour 		INT,
				@BeginDay_Minute 	INT,
				@StartDate_Hour  	INT,
				@StartDate_Minute 	INT,
				@EndDate_Hour	 	INT,
				@EndDate_Minute		INT
			
			SELECT 
				@BeginDay_Hour = CAST(SUBSTRING([Value],1, 2) AS INT),
				@BeginDay_Minute = CAST(SUBSTRING([Value],4, 2) AS INT),
				@StartDate_Hour = DATEPART(hh, @StartDate),
				@StartDate_Minute = DATEPART(mi, @StartDate),
				@EndDate_Hour = DATEPART(hh, @EndDate),
				@EndDate_Minute = DATEPART(mi, @EndDate)
			FROM 
				OP000 
			WHERE [Name] = 'HosCfg_BeginDayTime'
			IF (@BeginDay_Hour IS NOT NULL AND @BeginDay_Minute IS NOT NULL)
			BEGIN
				IF (@StartDate_Hour < @BeginDay_Hour)
					SET @num = @num + 1
				ELSE
				IF (@StartDate_Minute < @BeginDay_Minute)
					SET @num = @num + 1
		
				IF (@EndDate_Hour > @BeginDay_Hour)
					SET @num = @num + 1
				ELSE
				IF (@EndDate_Minute > @BeginDay_Minute)
					SET @num = @num + 1
			END
			
		END	
		ELSE
			SET @num = @num + 1	
	END

	SELECT @Price * @num as price
######################################
#END
