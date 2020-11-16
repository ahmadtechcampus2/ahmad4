################################################################################
CREATE PROCEDURE prcPOSGenerateCurrenciesEntry
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
			@ceGuid [UNIQUEIDENTIFIER], 
			@ceNumber [FLOAT], 
			@ceDebit [FLOAT], 
			@ceNote [NVARCHAR](250), 
			@orderNumber [FLOAT], 
			@orderDate [DATETIME], 
			@orderPaymentsPackageID [UNIQUEIDENTIFIER], 
			@orderBranchID [UNIQUEIDENTIFIER], 
			@language [INT],
			@EnID [UNIQUEIDENTIFIER],
			@payment [FLOAT],
			@UserNumber [FLOAT],
			@orderCashierID [UNIQUEIDENTIFIER],
			@mediatorCustomerID [UNIQUEIDENTIFIER],
			@cashAccountCusomterId [UNIQUEIDENTIFIER],
			@cashAccountID [UNIQUEIDENTIFIER],
			@pointsValue [FLOAT],
			@pointsAccountID [UNIQUEIDENTIFIER]
			 
	SET @language = [dbo].[fnConnections_GetLanguage]()		 
	SELECT	@salesBillID = [Guid], 
			@salesBillNumber = [Number] 
	FROM [BU000] 
	WHERE [Guid] = (SELECT [BillGUID]
					FROM [BillRel000] 
					WHERE [ParentGuid] = @orderGuid 
					AND  
					((@OrderType=1 AND [Type] = 1) OR (@OrderType=2 AND [Type] <> 1))) 
	IF @@ROWCOUNT < 1 
		RETURN -400011 
	
	SELECT @orderNumber = [Number], 
	          @orderDate = [Date], 
	          @orderPaymentsPackageID = ISNULL([PaymentsPackageID], 0x0), 
		   @orderCashierID = ISNULL([CashierID], 0x0),
	          @orderBranchID = ISNULL([BranchID], 0x0),
		   @mediatorCustomerID = ISNULL(CustomerID, 0x0),
		   @mediatorAccountID = ISNULL(DeferredAccountID, 0x0)
	FROM [POSOrder000] 
	WHERE [Guid] = @orderGuid 
	
	IF @@ROWCOUNT < 1 
		RETURN -400012
	SELECT @UserNumber = number FROM us000 WHERE GUID=@orderCashierID
	
	IF (@mediatorCustomerID = 0x0)
	BEGIN
		SELECT @mediatorCustomerID = CAST([value] AS [UNIQUEIDENTIFIER]), @mediatorAccountID = [cu].[AccountGUID] 
		FROM UserOp000 INNER JOIN [cu000] [cu] ON [cu].[GUID] = [value]
		WHERE [UserID] = @orderCashierID AND [Name] = 'AmnPOS_MediatorCustID'
	END
	
	SELECT @salesBillTypeID = CASE WHEN @OrderType=1 THEN SalesID ELSE ReturnedID END
	FROM posuserbills000
	WHERE [Guid] = @BillsID
			 
	IF @@ROWCOUNT <> 1 
		RETURN  -400013
	
	SELECT @salesBillTypeAbbrev = ISNULL([Abbrev], ''),  
	       @salesBillTypeLatinAbbrev = ISNULL([LatinAbbrev], '') 
	   FROM BT000 
	   WHERE [Guid] = @salesBillTypeID 
			 
	IF @@ROWCOUNT <> 1 
		RETURN -400014 
		 
	IF ((@language <> 0) AND (LEN(@salesBillTypeLatinAbbrev) <> 0)) 
		SET @ceNote = @salesBillTypeLatinAbbrev 
	ELSE 
		SET @ceNote = @salesBillTypeAbbrev 
	 
	Set @ceNote =  @ceNote + ' [' + CAST(@salesBillNumber AS NVARCHAR(250)) + ']' 
	
	SET @ceGuid = NEWID() 
	SELECT @ceNumber = MAX(ISNULL([Number], 0)) + 1 
	FROM [CE000] 
	 
	SET @ceDebit = 0 
	SELECT	@ceDebit = Sum(ABS(ISNULL([Paid], 0)) - ABS(ISNULL([Returned], 0))) 
	FROM [POSPaymentsPackageCurrency000] 
	WHERE [ParentID] = @orderPaymentsPackageID 
	
	SET @pointsValue = 0 
	SELECT	@pointsValue = ISNULL(PointsValue, 0) ,
			@pointsAccountID = pp.AccountGUID
	FROM  [POSPaymentsPackagePoints000] pp
	WHERE [ParentGUID] = @orderPaymentsPackageID 
	 
	IF @ceDebit = 0 AND @pointsValue = 0 
		RETURN 0
	
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
				@ceDebit + @pointsValue, --Debit 
				@ceDebit + @pointsValue, --Credit 
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
	 
	DECLARE @enNumber int 
	DECLARE @Type INT
	DECLARE @enPaid float 
	DECLARE @enReturned float 
	DECLARE @enCurrencyVal float 
	DECLARE @enCurrencyGUID uniqueidentifier 
	SET @enNumber = 0 
	
	SELECT
		my.Number AS [Number],
		1 AS [Type], 
		ABS(ISNULL(cur.[Paid], 0) * ISNULL(cur.[Equal], 0)) AS [Paid], 
		ABS(ISNULL(cur.[Returned], 0) * ISNULL(cur.[Equal], 0))AS [Returned], 
		ISNULL(cur.[Equal], 0) AS [CurrencyValue], 
		ISNULL(cur.[CurrencyID], 0x0) AS [CurrencyGuid] 
	INTO #EN
	FROM [POSPaymentsPackageCurrency000] cur
		INNER JOIN my000 my ON my.[GUID] = cur.CurrencyID 
	WHERE ParentID = @orderPaymentsPackageID
	ORDER BY cur.[Equal], cur.[Code]	
	
	IF @pointsValue > 0 
		INSERT INTO #EN VALUES(1,2, @pointsValue, 0, @currencyValue, @currencyGuid)
	
	DECLARE enCursor CURSOR FAST_FORWARD 
	FOR	SELECT	
			[Type], [Paid], [Returned], [CurrencyValue], [CurrencyGuid] 
		FROM #EN 		
		ORDER BY [Type], [Number]	
	OPEN enCursor 
	FETCH NEXT  
	FROM enCursor 
	INTO @Type, @enPaid, @enReturned, @enCurrencyVal, @enCurrencyGuid 
	WHILE @@FETCH_STATUS = 0 
	BEGIN 
		SET @cashAccountID = 0x0
	
		IF @Type = 1
		BEGIN
			SELECT @cashAccountID = CashAccID
			FROM POSCurrencyItem000
			WHERE CurID = @enCurrencyGuid AND UserID = @orderCashierID
		END
		ELSE
		BEGIN
			SET @cashAccountID = @pointsAccountID
		END
		
		IF EXISTS(SELECT * FROM cu000 WHERE AccountGUID = @cashAccountID HAVING COUNT(AccountGUID) = 1)
		BEGIN
			SELECT TOP 1 @cashAccountCusomterId = GUID FROM cu000 WHERE AccountGUID = @cashAccountID 
		END
	
		DECLARE @enNotes NVARCHAR(MAX) = [dbo].[fnStrings_get](IIF( @Type = 1, 'POS\CASH', 'POS\LOYALTY_POINTS'),@language)
	
		IF @enPaid > 0
		BEGIN
		SET @enNumber = @enNumber + 1
		SET @EnID = newID() 
		INSERT INTO [en000] (
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
		VALUES ( 
					@enNumber, --Number 
					@orderDate, --Date 
					@enPaid, --Debit 
					0, --Credit 
					@enNotes, --Notes 
					@enCurrencyVal, --CurrencyVal 
					'', --Class 
					0, --Num1 
					0, --Num2 
					0, --Vendor 
					@UserNumber, --SalesMan 
					@EnID,
					@ceGuid, --ParentGUID 
					CASE WHEN @OrderType=1 THEN @cashAccountID ELSE @mediatorAccountID END, --AccountGUID 
					@enCurrencyGuid, --CurrencyGUID 
					0x0, --CostGUID 
					CASE WHEN @OrderType=1 THEN @mediatorAccountID ELSE @cashAccountID END, --ContraAccGUID)
					CASE WHEN @OrderType=1 THEN ISNULL(@cashAccountCusomterId, 0x0) ELSE @mediatorCustomerID END) --CustomerGUID
					
		SET @enNumber = @enNumber + 1 
	
		SET @EnID = newID() 
		INSERT INTO [en000] (
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
		   VALUES ( 
					@enNumber, --Number 
					@orderDate, --Date 
					0, --Debit 
					@enPaid, --Credit 
					@enNotes, --Notes 
					@enCurrencyVal, --CurrencyVal 
					'', --Class 
					0, --Num1 
					0, --Num2 
					0, --Vendor 
					@UserNumber, --SalesMan 
					@EnID,
					@ceGuid, --ParentGUID 
					CASE WHEN @OrderType=1 THEN @mediatorAccountID ELSE @cashAccountID END, --AccountGUID 
					@enCurrencyGuid, --CurrencyGUID 
					0x0, --CostGUID 
					CASE WHEN @OrderType=1 THEN @cashAccountID ELSE @mediatorAccountID END, --ContraAccGUID)
					CASE WHEN @OrderType=1 THEN @mediatorCustomerID ELSE 0x0 END) --CustomerGUID

		INSERT INTO POSPaymentLink000 VALUES(@EnID, @orderGuid,10,newID())
	END
		IF @enReturned>0
		BEGIN
		SET @enNumber = @enNumber + 1
		INSERT INTO [en000] 
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
		VALUES (
					@enNumber, --Number 
					@orderDate, --Date 
					@enReturned, --Debit 
					0, --Credit 
					'Returned', --Notes 
					@enCurrencyVal, --CurrencyVal 
					'', --Class 
					0, --Num1 
					0, --Num2 
					0, --Vendor 
					@UserNumber, --SalesMan 
					newid(),
					@ceGuid, --ParentGUID 
					CASE WHEN @OrderType=1 THEN @mediatorAccountID ELSE @cashAccountID END, --AccountGUID 
					@enCurrencyGuid, --CurrencyGUID 
					0x0, --CostGUID 
					CASE WHEN @OrderType=1 THEN @cashAccountID ELSE @mediatorAccountID END, --ContraAccGUID)
					CASE WHEN @OrderType=1 THEN @mediatorCustomerID ELSE 0x0 END) --CusrtomerGUID

		SET @enNumber = @enNumber + 1 
		INSERT INTO [en000]  
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
		VALUES (
					@enNumber, --Number 
					@orderDate, --Date 
					0, --Debit 
					@enReturned, --Credit 
					'Returned', --Notes 
					@enCurrencyVal, --CurrencyVal 
					'', --Class 
					0, --Num1 
					0, --Num2 
					0, --Vendor 
					@UserNumber, --SalesMan 
					newid(),
					@ceGuid, --ParentGUID 
					CASE WHEN @OrderType=1 THEN @cashAccountID ELSE @mediatorAccountID END, --AccountGUID 
					@enCurrencyGuid, --CurrencyGUID 
					0x0, --CostGUID 
					CASE WHEN @OrderType=1 THEN @mediatorAccountID ELSE @cashAccountID END, --ContraAccGUID)
					CASE WHEN @OrderType=1 THEN 0x0 ELSE @mediatorCustomerID END) --CustomerGUID
	END
		FETCH NEXT  
		FROM enCursor 
		INTO @Type, @enPaid, @enReturned, @enCurrencyVal, @enCurrencyGuid 
	END 
	CLOSE enCursor 
	DEALLOCATE enCursor 
	UPDATE [CE000] 
	SET [IsPosted] = 1 
	WHERE [Guid] = @ceGuid 
	RETURN SIGN(@pointsValue) + SIGN(@ceDebit) 
  
################################################################################
#END
