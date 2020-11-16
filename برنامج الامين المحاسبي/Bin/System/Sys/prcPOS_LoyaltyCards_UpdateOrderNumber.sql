##################################################################
CREATE PROC prcPOS_LoyaltyCards_LOC_UpdateOrderNumber
	@OrderGUID				UNIQUEIDENTIFIER,
	@OrderNumber			BIGINT 
AS 
	SET NOCOUNT ON 

	UPDATE POSLoyaltyCardTransaction000 
	SET OrderNumber = @OrderNumber
	WHERE OrderGUID = @OrderGUID
##################################################################
CREATE PROC prcPOS_LoyaltyCards_UpdateOrderNumber
	@OrderGUID				UNIQUEIDENTIFIER,
	@SystemType				TINYINT = 0 -- 0: POS, 1: REST
AS 
	SET NOCOUNT ON 

	DECLARE @ErrorNumber INT
	SET @ErrorNumber = 0
	
	DECLARE @NeedUpdate BIT = 0

	DECLARE @PaymentsPackageID UNIQUEIDENTIFIER
	IF ISNULL(@SystemType, 0) = 1
	BEGIN 
		SELECT @PaymentsPackageID = PaymentsPackageID  FROM RESTOrder000 WHERE GUID = @OrderGUID
	END ELSE BEGIN
		SELECT @PaymentsPackageID = PaymentsPackageID  FROM POSOrder000 WHERE GUID = @OrderGUID
	END

	IF EXISTS (
		SELECT 1 FROM 
			POSPaymentsPackagePoints000 pp
			INNER JOIN POSPaymentsPackage000 p ON p.GUID = pp.ParentGUID
		WHERE 
			p.GUID = @PaymentsPackageID 
			AND (ISNULL(pp.LoyaltyCardGUID, 0x0) != 0x0) 
			AND (ISNULL(pp.LoyaltyCardTypeGUID, 0x0) != 0x0) 
			AND pp.PointsCount > 0) 
	BEGIN 
		SET @NeedUpdate = 1
	END 

	IF @NeedUpdate = 0
	BEGIN 
		IF ISNULL(@SystemType, 0) = 1
		BEGIN 
			IF EXISTS (SELECT 1 FROM RESTOrder000 WHERE GUID = @OrderGUID AND PointsCount > 0)
				SET @NeedUpdate = 1
		END ELSE BEGIN
			IF EXISTS (SELECT 1 FROM POSOrder000 WHERE GUID = @OrderGUID AND PointsCount > 0)
				SET @NeedUpdate = 1
		END
	END 

	IF @NeedUpdate = 0
		GOTO exitproc

	DECLARE @CentralizedDBName NVARCHAR(250)
	SELECT TOP 1
		@ErrorNumber =			ISNULL(ErrorNumber, 0),
		@CentralizedDBName =	ISNULL(CentralizedDBName, '')
	FROM 
		dbo.fnPOS_LoyaltyCards_CheckSystem (0x0)

	IF @ErrorNumber > 0 
		GOTO exitproc

	DECLARE @OrderNumber BIGINT = 0
	IF ISNULL(@SystemType, 0) = 1
	BEGIN 
		SELECT TOP 1 @OrderNumber = Number FROM RESTOrder000 WHERE GUID = @OrderGUID
	END ELSE BEGIN
		SELECT TOP 1 @OrderNumber = Number FROM POSOrder000 WHERE GUID = @OrderGUID
	END

	DECLARE @CmdText NVARCHAR(MAX)

	SET @CmdText = 
		'EXEC ' + @CentralizedDBName + 'prcPOS_LoyaltyCards_LOC_UpdateOrderNumber @OrderGUID, @OrderNumber ' 

	EXEC sp_executesql @CmdText, 
		N'@OrderGUID		UNIQUEIDENTIFIER,
		@OrderNumber		BIGINT', @OrderGUID, @OrderNumber

	exitProc:
		SELECT @ErrorNumber AS ErrorNumber
##################################################################
#END
