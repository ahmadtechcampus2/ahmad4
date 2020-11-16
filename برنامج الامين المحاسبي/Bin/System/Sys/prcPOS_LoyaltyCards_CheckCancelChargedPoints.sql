##################################################################
CREATE PROC prcPOS_LoyaltyCards_CheckCancelChargedPoints
	@OrderGUID				UNIQUEIDENTIFIER,
	@SystemType				TINYINT = 0	-- 0: POS, 1: REST
AS 
	SET NOCOUNT ON 
	
	DECLARE 
		@LoyaltyCardTypeGUID	UNIQUEIDENTIFIER,
		@LoyaltyCardGUID		UNIQUEIDENTIFIER,
		@PointsCount			INT,
		@AvailablePointsCount	INT,
		@ErrorNumber			INT,
		@CentralizedDBName		NVARCHAR(250)

	SET @PointsCount =			0
	SET @ErrorNumber =			0
	SET @AvailablePointsCount = 0
	SET @CentralizedDBName =	''

	IF @SystemType = 1
	BEGIN 
		SELECT TOP 1
			@LoyaltyCardTypeGUID =	LoyaltyCardTypeGUID,
			@LoyaltyCardGUID =		LoyaltyCardGUID,
			@PointsCount =			PointsCount
		FROM 
			RESTOrder000 
		WHERE GUID = @OrderGUID
	END ELSE BEGIN
		SELECT TOP 1
			@LoyaltyCardTypeGUID =	LoyaltyCardTypeGUID,
			@LoyaltyCardGUID =		LoyaltyCardGUID,
			@PointsCount =			PointsCount
		FROM 
			POSOrder000 
		WHERE GUID = @OrderGUID
	END 
	
	IF @PointsCount <= 0 
		GOTO exitProc

	SELECT TOP 1
		@ErrorNumber =			ISNULL(ErrorNumber, 0),
		@CentralizedDBName =	ISNULL(CentralizedDBName, '')
	FROM 
		dbo.fnPOS_LoyaltyCards_CheckSystem (0x0)

	IF @ErrorNumber > 0 
		GOTO exitproc

	IF @CentralizedDBName = ''
		SET @CentralizedDBName = 'dbo.'

	CREATE TABLE #CardPointsCount (Cnt INT)
	DECLARE @CmdText NVARCHAR(MAX)
	SET @CmdText = 'INSERT INTO #CardPointsCount(Cnt) SELECT ' + @CentralizedDBName + 'fnPOS_LoyaltyCards_GetAvailablePointsCount('''  + CAST(@LoyaltyCardGUID AS VARCHAR(100)) + ''')'
	EXEC (@CmdText)

	IF EXISTS (SELECT * FROM #CardPointsCount WHERE Cnt > 0)
		SET @AvailablePointsCount = (SELECT TOP 1 CAST(cnt AS INT) FROM #CardPointsCount)

	IF @AvailablePointsCount < @PointsCount
	BEGIN 
		SET @ErrorNumber = 31
		GOTO exitProc
	END 

	DELETE #CardPointsCount
	SET @CmdText = 'INSERT INTO #CardPointsCount(Cnt) SELECT PaidPointsCount FROM ' + @CentralizedDBName + 'POSLoyaltyCardTransaction000 WHERE State = 0 AND OrderGUID = ''' + CAST(@OrderGUID AS VARCHAR(40)) + ''''
	EXEC (@CmdText)

	IF EXISTS (SELECT * FROM #CardPointsCount WHERE Cnt > 0)
		SET @ErrorNumber = 32

	exitProc:
		SELECT @ErrorNumber AS ErrorNumber
##################################################################
#END
