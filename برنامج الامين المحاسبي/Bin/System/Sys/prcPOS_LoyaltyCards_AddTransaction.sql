##################################################################
CREATE PROC prcPOS_LoyaltyCards_LOC_AddTransaction
	@OrderGUID				UNIQUEIDENTIFIER,
	@OrderDate				DATETIME,
	@OrderNumber			BIGINT,
	@OrderCustomerName		NVARCHAR(250),
	@PointsCount			INT,	
	@OrderTotal				FLOAT,
	@OrderCurrencyVal		FLOAT,
	@OrderCurrencyCode		NVARCHAR(250),
	@LoyaltyCardGUID		UNIQUEIDENTIFIER,
	@State					TINYINT, -- 0: charge, 1: pay
	@DBName					NVARCHAR(250),
	@UserName				NVARCHAR(500),
	@ComputerName			NVARCHAR(500),
	@PointsValue			FLOAT,
	@BranchName				NVARCHAR(500),
	@BranchLatinName		NVARCHAR(500),
	@SystemType				TINYINT -- 0: POS, 1: REST
AS 
	SET NOCOUNT ON 
		
	IF (@State = 0) AND EXISTS (SELECT 1 FROM POSLoyaltyCardTransaction000 WHERE OrderGUID = @OrderGUID AND [State] = 0) 
		RETURN 
	
	DECLARE @guid UNIQUEIDENTIFIER
	SET @guid = NEWID()

	INSERT INTO POSLoyaltyCardTransaction000 (
		[GUID],
		OrderGUID,
		OrderDate,
		OrderNumber,
		OrderCustomerName,
		PointsCount,
		PaidPointsCount,
		OrderTotal,
		OrderCurrencyVal,
		OrderCurrencyCode,
		LoyaltyCardGUID,
		[State], 
		DBName,
		UserName, 
		ComputerName, 
		OperationTime,
		PointsValue,
		BranchName,
		BranchLatinName,
		SystemType)
	SELECT 
		@guid,
		@OrderGUID,
		@OrderDate,
		@OrderNumber,
		@OrderCustomerName,
		@PointsCount,	
		0, -- PaidPointsCount
		@OrderTotal,
		@OrderCurrencyVal,
		@OrderCurrencyCode,
		@LoyaltyCardGUID,
		@State,
		@DBName,
		@UserName, 
		@ComputerName, 
		GETDATE(),
		@PointsValue,
		@BranchName,
		@BranchLatinName,
		@SystemType
	
	IF @State = 1
	BEGIN 
		DECLARE 
			@c_transactions		CURSOR,
			@transaction_guid	UNIQUEIDENTIFIER,
			@transaction_points	INT

		DECLARE @today DATE 
		SET @today = GETDATE()

		DECLARE 
			@PointsExpire			INT,	-- monthes count
			@PointsCalcDaysCount	INT,
			@CalcedPoints			INT,
			@i_points				INT 

		SET @CalcedPoints			= @PointsCount
		SET @i_points				= 0
		SET @PointsExpire =			[dbo].[fnOption_GetInt]('AmnCfg_LoyaltyCards_PointsAvailability', '0')
		SET @PointsCalcDaysCount =	[dbo].[fnOption_GetInt]('AmnCfg_LoyaltyCards_PointsAddedAfter', '0')

		SET @c_transactions = CURSOR FAST_FORWARD FOR 
			SELECT 
				[GUID], 
				PointsCount - PaidPointsCount
			FROM 
				POSLoyaltyCardTransaction000
			WHERE 
				LoyaltyCardGUID = @LoyaltyCardGUID
				AND 
				[State] = 0 -- charge
				AND 
				PointsCount - PaidPointsCount > 0
				AND
				(
				    (ISNULL(@PointsCalcDaysCount, 0) = 0)
				    OR
				    ((@PointsCalcDaysCount != 0) AND (DATEADD(dd, @PointsCalcDaysCount, CONVERT(DATE, OrderDate)) <= @today))
				)
				AND
				(
					(ISNULL(@PointsExpire, 0) = 0)
					OR
					((@PointsExpire != 0) AND (DATEDIFF(dd, DATEADD(dd, @PointsCalcDaysCount, CONVERT(DATE, OrderDate)), @today) <= @PointsExpire))
				)
				AND 
				OrderGUID != @OrderGUID
			ORDER BY 
				OrderDate
		
		OPEN @c_transactions FETCH NEXT FROM @c_transactions INTO @transaction_guid, @transaction_points
		WHILE @@FETCH_STATUS = 0
		BEGIN 
			IF @CalcedPoints <= 0
				BREAK
			
			IF @CalcedPoints < @transaction_points
				SET @i_points = @CalcedPoints
			ELSE 
				SET @i_points = @transaction_points

			IF @i_points > 0 
			BEGIN 
				UPDATE POSLoyaltyCardTransaction000 SET PaidPointsCount = PaidPointsCount + @i_points WHERE [GUID] = @transaction_guid

				INSERT INTO POSLoyaltyCardTransactionRelation000 (GUID, ChargeTransactionGUID, PaidTransactionGUID, PointsCount)
				SELECT NEWID(), @transaction_guid, @guid, @i_points
			END 
			SET @CalcedPoints = @CalcedPoints - @i_points

			FETCH NEXT FROM @c_transactions INTO @transaction_guid, @transaction_points
		END CLOSE @c_transactions DEALLOCATE @c_transactions
	END 
