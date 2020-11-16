################################################################################
CREATE PROCEDURE prcPOSGenerateSalesBill
	@orderGuid			[UNIQUEIDENTIFIER], 
    @BillsID			[UNIQUEIDENTIFIER], 
	@payType			[INT], 
	@deferredAccount	[UNIQUEIDENTIFIER], 
	@checkType			[UNIQUEIDENTIFIER], 
	@currencyID			[UNIQUEIDENTIFIER], 
	@currencyValue		[FLOAT], 
	@salesBillTypeID	[UNIQUEIDENTIFIER] = 0x0, 
	@storeID			[UNIQUEIDENTIFIER] = 0x0,
	@deferredCustomer	[UNIQUEIDENTIFIER] = 0x0
AS
	SET NOCOUNT ON
		
	DECLARE 
		@orderNumber					[FLOAT],
		@orderType						[INT],
        @orderDate						[DATETIME],
		@orderNotes						[NVARCHAR](250),
		@orderSalesDiscount				[FLOAT],
		@orderSalesAdded				[FLOAT],
		@orderTax						[FLOAT],
		@orderCashierID					[UNIQUEIDENTIFIER],
		@orderBranchID					[UNIQUEIDENTIFIER],
		@costID							[UNIQUEIDENTIFIER],
		@customerName					[NVARCHAR](250),
		@discountAccountID				[UNIQUEIDENTIFIER],
		@extraAccountID					[UNIQUEIDENTIFIER],
		@vatSystem						[INT],
		@autoPost						[BIT],
		@autoEntry						[BIT],
		@snGuid							[UNIQUEIDENTIFIER],

		@salesBillID					[UNIQUEIDENTIFIER],
		@salesBillItemID				[UNIQUEIDENTIFIER],
		@salesBillNumber				[FLOAT],
		@salesOrderItemsTotal			[FLOAT],
		@salesOrderItemsSubTotal		[FLOAT],
		@salesOrderItemsDiscount		[FLOAT],
		@salesOrderItemsAdded			[FLOAT],
		@salesOrderItemsTax				[FLOAT],
		@salesBillTotal					[FLOAT],
		@UserNumber						[FLOAT],
		@paymentsPackageRoundedValue	[FLOAT],
		@rowcount						[INT],
		@GCCTaxEnable					[INT],
		@BillCustomerGuid				[UNIQUEIDENTIFIER],

		@TextFld1						[NVARCHAR](250),
		@TextFld2						[NVARCHAR](250),
		@TextFld3						[NVARCHAR](250),
		@TextFld4						[NVARCHAR](250),
		@CustomerAddressID				[UNIQUEIDENTIFIER]

	IF @salesBillTypeID = 0x0 
	BEGIN
		SELECT 
			@salesBillTypeID = ISNULL(SalesID, 0x0),
			@orderBranchID = ISNULL(BranchID, 0x0)
		FROM posuserbills000
		WHERE [Guid] = @BillsID
	END

	SELECT 
		@orderNumber =			[Number],
        @orderType =			[Type],
        @orderDate =			[Date],
		@orderNotes =			ISNULL([Notes], ''),
        @orderTax =				ISNULL([Tax], 0),
		@deferredCustomer =		CASE @deferredCustomer WHEN 0x0 THEN ISNULL([CustomerID], 0x0) ELSE @deferredCustomer END,
        @orderCashierID =		ISNULL([CashierID], 0x0),
        @orderBranchID =		ISNULL([BranchID], 0x0),
		@TextFld1 =				ISNULL([TextFld1], ''),
		@TextFld2 =				ISNULL([TextFld2], ''),
		@TextFld3 =				ISNULL([TextFld3], ''),
		@TextFld4 =				ISNULL([TextFld4], ''),
		@costID	 =				ISNULL([SalesManID], 0x0),
		@CustomerAddressID =	ISNULL([CustomerAddressID], 0x0)
	FROM [POSOrder000]
	WHERE [Guid] = @orderGuid

	SELECT @GCCTaxEnable = ISNULL((SELECT value FROM op000 WHERE name = 'AmnCfg_EnableGCCTaxSystem'), 0)

	IF ISNULL(@salesBillTypeID, 0x0) = 0x0 
		RETURN 0
	SELECT
		@storeID =				CASE WHEN @storeID=0x0 THEN ISNULL([DefStoreGuid], 0x0) ELSE @storeID END,
        @discountAccountID =	ISNULL([DefDiscAccGuid], 0x0),
        @extraAccountID =		ISNULL([DefExtraAccGuid], 0x0),
        @vatSystem =			CASE @GCCTaxEnable WHEN 1 THEN 1 ELSE ISNULL([VATSystem], 0) END,
        @autoPost =				ISNULL([bAutoPost], 0),
        @autoEntry =			ISNULL([bAutoEntry], 0),
        @costID =				CASE @costID WHEN 0x0 THEN ISNULL(DefCostGUID, 0x0) ELSE @costID END,
		@BillCustomerGuid =		ISNULL(CustAccGuid, 0x0)
	FROM [bt000]
	WHERE [Guid] = @salesBillTypeID
	
	IF @@ROWCOUNT <> 1
	BEGIN
		RETURN -24
	END
	
	SELECT 
		@UserNumber = Number 
	FROM us000 
	WHERE GUID = @orderCashierID

	SELECT 
		@orderSalesDiscount = ISNULL(SUM(ISNULL([Value], 0)), 0)
	FROM [POSOrderDiscount000]
	WHERE 
		[ParentID] = @orderGuid
	    AND 
		[OrderType] = 0  -- Sales

	SELECT 
		@orderSalesAdded = ISNULL(SUM(ISNULL([Value], 0)), 0)
	FROM [POSOrderAdded000]
	WHERE 
		[ParentID] = @orderGuid
	    AND 
		[OrderType] = 0  -- Sales

	SELECT 
		@salesOrderItemsTotal =		SUM(CASE @vatSystem WHEN 2 THEN ISNULL([Price], 0) /(1+ (VATValue/100)) ELSE [Price] END * [Qty]),
		@salesOrderItemsAdded =		SUM(ISNULL([Added], 0)),
		@salesOrderItemsTax =		SUM(ISNULL([Tax], 0)),
		@salesOrderItemsDiscount =	SUM(ISNULL([Discount], 0))
	FROM [POSOrderItems000]
	WHERE 
		[ParentID] = @orderGuid
		AND
		[State] = 0 --IS_NORMAL
		AND
		[Type] = 0 --IT_SALES

	IF @@ROWCOUNT <> 1
		RETURN -22

	SET @salesBillTotal = @salesOrderItemsTotal + @salesOrderItemsAdded - @salesOrderItemsDiscount + @salesOrderItemsTax - @orderSalesDiscount + @orderSalesAdded + @orderTax
	SET @customerName = ''

	IF ISNULL(@deferredCustomer, 0x0) = 0x0
		SET @deferredCustomer = CASE @GCCTaxEnable WHEN 1 THEN @BillCustomerGuid ELSE 0x0 END
	
	IF ISNULL(@deferredCustomer, 0x0) <> 0x0
	BEGIN
		SELECT @customerName = [CustomerName]
		FROM [cu000]
		WHERE [Guid] = @deferredCustomer
	END

	SELECT 
		@paymentsPackageRoundedValue = ISNULL(abs([RoundedValue]), 0)
	FROM [POSPaymentsPackage000]
	WHERE [Guid] = (SELECT [PaymentsPackageID]
					FROM [POSOrder000]
					WHERE [Guid] = @orderGuid)
	IF @paymentsPackageRoundedValue > 0
	BEGIN
		SET @orderSalesDiscount = @orderSalesDiscount + @paymentsPackageRoundedValue
	END
	
	IF @paymentsPackageRoundedValue < 0
	BEGIN
		SET @orderSalesAdded = @orderSalesAdded + ABS(@paymentsPackageRoundedValue)
	END
	
	SELECT @salesBillNumber = dbo.fnGetNextBillNumber(@salesBillTypeID, @orderBranchID);
	SET @salesBillNumber = ISNULL(@salesBillNumber, 1);
	SET @salesBillID = NEWID();
	DECLARE 
		@firstPayment AS FLOAT,
		@DrawerAccGUID AS UNIQUEIDENTIFIER

	SET @DrawerAccGUID = @deferredAccount

	IF(@payType <> 0 AND @orderType != 0 )
	BEGIN
		SELECT @firstPayment = Payment FROM POSOrder000 WHERE [GUID] = @OrderGUID
		SET @DrawerAccGUID = 
			ISNULL((SELECT TOP 1 cui.CashAccID FROM POSCurrencyItem000 cui INNER JOIN my000 my ON cui.CurID = my.GUID WHERE cui.UserID = @orderCashierID AND my.CurrencyVal = 1 ORDER BY my.Number), @deferredAccount)
	END
	ELSE
	SET @firstPayment = 0

	INSERT INTO [BU000]([Number],
	                    [Cust_Name], 
		                [Date], 
						[CurrencyVal], 
						[Notes], 
						[Total],
						[PayType], 
						[TotalDisc], 
						[TotalExtra], 
						[ItemsDisc], 
						[BonusDisc],
						[FirstPay], 
						[Profits], 
						[IsPosted], 
						[Security], 
						[Vendor], 
						[SalesManPtr], 
						[Branch], 
						[VAT], 
						[GUID], 
						[TypeGUID], 
						[CustGUID],
						[CurrencyGUID], 
						[StoreGUID], 
						[CustAccGUID], 
						[MatAccGUID], 
						[ItemsDiscAccGUID], 
						[BonusDiscAccGUID], 
						[FPayAccGUID], 
						[CostGUID],
						[UserGUID], 
						[CheckTypeGUID], 
						[TextFld1], 
						[TextFld2], 
						[TextFld3],
						[TextFld4], 
						[RecState], 
						[ItemsExtra], 
						[ItemsExtraAccGUID], 
						[CostAccGUID], 
						[StockAccGUID], 
						[VATAccGUID], 
						[BonusAccGUID],
						[BonusContraAccGUID],
						[CustomerAddressGUID])
	VALUES(@salesBillNumber,--Number
		   @customerName,--Cust_Name
		   @orderDate,--Date
		   @currencyValue,--CurrencyVal
		   @orderNotes,--Notes
		  @salesOrderItemsTotal ,--Total 
           @payType,--PayType
           @orderSalesDiscount + @salesOrderItemsDiscount,--TotalDisc
           @orderSalesAdded + @salesOrderItemsAdded,--TotalExtra
           @salesOrderItemsDiscount,--ItemsDisc
           0,--BonusDisc
           @firstPayment,--FirstPay
           0,--Profits
           0,--IsPosted
           1,--Security
           0,--Vendor
           @UserNumber,--SalesManPtr
           @orderBranchID,--Branch
           @salesOrderItemsTax + @orderTax,--VAT
           @salesBillID,--GUID
           @salesBillTypeID,--TypeGUID
           @deferredCustomer,--CustGUID
           @currencyID,--CurrencyGUID
           @storeID,--StoreGUID
           @deferredAccount,--CustAccGUID
           0x0,--MatAccGUID
           0x0,--ItemsDiscAccGUID
           @discountAccountID,--BonusDiscAccGUID
           @DrawerAccGUID,--FPayAccGUID
           @costID,--CostGUID
           @orderCashierID,--UserGUID
           @checkType,--CheckTypeGUID
           'Order Number: ''' + CAST(@orderNumber AS NVARCHAR(100)) + '''',--TextFld1
           @TextFld2,--TextFld2
           @TextFld3,--TextFld3
           @TextFld4,--TextFld4
           0,--RecState
           @salesOrderItemsAdded,--ItemsExtra
           0x0,--ItemsExtraAccGUID
           0x0,--CostAccGUID
           0x0,--StockAccGUID
           0x0,--VATAccGUID
           0x0,--BonusAccGUID
           0x0,
		   @CustomerAddressID)--BonusContraAccGUID
		
	--Add Bill Items
	INSERT INTO [bi000]([Number], 
						[Qty], 
						[Order],  
						[OrderQnt],  
						[Unity],  
						[Price],  
						[BonusQnt],  
						[Discount],  
						[BonusDisc],  
						[Extra],  
						[CurrencyVal],  
						[Notes],  
						[Profits],  
						[Num1],  
						[Num2],  
						[Qty2],  
						[Qty3],  
						[ClassPtr],  
						[ExpireDate],  
						[ProductionDate],  
						[Length],  
						[Width],  
						[Height],  
						[GUID],  
						[VAT],  
						[VATRatio],  
						[ParentGUID],  
						[MatGUID],  
						[CurrencyGUID],  
						[StoreGUID],  
						[CostGUID],  
						[SOType],  
						[SOGuid],  
						[Count],
						[TaxCode],
						[IsPOSSpecialOffer])	
		(SELECT	[Item].[Number] AS [Number],
				CASE WHEN [Item].[Type]=0 THEN (CASE [Item].[Unity]
					WHEN 2 THEN ISNULL([MT].[Unit2Fact], 1)
					WHEN 3 THEN ISNULL([MT].[Unit3Fact], 1)
					ELSE 1 
				END) * [Item].[Qty] ELSE 0 END,
				0, --Order
				0, --OrderQnt
				ISNULL([Item].[Unity], 1),
				 CASE @vatSystem WHEN 2 THEN ISNULL([Item].[Price], 0) /(1+ ([Item].VATValue/100)) ELSE [Item].[Price] END,
				CASE WHEN [Item].[Type]=2 THEN (CASE [Item].[Unity]
					WHEN 2 THEN ISNULL([MT].[Unit2Fact], 1)
					WHEN 3 THEN ISNULL([MT].[Unit3Fact], 1)
					ELSE 1 
				END) * [Item].[Qty] ELSE 0 END, --BonusQnt
				ISNULL([Item].[Discount], 0) AS [Discount],
				0, --BonusDisc
				ISNULL([Item].[Added], 0) AS [Added],
				@currencyValue, --CurrencyVal
				ISNULL([Item].[Note], '') AS [Note],
				0, --Profits
				0, --Num1
				0, --Num2
				0, --Qty2
				0, --Qty3
				ClassPtr, --ClassPtr
				[Item].[ExpirationDate] AS [ExpirationDate],
				[Item].[ProductionDate] AS [ProductionDate],
				0, --Length
				0, --Width
				0, --Height
				newID(),
				ISNULL([Item].[Tax], 0) AS [Tax],
				ISNULL([Item].[VATValue], 0) AS [VATValue],
				@salesBillID, --ParentGUID
				ISNULL([Item].[MatID], 0x0) AS [MatID],
				@currencyID, --CurrencyGUID
				@storeID,--StoreGUID
				ISNULL([Item].[SalesmanID], 0x0) AS [SalesmanID],
				CASE ISNULL([Item].[SpecialOfferID], 0x0) 
					WHEN 0x0 THEN 0
					ELSE CASE [Item].OfferedItem WHEN 0 THEN 1 ELSE 2 END
				END, --SOType
				ISNULL([Item].[SpecialOfferID], 0x0) AS [SpecialOfferID],
				0, --Count
				CASE @GCCTaxEnable WHEN 0 THEN 0 ELSE [TAX].TaxCode END,
				CASE ISNULL([Item].[SpecialOfferID], 0x0)
					WHEN 0x0 THEN 0
					ELSE 1
				END
			FROM [POSOrderItems000] AS [Item]
				INNER JOIN
             [MT000] AS [MT]
				ON([Item].[MatID] = [MT].[Guid])
				LEFT JOIN
			[GCCMaterialTax000] AS [TAX]
				ON([MT].[Guid] = [TAX].[MatGUID])
			WHERE	[Item].[ParentID] = @orderGuid
				AND
				[Item].[State] = 0
				AND
				([Item].[Type] = 0 OR [Item].[Type] = 2)
                AND
                ISNULL([TAX].[TaxType], 1) = 1
				)
	 IF EXISTS(SELECT 1 FROM snc000)
     BEGIN

		-- Save Serail Numbers
		SET @snGuid = NEWID()
		INSERT INTO [TempSn]([ID],  
							[Guid],  
							[SN],  
							[MatGuid],  
							[stGuid],  
							[biGuid]) 
			(SELECT	[Item].[Number],
					@snGuid,
					[Item].[SerialNumber],
					ISNULL([Item].[MatID], 0x0),
					@storeID,--StoreGUID
					[BI].[Guid]
				FROM [POSOrderItems000] AS [Item]
					INNER JOIN [BI000] AS [BI]
					ON([BI].ParentGUID=@salesBillID AND [Item].[MatID] = [BI].[MatGUID] AND [BI].Number = item.Number)
				WHERE ([Item].[ParentID] = @orderGuid
					AND [Item].[State] = 0
					AND	[Item].[Type] = 0				
					AND	LEN([Item].[SerialNumber]) > 0))
				
		EXEC [prcInsertIntoSN] @salesBillID, @snGuid
	END
	-- Save Discounts
	DECLARE @discountID UNIQUEIDENTIFIER,
			@discountNumber FLOAT,
			@discountDiscount FLOAT,
			@discountExtra FLOAT,
			@discountNotes NVARCHAR(250),
			@discountAccountGUID UNIQUEIDENTIFIER
	SET @discountNumber = 0
	DECLARE discountCursor CURSOR FAST_FORWARD
	FOR	SELECT	ISNULL([Discount].[Value], 0) AS [Value],
				ISNULL([Discount].[AccountID], 0x0) AS [AccountID],
				ISNULL([Discount].[Notes], '') AS [Notes]
			FROM [POSOrderDiscount000] AS [Discount]
		WHERE [Discount].[ParentID] = @orderGuid
		      AND
		      [Discount].[OrderType] = 0 -- TOrderTypes::Sales
				
	OPEN discountCursor
	FETCH NEXT 
	FROM discountCursor
	INTO @discountDiscount, @discountAccountGUID, @discountNotes 
	WHILE @@FETCH_STATUS = 0
	BEGIN
		SET @discountID = NEWID()
		SET @discountNumber = @discountNumber + 1
		EXECUTE [prcDiscount_Add] 
						@discountNumber, --Number
						@discountDiscount, --Discount
						0, --Extra
						@currencyValue, --CurrencyVal
						@discountNotes, --Notes
						0, --Flag
						'', --ClassPtr
						@salesBillID, --ParentGUID
						@discountAccountGUID, --AccountGUID
						0x0, --CustomerGUID
						@currencyID, --CurrencyGUID
						0x0, --CostGUID
						0x0 --ContraAccGUID
		FETCH NEXT 
		FROM discountCursor
		INTO @discountDiscount, @discountAccountGUID, @discountNotes 
	END
	CLOSE discountCursor
	DEALLOCATE discountCursor
	DECLARE addedCursor CURSOR FAST_FORWARD
	FOR	SELECT	ISNULL([Added].[Value], 0) AS [Value],
				ISNULL([Added].[AccountID], 0x0) AS [AccountID],
				ISNULL([Added].[Notes], '') AS [Notes]
			FROM [POSOrderAdded000] AS [Added]
		WHERE [Added].[ParentID] = @orderGuid
		      AND
		      [Added].[OrderType] = 0 -- Sales
	OPEN addedCursor
	FETCH NEXT 
	FROM addedCursor
	INTO @discountDiscount, @discountAccountGUID, @discountNotes 
	WHILE @@FETCH_STATUS = 0
	BEGIN
		SET @discountID = NEWID()	
		SET @discountNumber = @discountNumber + 1
		EXECUTE [prcDiscount_Add] 
						@discountNumber, --Number
						0, --Discount
						@discountDiscount, --Extra
						@currencyValue, --CurrencyVal
						@discountNotes, --Notes
						0, --Flag
						'', --ClassPtr
						@salesBillID, --ParentGUID
						@discountAccountGUID, --AccountGUID
						0x0, --CustomerGUID
						@currencyID, --CurrencyGUID
						0x0, --CostGUID
						0x0 --ContraAccGUID
		FETCH NEXT 
		FROM addedCursor
		INTO @discountDiscount, @discountAccountGUID, @discountNotes 
	END
	CLOSE addedCursor
	DEALLOCATE addedCursor
	IF @paymentsPackageRoundedValue > 0
	BEGIN
		SET @discountNumber = @discountNumber + 1
		EXECUTE [prcDiscount_Add]
					@discountNumber, --Number
					@paymentsPackageRoundedValue, --Discount
					0, --Extra
					@currencyValue, --CurrencyVal
					'Round', --Notes
					0, --Flag
					'', --ClassPtr
					@salesBillID, --ParentGUID
					@discountAccountID, --AccountGUID
					0x0, --CustomerGUID
					@currencyID, --CurrencyGUID
					0x0, --CostGUID
					0x0 --ContraAccGUID		
	END
	IF @paymentsPackageRoundedValue < 0
	BEGIN
		SET @discountNumber = @discountNumber + 1
		SET @paymentsPackageRoundedValue = ABS(@paymentsPackageRoundedValue)
		EXECUTE [prcDiscount_Add]
					@discountNumber, --Number
					0, --Discount
					@paymentsPackageRoundedValue, --Extra
					@currencyValue, --CurrencyVal
					'Round', --Notes
					0, --Flag
					'', --ClassPtr
					@salesBillID, --ParentGUID
					@extraAccountID, --AccountGUID
					0x0, --CustomerGUID
					@currencyID, --CurrencyGUID
					0x0, --CostGUID
					0x0 --ContraAccGUID		
	END
	INSERT INTO [BillRel000]
			   ([GUID]
			   ,[Type]
			   ,[BillGUID]
			   ,[ParentGUID]
			   ,[ParentNumber])
		 VALUES(NEWID(), --GUID
				1, --Type
				@salesBillID, --BillGUID
				@orderGuid, --ParentGUID
				@orderNumber) --ParentNumber
	-- use Smart Card so we must get Discount Account from Discount Types
	SET @discountAccountID = 0x0
	
	SELECT @discountAccountID = dt.Account
	FROM posorder000 ord
	INNER JOIN discountcard000 dc ON ord.CustomerID = dc.CustomerGuid
	INNER JOIN DiscountTypesCard000 dtc ON dc.Type = dtc.Guid
	INNER JOIN DiscountTypes000 dt ON dtc.DiscType = dt.Guid
	WHERE ord.Guid = @orderGuid
	
	IF (@discountAccountID <> 0x0)
	BEGIN
		DECLARE @discID [UNIQUEIDENTIFIER]
		SET @discID = 0x0
		
		--unfortune we use the notes field in where clause to distinguish the smart card's discount from other
		SELECT @discID = di.Guid
		FROM di000 di 
		INNER JOIN bu000 bu ON bu.Guid = di.ParentGuid
		WHERE bu.Guid = @salesBillID AND di.Discount > 0 AND di.Notes = 'DiscountCard'
		
		UPDATE di000
		SET  AccountGuid = @discountAccountID
		WHERE GUID = @discID
	END
	-- end Discount Account
	
	IF @autoPost = 1
	BEGIN
		EXECUTE [prcBill_Post1] @salesBillID, 1
	END
	IF @autoEntry = 1
	BEGIN
		EXECUTE [prcBill_GenEntry] @salesBillID, 1, 0, 0, 0, 0, 1, @GCCTaxEnable
	END
	UPDATE [POSOrder000]
	SET [BillNumber] = @salesBillNumber
	WHERE [Guid] = @orderGuid
	RETURN 1 
################################################################################
#END	