################################################################
CREATE PROCEDURE prcRest_ModifyOrderNumberOption
    @Number [FLOAT]
AS 
	SET NOCOUNT ON 
	     
	IF EXISTS (SELECT * FROM op000 WHERE [Name] = 'RestaurantOrderNumber' AND [Type] = 0)
		UPDATE [op000] SET [PrevValue] = [Value], [Value] = CAST(@Number AS VARCHAR(10)) WHERE [Name] = 'RestaurantOrderNumber' AND [Type] = 0
	ELSE 
		INSERT INTO op000 ([Name], [Value], [Type], [Computer], [Time], OwnerGUID) 
		SELECT 'RestaurantOrderNumber', CAST(@Number AS VARCHAR(10)), 0, HOST_NAME(), GETDATE(), [dbo].[fnGetCurrentUserGUID]()
################################################################
CREATE PROCEDURE prcRestAdd_Order
    @Mode [INT],     
    @Number [FLOAT] OUTPUT,    
    @Guid [UNIQUEIDENTIFIER],    
    @Type [INT] = 0,   
    @State [INT] = 0,   
    @CashierID [UNIQUEIDENTIFIER] = 0x0,    
    @FinishCashierID [UNIQUEIDENTIFIER] = 0x00,    
    @BranchID [UNIQUEIDENTIFIER] = 0x00,    
    -- @Date [DATETIME] = '1/1/1980',    
    @Notes [NVARCHAR](250) = '',    
    @Cashed [FLOAT] = 0,    
    @Discount [FLOAT] = 0,    
    @Added [FLOAT] = 0,    
    @Tax [FLOAT] = 0,    
    @SubTotal [FLOAT] = 0,    
    @CustomerID [UNIQUEIDENTIFIER] = 0x00,    
    @DeferredAccountID [UNIQUEIDENTIFIER] = 0x00,    
    @CurrencyID [UNIQUEIDENTIFIER] = 0x00,    
    @IsPrinted [INT] = 0,    
    @HostName [NVARCHAR](250) = '',    
    @BillNumber [FLOAT] = 0,    
    @DepartmentID [UNIQUEIDENTIFIER] = 0x00,   
    @GuestID [UNIQUEIDENTIFIER] = 0x00,   
    @PaymentsPackageID [UNIQUEIDENTIFIER] = 0x00,    
    @Opening [DATETIME] = '1/1/1980',   
    @Preparing [DATETIME] = '1/1/1980',   
    @Receipting [DATETIME] = '1/1/1980',   
    @Closing [DATETIME] = '1/1/1980',   
    @Version [INT] = -1, 
    @PrintTimes [INT] = 0,  
    @Period [BIGINT] = -1, 
	@externalCustomerName [NVARCHAR](250) = '',
	@CustomerAddressID [UNIQUEIDENTIFIER] = 0x00,
    @DeliveringTime [DATETIME] = '1/1/1980',  
    @DeliveringFees [FLOAT] = 0,  
	@EnableAndroidNotification [BIT] = 0,
	@IsManualPrinted BIT = 0
