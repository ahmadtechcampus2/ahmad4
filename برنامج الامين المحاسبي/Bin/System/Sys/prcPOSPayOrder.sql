################################################################################
CREATE PROCEDURE prcPOSPayOrder
	@orderGuid [UNIQUEIDENTIFIER],
	@orderPaymentsPackageID [UNIQUEIDENTIFIER],
	@BillsID  [UNIQUEIDENTIFIER],
	@PaidType [INT],
	@OrderType [INT] -- 1 Sales 2 Returned
AS
	SET NOCOUNT ON

	DECLARE	
		@currencyID [UNIQUEIDENTIFIER],
		@currencyValue [FLOAT],
		@AccountID [UNIQUEIDENTIFIER],
		@CashierID [UNIQUEIDENTIFIER],
		@deferredAccount [UNIQUEIDENTIFIER],
		@CustomerAccount [UNIQUEIDENTIFIER],			
		@done [BIT]

	SELECT 
		@CustomerAccount = ISNULL(DeferredAccountID, 0x0),
		@CashierID = ISNULL(CashierID, 0x0)
	FROM  
		POSOrder000 
	WHERE GUID = @orderGuid

DECLARE @AccountBalance FLOAT = ISNULL((SELECT MaxDebit  FROM ac000 Where Guid =@CustomerAccount), 0)

SELECT TOP 1 @currencyID= ISNULL([Value], 0x0) FROM FileOP000 
    WHERE [Name] = 'AmnPOS_DefaultCurrencyID'

	IF ISNULL(@currencyID,0X0) = 0X0
	BEGIN
		SELECT TOP 1 @currencyID = ISNULL([Value], 0x0) 
		FROM [OP000] WHERE [Name] = 'AmnCfg_DefaultCurrency'

		SELECT @currencyValue = ISNULL([CurrencyVal], 0) 
		FROM [MY000] WHERE [Guid] = @currencyID
	END

	ELSE
		SET @currencyValue = dbo.fnGetCurVal(@currencyID,GetDate())	
SET @done = -1
IF @PaidType = 1
BEGIN
	DECLARE @salesBillTypeID [UNIQUEIDENTIFIER]

	SELECT	@currencyID = ISNULL([pay].[CurrencyID], @currencyID), 
			@currencyValue = ISNULL([pay].[Equal], @currencyValue)
    FROM [POSPaymentsPackageCurrency000] [pay]
	INNER JOIN POSOrder000 [order] ON [Pay].[ParentID] = [order].[PaymentsPackageID] 
    WHERE	[ParentID] = @orderPaymentsPackageID AND Paid<>0
	
		SELECT @AccountID = CashAccID
		FROM 
			POSCurrencyItem000 ci
			INNER JOIN my000 my ON my.GUID = ci.CurID
		WHERE 
			my.GUID = @currencyID AND UserID = @CashierID
	
		IF ISNULL(@AccountID, 0x0) = 0x0
		BEGIN
			SELECT @salesBillTypeID = [SalesID]
			FROM posuserbills000
			WHERE [Guid] = @BillsID
			
			SELECT @AccountID = [dbo].fnGetDAcc([DefCashAccGUID])
			FROM [BT000]
			WHERE [Guid] = @salesBillTypeID	
		END
		
		EXEC @done = prcPOSGenerateBills @orderGuid, @BillsID, 0, @AccountID, 0x0, @currencyID, @currencyValue, 0x0
	END
	
	IF @PaidType = 2
	BEGIN
		DECLARE @deferredCustomer [UNIQUEIDENTIFIER]

		SELECT 
			@deferredCustomer = ISNULL([DeferredAccount], 0x0), 
			@deferredAccount = [cu].[AccountGUID]
		FROM 
			[POSPaymentsPackage000] [pos] 
			INNER JOIN [cu000] [cu] ON [cu].[GUID] = [DeferredAccount]
		WHERE [pos].[Guid] = @orderPaymentsPackageID
			
		EXEC @done = prcPOSGenerateBills @orderGuid, @BillsID, 1, @deferredAccount, 0x0, @currencyID, @currencyValue, @deferredCustomer
	END
	
	IF @PaidType = 3
	BEGIN
		 EXEC @done = prcPOSMultiPayments @orderGuid, @BillsID, @OrderType
	END

	RETURN @done
################################################################################
CREATE PROC prcGetStateBalanceDiscoutCard
	@OrderValue FLOAT,
	@DiscountCardID UNIQUEIDENTIFIER
	--0 PASSED
	--1 BALANCE NOT ENOUGH AND CAN Cach
	--2 NO BALANCE
	--3 DAILY BALANCE FINISHED
	--4 DAILY BALANCE NOT ENOUGH
	--5 BALANCE NOT ENOUGH AND CAN'T Cach
