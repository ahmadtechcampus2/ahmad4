################################################################################
CREATE PROCEDURE prcPOSGenerateDeferredEntry
	@orderGuid [UNIQUEIDENTIFIER],
    @BillsID  [UNIQUEIDENTIFIER],
	@currencyGuid [UNIQUEIDENTIFIER],
	@currencyValue [FLOAT],
	@OrderType [INT] -- 1 Sales 2 Returned	
AS
	SET NOCOUNT ON

	DECLARE	@salesBillTypeID [UNIQUEIDENTIFIER],
			@salesBillID [UNIQUEIDENTIFIER],
			@salesBillNumber [FLOAT],
			@salesBillTypeAbbrev [NVARCHAR](100),
			@salesBillTypeLatinAbbrev [NVARCHAR](100),
			@mediatorAccountID [UNIQUEIDENTIFIER],
			@deferredAccountID [UNIQUEIDENTIFIER],
			@deferredAmount [FLOAT],
			@ceGuid [UNIQUEIDENTIFIER],
			@ceNumber [FLOAT],
			@ceNote [NVARCHAR](250),

			@orderNumber [FLOAT],
			@orderDate [DATETIME],
			@orderPaymentsPackageID [UNIQUEIDENTIFIER],
			@orderBranchID [UNIQUEIDENTIFIER],
			@UserID [UNIQUEIDENTIFIER],
			@EnID [UNIQUEIDENTIFIER],
			@language [INT],
			@deferredCustomerID [UNIQUEIDENTIFIER],
			@mediatorCustomerID [UNIQUEIDENTIFIER]
			
	SET @language = [dbo].[fnConnections_GetLanguage]()		

	SELECT @orderNumber = [Number],
           @orderDate = [Date],
           @orderPaymentsPackageID = ISNULL([PaymentsPackageID], 0x0),
           @orderBranchID = ISNULL([BranchID], 0x0),
		   @UserID = CashierID
	  FROM [POSOrder000]
	 WHERE [Guid] = @orderGuid

	IF @@ROWCOUNT <> 1
		RETURN -300010

	SELECT @mediatorCustomerID = CAST([value] AS [UNIQUEIDENTIFIER]), @mediatorAccountID = [cu].[AccountGUID] 
	  FROM [UserOp000] INNER JOIN [cu000] [cu] ON [cu].[GUID] = [value] 
	 WHERE [UserID] = @UserID AND Name='AmnPOS_MediatorCustID'

	SELECT @salesBillTypeID = CASE WHEN @OrderType=1 THEN SalesID ELSE ReturnedID END
	  FROM posuserbills000
	 WHERE [Guid] = @BillsID
			
	IF @@ROWCOUNT <> 1
		RETURN -300011

	SELECT @salesBillTypeAbbrev = ISNULL([Abbrev], ''), 
	       @salesBillTypeLatinAbbrev = ISNULL([LatinAbbrev], '')
    FROM BT000
    WHERE [Guid] = @salesBillTypeID
			
	IF @@ROWCOUNT <> 1
		RETURN -300012
		
	IF ((@language <> 0) AND (LEN(@salesBillTypeLatinAbbrev) <> 0))
		SET @ceNote = @salesBillTypeLatinAbbrev
	ELSE
		SET @ceNote = @salesBillTypeAbbrev
	
	Set @ceNote =  @ceNote + ' [' + CAST(@salesBillNumber AS NVARCHAR(250)) + ']'
	
	SELECT	@deferredAmount = ABS(ISNULL([DeferredAmount], 0)),
			@deferredCustomerID = ISNULL(DeferredAccount, 0x0),
			@deferredAccountID = ISNULL([cu].[AccountGUID], 0x0)
	FROM [POSPaymentsPackage000] [pos] INNER JOIN [cu000] [cu] ON [cu].[GUID] = [pos].[DeferredAccount]
	WHERE [pos].[Guid] = @orderPaymentsPackageID

	IF @@ROWCOUNT <> 1 or @deferredAccountID = 0x0
		RETURN -300013

	IF (@deferredAmount <> 1) AND (@deferredAmount > 0)
	BEGIN
		SET @ceGuid = NEWID()
		SELECT @ceNumber = MAX(ISNULL([Number], 0)) + 1
		FROM CE000

		INSERT INTO [CE000]
				   ([Type]
				   ,[Number]
				   ,[Date]
				   ,[Debit]
				   ,[Credit]
				   ,[Notes]
				   ,[CurrencyVal]
				   ,[IsPosted]
				   ,[State]
				   ,[Security]
				   ,[Num1]
				   ,[Num2]
				   ,[Branch]
				   ,[GUID]
				   ,[CurrencyGUID]
				   ,[TypeGUID], 
					[PostDate])  
			 VALUES(1,--Type
					@ceNumber,--Number
					@orderDate,--Date
					@deferredAmount, --Debit
					@deferredAmount, --Credit
					@ceNote,--Notes
					@currencyValue,--CurrencyVal
					0,--IsPosted
					0,--State
					1,--Security
					0,--Num1
					0,--Num2
					@orderBranchID,--Branch
					@ceGuid,--GUID
					@currencyGuid,--CurrencyGUID
					0x0, --TypeGUID  
					@orderDate) 
		
		INSERT INTO en000  
		([Number]
           ,[Date]
           ,[Debit]
           ,[Credit]
           ,[Notes]
           ,[CurrencyVal]
           ,[Class]
           ,[Num1]
           ,[Num2]
           ,[Vendor]
           ,[SalesMan]
           ,[GUID]
           ,[ParentGUID]
           ,[AccountGUID]
           ,[CurrencyGUID]
           ,[CostGUID]
           ,[ContraAccGUID]
		   ,[CustomerGUID])
		VALUES (1, --Number
						@orderDate, --Date
						@deferredAmount, --Debit
						0, --Credit
						'Deferred', --Notes
						@currencyValue, --CurrencyVal
						'', --Class
						0, --Num1
						0, --Num2
						0, --Vendor
						0, --SalesMan
						newid(),
						@ceGuid, --ParentGUID
						CASE WHEN @OrderType=1 THEN @deferredAccountID ELSE @mediatorAccountID END, --AccountGUID
						@currencyGuid, --CurrencyGUID
						0x0, --CostGUID
						CASE WHEN @OrderType=1 THEN @mediatorAccountID ELSE @deferredAccountID END, --ContraAccGUID)
						CASE WHEN @OrderType=1 THEN @deferredCustomerID ELSE @mediatorCustomerID END) --CustomerGUID
		SET @EnID = newID()
		INSERT INTO en000  (
			[Number]
           ,[Date]
           ,[Debit]
           ,[Credit]
           ,[Notes]
           ,[CurrencyVal]
           ,[Class]
           ,[Num1]
           ,[Num2]
           ,[Vendor]
           ,[SalesMan]
           ,[GUID]
           ,[ParentGUID]
           ,[AccountGUID]
           ,[CurrencyGUID]
           ,[CostGUID]
           ,[ContraAccGUID]
		   ,[CustomerGUID])
	
		VALUES ( 2, --Number
						@orderDate, --Date
						0, --Debit
						@deferredAmount, --Credit
						'Deferred', --Notes
						@currencyValue, --CurrencyVal
						'', --Class
						0, --Num1
						0, --Num2
						0, --Vendor
						0, --SalesMan
						@EnID,
						@ceGuid, --ParentGUID
						CASE WHEN @OrderType=1 THEN @mediatorAccountID ELSE @deferredAccountID END, --AccountGUID
						@currencyGuid, --CurrencyGUID
						0x0, --CostGUID
						CASE WHEN @OrderType=1 THEN @deferredAccountID ELSE @mediatorAccountID END, --ContraAccGUID)
						CASE WHEN @OrderType=1 THEN @mediatorCustomerID ELSE @deferredCustomerID END) --CustomerGUID 
		INSERT INTO POSPaymentLink000 VALUES(@EnID, @orderGuid,1,newID())

		UPDATE [CE000]
		SET [IsPosted] = 1
		WHERE [Guid] = @ceGuid							
		RETURN 1
	END

	RETURN -300014
################################################################################
#END