##################################################################
CREATE PROC prcPOS_LoyaltyCards_AddTransaction
	@OrderGUID					UNIQUEIDENTIFIER,
	@State						TINYINT, -- 0 charged, 1 paid  
	@ChargedLoyaltyCardTypeGUID	UNIQUEIDENTIFIER = 0x0,
	@ChargedLoyaltyCardGUID		UNIQUEIDENTIFIER = 0x0,
	@ChargedPointsCount			INT = 0,
	@SystemType					TINYINT = 0 -- 0: POS, 1: REST
AS 
	SET NOCOUNT ON 
	
	DECLARE @ErrorNumber INT
	SET @ErrorNumber = 0
	
	DECLARE @PaymentsPackageID UNIQUEIDENTIFIER

	IF ISNULL(@SystemType, 0) = 1
	BEGIN 
		SELECT @PaymentsPackageID = PaymentsPackageID  FROM RESTOrder000 WHERE GUID = @OrderGUID
	END ELSE BEGIN
		SELECT @PaymentsPackageID = PaymentsPackageID  FROM POSOrder000 WHERE GUID = @OrderGUID
	END
	IF ISNULL(@PaymentsPackageID, 0x0) = 0x0
		GOTO exitproc

	IF (@State = 1) AND NOT EXISTS(
		SELECT 1 FROM 
			POSPaymentsPackagePoints000 pp
			INNER JOIN POSPaymentsPackage000 p ON p.GUID = pp.ParentGUID
		WHERE 
			p.GUID = @PaymentsPackageID 
			AND (ISNULL(pp.LoyaltyCardGUID, 0x0) != 0x0) 
			AND (ISNULL(pp.LoyaltyCardTypeGUID, 0x0) != 0x0) 
			AND pp.PointsCount > 0)
		GOTO exitproc

	IF (@State = 0) AND ((ISNULL(@ChargedLoyaltyCardTypeGUID, 0x0) = 0x0) OR (ISNULL(@ChargedLoyaltyCardGUID, 0x0) = 0x0) OR (ISNULL(@ChargedPointsCount, 0) = 0))
		GOTO exitproc

	DECLARE 
		@LoyaltyCardTypeGUID	UNIQUEIDENTIFIER,
		@LoyaltyCardGUID		UNIQUEIDENTIFIER,
		@PointsCount			INT,
		@PointsValue			FLOAT

	DECLARE 
		@OrderDate				DATETIME,
		@OrderNumber			BIGINT,
		@OrderCustomerName		NVARCHAR(500),
		@OrderTotal				FLOAT,
		@OrderCurrencyVal		FLOAT,
		@OrderCurrencyCode		NVARCHAR(500),
		@OrderBranchName		NVARCHAR(500),
		@OrderBranchLatinName	NVARCHAR(500)

	IF @State = 1
	BEGIN 
		SELECT TOP 1 
			@LoyaltyCardTypeGUID =	pp.LoyaltyCardTypeGUID,
			@LoyaltyCardGUID =		pp.LoyaltyCardGUID,
			@PointsCount =			pp.PointsCount,
			@PointsValue =			pp.PointsValue
		FROM 	
			POSPaymentsPackagePoints000 pp
			INNER JOIN POSPaymentsPackage000 p ON p.GUID = pp.ParentGUID
		WHERE 
			p.GUID = @PaymentsPackageID 
	
		IF ((ISNULL(@LoyaltyCardTypeGUID, 0x0) = 0x0) OR
			(ISNULL(@LoyaltyCardGUID, 0x0) = 0x0) OR
			(ISNULL(@PointsCount, 0) <= 0))
			GOTO exitproc

		IF ISNULL(@SystemType, 0) = 1
		BEGIN 
			SELECT 
				@OrderDate				= ord.[Date],
				@OrderNumber			= ord.Number,
				@OrderCustomerName		= ISNULL(cu.CustomerName, ''), 
				@OrderCurrencyVal		= 1,
				@OrderCurrencyCode		= ISNULL(my.Code, ''),
				@OrderBranchName		= ISNULL(br.[Name], ''),
				@OrderBranchLatinName	= ISNULL(br.LatinName, ''),
				@OrderTotal				= ord.SubTotal - ord.Discount + ord.Added
			FROM 
				RESTOrder000 ord
				LEFT JOIN cu000 cu ON cu.GUID = ord.CustomerID
				LEFT JOIN my000 my ON my.GUID = ord.CurrencyID
				LEFT JOIN br000 br ON br.GUID = ord.BranchID
			WHERE 
				ord.GUID = @OrderGUID	
		END ELSE BEGIN
			SELECT 
				@OrderDate			= ord.[Date],
				@OrderNumber		= ord.Number,
				@OrderCustomerName	= ISNULL(cu.CustomerName, ''), 
				@OrderCurrencyVal	= ord.CurrencyValue,
				@OrderCurrencyCode	= ISNULL(my.Code, ''),
				@OrderBranchName		= ISNULL(br.[Name], ''),
				@OrderBranchLatinName	= ISNULL(br.LatinName, ''),
				@OrderTotal				= ord.SubTotal - ord.Discount + ord.Added
			FROM 
				POSOrder000 ord
				LEFT JOIN cu000 cu ON cu.GUID = ord.CustomerID
				LEFT JOIN my000 my ON my.GUID = ord.CurrencyID
				LEFT JOIN br000 br ON br.GUID = ord.BranchID
			WHERE 
				ord.GUID = @OrderGUID	
		END
	END
	IF @State = 0
	BEGIN 
		IF ISNULL(@SystemType, 0) = 1
		BEGIN 
			UPDATE RESTOrder000 
			SET 
				LoyaltyCardGUID =		@ChargedLoyaltyCardGUID, 
				LoyaltyCardTypeGUID =	@ChargedLoyaltyCardTypeGUID, 
				PointsCount =			@ChargedPointsCount
			WHERE GUID = @OrderGUID

			SELECT TOP 1 
				@LoyaltyCardTypeGUID =	ord.LoyaltyCardTypeGUID,
				@LoyaltyCardGUID =		ord.LoyaltyCardGUID,
				@PointsCount =			ord.PointsCount,
				@OrderDate =			ord.[Closing],
				@OrderNumber =			ord.Number,
				@OrderCustomerName =	ISNULL(cu.CustomerName, ''), 
				@PointsValue =			ord.SubTotal - ord.Discount + ord.Added,
				@OrderCurrencyVal =		1,
				@OrderCurrencyCode =	ISNULL(my.Code, ''),
				@OrderBranchName =		ISNULL(br.[Name], ''),
				@OrderBranchLatinName = ISNULL(br.LatinName, ''),
				@OrderTotal =			ord.SubTotal - ord.Discount + ord.Added
			FROM 
				RESTOrder000 ord
				LEFT JOIN cu000 cu ON cu.GUID = ord.CustomerID
				LEFT JOIN my000 my ON my.GUID = ord.CurrencyID
				LEFT JOIN br000 br ON br.GUID = ord.BranchID
			WHERE 
				ord.GUID = @OrderGUID 
		END ELSE BEGIN
			UPDATE POSOrder000 
			SET 
				LoyaltyCardGUID =		@ChargedLoyaltyCardGUID, 
				LoyaltyCardTypeGUID =	@ChargedLoyaltyCardTypeGUID, 
				PointsCount =			@ChargedPointsCount
			WHERE GUID = @OrderGUID

			SELECT TOP 1 
				@LoyaltyCardTypeGUID =	ord.LoyaltyCardTypeGUID,
				@LoyaltyCardGUID =		ord.LoyaltyCardGUID,
				@PointsCount =			ord.PointsCount,
				@OrderDate =			ord.[Date],
				@OrderNumber =			ord.Number,
				@OrderCustomerName =	ISNULL(cu.CustomerName, ''), 
				@PointsValue =			ord.SubTotal - ord.Discount + ord.Added,
				@OrderCurrencyVal =		ord.CurrencyValue,
				@OrderCurrencyCode =	ISNULL(my.Code, ''),
				@OrderBranchName =		ISNULL(br.[Name], ''),
				@OrderBranchLatinName = ISNULL(br.LatinName, ''),
				@OrderTotal =			ord.SubTotal - ord.Discount + ord.Added
			FROM 
				POSOrder000 ord
				LEFT JOIN cu000 cu ON cu.GUID = ord.CustomerID
				LEFT JOIN my000 my ON my.GUID = ord.CurrencyID
				LEFT JOIN br000 br ON br.GUID = ord.BranchID
			WHERE 
				ord.GUID = @OrderGUID 
		END	
		IF ((ISNULL(@LoyaltyCardTypeGUID, 0x0) = 0x0) OR
			(ISNULL(@LoyaltyCardGUID, 0x0) = 0x0) OR
			(ISNULL(@PointsCount, 0) <= 0))
			GOTO exitproc
	END

	DECLARE @CentralizedDBName NVARCHAR(250)

	SELECT TOP 1
		@ErrorNumber =			ISNULL(ErrorNumber, 0),
		@CentralizedDBName =	ISNULL(CentralizedDBName, '')
	FROM 
		dbo.fnPOS_LoyaltyCards_CheckSystem (@LoyaltyCardTypeGUID)

	IF @ErrorNumber > 0 
		GOTO exitproc

	DECLARE 
		@DBName			NVARCHAR(500),
		@UserName		NVARCHAR(500),
		@ComputerName	NVARCHAR(500)
	
	SET @UserName =		[dbo].[fnGetCurrentUserName]()
	SET @ComputerName =	HOST_NAME()
	SET @DBName =		DB_NAME()
	
	DECLARE @CmdText NVARCHAR(MAX)

	SET @CmdText = 
		'EXEC '  + @CentralizedDBName + 'prcPOS_LoyaltyCards_LOC_AddTransaction 
			@OrderGUID, @OrderDate, @OrderNumber, @OrderCustomerName, @PointsCount, 
			@OrderTotal, @OrderCurrencyVal, @OrderCurrencyCode, @LoyaltyCardGUID, @State, 
			@DBName, @UserName, @ComputerName, @PointsValue, @BranchName, @BranchLatinName, @SystemType ' 

	EXEC sp_executesql @CmdText, 
		N'@OrderGUID		UNIQUEIDENTIFIER,
		@OrderDate			DATETIME,
		@OrderNumber		BIGINT,
		@OrderCustomerName	NVARCHAR(250),
		@PointsCount		INT,	
		@OrderTotal			FLOAT,
		@OrderCurrencyVal	FLOAT,
		@OrderCurrencyCode	NVARCHAR(250),
		@LoyaltyCardGUID	UNIQUEIDENTIFIER,
		@State				TINYINT,
		@DBName				NVARCHAR(250),
		@UserName			NVARCHAR(500),
		@ComputerName		NVARCHAR(500),
		@PointsValue		FLOAT,
		@BranchName			NVARCHAR(500),
		@BranchLatinName	NVARCHAR(500),	
		@SystemType			TINYINT', 
		@OrderGUID, @OrderDate, @OrderNumber, @OrderCustomerName, @PointsCount, @OrderTotal, @OrderCurrencyVal, @OrderCurrencyCode, 
		@LoyaltyCardGUID, @State, @DBName, @UserName, @ComputerName, @PointsValue, @OrderBranchName, @OrderBranchLatinName, @SystemType

	exitProc:
		SELECT @ErrorNumber AS ErrorNumber
##################################################################
#END