AS
	DECLARE @POSCurrencyID UNIQUEIDENTIFIER,
			@currencyValue FLOAT
	SET @currencyValue = 1

	SELECT TOP 1 @POSCurrencyID = ISNULL([Value], 0x0)
	FROM FileOP000 
    WHERE [Name] = 'AmnPOS_DefaultCurrencyID'

	IF(@POSCurrencyID = 0x0)
		BEGIN 
			SELECT TOP 1 @POSCurrencyID = [GUID] 
			FROM [MY000] 
			WHERE CurrencyVal = @currencyValue
		END
	ELSE
		SET @currencyValue = dbo.fnGetCurVal(@POSCurrencyID,GetDate())	
	IF ISNULL(@currencyValue, 0) = 0
		SET @currencyValue = 1

	DECLARE 
		@Balance		FLOAT = 0,
		@DailyBalance	FLOAT = 0,
		@DailyPackage	FLOAT = 0,
		@StateCard		TINYINT = 0,
		@IsCashPay		BIT = 1

	SELECT 
		@IsCashPay = ISNULL((CASE dt.DailyPackage WHEN 0 THEN 1 ELSE 0 END), 1)
	FROM 
		DiscountTypesCard000 dt
		INNER JOIN DiscountCard000 dc ON dt.[GUID] = dc.[Type] 
	WHERE dc.[Guid] = @DiscountCardID 

	SELECT @Balance =  ISNULL (SUM([en].[Credit] - [en].[Debit]), 0) / @currencyValue
	FROM 
		[ac000] [ac] 
		INNER JOIN [cu000] [cu] ON [ac].[GUID] = [cu].[AccountGUID] 
		INNER JOIN [en000] [en] ON [ac].[GUID] = [en].[AccountGUID] 
		INNER JOIN [ce000] [ce] ON [ce].[GUID] = [en].[ParentGUID]
		INNER JOIN DiscountCard000 dc ON dc.CustomerGuid = CU.[GUID]
	WHERE ([ce].[IsPosted] = 1)  AND dc.[GUID] = @DiscountCardID 
	
	DECLARE @CustomerGUID UNIQUEIDENTIFIER
	SELECT TOP 1 @CustomerGUID = CustomerGUID FROM DiscountCard000 WHERE [GUID] = @DiscountCardID 

	SET @Balance = @Balance - (dbo.fnPOS_GetCustomerDeferredAmount(@CustomerGUID, DEFAULT) / @currencyValue)

	IF (@Balance <= 0)
	BEGIN
		SET @StateCard = 2
		GOTO EndProc
	END 

	IF (@Balance < @OrderValue AND @IsCashPay = 1)
	BEGIN
		SET @StateCard = 1 
		GOTO EndProc
	END 

	IF (@IsCashPay = 0)
	BEGIN
		SELECT 
			@DailyPackage = dt.DailyPackage 
		FROM 
			DiscountTypesCard000 dt
			INNER JOIN DiscountCard000 dc ON dc.[Type] = dt.[Guid]
		WHERE dc.[Guid] = @DiscountCardID  
				 
		SELECT 
			@DailyBalance = ISNULL( SUM([en].[Debit]), 0) / @currencyValue
		FROM 
			[ac000] [ac] 
			INNER JOIN [cu000] [cu] on [ac].[GUID] = [cu].[AccountGUID] 
			INNER JOIN [en000] [en] on [ac].[GUID] = [en].[AccountGUID] 
			INNER JOIN [ce000] [ce] on [ce].[GUID] = [en].[ParentGUID] 
			INNER JOIN DiscountCard000 dc ON dc.CustomerGuid = cu.[GUID]
		WHERE 
			([ce].[IsPosted] = 1) AND dc.[Guid] = @DiscountCardID
			AND 
			CONVERT(DATE, ce.[Date]) = CONVERT(DATE, GETDATE()) 

		SET @DailyBalance = @DailyBalance -( dbo.fnPOS_GetCustomerDeferredAmount(@CustomerGUID, 1) / @currencyValue)
		IF @DailyBalance = @DailyPackage
		BEGIN 
			SET @StateCard = 3
			GOTO EndProc
		END 

		IF (@DailyBalance + @OrderValue > @DailyPackage)
		BEGIN 
			SET @StateCard = 4
			GOTO EndProc
		END 
		
		IF (@Balance < @OrderValue)
		BEGIN 
			SET @StateCard = 5
			GOTO EndProc
		END 
	END

	EndProc:
		SELECT @StateCard AS [State], @Balance AS Balance, @DailyPackage - @DailyBalance AS DailyBalance
################################################################################
#END