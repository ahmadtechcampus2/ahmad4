################################################################################
CREATE PROCEDURE prcPOSGenerateReturnVoucherEntry
	@orderGuid [UNIQUEIDENTIFIER],
    @BillsID  [UNIQUEIDENTIFIER],
	@currencyGuid [UNIQUEIDENTIFIER],
	@currencyValue [FLOAT]
	
AS
	SET NOCOUNT ON
	DECLARE	@salesBillTypeID [UNIQUEIDENTIFIER],
			@salesBillID [UNIQUEIDENTIFIER],
			@salesBillNumber [FLOAT],
			@salesBillTypeAbbrev [NVARCHAR](100),
			@salesBillTypeLatinAbbrev [NVARCHAR](100),
			@returnVoucherType [UNIQUEIDENTIFIER],
			@returnVoucherTypeName [NVARCHAR](255),
			@returnVoucherNumber[NVARCHAR](100),
			@mediatorAccountID [UNIQUEIDENTIFIER],
			@returnVoucherID [UNIQUEIDENTIFIER],
			@returnVoucherValue [FLOAT],
			@ceGuid [UNIQUEIDENTIFIER],
			@ceNumber [FLOAT],
			@ceNote [NVARCHAR](250),
			@enNote [NVARCHAR] (250),
			@orderNumber [FLOAT],
			@orderType [INT],
            @orderDate [DATETIME],
			@orderPaymentsPackageID [UNIQUEIDENTIFIER],
			@orderBranchID [UNIQUEIDENTIFIER],
			@UserID [UNIQUEIDENTIFIER],
			@EnID [UNIQUEIDENTIFIER],
			@language [INT],
			@mediatorCustomerID [UNIQUEIDENTIFIER]

	SET @language = [dbo].[fnConnections_GetLanguage]()		
	SELECT
		@salesBillID =		[GUID],
		@salesBillNumber =	[Number],
		@salesBillTypeID =	[TypeGUID]
	FROM [BU000]
	WHERE [Guid] = (SELECT TOP 1 [BillGUID]
					FROM [BillRel000]
					WHERE [ParentGuid] = @orderGuid
					AND 
					[Type] = 1)
	IF @@ROWCOUNT <> 1
		RETURN 0
	SELECT @orderNumber = [Number],
           @orderType = [Type],
           @orderDate = [Date],
           @orderPaymentsPackageID = ISNULL([PaymentsPackageID], 0x0),
           @orderBranchID = ISNULL([BranchID], 0x0),
		   @UserID = CashierID,
		   @mediatorCustomerID = ISNULL(CustomerID, 0x0),
		   @mediatorAccountID = ISNULL(DeferredAccountID, 0x0)
	FROM [POSOrder000]
	WHERE [Guid] = @orderGuid
	IF @@ROWCOUNT <> 1
		RETURN 0

	IF (@mediatorCustomerID = 0x0)
	BEGIN
		SELECT @mediatorCustomerID = CAST([value] AS [UNIQUEIDENTIFIER]), @mediatorAccountID = [cu].[AccountGUID] 
		FROM UserOp000 INNER JOIN [cu000] [cu] ON [cu].[GUID] = [value]
		WHERE [UserID] = @UserID AND [Name] = 'AmnPOS_MediatorCustID'
	END

	SELECT @returnVoucherType = CAST([value] AS [UNIQUEIDENTIFIER]) 
	  FROM UserOp000 
	 WHERE [UserID] = @UserID AND [Name] = 'AmnPOS_ReturnVoucherType'
	--SELECT @salesBillTypeID = SalesID
	--FROM posuserbills000
	--WHERE [Guid] = @BillsID
			
	IF @@ROWCOUNT <> 1
		RETURN 0
	SELECT @salesBillTypeAbbrev = ISNULL([Abbrev], ''), 
	       @salesBillTypeLatinAbbrev = ISNULL([LatinAbbrev], '')
    FROM BT000
    WHERE [Guid] = @salesBillTypeID
			
	IF @@ROWCOUNT <> 1
		RETURN 0
		
	IF ((@language <> 0) AND (LEN(@salesBillTypeLatinAbbrev) <> 0))
		SET @ceNote = @salesBillTypeLatinAbbrev
	ELSE
		SET @ceNote = @salesBillTypeAbbrev
	
	Set @ceNote =  @ceNote + ' [' + CAST(@salesBillNumber AS NVARCHAR(250)) + ']'

	
	SELECT	@returnVoucherID = ISNULL([ReturnVoucherID], 0x0),
		@returnVoucherValue = ISNULL([ReturnVoucherValue], 0)
	FROM [POSPaymentsPackage000]
	WHERE [Guid] = @orderPaymentsPackageID
	IF @@ROWCOUNT <> 1
		RETURN 0
	IF (@returnVoucherID <> 0x0) AND (@returnVoucherValue > 0)
	BEGIN
		DECLARE		@debitAccount UNIQUEIDENTIFIER
		SELECT @debitAccount = ISNULL([DefPayAccGuid], 0x0),
		@returnVoucherTypeName = ISNULL(CASE @language WHEN 0 THEN [Name] ELSE (CASE LatinName WHEN '' THEN [Name] ELSE LatinName END) END, '')
		FROM [NT000]
		WHERE [Guid] = @returnVoucherType

		SELECT @returnVoucherNumber = NUM 
		FROM CH000
		WHERE [Guid] = @returnVoucherID
		
		SET @ceGuid = NEWID()
		SELECT @ceNumber = MAX(ISNULL([Number], 0)) + 1
		FROM [CE000]
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
					@returnVoucherValue, --Debit
					@returnVoucherValue, --Credit
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
					@returnVoucherType,
					@orderDate) --TypeGUID
		
		SELECT @enNote = [dbo].[fnStrings_get]('POS\CHECK', @language)
		SET @enNote = @enNote + ' ' + @returnVoucherTypeName + ':' + @returnVoucherNumber
		SET @EnID = newID()
		INSERT INTO en000 ([Number]
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
		VALUES(   1, --Number
						@orderDate, --Date
						@returnVoucherValue, --Debit
						0, --Credit
						@enNote,--Notes
						--'Return Voucher', --Notes
						@currencyValue, --CurrencyVal
						'', --Class
						0, --Num1
						0, --Num2
						0, --Vendor
						0, --SalesMan
						@EnID,
						@ceGuid, --ParentGUID
						@debitAccount, --AccountGUID
						@currencyGuid, --CurrencyGUID
						0x0, --CostGUID
						@mediatorAccountID, --ContraAccGUID
						0x0) --CustomerGUID
						
SET @EnID = newID()
		INSERT INTO en000 ([Number]
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
		 VALUES(   2, --Number
						@orderDate, --Date
						0, --Debit
						@returnVoucherValue, --Credit
						@enNote,--Notes
						@currencyValue, --CurrencyVal
						'', --Class
						0, --Num1
						0, --Num2
						0, --Vendor
						0, --SalesMan
						@EnID,
						@ceGuid, --ParentGUID
						@mediatorAccountID, --AccountGUID
						@currencyGuid, --CurrencyGUID
						0x0, --CostGUID
						@debitAccount, --ContraAccGUID
						@mediatorCustomerID) --CustomerGUID 
		INSERT INTO POSPaymentLink000 VALUES(@EnID, @orderGuid,3,newID())
		UPDATE [CE000]
		SET [IsPosted] = 1
		WHERE [Guid] = @ceGuid
		INSERT INTO [er000]
				   ([GUID]
				   ,[EntryGUID]
				   ,[ParentGUID]
				   ,[ParentType]
				   ,[ParentNumber])
			 VALUES(NEWID(), --GUID
				   @ceGuid, --EntryGUID
				   @returnVoucherID, --ParentGUID
				   6, --ParentType
				   0) --ParentNumber
		UPDATE [CH000]
		SET [State] = 1
		WHERE [Guid] = @returnVoucherID
		  EXEC prcCheque_History_Add @returnVoucherID, @orderDate, 1, 0, @ceGuid, @debitAccount, @mediatorAccountID, 
			    @returnVoucherValue,
			    5, @currencyGuid, @currencyValue, 0x0 , 0.0 , 0x0, 0x0, 0x0, @mediatorCustomerID
	END
	RETURN 1
################################################################################
#END