/*	@State 
		OS_None = -1, 
		OS_InputOrder  = 1, 
		OS_PrevPrepare = 2, 
		OS_StartPrepare = 4, 
		OS_FinishPrePare = 5, 
		OS_Corrected = 7, 
		OS_Waiting = 8, 
		OS_StartDelivery = 9, 
		OS_PayToCaptin = 10, 
		OS_Finished = 11, 
		OS_Canceled = 12, 
		// maybe dont have because the items dont have ingredients 
		OS_HasInOutBill = 13  
*/ 
AS    
	SET NOCOUNT ON
	IF (@CustomerID <> 0x0)
	BEGIN
		SELECT @DeferredAccountID = [AccountGUID]
		FROM cu000
		WHERE [GUID] = @CustomerID
	END

	IF ((@Number < 1) OR (EXISTS(SELECT [Number] FROM [RestOrderTemp000] WHERE [Number] = @Number AND [GUID] != @Guid)))
	BEGIN 
		SET @Number = ISNULL((SELECT TOP 1 CAST([Value] AS INT) FROM op000 WHERE [Name] = 'RestaurantOrderNumber' AND [Type] = 0), 0) + 1
		IF EXISTS (SELECT [Number] FROM [RestOrderTemp000] WHERE [Number] = @Number AND [GUID] != @Guid)
		BEGIN 
			DECLARE @found BIT 
			SET @found = 1
			WHILE (@found = 1)
			BEGIN 
				SET @Number = @Number + 1
				IF NOT EXISTS (SELECT [Number] FROM [RestOrderTemp000] WHERE [Number] = @Number AND [GUID] != @Guid)
					SET @found = 0
			END 
		END 

		EXEC prcRest_ModifyOrderNumberOption @Number
	END 

	IF @Mode = 0  -- DOM_SAVE = 0, // Save new order in RestOrderTemp000  
	BEGIN    
		INSERT INTO [RestOrderTemp000] ( 
			[Number], [OrderNumber], [Guid], [Type], [State], [CashierID], [FinishCashierID], [BranchID] -- ,[Date]     
			,[Notes], [Cashed], [Discount], [Added], [Tax], [SubTotal], [CustomerID], [DeferredAccountID]    
			,[CurrencyID], [IsPrinted], [HostName], [BillNumber], [DepartmentID]   
			,[GuestID],[PaymentsPackageID],[Opening],[Preparing],[Receipting],[Closing], 
			[Version],[Period],printTimes,[externalCustomerName],[CustomerAddressID], [DeliveringTime], [DeliveringFees], IsManualPrinted)    
		SELECT  
			@Number, @Number, @Guid, @Type, @State,@CashierID, @FinishCashierID, @BranchID, -- @Date,     
			@Notes,  @Cashed, @Discount, @Added, @Tax, @SubTotal, @CustomerID, @DeferredAccountID,    
			@CurrencyID, @IsPrinted, @HostName, @BillNumber, @DepartmentID, @GuestID,   
			@PaymentsPackageID, @Opening, @Preparing, @Receipting, @Closing, @Version, 
			@Period , 
			@PrintTimes,  
			@externalCustomerName, @CustomerAddressID, @DeliveringTime, @DeliveringFees, @IsManualPrinted
	END  
	ELSE IF @Mode = 1 OR @Mode = 4  -- DOM_UPDATE = 1, // update order in RestOrderTemp000 
									-- DOM_SAVE_FROM_TEMP = 4 // move order from RestOrderTemp000 to RestOrder000 
	BEGIN    
		DECLARE 
			@Type1 INT,
			@OldState INT 
		SELECT @Type1 = [Type], @OldState = [State] FROM RestOrderTemp000 WHERE GUID = @GUID   
		 
		IF ISNULL(@Type1, 0) <> 0 AND @Type1 <> @Type   
		BEGIN   
			IF @Type = 3 AND @Type1 <> 3 --DOM_GET_TO_TEMP = 3, // move order from RestOrder000 to RestOrderTemp000  
				SELECT @GuestID = DriverID FROM RestDepartment000 WHERE GUID = @DepartmentID   
			ELSE IF @Type <> 3 AND @Type1 = 3   
				SELECT @GuestID = GuestID FROM RestDepartment000 WHERE GUID = @DepartmentID   
		END

		DECLARE @LastAdditionDate DATETIME 
		SET @LastAdditionDate = NULL
		
		IF (@Mode = 1) AND (@State = 2 OR @State = 4 OR @State = 5)
		BEGIN
			IF EXISTS(SELECT * FROM RestOrderItemTemp000 WHERE ParentID = @GUID AND (IsNew = 1 OR QtyDiff != 0))
			BEGIN
				IF EXISTS(SELECT * FROM RestOrderItemTemp000 WHERE ParentID = @GUID AND (IsNew = 1 OR QtyDiff > 0))
					SET @LastAdditionDate = GETDATE()

				UPDATE RestOrderItemTemp000 SET IsNew = 0, QtyDiff = 0 WHERE ParentID = @GUID AND (IsNew = 1 OR QtyDiff != 0)
			END
		END 
		UPDATE [RestOrderTemp000]  
		SET 
			[Number] = @Number
			-- ,[OrderNumber] = @Number    
			,[Type] = @Type    
			,[CashierID] = @CashierID    
			,[FinishCashierID] = @FinishCashierID    
			,[BranchID] = @BranchID    
			,[State] = @State    
			-- ,[Date] = @Date    
			,[Notes] = @Notes    
			,[Cashed] = @Cashed    
			,[Discount] = @Discount    
			,[Added] = @Added    
			,[Tax] = @Tax    
			,[SubTotal] = @SubTotal    
			,[CustomerID] = @CustomerID    
			,[DeferredAccountID] = @DeferredAccountID    
			,[CurrencyID] = @CurrencyID    
			,[IsPrinted] = @IsPrinted    
			,[HostName] = @HostName    
			,[BillNumber] = @BillNumber    
			,[PaymentsPackageID] = @PaymentsPackageID    
			,[DepartmentID] = @DepartmentID   
			,[GuestID] = @GuestID   
			,[Opening] = @Opening   
			,[Preparing] = @Preparing   
			,[Receipting] = @Receipting   
			,[Closing] = @Closing   
			,[Version] = @Version  
			,[Period] = @Period  
			,[PrintTimes] = @PrintTimes  
			,[externalCustomerName]  = @externalCustomerName 
			,LastAdditionDate = ISNULL(@LastAdditionDate, LastAdditionDate)
			,CustomerAddressID = @CustomerAddressID
			,DeliveringTime = @DeliveringTime
			,DeliveringFees = @DeliveringFees
			,IsManualPrinted = @IsManualPrinted
		WHERE GUID = @GUID   

		IF @EnableAndroidNotification = 1 AND @State = 5 AND @OldState <> 5
		BEGIN
			INSERT INTO RestFinishedOrder000
			SELECT NEWID(), vwto.TableID, vwto.Code, vwto.DepartmentID, ot.Closing
				FROM RestOrderTemp000 ot
				INNER JOIN vwRestTablesOrders vwto ON ot.Guid = vwto.ParentID
					WHERE ot.GUID = @GUID
						ORDER BY Code
		END
		 
		IF @Mode = 4  --DOM_SAVE_FROM_TEMP = 4 // move order from RestOrderTemp000 to RestOrder000 
		BEGIN   
			SELECT @Number = ISNULL(MAX(ISNULL(Number, 0)), 0) + 1 From RestOrder000

			INSERT INTO RestOrder000 (
				[Number], OrderNumber, [Guid] ,[Type] ,[State],[CashierID] ,[FinishCashierID] ,[BranchID] -- ,[Date]    
				,[Notes] ,[Cashed] ,[Discount] ,[Added] ,[Tax] ,[SubTotal] ,[CustomerID] ,[DeferredAccountID]    
				,[CurrencyID] ,[IsPrinted] ,[HostName] ,[BillNumber] ,[DepartmentID]   
				,[GuestID],[PaymentsPackageID],[Opening],[Preparing],[Receipting],[Closing],[Version],[Period],[printTimes],[externalCustomerName], [CustomerAddressID], DeliveringTime, DeliveringFees)   
			SELECT 
				@Number, [Number], [Guid],[Type],CASE WHEN [State]=12 THEN 12 ELSE 10 END   
				,[CashierID],[FinishCashierID],[BranchID]/*,[Date]*/,[Notes],[Cashed],[Discount]    
				,[Added],[Tax],[SubTotal],[CustomerID],[DeferredAccountID],[CurrencyID],[IsPrinted]    
				,[HostName],[BillNumber],[DepartmentID],[GuestID],[PaymentsPackageID]   
				,[Opening],[Preparing],[Receipting],[Closing],[Version],[Period],[printTimes],[externalCustomerName], [CustomerAddressID] , DeliveringTime, DeliveringFees
			FROM RestOrderTemp000 
			WHERE GUID = @GUID   

			INSERT INTO RestOrderItem000 (
				[Number],[Guid],[State]   
				,[Type],[Qty],[MatPrice],[Price],[PriceType],[Unity],[MatID],[Discount]   
				,[Added],[Tax],[ParentID],[ItemParentID],[KitchenID],[PrinterID]   
				,[AccountID],[Note],[SpecialOfferID],[SpecialOfferIndex],[OfferedItem]   
				,[IsPrinted],[BillType],[Vat],[VatRatio]) 
			SELECT 
				[Number],[Guid],/*[State]*/ 5   
				,[Type],[Qty],[MatPrice],[Price],[PriceType],[Unity],[MatID],[Discount]   
				,[Added],[Tax],[ParentID],[ItemParentID],[KitchenID],[PrinterID]   
				,[AccountID],[Note],[SpecialOfferID],[SpecialOfferIndex],[OfferedItem]   
				,[IsPrinted],[BillType],[Vat],[VatRatio]
			FROM RestOrderItemTemp000 
			WHERE ParentID = @GUID

			INSERT INTO [RestDiscTax000] SELECT * FROM [RestDiscTaxTemp000] WHERE ParentID = @GUID   
			INSERT INTO RestOrderTable000 SELECT * FROM RestOrderTableTemp000 WHERE ParentID = @GUID   
			INSERT INTO [RestOrderDiscountCard000] SELECT * FROM [RestOrderDiscountCardTemp000] WHERE ParentID = @GUID   

			DELETE RestOrderTemp000 WHERE GUID = @GUID   
		END   
	END ELSE IF @Mode = 2  --		DOM_DELETE = 2,  // delete order from RestOrderTemp000 
	BEGIN   

		DECLARE 
			@tempState INT,
			@DeletedNumber INT

		SELECT TOP 1 @tempState = [State], @DeletedNumber = [Number] FROM RestOrderTemp000 WHERE GUID = @GUID 
		IF @tempState = 12 -- OS_Canceled = 12, 
		BEGIN 
			INSERT INTO [RestDeletedOrders000] (
				[Number], [Guid], [Type], [State], [CashierID], [FinishCashierID],  
				[BranchID], [Date], [Notes], [Cashed], [Discount], [Added], 
				[Tax], [SubTotal], [CustomerID], [DeferredAccountID],  
				[CurrencyID], [IsPrinted], [HostName], [BillNumber],  
				[DepartmentID], [GuestID], [PaymentsPackageID], [Opening], 
				[Preparing], [Receipting], [Closing], [Version], [Period],[externalcustomername], 
				[CancelationDate], [UserGuid], DeliveringTime, DeliveringFees) 
			SELECT 
				Number, Guid, Type, State, CashierID, FinishCashierID,  
				BranchID, Date, Notes, Cashed, Discount, Added, Tax, SubTotal, 
				CustomerID, DeferredAccountID, CurrencyID, IsPrinted, [HostName],  
				[BillNumber], [DepartmentID], [GuestID], [PaymentsPackageID], [Opening],  
				[Preparing], [Receipting], [Closing], [Version], [Period], [externalcustomername],
				GETDATE() as CancelationDate, dbo.fnGetCurrentUserGUID() AS userGuid , DeliveringTime, DeliveringFees
			FROM RestOrderTemp000 
			WHERE GUID = @GUID AND [State] = 12 

			INSERT INTO RestDeletedOrderItems000	 
			SELECT * FROM RestOrderItemTemp000 
			WHERE Parentid = @GUID 
		END

		DELETE [RestOrderTemp000] WHERE GUID = @GUID   
		IF (@DeletedNumber > 0)
		BEGIN 
			DECLARE @NumberOption INT 
			SET @NumberOption = ISNULL((SELECT TOP 1 CAST([Value] AS INT) FROM op000 WHERE [Name] = 'RestaurantOrderNumber' AND [Type] = 0), 0)
			IF @DeletedNumber = @NumberOption
			BEGIN 
				IF EXISTS(SELECT * FROM op000 WHERE [Name] = 'RestaurantOrderNumber' AND [Type] = 0)
					UPDATE [op000] SET [PrevValue] = [Value], [Value] = CAST((@DeletedNumber - 1) AS VARCHAR(10)) WHERE [Name] = 'RestaurantOrderNumber' AND [Type] = 0
				ELSE 
					INSERT INTO op000([Name], [Value], [Type], [Computer], [Time], OwnerGUID) 
					SELECT 'RestaurantOrderNumber', CAST((@DeletedNumber - 1) AS VARCHAR(10)), 0, HOST_NAME(), GETDATE(), [dbo].[fnGetCurrentUserGUID]()
			END 
		END 
	END ELSE IF @Mode = 3  --DOM_GET_TO_TEMP = 3, // move order from RestOrder000 to RestOrderTemp000 
	BEGIN   
		INSERT INTO RestOrderTemp000 (
			[Number],[Guid] ,[Type] ,[State],[CashierID] ,[FinishCashierID] ,[BranchID] -- ,[Date]     
			,[Notes] ,[Cashed] ,[Discount] ,[Added] ,[Tax] ,[SubTotal] ,[CustomerID] ,[DeferredAccountID]    
			,[CurrencyID] ,[IsPrinted] ,[HostName] ,[BillNumber] ,[DepartmentID]   
			,[GuestID],[PaymentsPackageID],[Opening],[Preparing],[Receipting],[Closing],[Version],[Period],[printTimes],[externalcustomername], [CustomerAddressID], DeliveringTime, DeliveringFees)    
		SELECT (SELECT (ISNULL(MAX(ISNULL(Number, 0)), 0) + 1) From RestOrderTemp000), [Guid], [Type], [State], [CashierID], [FinishCashierID], [BranchID] -- ,[Date]     
			,[Notes] ,[Cashed] ,[Discount] ,[Added] ,[Tax] ,[SubTotal] ,[CustomerID] ,[DeferredAccountID]    
			,[CurrencyID] ,[IsPrinted] ,[HostName] ,[BillNumber] ,[DepartmentID]   
			,[GuestID],[PaymentsPackageID],[Opening],[Preparing],[Receipting],[Closing],[Version],[Period] ,[printTimes],[externalcustomername], [CustomerAddressID], DeliveringTime , DeliveringFees 
		FROM RestOrder000 
		WHERE GUID = @GUID   

		INSERT INTO RestOrderItemTemp000 SELECT * FROM RestOrderItem000 WHERE ParentID = @GUID   
		INSERT INTO [RestDiscTaxTemp000]  SELECT * FROM [RestDiscTax000] WHERE ParentID = @GUID   
		INSERT INTO RestOrderTableTemp000 SELECT * FROM RestOrderTable000 WHERE ParentID = @GUID   
		INSERT INTO [RestOrderDiscountCardTemp000] SELECT * FROM [RestOrderDiscountCard000] WHERE ParentID = @GUID   

		DELETE RestOrder000 WHERE GUID = @GUID   
	END
####################################################################
#END


