################################################################################
CREATE PROCEDURE prcPOSGenerateChecks
	@orderGuid [UNIQUEIDENTIFIER], 
    @BillsID   [UNIQUEIDENTIFIER], 
	@currencyGuid [UNIQUEIDENTIFIER], 
	@currencyValue [FLOAT], 
	@OrderType [INT] 
AS 
	SET NOCOUNT ON  
	DECLARE	@salesBillTypeID [UNIQUEIDENTIFIER],  
			@salesBillID [UNIQUEIDENTIFIER],  
			@salesBillNumber                             [FLOAT],  
			@salesBillTypeAbbrev [NVARCHAR](100),  
			@salesBillTypeLatinAbbrev [NVARCHAR](100),  
			@DefCostGuid [UNIQUEIDENTIFIER],
			@mediatorAccountID [UNIQUEIDENTIFIER],  
			@mediatorAccountName [NVARCHAR](250),  
			@chNumber [FLOAT],  
			@chNum [NVARCHAR](250),  
			@chNotes1 [NVARCHAR](250),  
			@chNotes2 [NVARCHAR](250),  
			@chGuid [UNIQUEIDENTIFIER],  
			@ceGuid [UNIQUEIDENTIFIER],  
			@ceNumber [FLOAT],  
			@ceNote [NVARCHAR](250),  
			@orderNumber [FLOAT],  
			@orderDate [DATE],  
			@orderPaymentsPackageID [UNIQUEIDENTIFIER],  
			@orderBranchID [UNIQUEIDENTIFIER],  
			@UserID [UNIQUEIDENTIFIER],  
			@checkNumber [NVARCHAR](250),  
			@checkPaid [FLOAT],  
			@checkType [UNIQUEIDENTIFIER],  
			@checkNotes [NVARCHAR](250),  
			@checkDebitAccID [UNIQUEIDENTIFIER],  
			@checkCreditAccID [UNIQUEIDENTIFIER],  
			@checkDebitAccName [NVARCHAR](250),  
			@checksCount [INT],  
			@EnID [UNIQUEIDENTIFIER],  
			@language [INT],  
			@currencyGuid1 [UNIQUEIDENTIFIER],  
			@currencyValue1 [FLOAT],  
			@NewVoucher [INT],
			@checkGuid [UNIQUEIDENTIFIER],
			@UserGuid [UNIQUEIDENTIFIER],
			@Cost2Guid [UNIQUEIDENTIFIER],
			@BankGuid  [UNIQUEIDENTIFIER],
			@TypeName NVARCHAR(250),
			@GenNote BIT ,
			@GenContraNote BIT,
			@CanFinishing BIT,  
			@ManualGenEntry BIT,
			@AutoPostEntry BIT,
			@InnerNum [NVARCHAR](250),
			@Cheque_Num [NVARCHAR](250),
			@ChequeNum INT,
			@CanbeFinishing BIT, 
			@DefaultCurrencyGuid UNIQUEIDENTIFIER , 
			@DefaultCurrencyVal FLOAT,
			@State INT,
			@mediatorCustomerID [UNIQUEIDENTIFIER] ,
			@debitAccountCusomterId [UNIQUEIDENTIFIER],
			@creditAccountCusomterId [UNIQUEIDENTIFIER] 

    SELECT TOP 1 @DefaultCurrencyGuid = [Value] 
	FROM [FileOP000] 
	WHERE [Name] = 'AmnPOS_DefaultCurrencyID'
	IF ISNULL(@DefaultCurrencyGuid,0X0) = 0X0
		BEGIN
			SELECT TOP 1 @DefaultCurrencyGuid = [Value] 
			FROM [OP000] 
			WHERE [Name] = 'AmnCfg_DefaultCurrency'

			SELECT @DefaultCurrencyVal = [CurrencyVal] 
			FROM [MY000] 
			WHERE [Guid] = @DefaultCurrencyGuid 
		END
		
	ELSE 
		SET @DefaultCurrencyVal = dbo.fnGetCurVal(@DefaultCurrencyGuid,GetDate())	

	SET @language = [dbo].[fnConnections_GetLanguage]()		  
	SELECT	@salesBillID = [Guid],  
			@salesBillNumber = [Number]  
	FROM [BU000]  
	WHERE [Guid] = (SELECT [BillGUID]  
					FROM [BillRel000]  
					WHERE [ParentGuid] = @orderGuid  
					AND   
					((@OrderType=1 AND [Type] = 1) OR (@OrderType=2 AND [Type] <> 1)))  
	IF @@ROWCOUNT <> 1  
		BEGIN  
			RETURN -100010  
		END  
	SELECT @orderNumber = [Number],  
	       @orderDate = [Date],  
           @orderPaymentsPackageID = ISNULL([PaymentsPackageID], 0x0),  
           @orderBranchID = ISNULL([BranchID], 0x0),  
		   @UserID = CashierID,
		   @mediatorCustomerID = ISNULL(CustomerID, 0x0),
		   @mediatorAccountID = ISNULL(DeferredAccountID, 0x0)  
	FROM [POSOrder000]  
		WHERE [Guid] = @orderGuid  
	  
	IF @@ROWCOUNT <> 1  
		BEGIN  
			RETURN -100011  
		END  
	
	IF (@mediatorCustomerID = 0x0)
	BEGIN
		SELECT @mediatorCustomerID = CAST([value] AS [UNIQUEIDENTIFIER]), @mediatorAccountID = [cu].[AccountGUID] 
		FROM UserOp000 INNER JOIN [cu000] [cu] ON [cu].[GUID] = [value]
		WHERE [UserID] = @UserID AND [Name] = 'AmnPOS_MediatorCustID'
	END
	SELECT @salesBillTypeID = CASE WHEN @OrderType=1 THEN SalesID ELSE ReturnedID END  
	FROM posuserbills000  
		WHERE [Guid] = @BillsID  
	  
	IF @@ROWCOUNT <> 1  
		RETURN -100012  
		  
	SET @mediatorAccountName = ''  
	  
	SELECT @mediatorAccountName = [Name]  
	FROM AC000  
		WHERE [Guid] = @mediatorAccountID  
	SELECT @salesBillTypeAbbrev = ISNULL([Abbrev], ''),   
	       @salesBillTypeLatinAbbrev = ISNULL([LatinAbbrev], '') , 
	       @DefCostGuid = ISNULL([DefCostGuid], 0x0)--- 
    	FROM BT000  
    WHERE [Guid] = @salesBillTypeID  
			  
	IF @@ROWCOUNT <> 1  
		RETURN -100013  
		  
	IF ((@language <> 0) AND (LEN(@salesBillTypeLatinAbbrev) <> 0))  
		SET @salesBillTypeAbbrev = @salesBillTypeLatinAbbrev  
		  
	Set @ceNote =  @salesBillTypeAbbrev + ' [' + CAST(@salesBillNumber AS NVARCHAR(250)) + ']'    
	EXEC prcDisableTriggers	'en000'
	DECLARE checkCursor CURSOR FAST_FORWARD  
	FOR	SELECT	[Guid],
				ISNULL([Paid], 0),  
				ISNULL([Number], ''),  
				ISNULL([Type], 0x0),  
				ISNULL([Notes], ''),  
				ISNULL([CreditAccID], 0x0),  
				ISNULL([DebitAccID], 0x0),  
				ISNULL(CurrencyID, @currencyGuid),  
				ISNULL(CurrencyValue, @currencyValue ),  
				ISNULL(NewVoucher, 0)
			FROM [POSPaymentsPackageCheck000]  
				WHERE [ParentID] = @orderPaymentsPackageID  
	OPEN checkCursor  
	FETCH NEXT   
	FROM checkCursor  
	INTO @checkGuid, @checkPaid, @checkNumber, @checkType, @checkNotes, @checkCreditAccID, @checkDebitAccID, @currencyGuid1, @currencyValue1, @NewVoucher  
	SET @checksCount = 0  
	WHILE @@FETCH_STATUS = 0  
	BEGIN 
		SET @chGuid = NEWID() 
		UPDATE [POSPaymentsPackageCheck000] SET ChildID = @chGuid WHERE [Guid] = @checkGuid --PK To Ch000
		IF @checkPaid <> 0  
		BEGIN  
			SET @checksCount = @checksCount + 1  
			IF ISNULL(@currencyGuid1, 0x0) = 0x0  
			BEGIN  
				SET @currencyGuid1 = @currencyGuid  
				SET @currencyValue1 = @currencyValue  
			END  
			  
			SELECT @chNumber = MAX(ISNULL([Number], 0)) + 1  
			FROM [CH000]  
				WHERE [TypeGUID] = @checkType  
			SET @chNumber = ISNULL(@chNumber, 1)  
					  
			SET @chNum =  @salesBillTypeAbbrev +  ' [' + CAST(@salesBillNumber AS NVARCHAR(250)) + ']'  
			  
		     SELECT @ChequeNum =  ISNULL(CAST (MAX(convert(int, case ISNUMERIC(num) when 1 then num else '' end ))+ 1 AS nvarchar(255)), 1) 
		        FROM CH000 
			   WHERE [TypeGUID] = @checkType 
				IF (NOT EXISTS(SELECT num FROM CH000 WHERE NUM = @checkNumber)) AND( @checkNumber <>'')
					SET @Cheque_Num  = 	@checkNumber 
				ELSE 
					SET @Cheque_Num = convert(NVARCHAR(255), @ChequeNum)
			
			SET @checkDebitAccName = ''  
			  
			  
			SELECT @checkDebitAccName = [Name]  
			FROM [AC000]  
				WHERE [Guid] = @checkDebitAccID  
			  
			SET @TypeName =  (SELECT Name FROM nt000 WHERE guid = @checkType)
			SET @GenNote  =  (SELECT bAutoGenerateNote FROM nt000 WHERE guid = @checkType)
			SET @GenContraNote  = (SELECT bAutoGenerateContraNote FROM nt000 WHERE guid = @checkType)
			SET @CanFinishing  = (SELECT bCanFinishing FROM nt000 WHERE guid = @checkType)
			SET @BankGuid = (SELECT BankGUID FROM NT000 WHERE GUID = @checkType )
			SET @Cost2Guid = (SELECT DefaultCostcenter FROM NT000 WHERE GUID = @checkType) 
			SET @ManualGenEntry = (SELECT bManualGenEntry FROM NT000 WHERE GUID = @checkType)
			SET @AutoPostEntry = (SELECT bAutoPost FROM NT000 WHERE GUID = @checkType)
			SET @CanbeFinishing = (SELECT bCanFinishing FROM NT000 WHERE GUID = @checkType)
			
			SET @chNotes1 = (CASE @GenNote WHEN 1 THEN (CASE WHEN @OrderType = 1 AND @NewVoucher = 0 THEN [dbo].[fnStrings_get]('POS\RECEIVEDFROM', @language) ELSE [dbo].[fnStrings_get]('POS\PAIDTO', @language) END + 
							(SELECT Code +'-'+ Name FROM ac000 WHERE GUID = ISNULL(@mediatorAccountID, @checkDebitAccID))) + ' - ' +
							(SELECT CustomerName FROM cu000 WHERE GUID = @mediatorCustomerID) + ' ' + @TypeName + ' ' 
							+ [dbo].[fnStrings_get]('POS\NUMBER', @language) + ':' + @Cheque_Num + ' ' +
							+ [dbo].[fnStrings_get]('POS\INNERNUMBER', @language) + ':' +  @chNum + ' ' +
							+ [dbo].[fnStrings_get]('POS\DATEOFPAYMENT', @language) + ':' +  CONVERT(NVARCHAR(255), @orderDate,105) + ' ' + 
							+ (CASE WHEN  @BankGuid <> 0x0 THEN [dbo].[fnStrings_get]('POS\DESTINATION', @language) + ':' + 
							+ (SELECT Code + '-' + BankName FROM Bank000 WHERE Guid = @BankGuid) + ' ' ELSE ' ' END) 
								 ELSE ' ' END)
							+ @checkNotes 			 
			 
			SET @chNotes2 =  (CASE @GenContraNote WHEN 1 THEN( CASE WHEN @OrderType = 1 AND @NewVoucher = 0 THEN [dbo].[fnStrings_get]('POS\RECEIVEDFROM', @language) ELSE [dbo].[fnStrings_get]('POS\PAIDTO', @language) END + 
							 (SELECT Code +'-'+ Name from ac000 where guid = ISNULL(@mediatorAccountID, @checkDebitAccID))) + ' - ' +
							 (SELECT CustomerName FROM cu000 WHERE GUID = @mediatorCustomerID) + ' ' + @TypeName + ' '
							 + [dbo].[fnStrings_get]('POS\NUMBER', @language) + ':' + @Cheque_Num + ' ' +
							 + [dbo].[fnStrings_get]('POS\INNERNUMBER', @language) + ':' + @chNum + ' ' +
							 + [dbo].[fnStrings_get]('POS\DATEOFPAYMENT', @language) + ':' + CONVERT(NVARCHAR(255), @orderDate,105) + ' ' +
							 + (CASE WHEN  @BankGuid <> 0x0  THEN [dbo].[fnStrings_get]('POS\DESTINATION', @language) + ':' + 
							 + (SELECT Code + '-' + BankName FROM Bank000 WHERE Guid = @BankGuid) + ' ' ELSE ' ' END) 
								 ELSE ' ' END)
							 + @checkNotes 
				  
			 SET @State = CASE @CanFinishing WHEN 1 THEN 1 ELSE 0 END
			 
			IF EXISTS(SELECT * FROM cu000 WHERE AccountGUID = @checkDebitAccID HAVING COUNT(AccountGUID) = 1)
			BEGIN
				SELECT TOP 1  @debitAccountCusomterId = GUID FROM cu000 WHERE AccountGUID = @checkDebitAccID  
			END

			IF EXISTS(SELECT * FROM cu000 WHERE AccountGUID = @checkCreditAccID HAVING COUNT(AccountGUID) = 1)
			BEGIN
				SELECT TOP 1  @creditAccountCusomterId = GUID FROM cu000 WHERE AccountGUID = @checkCreditAccID  
			END

			INSERT INTO [ch000]  
					   ([Number],  
					   [Dir],  
					   [Date],  
					   [DueDate],  
					   [ColDate],  
					   [Num],  
					   [BankGUID],  
					   [Notes],  
					   [Val],  
					   [CurrencyVal],  
					   [State],  
					   [Security],  
					   [PrevNum],  
					   [IntNumber],  
					   [FileInt],  
					   [FileExt],  
					   [FileDate],  
					   [OrgName],  
					   [GUID],  
					   [TypeGUID],  
					   [ParentGUID],  
					   [AccountGUID],  
					   [CurrencyGUID],  
					   [Cost1GUID],  
					   [Cost2GUID],  
					   [Account2GUID],  
					   [BranchGUID],  
					   [Notes2],
					   [CustomerGUID])  
				 VALUES(@chNumber, --Number  
					   CASE WHEN @OrderType = 1 AND @NewVoucher = 0 THEN 1 ELSE 2 END, --Dir  
					   @orderDate, --Date  
					   @orderDate, --DueDate  
					   @orderDate, --ColDate  
						@Cheque_Num,--
					   --CASE WHEN @NewVoucher=1 THEN @checkNumber ELSE @chNum END, --Num  @InnerNum,
					   @BankGuid, --Bank  
					   @chNotes1, --Notes  
					   @checkPaid, --Val  
					   @currencyValue1, --CurrencyVal  
					   @State, --State  
					   1, --Security  
					   0, --PrevNum  
					   @chNum,-- ÇáÑÞã ÇáÏÇÎáí 
					   --CASE WHEN @NewVoucher=1 THEN @chNum ELSE @checkNumber END, --IntNumber 
					   0, --FileInt  
					   0, --FileExt  
					   @orderDate, --FileDate  
					   '', --OrgName  
					   @chGuid, --GUID  
					   @checkType, --TypeGUID  
					   @salesBillID, --ParentGUID  
					   @mediatorAccountID, --AccountGUID  
					   @currencyGuid1, --CurrencyGUID  
					   @DefCostGuid, --Cost1GUID 
					   @Cost2Guid ,--Cost2GUID 
					   CASE WHEN @OrderType = 1 AND @NewVoucher = 0 THEN @checkDebitAccID ELSE @checkCreditAccID END, --Account2GUID  
					   @orderBranchID, --BranchGUID  
					   @chNotes2, --Notes2
					   @mediatorCustomerID) --CustomerGUID 
					    
			--Add Log File Record
			SET @UserGuid = [dbo].[fnGetCurrentUserGUID]()
			INSERT INTO  LoG000 (Computer,GUID,LogTime,RecGUID,RecNum,TypeGUID,Operation,OperationType,UserGUID) 
				VALUES(host_Name(),NEWID(),GETDATE(),@chGuid,@chNumber,@checkType,4,1,@UserGUID) 
			
		IF (@ManualGenEntry = 0)					    
		BEGIN 
			SET @ceGuid = NEWID()  
			SELECT @ceNumber = MAX(ISNULL([Number], 0)) + 1  
			FROM [CE000]  
			  
			SET @ceNumber = ISNULL(@ceNumber, 1)  
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
					   ,[TypeGUID]
					   ,[PostDate])  
				 VALUES(1,--Type  
						@ceNumber,--Number  
						CONVERT(date,@orderDate,113),--Date  
						@checkPaid, --Debit  
						@checkPaid, --Credit  
						@chNotes1,--@ceNote,--Notes  
						@DefaultCurrencyVal,	--@currencyValue1,--CurrencyVal  
						0,--IsPosted  
						0,--State  
						1,--Security  
						0,--Num1  
						0,--Num2  
						@orderBranchID,--Branch  
						@ceGuid,--GUID  
						@DefaultCurrencyGuid,--@currencyGuid1,--CurrencyGUID  
						@checkType,--TypeGUID 
						CONVERT(date,@orderDate,113))--Date
						-- post entry: 
			  
			INSERT INTO en000 (   
				[Number], 
				[Date], 
				[Debit], 
				[Credit], 
				[Notes], 
				[CurrencyVal], 
				[Class], 
				[Num1], 
				[Num2],  
				[Vendor], 
				[SalesMan], 
				[GUID], 
				[ParentGUID], 
				[AccountGUID], 
				[CurrencyGUID], 
				[CostGUID], 
				[ContraAccGUID],
				[CustomerGUID]) 			  
			SELECT	1, --Number  
					@orderDate, --Date  
					@checkPaid, --Debit  
					0, --Credit  
					@chNotes2,--Notes2  
					--[dbo].[fnStrings_get]('POS\CHECK', @language), --Notes  
					@currencyValue1, --CurrencyVal  
					'', --Class  
					0, --Num1  
					0, --Num2  
					0, --Vendor  
					0, --SalesMan  
					newid(),  
					@ceGuid, --ParentGUID  
					CASE WHEN @OrderType = 1 AND @NewVoucher = 0 THEN @checkDebitAccID ELSE @mediatorAccountID END, --AccountGUID  
					@currencyGuid1, --CurrencyGUID  
					@Cost2Guid ,--@Cost2Guid,--Cost2GUID 
					CASE WHEN @OrderType = 1 AND @NewVoucher = 0 THEN @mediatorAccountID ELSE @checkCreditAccID END, --ContraAccGUID  
					CASE WHEN @OrderType = 1 AND @NewVoucher = 0 THEN ISNULL(@debitAccountCusomterId, 0x0)  ELSE @mediatorCustomerID END --CustomerGUID  
				 
			SET @EnID = newID()  
			INSERT INTO en000 (   
				[Number], 
				[Date], 
				[Debit], 
				[Credit], 
				[Notes], 
				[CurrencyVal], 
				[Class], 
				[Num1], 
				[Num2],  
				[Vendor], 
				[SalesMan], 
				[GUID], 
				[ParentGUID], 
				[AccountGUID], 
				[CurrencyGUID], 
				[CostGUID], 
				[ContraAccGUID],
				[CustomerGUID]) 			  
			SELECT	2, --Number  
					@orderDate, --Date  
					0, --Debit  
					@checkPaid, --Credit  
					@chNotes1,--Notes1
					@currencyValue1, --CurrencyVal  
					'', --Class  
					0, --Num1  
					0, --Num2  
					0, --Vendor  
					0, --SalesMan  
					@EnID,  
					@ceGuid, --ParentGUID  
					CASE WHEN @OrderType = 1 AND @NewVoucher = 0 THEN @mediatorAccountID ELSE @checkCreditAccID END, --AccountGUID  
					@currencyGuid1, --CurrencyGUID  
					 @DefCostGuid, --CostGUID
					CASE WHEN @OrderType = 1 AND @NewVoucher = 0 THEN @checkDebitAccID  ELSE @mediatorAccountID END, --ContraAccGUID  
					CASE WHEN @OrderType = 1 AND @NewVoucher = 0 THEN @mediatorCustomerID ELSE ISNULL(@creditAccountCusomterId, 0x0) END --CustomerGUID  
					 
			INSERT INTO POSPaymentLink000 VALUES(@EnID, @orderGuid,4,newID())  
		
			INSERT INTO [er000]  
					   ([GUID]  
					   ,[EntryGUID]  
					   ,[ParentGUID]  
					   ,[ParentType]  
					   ,[ParentNumber])  
				 VALUES(NEWID(), --GUID  
					   @ceGuid, --EntryGUID  
					   @chGuid, --ParentGUID  
					   5, --ParentType  
					   @chNumber) --ParentNumber  

			IF (@AutoPostEntry = 1)
			BEGIN
				UPDATE [CE000] 
				SET [IsPosted] = 1 
				WHERE [Guid] = @ceGuid 
			END
	
		END 
		DECLARE @acGuid AS uniqueidentifier
		select @acGuid = CASE WHEN @OrderType = 1 AND @NewVoucher = 0 THEN @checkDebitAccID ELSE @checkCreditAccID END
			  --AddToChequeHistory 
			   EXEC prcCheque_History_Add @chGuid, @orderDate, @State,33,@ceGuid, @acGuid,@mediatorAccountID, 
			    @checkPaid,
			    5 , @currencyGuid1, @currencyValue1, 0x0 ,0.0 ,@Cost2Guid, @DefCostGuid, 0x0, @mediatorCustomerID
	
			Exec prcRestDistributeAccEn @ceGuid
			
		END  
		FETCH NEXT   
		FROM checkCursor  
		INTO @checkGuid, @checkPaid, @checkNumber, @checkType, @checkNotes, @checkCreditAccID, @checkDebitAccID, @currencyGuid1, @currencyValue1, @NewVoucher  
	END  
	CLOSE checkCursor  
	DEALLOCATE checkCursor  
 
	EXEC prcEnableTriggers	'en000'
	
	IF @checksCount <> 0  
	BEGIN  
		RETURN 1  
	END  
	RETURN 0
################################################################################
#END
