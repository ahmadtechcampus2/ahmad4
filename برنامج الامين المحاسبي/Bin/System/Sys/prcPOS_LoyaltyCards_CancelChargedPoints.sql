##################################################################
CREATE PROC prcPOS_LoyaltyCards_LOC_CancelChargedPoints
	@OrderGUID				UNIQUEIDENTIFIER
AS 
	SET NOCOUNT ON 

	SELECT 
		r.ChargeTransactionGUID,
		SUM (r.PointsCount) AS PointsCount
	INTO #ChargeTransactions
	FROM 
		POSLoyaltyCardTransactionRelation000 r 
		INNER JOIN POSLoyaltyCardTransaction000 t ON r.PaidTransactionGUID = t.GUID
	WHERE t.OrderGUID = @OrderGUID
	GROUP BY r.ChargeTransactionGUID

	UPDATE t
	SET 
		PaidPointsCount = CASE WHEN t.PaidPointsCount < r.PointsCount THEN 0 ELSE t.PaidPointsCount - r.PointsCount END
	FROM 
		POSLoyaltyCardTransaction000 t
		INNER JOIN #ChargeTransactions r ON t.GUID = r.ChargeTransactionGUID

	DELETE r 
	FROM 
		POSLoyaltyCardTransactionRelation000 r 
		INNER JOIN POSLoyaltyCardTransaction000 t ON r.PaidTransactionGUID = t.GUID OR r.ChargeTransactionGUID = t.GUID
	WHERE t.OrderGUID = @OrderGUID 

	DELETE POSLoyaltyCardTransaction000 WHERE OrderGUID = @OrderGUID
##################################################################
CREATE PROC prcPOS_LoyaltyCards_CancelChargedPoints
	@OrderGUID				UNIQUEIDENTIFIER
AS 
	SET NOCOUNT ON 

	DECLARE 
		@CentralizedDBName			NVARCHAR(500),
		@ErrorNumber				INT
	
	SELECT TOP 1
		@ErrorNumber =			ISNULL(ErrorNumber, 0),
		@CentralizedDBName =	ISNULL(CentralizedDBName, '')
	FROM 
		dbo.fnPOS_LoyaltyCards_CheckSystem (0x0)

	IF @ErrorNumber > 0 
		GOTO exitproc

	DECLARE @CmdText NVARCHAR(MAX)
	SET @CmdText = 'EXEC '  + @CentralizedDBName + 'prcPOS_LoyaltyCards_LOC_CancelChargedPoints '''  + CAST(@OrderGUID AS VARCHAR(100)) + ''''
	
	EXEC (@CmdText)
	exitproc:
		SELECT 
			@ErrorNumber			AS ErrorNumber
##################################################################
#END
