################################################################################
CREATE PROC repPOS_LoyaltyCards_LOC_MoveByFiles
	@EndDate DATE
AS
	SET NOCOUNT ON

	DECLARE @Result TABLE (
		DBName				NVARCHAR(500),
		ChargedPointsCount	INT,
		PaidPointsCount		INT,
		FilePointsCount		INT,
		CanceledPointsCount	INT,
		FilePointsCountPeriod FLOAT)

	INSERT INTO @Result
	SELECT 
		DBName,
		SUM(CASE [State] WHEN 0 THEN PointsCount ELSE 0 END),
		SUM(CASE [State] WHEN 0 THEN PaidPointsCount ELSE 0 END),
		SUM(CASE [State] WHEN 1 THEN PointsCount ELSE 0 END),
		0,
		0
	FROM POSLoyaltyCardTransaction000
	WHERE 
		CONVERT(DATE, OrderDate) <= @EndDate
	GROUP BY DBName

	DECLARE 
		@SumChargedPointsCount	INT,
		@SumFilePaidPointsCount	INT 

	SELECT 
		@SumChargedPointsCount = SUM(ChargedPointsCount),
		@SumFilePaidPointsCount = SUM(FilePointsCount)
	FROM @Result

	IF @SumChargedPointsCount > 0
	BEGIN 
		UPDATE @Result
		SET FilePointsCountPeriod = CAST(ChargedPointsCount AS FLOAT) * @SumFilePaidPointsCount / @SumChargedPointsCount
	END

	DECLARE @PointsExpire INT	
	SET @PointsExpire = [dbo].[fnOption_GetInt]('AmnCfg_LoyaltyCards_PointsAvailability', '0')

	IF ISNULL(@PointsExpire, 0) > 0
	BEGIN 
		DECLARE 
			@today					DATE,
			@PointsCalcDaysCount	INT,
			@PointsCount			INT

		SET @today = GETDATE()
		SET @PointsCalcDaysCount =	[dbo].[fnOption_GetInt]('AmnCfg_LoyaltyCards_PointsAddedAfter', '0')
		
		DECLARE 
			@c					CURSOR,
			@dbName				NVARCHAR(500)
	
		SET @c = CURSOR FAST_FORWARD FOR SELECT DBName FROM @Result
		OPEN @c FETCH NEXT FROM @c INTO @dbName
		WHILE @@FETCH_STATUS = 0
		BEGIN 
			IF ISNULL(@PointsExpire, 0) > 0
			BEGIN 
				SET @PointsCount = ISNULL((
				SELECT 
					SUM(t.PointsCount - t.PaidPointsCount)
				FROM 
					POSLoyaltyCardTransaction000 t 
				WHERE 
					t.DBName = @dbName
					AND 
					CONVERT(DATE, t.OrderDate) <= @EndDate
					AND 
					t.State = 0
					AND 
					(DATEDIFF(dd, DATEADD(dd, @PointsCalcDaysCount, CONVERT(DATE, t.OrderDate)), @today) > @PointsExpire)), 0)

				IF @PointsCount > 0
				BEGIN 
					UPDATE @Result 
					SET 
						CanceledPointsCount = @PointsExpire
					WHERE DBName = @dbName
				END 
			END 

			FETCH NEXT FROM @c INTO @dbName
		END CLOSE @c DEALLOCATE @c 
	END 

	DECLARE @fileName [NVARCHAR](128) 
	SET @fileName = (SELECT TOP 1 CAST(VALUE AS [NVARCHAR](50)) FROM [sys].[fn_listextendedproperty]( 'AmnDBName', NULL, NULL, NULL, NULL, NULL, NULL))

	SELECT 
		CASE ISNULL(cs.[FileName], '')
			WHEN '' THEN (CASE WHEN r.DBName = DB_NAME() THEN @fileName ELSE r.DBName END)
			ELSE cs.[FileName]
		END AS [FileName],
		r.DBName AS DBName,
		ISNULL(r.ChargedPointsCount, 0) AS ChargedPointsCount,
		ISNULL(r.PaidPointsCount, 0) AS PaidPointsCount,
		ISNULL(r.FilePointsCount, 0) AS FilePaidPointsCount,
		ISNULL(r.CanceledPointsCount, 0) AS CanceledPointsCount,
		(r.ChargedPointsCount - r.PaidPointsCount - r.CanceledPointsCount) AS AvailablePointsCount,
		ISNULL(r.FilePointsCountPeriod, 0) AS FilePointsCountPeriod,
		CAST((FilePointsCount - FilePointsCountPeriod) AS FLOAT) AS DefPaidPointsCount
	FROM 
		@Result r 
		LEFT JOIN POSLoyaltyCardSource000 cs ON cs.DBName = r.DBName
#######################################################################################
CREATE PROC repPOS_LoyaltyCards_MoveByFiles 
	@EndDate	DATE
AS
	SET NOCOUNT ON

	DECLARE @ErrorNumber INT = 0 
	DECLARE @CentralizedDBName NVARCHAR(250)

	SELECT TOP 1
		@ErrorNumber =			ISNULL(ErrorNumber, 0),
		@CentralizedDBName =	ISNULL(CentralizedDBName, '')
	FROM 
		dbo.fnPOS_LoyaltyCards_CheckSystem (0x0)

	IF @ErrorNumber > 0 
		GOTO exitproc

	DECLARE @CmdText NVARCHAR(MAX)

	SET @CmdText = N'EXEC ' + @CentralizedDBName + N'repPOS_LoyaltyCards_LOC_MoveByFiles @EndDate  '
	EXEC sp_executesql @CmdText, N' @EndDate DATE', @EndDate
		  
	exitproc:
		SELECT @ErrorNumber AS ErrorNumber
#######################################################################################
#END
