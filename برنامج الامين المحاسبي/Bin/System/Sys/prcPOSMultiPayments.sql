################################################################################
CREATE PROCEDURE prcPOSMultiPayments
	@orderGUID		[UNIQUEIDENTIFIER],
    @BillsID		[UNIQUEIDENTIFIER],
	@OrderType		[INT]
AS
	SET NOCOUNT ON

	DECLARE	
		@currencyID				[UNIQUEIDENTIFIER],
		@currencyValue			[FLOAT],
		@mediatorAccountID		[UNIQUEIDENTIFIER],
		@orderPaymentsPackageID	[UNIQUEIDENTIFIER],
		@result					[BIT],
		@UserID					[UNIQUEIDENTIFIER],
		@mediatorCustomerID		[UNIQUEIDENTIFIER]
  
	SELECT TOP 1 @currencyID = ISNULL([Value], 0x0) 
	FROM FileOP000
	WHERE [Name] = 'AmnPOS_DefaultCurrencyID'
	
	IF ISNULL(@currencyID, 0x0) = 0X0
	BEGIN
		SELECT TOP 1 @currencyID = [Value] 
		FROM [op000] 
		WHERE [Name] = 'AmnCfg_DefaultCurrency'
		IF @@ROWCOUNT <> 1
			RETURN -200101

		SELECT @currencyValue = [CurrencyVal] 
		FROM [my000] 
		WHERE [Guid] = @currencyID
	END
	ELSE 
		SET @currencyValue = dbo.fnGetCurVal(@currencyID, GetDate())	
	
	SELECT 
		@orderPaymentsPackageID =	ISNULL([PaymentsPackageID], 0x0),
		@UserID =					CashierID,
		@mediatorCustomerID =		ISNULL(CustomerID, 0x0),
		@mediatorAccountID =		ISNULL(DeferredAccountID, 0x0)
	FROM [POSOrder000]
	WHERE [Guid] = @orderGuid

	IF (@mediatorCustomerID = 0x0)
	BEGIN
		SELECT 
			@mediatorCustomerID = CAST([value] AS [UNIQUEIDENTIFIER]), 
			@mediatorAccountID = [cu].[AccountGUID] 
		FROM 
			UserOp000 
			INNER JOIN [cu000] [cu] ON [cu].[GUID] = [value]
		WHERE [UserID] = @UserID AND [Name] = 'AmnPOS_MediatorCustID'
	END

	SET @result = 0
	
	EXECUTE @result = prcPOSGenerateBills @orderGuid, @BillsID, 1, @mediatorAccountID, 0x0, @currencyID, @currencyValue, @mediatorCustomerID

	
	IF @result <> 0
	BEGIN
		SET @result = 0
		
		--Generate Currencies Entry
		DECLARE	@currenciesDebit [FLOAT],
				@deferredAmount [FLOAT],
				@checksPaid [FLOAT],
				@returnVoucherValue [FLOAT],
				@PointsValue [FLOAT],
				@currenciesAndPointsResult [INT],
				@deferredResult [INT],
				@checksResult [INT],
				@returnVoucherResult [INT],
				@PointsResult [INT],
				@calcPayment [INT]
			
		SET @currenciesDebit = 0
		SET @deferredAmount = 0
		SET @checksPaid = 0
		SET @returnVoucherValue = 0
		SET @PointsValue = 0
		SET	@currenciesAndPointsResult = 1
		SET	@deferredResult  = 1
		SET	@checksResult = 1
		SET	@returnVoucherResult = 1
				
		SELECT	@returnVoucherValue = ISNULL([ReturnVoucherValue], 0),
				@deferredAmount = ABS(ISNULL([DeferredAmount], 0))
		FROM [POSPaymentsPackage000]
		WHERE [Guid] = @orderPaymentsPackageID

		SELECT	@currenciesDebit = Sum(ABS(ISNULL([Paid], 0)) - ABS(ISNULL([Returned], 0)))
		FROM [POSPaymentsPackageCurrency000]
		WHERE [ParentID] = @orderPaymentsPackageID
		
		SELECT @checksPaid = SUM(ABS(ISNULL([Paid], 0)))
			FROM [POSPaymentsPackageCheck000]
		WHERE [ParentID] = @orderPaymentsPackageID		

		SELECT @PointsValue = ISNULL(PointsValue, 0) 
			FROM [POSPaymentsPackagePoints000]
		WHERE [ParentGUID] = @orderPaymentsPackageID	

		IF @currenciesDebit <> 0 OR @PointsValue <> 0
		BEGIN
			EXECUTE @currenciesAndPointsResult = prcPOSGenerateCurrenciesEntry @orderGuid, @BillsID, @currencyID, @currencyValue, @OrderType
		END
		
		--Generate Checks
		IF @checksPaid <> 0
		BEGIN
			EXECUTE @checksResult = prcPOSGenerateChecks @orderGuid, @BillsID, @currencyID, @currencyValue, @OrderType
		END

		--Generate Return Voucher Entry
		IF @returnVoucherValue <> 0
		BEGIN
			EXECUTE @returnVoucherResult = prcPOSGenerateReturnVoucherEntry @orderGuid, @BillsID, @currencyID, @currencyValue
		END
		
		EXECUTE @calcPayment = prcPOSLinkPayments @orderGuid
		
		SET	@result = @calcPayment + @currenciesAndPointsResult + @deferredResult + @checksResult + @returnVoucherResult
	END
	
	RETURN @result
################################################################################
#END