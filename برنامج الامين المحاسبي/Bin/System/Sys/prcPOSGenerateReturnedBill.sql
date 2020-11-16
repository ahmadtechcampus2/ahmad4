################################################################################
CREATE PROCEDURE prcPOSGenerateReturnedBill
	@orderGuid [UNIQUEIDENTIFIER], 
    @BillsID  [UNIQUEIDENTIFIER], 
	@payType [INT], 
	@deferredAccount [UNIQUEIDENTIFIER], 
	@checkType [UNIQUEIDENTIFIER], 
	@currencyID [UNIQUEIDENTIFIER], 
	@currencyValue [FLOAT], 
	@deferredCustomer [UNIQUEIDENTIFIER]
AS
	SET NOCOUNT ON
	
	DECLARE @orderNumber [FLOAT],
			@orderType [INT],
            @orderDate [DATETIME],
			@orderNotes [NVARCHAR](250),
			@orderReturnedDiscount [FLOAT],
			@orderReturnedAdded [FLOAT],
			@orderTax [FLOAT],
			@orderCashierID [UNIQUEIDENTIFIER],
			@orderBranchID [UNIQUEIDENTIFIER],
			@costID [UNIQUEIDENTIFIER],
			@customerName [NVARCHAR](250),
			@storeID [UNIQUEIDENTIFIER],
			@discountAccountID [UNIQUEIDENTIFIER],
			@vatSystem [INT],
			@autoPost [BIT],
			@autoEntry [BIT],
			@snGuid [UNIQUEIDENTIFIER],
			@UserNumber [FLOAT],
			@returnSalesBillID [UNIQUEIDENTIFIER],
			@returnSalesBillNumber [FLOAT],
			@returnSalesBillItemID [UNIQUEIDENTIFIER],
			@returnSalesOrderItemsTotal [FLOAT],
			@returnSalesOrderItemsSubTotal [FLOAT],
			@returnSalesOrderItemsDiscount [FLOAT],
			@returnSalesOrderItemsAdded [FLOAT],
			@returnSalesOrderItemsTax [FLOAT],
			@returnSalesBillTypeID [UNIQUEIDENTIFIER],
			@returnSalesBillTotal [FLOAT],
			@GCCTaxEnable [INT],
			@BillCustomerGuid [UNIQUEIDENTIFIER],
			@OrginalBillNumber	[NVARCHAR](250),
			@OrginalBillDate	[datetime],
			@TextFld1 [NVARCHAR](250),
			@TextFld2 [NVARCHAR](250),
			@TextFld3 [NVARCHAR](250),
			@TextFld4 [NVARCHAR](250),
			@CustomerAddressID [UNIQUEIDENTIFIER]

	SELECT @returnSalesBillTypeID = ISNULL(ReturnedID, 0x0)
	FROM posuserbills000
	WHERE [Guid] = @BillsID
	IF @returnSalesBillTypeID = 0x0
		RETURN 0

	SELECT @orderNumber = [Number],
           @orderType = [Type],
           @orderDate = [Date],
		   @orderNotes = ISNULL([Notes], ''),
           @orderTax = ISNULL([Tax], 0),
		   @deferredCustomer = CASE @deferredCustomer WHEN 0x0 THEN ISNULL([CustomerID], 0x0) ELSE @deferredCustomer END,
           @orderCashierID = ISNULL([CashierID], 0x0),
           @orderBranchID = ISNULL([BranchID], 0x0),
		   @OrginalBillNumber = ISNULL([ReturendBillNumber], '0'),
		   @OrginalBillDate	= [ReturendBillDate],
		   @TextFld1 = ISNULL([TextFld1], ''),
		   @TextFld2 = ISNULL([TextFld2], ''),
		   @TextFld3 = ISNULL([TextFld3], ''),
		   @TextFld4 = ISNULL([TextFld4], ''),
		   @costID	 = ISNULL([SalesManID], 0x0),
		   @CustomerAddressID = ISNULL([CustomerAddressID], 0x0)
	FROM [POSOrder000]
	WHERE [Guid] = @orderGuid
	
	IF @@ROWCOUNT <> 1
		RETURN 0

	SELECT @GCCTaxEnable = ISNULL((SELECT value FROM op000 WHERE name = 'AmnCfg_EnableGCCTaxSystem'), 0)
	SELECT @storeID = ISNULL([DefStoreGuid], 0x0),
           @discountAccountID = ISNULL([DefDiscAccGuid], 0x0),
           @vatSystem = CASE @GCCTaxEnable WHEN 1 THEN 1 ELSE ISNULL([VATSystem], 0) END,
           @autoPost = ISNULL([bAutoPost], 0),
           @autoEntry = ISNULL([bAutoEntry], 0),
           @costID = CASE @costID WHEN 0x0 THEN ISNULL(DefCostGUID, 0x0) ELSE @costID END,
		   @BillCustomerGuid = ISNULL(CustAccGuid, 0x0)
	FROM [BT000]
	WHERE [Guid] = @returnSalesBillTypeID
	
	IF @@ROWCOUNT <> 1
		RETURN 0
			
	SELECT @UserNumber = number from us000 where GUID=@orderCashierID
	SELECT @orderReturnedDiscount = SUM(ISNULL([Value], 0))
	FROM [POSOrderDiscount000]
	WHERE [ParentID] = @orderGuid
	      AND
	      [OrderType] = 1 --TOrderTypes::Returned
	
	SELECT @orderReturnedAdded = SUM(ISNULL([Value], 0))
	FROM [POSOrderAdded000]
	WHERE [ParentID] = @orderGuid
	      AND
	      [OrderType] = 1 --TOrderTypes::Returned
	
	SELECT @returnSalesOrderItemsTotal = SUM(CASE @vatSystem WHEN 2 THEN ISNULL([Price], 0) /(1+ (VATValue/100)) ELSE [Price] END * [Qty]),
		   @returnSalesOrderItemsAdded = SUM(ISNULL([Added], 0)),
		   @returnSalesOrderItemsTax = SUM(ISNULL([Tax], 0)),
		   @returnSalesOrderItemsDiscount = SUM(ISNULL([Discount], 0))
	FROM [POSOrderItems000]
	WHERE [POSOrderItems000].[ParentID] = @orderGuid
		  AND
		  [POSOrderItems000].[State] = 0 --IS_NORMAL
		  AND
		  [POSOrderItems000].[Type] = 1 --IT_RETURNED
	IF @@ROWCOUNT <> 1
		RETURN 0
	SET @returnSalesBillTotal = ISNULL(@returnSalesOrderItemsTotal, 0) + ISNULL(@returnSalesOrderItemsAdded, 0) - ISNULL(@returnSalesOrderItemsDiscount,0) + ISNULL(@returnSalesOrderItemsTax,0) - ISNULL(@orderReturnedDiscount,0) + ISNULL(@orderReturnedAdded,0) +ISNULL(@orderTax,0)
	SET @customerName = ''
	IF ISNULL(@deferredCustomer, 0x0) = 0x0	
		SET @deferredCustomer = CASE @GCCTaxEnable WHEN 1 THEN @BillCustomerGuid ELSE 0x0 END
	SELECT @customerName = [CustomerName]
	From [CU000]
	WHERE [Guid] = @deferredCustomer
	
	SELECT @returnSalesBillNumber = dbo.fnGetNextBillNumber(@returnSalesBillTypeID, @orderBranchID);
	SET @returnSalesBillNumber = ISNULL(@returnSalesBillNumber, 1);
		
	SET @returnSalesBillID = NEWID()
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
						[IsPrinted],
						[ReturendBillNumber],
						[ReturendBillDate],
						[CustomerAddressGUID])
	VALUES(@returnSalesBillNumber,--Number
		   @customerName,--Cust_Name
		   @orderDate,--Date
		   @currencyValue,--CurrencyVal
		   @orderNotes,--Notes
		   @returnSalesOrderItemsTotal,--Total
           @payType,--PayType
           ISNULL(@orderReturnedDiscount,0) + ISNULL(@returnSalesOrderItemsDiscount,0),--TotalDisc
           ISNULL(@orderReturnedAdded, 0) + ISNULL(@returnSalesOrderItemsAdded,0),--TotalExtra
           ISNULL(@returnSalesOrderItemsDiscount,0),--ItemsDisc
           0,--BonusDisc
           0,--FirstPay
           0,--Profits
           0,--IsPosted
           1,--Security
           0,--Vendor
           @UserNumber,--SalesManPtr
           @orderBranchID,--Branch
           @returnSalesOrderItemsTax + @orderTax,--VAT
           @returnSalesBillID,--GUID
           @returnSalesBillTypeID,--TypeGUID
           @deferredCustomer,--CustGUID
           @currencyID,--CurrencyGUID
           @storeID,--StoreGUID
           @deferredAccount,--CustAccGUID
           0x0,--MatAccGUID
           0x0,--ItemsDiscAccGUID
           @discountAccountID,--BonusDiscAccGUID
           0x0,--FPayAccGUID
           @costID,--CostGUID
           @orderCashierID,--UserGUID
           @checkType,--CheckTypeGUID
           'Order Number: ''' + CAST(@orderNumber AS NVARCHAR(100)) + '''',--TextFld1
           @TextFld2,--TextFld2
           @TextFld3,--TextFld3
           @TextFld4,--TextFld4
           0,--RecState
           @returnSalesOrderItemsAdded,--ItemsExtra
           0x0,--ItemsExtraAccGUID
           0x0,--CostAccGUID
           0x0,--StockAccGUID
           0x0,--VATAccGUID
           0x0,--BonusAccGUID
           0x0,--BonusContraAccGUID
           0, --IsPrinted
		   @OrginalBillNumber,--ReturendBillNumber
		   @OrginalBillDate,
		   @CustomerAddressID)--ReturendBillDate
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
						[RelatedTo],
						[IsPOSSpecialOffer])
		(SELECT	[Item].[Number] AS [Number],
				(CASE [Item].[Unity]
					WHEN 2 THEN ISNULL([MT].[Unit2Fact], 1)
					WHEN 3 THEN ISNULL([MT].[Unit3Fact], 1)
					ELSE 1 
				END) * [Item].[Qty],
				0, --Order
				0, --OrderQnt
				ISNULL([Item].[Unity], 1),
				CASE @vatSystem WHEN 2 THEN ISNULL([Item].[Price], 0) /(1+ ([Item].VATValue/100)) ELSE [Item].[Price] END,
				0, --BonusQnt
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
				'', --ClassPtr
				[Item].[ExpirationDate] AS [ExpirationDate],
				[Item].[ProductionDate] AS [ProductionDate],
				0, --Length
				0, --Width
				0, --Height
				NEWID(),
				ISNULL([Item].[Tax], 0) AS [Tax],
				ISNULL([Item].[VATValue], 0) AS [VATValue],
				@returnSalesBillID, --ParentGUID
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
				[Item].[BillItemID],
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
				[Item].[Type] = 1
				AND
                ISNULL([TAX].[TaxType], 1) = 1)

	-- SAVE RETURNED BILL RELATIONS
	INSERT INTO BillRelations000 (BillGuid, RelatedBillGuid, IsRefundFromBill)
		SELECT DISTINCT [Item].[RelatedBillID], @returnSalesBillID, 1 FROM [POSOrderItems000] [Item]
			WHERE	[Item].[ParentID] = @orderGuid
					AND
					[Item].[State] = 0
					AND
					[Item].[Type] = 1
					AND
					ISNULL([Item].[RelatedBillID], 0x0) <> 0x0

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
				INNER JOIN [BI000] AS [BI] ON(Item.[MatID] = [BI].[MatGUID] AND BI.Number=Item.Number)
			WHERE	[Item].[ParentID] = @orderGuid
				AND	[Item].[State] = 0
				AND	[Item].[Type] = 1
				AND	[BI].[ParentGUID] = @returnSalesBillID
				AND	LEN([Item].[SerialNumber]) > 0)
				
		EXEC [prcInsertIntoSN] @returnSalesBillID, @snGuid
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
		      [Discount].[OrderType] = 1 -- TOrderTypes::Returned
				
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
						@returnSalesBillID, --ParentGUID
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
		      [Added].[OrderType] = 1 -- TOrderTypes::Returned
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
						@returnSalesBillID, --ParentGUID
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
	INSERT INTO [BillRel000]
			   ([GUID]
			   ,[Type]
			   ,[BillGUID]
			   ,[ParentGUID]
			   ,[ParentNumber])
		 VALUES(NEWID(), --GUID
				2, --Type
				@returnSalesBillID, --BillGUID
				@orderGuid, --ParentGUID
				@orderNumber) --ParentNumber
	IF @autoPost = 1
	BEGIN
		EXECUTE [prcBill_Post1] @returnSalesBillID, 1
	END
	IF @autoEntry = 1
	BEGIN
		EXECUTE [prcBill_GenEntry] @returnSalesBillID, 1, 0, 0, 0, 0, 1, @GCCTaxEnable
	END
	RETURN 1 

################################################################################
#END	