##################################################################
CREATE PROC prcPOS_LoyaltyCards_CalcChargedPointsCountFoPaidOrder
	@OrderGUID				UNIQUEIDENTIFIER,
	@LoyaltyCardGUID		UNIQUEIDENTIFIER,
	@LoyaltyCardTypeGUID	UNIQUEIDENTIFIER,
	@SystemType				TINYINT = 0	-- 0: POS, 1: REST
AS 
	SET NOCOUNT ON 

	DECLARE 
		@ErrorNumber INT,
		@PointsCount INT
	
	SET @ErrorNumber = 0
	SET @PointsCount = 0

	CREATE TABLE #EndResult (ErrorNumber INT, PointsCount INT)
	INSERT INTO #EndResult EXEC prcPOS_LoyaltyCards_CalcChargedPointsCount @OrderGUID, @LoyaltyCardGUID, @LoyaltyCardTypeGUID, @SystemType, 0
	
	SELECT TOP 1 
		@ErrorNumber = ErrorNumber,
		@PointsCount = PointsCount
	FROM #EndResult

	IF @ErrorNumber > 0
		GOTO exitProc

	IF @PointsCount <= 0
	BEGIN 
		SET @ErrorNumber = 200
		GOTO exitProc
	END 

	CREATE TABLE #ErrorNumbers (ErrorNumber INT)
	BEGIN TRAN 
	INSERT INTO #ErrorNumbers EXEC prcPOS_LoyaltyCards_AddTransaction @OrderGUID, 0 /*charge points*/, @LoyaltyCardTypeGUID, @LoyaltyCardGUID, @PointsCount, @SystemType		
	
	SELECT TOP 1 
		@ErrorNumber = ErrorNumber
	FROM #ErrorNumbers

	exitProc:
		SELECT @ErrorNumber AS ErrorNumber
		IF @@TRANCOUNT > 0
		BEGIN 
			IF @ErrorNumber > 0
				ROLLBACK TRAN 
			ELSE 
				COMMIT TRAN 
		END 
##################################################################
#END
