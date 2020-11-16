##################################################################
CREATE PROC prcPOS_LoyaltyCards_CheckPaidOrder
	@OrderGUID				UNIQUEIDENTIFIER,
	@SystemType				TINYINT = 0	-- 0: POS, 1: REST
AS 
	SET NOCOUNT ON 

	DECLARE 
		@ErrorNumber	INT,
		@OrderDate		DATE
	
	SET @ErrorNumber = 0

	IF @SystemType = 1
	BEGIN 
		IF NOT EXISTS (SELECT * FROM RESTOrder000 WHERE GUID = @OrderGUID)
		BEGIN 
			SET @ErrorNumber = 21
			GOTO exitProc
		END 

		IF EXISTS (SELECT * FROM RESTOrder000 WHERE (GUID = @OrderGUID) AND (ISNULL(PointsCount, 0) > 0) AND (ISNULL(LoyaltyCardGUID, 0x0) != 0x0))
		BEGIN 
			SET @ErrorNumber = 22
			GOTO exitProc
		END
		
		SELECT TOP 1 
			@OrderDate = Date
		FROM RESTOrder000 WHERE GUID = @OrderGUID

	END ELSE BEGIN 
		IF NOT EXISTS (SELECT * FROM POSOrder000 WHERE GUID = @OrderGUID)
		BEGIN 
			SET @ErrorNumber = 21
			GOTO exitProc
		END 

		IF EXISTS (SELECT * FROM POSOrder000 WHERE (GUID = @OrderGUID) AND (ISNULL(PointsCount, 0) > 0) AND (ISNULL(LoyaltyCardGUID, 0x0) != 0x0))
		BEGIN 
			SET @ErrorNumber = 22
			GOTO exitProc
		END 

		SELECT TOP 1 
			@OrderDate = Date
		FROM POSOrder000 WHERE GUID = @OrderGUID
	END 
	
	CREATE TABLE #op (ErrorNumber INT, OptionValue NVARCHAR(500))
	INSERT INTO #op EXEC prcPOS_LoyaltyCards_GetOptionValue 'AmnCfg_LoyaltyCards_PaidOrderAvailabilityForPointsCalc'
	
	DECLARE @OptionValue NVARCHAR(500)

	SELECT TOP 1 
		@ErrorNumber = ErrorNumber,
		@OptionValue = OptionValue
	FROM #op

	IF @ErrorNumber > 0 
		GOTO exitProc
	
	DECLARE @PaidOrderAvailabilityForPointsCalc INT = 0
	SET @PaidOrderAvailabilityForPointsCalc = 
		CASE ISNULL(@OptionValue, '')
			WHEN '' THEN 0
			ELSE CAST(@OptionValue AS INT)
		END 

	IF @PaidOrderAvailabilityForPointsCalc > 0
	BEGIN 
		DECLARE @today DATE 
		SET @today = GETDATE()
		
		IF DATEADD(dd, @PaidOrderAvailabilityForPointsCalc, @OrderDate) < @today
		BEGIN 
			SET @ErrorNumber = 23 
			GOTO exitProc
		END 
	END 

	exitProc:
		SELECT @ErrorNumber AS ErrorNumber
##################################################################
#END
