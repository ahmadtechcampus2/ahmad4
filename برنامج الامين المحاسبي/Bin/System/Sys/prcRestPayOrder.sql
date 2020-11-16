###############################################
CREATE PROCEDURE prcRestPayOrder
	@orderGuid [UNIQUEIDENTIFIER], 
	@BillTypeID [UNIQUEIDENTIFIER], 
	@MediatorCustID [UNIQUEIDENTIFIER], 
	@orderPaymentsPackageID  [UNIQUEIDENTIFIER], 
	@PayType [INT], 
	@CostID [UNIQUEIDENTIFIER] = 0x0, 
	@DefCashAcc [UNIQUEIDENTIFIER] = 0x0, 
	@GeneratedNote [NVARCHAR](250) = '' 
AS 
SET NOCOUNT ON
DECLARE	@orderTotal [FLOAT], 
		@Date [DATETIME], 
		@orderCashierID [UNIQUEIDENTIFIER], 
		@BranchID [UNIQUEIDENTIFIER], 
	    @currencyID [UNIQUEIDENTIFIER], 
		@currencyValue [FLOAT], 
		@currencyPaid [FLOAT], 
		@deferredAmount [FLOAT], 
		@deferredAccount [UNIQUEIDENTIFIER], 
		@cashAccountID [UNIQUEIDENTIFIER], 
		@language INT, 
		@UserNumber [FLOAT], 
		@salesBillID [UNIQUEIDENTIFIER], 
		@salesBillNumber [FLOAT], 
		@BillTypeAbbrev NVARCHAR(250), 
		@BillTypeLatinAbbrev NVARCHAR(250), 
		@ceGuid  [UNIQUEIDENTIFIER], 
		@ceNote  NVARCHAR(250), 
		@done INT,
		@deferredCust [UNIQUEIDENTIFIER]

CREATE TABLE #CurrencyItems 
( 
	Number [INT] ,  
	Debit [FLOAT], 
	Credit [FLOAT], 
	AccountID [UNIQUEIDENTIFIER], 
	ContraID [UNIQUEIDENTIFIER],
	CostID	[UNIQUEIDENTIFIER], 
	CurrencyID	[UNIQUEIDENTIFIER], 
	CurrencyValue [FLOAT], 
	UserNumber [FLOAT], 
	Note NVARCHAR(250) COLLATE ARABIC_CI_AI,
	CustID [UNIQUEIDENTIFIER]
) 
CREATE TABLE #CheckItems 
( 
	PaymentGuid UNIQUEIDENTIFIER,  
	Paid [FLOAT], 
	Note NVARCHAR(250) COLLATE ARABIC_CI_AI, 
	Number NVARCHAR(250) COLLATE ARABIC_CI_AI, 
	IntNumber  NVARCHAR(250) COLLATE ARABIC_CI_AI, 
	DebitAcc [UNIQUEIDENTIFIER], 
	CreditAcc [UNIQUEIDENTIFIER], 
	TypeAcc [UNIQUEIDENTIFIER], 
	CurrencyID [UNIQUEIDENTIFIER],
	CurrencyValue [FLOAT], 
	CustID	[UNIQUEIDENTIFIER]
) 
SELECT 	@Date = Orders.Closing,  
		@BranchID = ISNULL(Orders.BranchID, 0x0), 
		@orderCashierID = ISNULL(Orders.[CashierID], 0x0) ,
		@deferredAccount = ISNULL(DeferredAccountID, 0x0),
	    @deferredCust  = ISNULL(CustomerID, 0x0)
FROM RestOrder000 Orders  
WHERE Orders.GUID=@orderGuid 

IF @@ROWCOUNT <> 1 
	return -10 
UPDATE RestOrder000 Set  
	PaymentsPackageId=@orderPaymentsPackageID, 
	Notes=CASE WHEN LEN(Notes)>0 THEN Notes + ' ' + @GeneratedNote ELSE @GeneratedNote END
WHERE GUID=@orderGuid 
SET @language = [dbo].[fnConnections_GetLanguage]() 
SELECT @UserNumber = number from us000 where GUID=@orderCashierID 
SELECT @BillTypeAbbrev = ISNULL([Abbrev], ''),   
	   @BillTypeLatinAbbrev = ISNULL([LatinAbbrev], ''), 
	   @cashAccountID = CASE WHEN ISNULL(@DefCashAcc, 0x0)=0x0 THEN [dbo].fnGetDAcc([DefCashAccGUID]) ELSE @DefCashAcc END 
FROM BT000  
WHERE [Guid] = @BillTypeID  
IF @@ROWCOUNT <> 1 
	return -12 
SET @done = 0 
SELECT TOP 1 @currencyID = ISNULL([Value], 0x0)  
FROM [OP000] WHERE [Name] = 'AmnCfg_DefaultCurrency' 
SELECT @currencyValue = ISNULL([CurrencyVal], 0)  
FROM [MY000] WHERE [Guid] = @currencyID 
IF @PayType = 1 
BEGIN 
	SELECT	@currencyID = ISNULL([CurrencyID], @currencyID),  
		@currencyValue = ISNULL([Equal], @currencyValue) 
	FROM [POSPaymentsPackageCurrency000] 
	WHERE	[ParentID] = @orderPaymentsPackageID AND Paid<>0 
	EXEC @done = prcRestGenerateSaleBill @orderGuid, @BillTypeID, 0, @cashAccountID, 0x0, @currencyID, @currencyValue, @CostID, 0x0 
END  
ELSE IF @PayType = 2  
BEGIN  
	EXEC @done = prcRestGenerateSaleBill @orderGuid, @BillTypeID, 1, @deferredAccount, 0x0, @currencyID, @currencyValue, @CostID, @deferredCust		 
END 
ELSE IF @PayType = 3 
BEGIN 
	
	IF (@deferredAccount <> 0x0) 
	BEGIN
		SET @MediatorCustID = @deferredCust
	END
	ELSE
	BEGIN
		SELECT @deferredAccount = [AccountGUID]
		FROM cu000 WHERE [GUID] = @MediatorCustID
	END

	EXECUTE @done = prcRestGenerateSaleBill @orderGuid, @BillTypeID, 1, @deferredAccount, 0x0, @currencyID, @currencyValue, @CostID, @MediatorCustID 
	 
	IF @done=0 
		RETURN -16 
	SELECT	@salesBillID = [Guid],  
			@salesBillNumber = [Number]  
	FROM [BU000] 
	WHERE [Guid] = (SELECT [BillGUID] 
					FROM [BillRel000]  
					WHERE [ParentGuid] = @orderGuid)  
	IF ((@language <> 0) AND (LEN(@BillTypeLatinAbbrev) <> 0))  
		SET @ceNote = @BillTypeLatinAbbrev  
	ELSE  
		SET @ceNote = @BillTypeAbbrev  
	  
	Set @ceNote =  @ceNote + ' [' + CAST(@salesBillNumber AS NVARCHAR(250)) + ']'  
	Set @ceGuid=newid() 
	INSERT INTO #CurrencyItems(Number, Debit,Credit,Note,CurrencyValue,CurrencyID,UserNumber,AccountID,CostID,ContraID,CustID)
		SELECT	 
				my.Number AS Number,
				ABS(ISNULL(Cur.[Paid], 0) * ISNULL(Cur.[Equal], 0)) AS Debit,  
				0.0 AS Credit, 
				[dbo].[fnStrings_get]('POS\CASH', @language) AS Note, 
				ISNULL(Cur.[Equal], 0) AS [CurrencyValue],  
				ISNULL(Cur.[CurrencyID], 0x0) AS [CurrencyGuid], 
				@UserNumber AS UserNumber, 
				@cashAccountID AS AccountID, 
				0x0 AS Cost, 
				@deferredAccount AS contra,
				0x0 AS CustID
			FROM [POSPaymentsPackageCurrency000] Cur
				INNER JOIN my000 my ON my.Guid = Cur.CurrencyID
			WHERE [ParentID] = @orderPaymentsPackageID AND [Paid] > 0

			UNION ALL
			
			SELECT	
			    my.Number AS Number,
				0.0 AS Debit,  
				ABS(ISNULL(Cur.[Paid], 0) * ISNULL(Cur.[Equal], 0)) AS Credit, 
				[dbo].[fnStrings_get]('POS\CASH', @language)  AS Note, 
				ISNULL(Cur.[Equal], 0) AS [CurrencyValue],  
				ISNULL(Cur.[CurrencyID], 0x0) AS [CurrencyGuid], 
				@UserNumber AS UserNumber, 
				@deferredAccount AS AccountID, 
				0x0 AS Cost, 
				@cashAccountID AS contra,
				@MediatorCustID AS CustID		
			FROM [POSPaymentsPackageCurrency000] Cur  
				INNER JOIN my000 my ON my.Guid = Cur.CurrencyID
			WHERE Cur.[ParentID] = @orderPaymentsPackageID AND Cur.[Paid] > 0

			UNION ALL
			
			SELECT	 
			    my.Number AS Number,
				ABS(ISNULL(Cur.[Returned], 0) * ISNULL(Cur.[Equal], 0)) AS Debit,  
				0.0  AS Credit, 
				'Returned' As Note, 
				ISNULL(Cur.[Equal], 0) AS [CurrencyValue],  
				ISNULL(Cur.[CurrencyID], 0x0) AS [CurrencyGuid], 
				@UserNumber AS UserNumber, 
				@deferredAccount AS AccountID, 
				0x0 AS Cost, 
				@cashAccountID AS contra,
				@MediatorCustID AS CustID					
			FROM [POSPaymentsPackageCurrency000] AS Cur
				INNER JOIN my000 my ON my.Guid = Cur.CurrencyID
			WHERE Cur.[ParentID] = @orderPaymentsPackageID AND Cur.[Returned] > 0
			
			UNION ALL

			SELECT	
				my.Number AS Number,
				0.0 AS Debit,  
				ABS(ISNULL(Cur.[Returned], 0) * ISNULL(Cur.[Equal], 0)) AS Credit, 
				'Returned' AS Note, 
				ISNULL(Cur.[Equal], 0) AS [CurrencyValue],  
				ISNULL(Cur.[CurrencyID], 0x0) AS [CurrencyGuid], 
				@UserNumber AS UserNumber, 
				@cashAccountID as AccountID, 
				0x0 AS Cost, 
				@deferredAccount AS contra,
				0x0 AS CustID		
			FROM [POSPaymentsPackageCurrency000] AS Cur
			INNER JOIN my000 my ON my.Guid = Cur.CurrencyID
			WHERE Cur.[ParentID] = @orderPaymentsPackageID AND Cur.[Returned] > 0

			UNION ALL 
			
			SELECT
				0 AS Number,
				ISNULL(PointsValue, 0),
				0,
				[dbo].[fnStrings_get]('POS\LOYALTY_POINTS', @language),
				@currencyValue,
				@currencyID,
				@UserNumber,
				AccountGUID,
				0x0,
				@cashAccountID,
				@MediatorCustID
			FROM [POSPaymentsPackagePoints000]
			WHERE [ParentGUID] = @orderPaymentsPackageID

			UNION ALL

			SELECT
				0 AS Number,
				0,
				ISNULL(PointsValue, 0),
				[dbo].[fnStrings_get]('POS\LOYALTY_POINTS', @language),
				@currencyValue,
				@currencyID,
				@UserNumber,
				@cashAccountID,
				0x0,
				AccountGUID,
				0x0
			FROM [POSPaymentsPackagePoints000]
			WHERE [ParentGUID] = @orderPaymentsPackageID
			
			ORDER BY Number

			
	IF(EXISTS(SELECT TOP 1 * FROM #CurrencyItems)) 
	BEGIN
		EXEC prcRestGenerateEntry @ceGuid, @Date, @currencyID, @BranchID, @currencyValue, @ceNote 
	END
	INSERT INTO #CheckItems 
	SELECT		Guid,
				ISNULL([Paid], 0), 
				ISNULL([Notes], ''), 
				@ceNote, 
				ISNULL([Number], ''), 
				ISNULL([DebitAccID], 0x0), 
				@deferredAccount,  
				ISNULL([Type], 0x0),
				ISNULL([CurrencyID], @currencyID),
				ISNULL([CurrencyValue], @currencyValue),
				@MediatorCustID
			FROM [POSPaymentsPackageCheck000] 
		WHERE [ParentID] = @orderPaymentsPackageID 
		
	IF(EXISTS(SELECT TOP 1 * FROM #CheckItems)) 
		EXEC prcRestGenerateChecks @Date, @BranchID, @salesBillID, @currencyID, @currencyValue, @language 
END 
DROP TABLE #CurrencyItems 
DROP TABLE #CheckItems 
RETURN @Done 
#########################################################
CREATE PROCEDURE prcRestGenerateSaleBill
	@orderGuid [UNIQUEIDENTIFIER],
	@salesBillTypeID [UNIQUEIDENTIFIER],
	@payType [INT],
	@deferredAccount [UNIQUEIDENTIFIER],
	@checkType [UNIQUEIDENTIFIER],
	@currencyID [UNIQUEIDENTIFIER],
	@currencyValue [FLOAT],
	@CostID [UNIQUEIDENTIFIER],
	@mediatorCustID [UNIQUEIDENTIFIER] = 0x0
AS
	SET NOCOUNT ON 
	
	DECLARE @orderNumber                  [FLOAT],
	        @orderDate                    DATETIME,
	        @orderNotes                   [NVARCHAR](250),
	        @orderSalesDiscount           [FLOAT],
	        @orderSalesAdded              [FLOAT],
	        @orderCustomerGuid            [UNIQUEIDENTIFIER],
	        @orderAccountGuid             [UNIQUEIDENTIFIER],	-- This Account Not Used 
	        @orderCashierID               [UNIQUEIDENTIFIER],
	        @orderBranchID                [UNIQUEIDENTIFIER],
	        @Codes                        NVARCHAR(250),
	        @customerName                 [NVARCHAR](250),
	        @billAccountID                [UNIQUEIDENTIFIER],
	        @discountAccountID            [UNIQUEIDENTIFIER],
	        @extraAccountID               [UNIQUEIDENTIFIER],
	        @vatSystem                    [INT],
	        @autoPost                     [BIT],
	        @autoEntry                    [BIT],
	        @snGuid                       [UNIQUEIDENTIFIER],
	        @salesBillID                  [UNIQUEIDENTIFIER],
	        @salesCostID                  [UNIQUEIDENTIFIER],
	        @salesBillItemID              [UNIQUEIDENTIFIER],
	        @salesBillNumber              [FLOAT],
	        @salesOrderItemsTotal         [FLOAT],
	        @salesOrderItemsTotalForTax   [FLOAT] = 0,
	        @salesOrderItemsSubTotal      [FLOAT],
	        @salesOrderItemsDiscount      [FLOAT],
	        @salesOrderItemsAdded         [FLOAT],
	        @salesBillTotal               [FLOAT],
	        @UserNumber                   [FLOAT],
	        @storeID                      [UNIQUEIDENTIFIER],
	        @paymentsPackageRoundedValue  [FLOAT],
	        @CostItemID                   [UNIQUEIDENTIFIER],
			@salesOrderTax				  [FLOAT],
			@GCCTaxEnable				  [INT],
			@GCCVatValue				  [FLOAT],
			@BillCustomerGuid			  [UNIQUEIDENTIFIER],
			@mediatorCustName			  [NVARCHAR](250),
			@CustomerAddressGUID		  [UNIQUEIDENTIFIER],
			@OrderDriverAccID			  [UNIQUEIDENTIFIER] = 0x0,
			@DeliveringFees				  [FLOAT] = 0.0,
			@IsDeliveryOrder			  [BIT] 
			
	SELECT @GCCTaxEnable = ISNULL((SELECT value FROM op000 WHERE name = 'AmnCfg_EnableGCCTaxSystem'), 0)

	SELECT @orderNumber = [Ordernumber],
	       @orderDate = [Closing],
		   @orderNotes = ISNULL([Notes], ''), -- CASE WHEN (ro.Guid = rt.ParentID) THEN  'ÿ·» —ﬁ„ ['+ Convert(nvarchar,ordernumber)+']'+'ÿ«Ê·… —ﬁ„ ['+ Convert(nvarchar,rt.Code)+ ']'  ELSE ISNULL([Notes], '') END,
	       @orderCustomerGuid = ISNULL([CustomerID], 0x0),
	       @orderAccountGuid = ISNULL([DeferredAccountID], 0x0),
	       @orderCashierID = ISNULL([CashierID], 0x0),
	       @orderBranchID = ISNULL([BranchID], 0x0),
	       @orderSalesDiscount = ISNULL(Discount, 0),
	       @orderSalesAdded = ISNULL(Added, 0) ,
		   @salesOrderTax = ISNULL(Tax, 0),
		   @salesBillNumber = ISNULL(BillNumber, 0),
		   @CustomerAddressGUID = ISNULL([CustomerAddressID], 0x0),
		   @DeliveringFees   = ro.[DeliveringFees],
		   @IsDeliveryOrder = CASE 
									WHEN [Type] = 3 THEN  1
									ELSE  0
							  END
	FROM RestOrder000 ro -- LEFT JOIN (SELECT TOP 1 * FROM  RestOrderTable000 WHERE ParentID = @orderGuid ) rt on rt.ParentID = ro.Guid
	WHERE  ro.[Guid] = @orderGuid 

	IF @@ROWCOUNT <> 1
	    RETURN -1

	SELECT @UserNumber = number
	FROM   us000
	WHERE  GUID = @orderCashierID
	
	SELECT @salesOrderItemsAdded = ISNULL(SUM(ISNULL([Added], 0)) + SUM(ISNULL([Tax], 0)), 0),
	       @salesOrderItemsDiscount = ISNULL(SUM(ISNULL([Discount], 0)), 0),
	       @salesOrderItemsTotal = ISNULL(SUM(ISNULL([Qty], 0) * ISNULL([Price], 0)), 0),
		   @GCCVatValue = CASE @GCCTaxEnable WHEN 1 THEN SUM(ISNULL([Vat], 0)) ELSE 0 END
	FROM   [RestOrderItem000]
	WHERE  [ParentID] = @orderGuid
	       AND [Type] NOT IN (1, 2, 3, 4)
	
	SET @salesBillTotal = @salesOrderItemsTotal - @salesOrderItemsDiscount - @orderSalesDiscount + @orderSalesAdded + @salesOrderTax

	SELECT @paymentsPackageRoundedValue = ISNULL([RoundedValue], 0)
	FROM   [POSPaymentsPackage000]
	WHERE  [Guid] = (
	           SELECT [PaymentsPackageID]
	           FROM   [RestOrder000]
	           WHERE  [Guid] = @orderGuid
	       )
	
	IF @paymentsPackageRoundedValue > 0
	BEGIN
	    SET @orderSalesDiscount = @orderSalesDiscount + @paymentsPackageRoundedValue
	END
	
	IF @paymentsPackageRoundedValue < 0
	BEGIN
	    SET @orderSalesAdded = @orderSalesAdded + @salesOrderTax + ABS(@paymentsPackageRoundedValue)
	END
	
	SELECT @billAccountID = ISNULL([DefBillAccGUID], 0x0),
	       @deferredAccount = CASE 
	                               WHEN ISNULL(@deferredAccount, 0x0) <> 0x0 THEN 
	                                    @deferredAccount
	                               ELSE [dbo].fnGetDAcc([DefCashAccGUID])
	                          END,
	       @discountAccountID = ISNULL([DefDiscAccGuid], 0x0),
	       @extraAccountID = ISNULL([DefExtraAccGuid], 0x0),
	       @vatSystem = ISNULL([VATSystem], 0),
	       @autoPost = ISNULL([bAutoPost], 0),
	       @autoEntry = ISNULL([bAutoEntry], 0),
	       @StoreID = ISNULL([DefStoreGUID], 0x0),
	       @salesCostID = ISNULL(DefCostGUID, 0x0),
	       @CostItemID = CASE 
	                          WHEN bCostToItems <> 0 THEN CASE 
	                                                           WHEN @CostID <>
	                                                                0x0 THEN @CostID
	                                                           ELSE ISNULL(DefCostGUID, 0x0)
	                                                      END
	                          ELSE 0x0
	                     END,
			@BillCustomerGuid = ISNULL(CustAccGuid, 0x0)
	FROM   [BT000]
	WHERE  [Guid] = @salesBillTypeID 
	
	IF @@ROWCOUNT <> 1
	BEGIN
	    RETURN -2
	END

	IF(@GCCTaxEnable = 1 AND @orderCustomerGuid = 0x0)
		SET @orderCustomerGuid = @BillCustomerGuid
	
	SET @customerName = '' 
	
	IF ISNULL(@orderCustomerGuid, 0x0) = 0x0
	    SELECT @orderCustomerGuid = GUID
	    FROM   cu000
	    WHERE  AccountGUID = @deferredAccount

	IF ISNULL(@orderCustomerGuid, 0x0) <> 0x0
	BEGIN
	    SELECT @customerName = [CustomerName]
	    FROM   [CU000]
	    WHERE  [Guid] = @orderCustomerGuid
	END

	IF(ISNULL(@mediatorCustID, 0x0) <> 0x0) 
	BEGIN
		SELECT @mediatorCustName = [CustomerName]
		  FROM [cu000]
		 WHERE [GUID] = @mediatorCustID
	END

	SET @Codes = 'Tables : ' 
	SELECT @Codes = @Codes + ', ' + Code
	FROM   restordertable000
	WHERE  ParentID = @orderGuid
	
	IF @@ROWCOUNT = 0
	BEGIN
	    SET @Codes = ''
	END 
	
	IF @salesBillNumber < 1
	BEGIN
		SELECT @salesBillNumber = dbo.fnGetNextBillNumber(@salesBillTypeID, @orderBranchID);
		SET @salesBillNumber = ISNULL(@salesBillNumber, 1);
	END
	SET @salesBillID = NEWID();

	INSERT INTO [BU000]
	  (
	    [Number],
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
		[CustomerAddressGUID]
	  )
	VALUES
	  (
	    @salesBillNumber,	--Number 
	    CASE ISNULL(@mediatorCustID, 0x0) WHEN 0x0 THEN @customerName ELSE @mediatorCustName END,	--Cust_Name 
	    @orderDate,	--Date  
	    @currencyValue,	--CurrencyVal 
	    @orderNotes,	--Notes 
	    @salesOrderItemsTotal,	--Total 
	    @payType,	--PayType 
	    @orderSalesDiscount + @salesOrderItemsDiscount,	--TotalDisc 
	    @orderSalesAdded + @salesOrderTax + @salesOrderItemsAdded + @DeliveringFees,	--TotalExtra 
	    @salesOrderItemsDiscount,	--ItemsDisc 
	    0,	--BonusDisc 
	    0,	--FirstPay 
	    0,	--Profits 
	    0,	--IsPosted 
	    1,	--Security 
	    0,	--Vendor 
	    @UserNumber,	--SalesManPtr 
	    @orderBranchID,	--Branch 
	    @GCCVatValue,	--VAT 
	    @salesBillID,	--GUID 
	    @salesBillTypeID,	--TypeGUID 
	    CASE ISNULL(@mediatorCustID, 0x0) WHEN 0x0 THEN @orderCustomerGuid ELSE @mediatorCustID END,	--CustGUID 
	    @currencyID,	--CurrencyGUID 
	    @storeID,	--StoreGUID 
	    @deferredAccount,	--CustAccGUID 
	    0x0,	--MatAccGUID 
	    0x0,	--ItemsDiscAccGUID 
	    @discountAccountID,	--BonusDiscAccGUID 
	    0x0,	--FPayAccGUID 
	    CASE 
	         WHEN @CostID = 0x0 THEN @salesCostID
	         ELSE @CostID
	    END,	--CostGUID 
	    @orderCashierID,	--UserGUID 
	    @checkType,	--CheckTypeGUID 
	    'Order Number: ''' + CAST(@orderNumber AS NVARCHAR(100)) + '''',	--TextFld1 
	    @Codes,	--TextFld2 
	    '',	--TextFld3 
	    '',	--TextFld4 
	    0,	--RecState 
	    @salesOrderItemsAdded,	--ItemsExtra 
	    0x0,	--ItemsExtraAccGUID 
	    0x0,	--CostAccGUID 
	    0x0,	--StockAccGUID 
	    0x0,	--VATAccGUID 
	    0x0,	--BonusAccGUID 
	    0x0,
		@CustomerAddressGUID
	  )--BonusContraAccGUID
	   --Add Bill Items 
	INSERT INTO [bi000]
	  (
	    [Number],
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
		[TaxCode])
		(SELECT [Item].[Number] AS [Number],
	              CASE 
	                   WHEN [Item].[Type] <> 2 THEN (
	                            CASE [Item].[Unity]
	                                 WHEN 2 THEN ISNULL([MT].[Unit2Fact], 1)
	                                 WHEN 3 THEN ISNULL([MT].[Unit3Fact], 1)
	                                 ELSE 1
	                            END
	                        ) * [Item].[Qty]
	                   ELSE 0
	              END,
	              0,	--Order 
	              0,	--OrderQnt 
	              ISNULL([Item].[Unity], 1),
	              ISNULL([Item].[Price], 0),
	              CASE 
	                   WHEN [Item].[Type] = 2 THEN (
	                            CASE [Item].[Unity]
	                                 WHEN 2 THEN ISNULL([MT].[Unit2Fact], 1)
	                                 WHEN 3 THEN ISNULL([MT].[Unit3Fact], 1)
	                                 ELSE 1
	                            END
	                        ) * [Item].[Qty]
	                   ELSE 0
	              END,	--BonusQnt 
	              ISNULL([Item].[Discount], 0) AS [Discount],
	              0,	--BonusDisc 
	              ISNULL([Item].[Added], 0) AS [Added],
	              @currencyValue,	--CurrencyVal 
	              ISNULL([Item].[Note], '') AS [Note],
	              0,	--Profits 
	              0,	--Num1 
	              0,	--Num2 
	              0,	--Qty2 
	              0,	--Qty3 
	              '',	--ClassPtr 
	              '1/1/1980',	--[ExpirationDate] 
	              '1/1/1980',	--[ProductionDate] 
	              0,	--Length 
	              0,	--Width 
	              0,	--Height 
	              item.guid,
	              ISNULL([Item].[Vat], 0) AS [VAT],
				  ISNULL([Item].[VatRatio], 0) AS [VatRatio],
	              @salesBillID,	--ParentGUID 
	              ISNULL([Item].[MatID], 0x0) AS [MatID],
	              @currencyID,	--CurrencyGUID 
	              @storeID,	--StoreGUID 
	              @CostItemID,
	              0,	--SOType 
	              ISNULL([Item].[SpecialOfferID], 0x0) AS [SpecialOfferID],
	              0, --Count
				  CASE @GCCTaxEnable WHEN 0 THEN 0 ELSE [TAX].TaxCode END
	       FROM   [RestOrderItem000] AS [Item]
	              INNER JOIN [MT000] AS [MT]
	                   ON  ([Item].[MatID] = [MT].[Guid])
				  LEFT JOIN GCCMaterialTax000 AS [TAX]
					   ON ([MT].[Guid] = [TAX].[MatGUID])
	       WHERE  [Item].[ParentID] = @orderGuid
	              AND [Item].[Type] IN (0, 2, 5)
				  AND ISNULL([TAX].[TaxType], 1) = 1
	   )
	   
	   SELECT 
		   @OrderDriverAccID = rd.[AccountGUID]
		FROM RestOrder000 ro 
			 INNER JOIN vwRestDriver rd on rd.GUID = ro.GuestID
		WHERE  ro.[Guid] = @orderGuid  
	DECLARE @discountNumber INT = 0
	IF @IsDeliveryOrder = 1 AND @DeliveringFees > 0
	BEGIN 
		IF (@OrderDriverAccID = 0x0)
			SET @OrderDriverAccID = @extraAccountID
		
		SET @discountNumber = @discountNumber + 1
	        
	    EXECUTE [prcDiscount_Add] @discountNumber, --Number 
	    0, --Discount 
	    @DeliveringFees, --Extra 
	    @currencyValue, --CurrencyVal 
	    @orderNotes, --Notes 
	    0, --Flag 
	    '', --ClassPtr 
	    @salesBillID, --ParentGUID 
	    @OrderDriverAccID, --AccountGUID
		0x0, --CustomerGUID
	    @currencyID, --CurrencyGUID 
	    0x0, --CostGUID 
	    0x0 --ContraAccGUID
	END
	-- Save Discounts 
	DECLARE @discountID           UNIQUEIDENTIFIER,
	        @discountDiscount     FLOAT,
	        @discountExtra        FLOAT,
	        @discountType         INT,
	        @discountNotes        NVARCHAR(250),
	        @discountAccountGUID  UNIQUEIDENTIFIER,
	        @PaerentTaxID         UNIQUEIDENTIFIER,
	        @TaxesCalcMethod      BIT,
			@taxes				  FLOAT = 0.0,
			@IsAded				  BIT,
			@IsDisc				  BIT,
			@IsApplyOnPrevTax	  BIT, 
			@DiscTaxGUID		  UNIQUEIDENTIFIER,
			@diCategory           INT,
			@Number				  INT
	
	DECLARE discountCursor CURSOR FAST_FORWARD 
	FOR SELECT [GUID], [Type],
	                [Value],
	               [AccountID],
	              [Notes],
	               [ParentTaxID],
				   [IsAddClc],
				   [IsDiscountClc],
				   [IsApplayOnPrevTaxes],
				   [diCategory],
				   [Number] FROM 
	    ((
	        SELECT [GUID], [Type] AS [Type],
	               CASE 
	                    WHEN IsPercent = 1 THEN @salesOrderItemsTotal * [Value] 
	                         /
	                         100.0
	                    ELSE [Value]
	               END AS [Value],
	               [AccountID] AS [AccountID],
	               [Notes] AS [Notes],
	               ParentTaxID,
				   [IsAddClc],
				   [IsDiscountClc],
				   [IsApplayOnPrevTaxes],
				   0 AS [diCategory],
				   Number AS [Number]
	        FROM   RestDiscTax000
	        WHERE  ParentID = @orderGuid
	               AND (ISNULL(ParentTaxID, 0X0) = 0x0)
	    ) UNION ALL (
	        SELECT 0x0 , CASE 
	                    WHEN @paymentsPackageRoundedValue > 0 THEN 0
	                    ELSE 1
	               END AS [Type],
	               ABS(@paymentsPackageRoundedValue) AS [Value],
	               0x0 AS [AccountID],
	               'Round' [Notes],
	               0X0,
				   1,
				   1,
				   0,
				   1 AS [diCategory],
				   1 AS [Number]

	        WHERE  @paymentsPackageRoundedValue <> 0
	    )
	    UNION ALL (
	        SELECT 
				   [GUID],
				   [Type],
	               [Value],
	               [AccountID],
	               [Notes],
	               ParentTaxID,
				   [IsAddClc],
				   [IsDiscountClc],
				   [IsApplayOnPrevTaxes],
				   2 AS [diCategory],
				   Number AS [Number]
	        FROM   (
	                   SELECT DISTINCT TOP 100000 RD.[GUID], RD.[Type],
	                          CASE 
-- ParentTaxID  ›Ï Õ«·… ﬂ«‰ 0x0  «„«  –«« ﬂ«‰  €Ì— –«·ﬂ „⁄‰«Â« «‰Â« ÷—Ì»…  ›Ï Õ«·… ﬂ«‰  «·ﬁÌ„… «·„÷«›… ⁄»«—Â ⁄‰ ÷—Ì»… ›ﬁÿ Ê«·–Ï ÌÊ÷Õ ﬂÊ‰ «·ﬁÌ„… «·„÷«›… ⁄»«—Â ⁄‰ ÷—Ì»… ÂÊ ﬁÌ„ «·Õﬁ· 
--	IsPercent = 0  --> mean that value type is 		IsPercent ‰”»…
-- 	IsPercent = 1  --> mean that value type is 		value	ﬁÌ„…		 
	                               WHEN RT.IsPercent = 0 THEN RT.[Value] /100
	                               ELSE RT.[Value]
	                          END AS [Value],
	                          RD.[AccountID] AS [AccountID],

							  CASE 		 
	                               WHEN RD.[Notes] = '' THEN RT.[Name]
								 ELSE RD.[Notes] + ' - ' +RT.[Name]
	                          END AS [Notes],

	                          RD.ParentTaxID,
							  RT.IsAddClc,
							  RT.IsDiscountClc,
							  RT.IsApplayOnPrevTaxes ,
	                          RT.Number Number
	                   FROM   RestDiscTax000 RD
	                          INNER JOIN RestTaxes000 rt
	                               ON  RT.Guid = RD.ParentTaxID
	                   WHERE  RD.ParentID = @orderGuid
	                          AND ISNULL(RD.ParentTaxID, 0X0) <> 0x0
	                   ORDER BY
	                          rt.Number
	               ) AS test
	    )) AS diItems
		ORDER BY diCategory, Number
	
	OPEN discountCursor 
	FETCH NEXT 
	FROM discountCursor 
	INTO @DiscTaxGUID , @discountType, @discountDiscount, @discountAccountGUID, @discountNotes , 
	@PaerentTaxID, @IsAded, @IsDisc, @IsApplyOnPrevTax, @diCategory, @Number
	WHILE @@FETCH_STATUS = 0
	BEGIN
  IF (ISNULL(@PaerentTaxID, 0X0) <> 0X0 )
	    BEGIN
	        IF (@discountDiscount < 1)
	        BEGIN
	            SET @discountDiscount = (@salesOrderItemsTotal + ((@DeliveringFees + @orderSalesAdded) * @IsAded) - (@orderSalesDiscount * @IsDisc) + (@taxes) * @IsApplyOnPrevTax) * (@discountDiscount) 
				SET @taxes = @taxes + @discountDiscount
	        END
	    END
	    
	    
	    SET @discountID = NEWID() 
	    IF @discountType = 0
	    BEGIN
	        SET @discountNumber = @discountNumber + 1 
	        
	        EXECUTE [prcDiscount_Add] @discountNumber, --Number 
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
	    END
	    ELSE
	    BEGIN
	        SET @discountNumber = @discountNumber + 1 
	        EXECUTE [prcDiscount_Add] @discountNumber, --Number 
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
	    END 

		IF (ISNULL(@DiscTaxGUID,0x0) <> 0x0)
		BEGIN
			UPDATE RestDiscTax000 
			SET CalculatedValue = @discountDiscount
			WHERE GUID = @DiscTaxGUID
		END

	    FETCH NEXT FROM discountCursor 
	    INTO @DiscTaxGUID , @discountType, @discountDiscount, @discountAccountGUID, @discountNotes, 
	    @PaerentTaxID, @IsAded, @IsDisc, @IsApplyOnPrevTax, @diCategory, @Number
	END 
	CLOSE discountCursor 
	DEALLOCATE discountCursor 
	INSERT INTO [BillRel000]
	  (
	    [GUID],
	    [Type],
	    [BillGUID],
	    [ParentGUID],
	    [ParentNumber]
	  )
	VALUES
	  (
	    NEWID(),	--GUID 
	    1,	--Type 
	    @salesBillID,	--BillGUID 
	    @orderGuid,	--ParentGUID 
	    @orderNumber
	  ) --ParentNumber 
	IF @autoPost = 1
	BEGIN
	    EXECUTE [prcBill_Post1] @salesBillID, 1
	END
	
	IF @autoEntry = 1
	BEGIN
	    EXECUTE [prcBill_GenEntry] @salesBillID, 1, 0, 0, 0, 0, 1, @GCCTaxEnable
	END
	
	UPDATE [RestOrder000]
	SET    [BillNumber] = @salesBillNumber
	WHERE  [Guid] = @orderGuid
	
	RETURN 1 
#########################################################
CREATE Procedure prcRestDistributeAccEn
	@entryGUID UNIQUEIDENTIFIER
AS
WHILE 
	EXISTS
	(
		SELECT * FROM [en000] [e] 
			INNER JOIN [ac000] [a] ON [e].[accountGuid] = [a].[guid] 
		WHERE [e].[parentGuid] = @entryGUID AND [a].[type] = 8
	)    

BEGIN    
	-- mark distributives:    
	UPDATE [en000] SET [number] = - [e].[number] FROM [en000] [e] INNER JOIN [ac000] [a] ON [e].[accountGuid] = [a].[guid] WHERE [e].[parentGuid] = @entryGuid AND [a].[type] = 8    
    
	-- insert distributives detailes:    
	INSERT INTO [en000] ([Number], [Date], [Debit], [Credit], [Notes], [CurrencyVal], [ParentGUID], [accountGUID],[CurrencyGUID],[CostGUID],[ContraAccGUID])    
		SELECT    
			- [e].[number], -- this is called unmarking.    
			[e].[date],    
			[e].[debit] * [c].[num2] / 100,    
			[e].[credit] * [c].[num2] / 100,    
			[e].[notes],    
			[e].[currencyVal],    
			[e].[parentGUID],    
			[c].[sonGuid],--e.accountGUID,    
			[e].[currencyGUID],    
			[e].[costGUID],    
			[e].[contraAccGUID]    
		from [en000] [e] inner join [ac000] [a] on [e].[accountGuid] = [a].[guid] inner join [ci000] [c] on [a].[guid] = [c].[parentGuid]    
		where [e].[parentGuid] = @entryGuid and [a].[type] = 8    

	-- delete the marked distributives:    
	delete [en000] where [parentGuid] = @entryGuid and [number] < 0    
	-- continue looping untill no distributive accounts are found    
END    
#########################################################
CREATE PROCEDURE prcRestGenerateEntry
	@ceGuid [UNIQUEIDENTIFIER],
	@ceDate [DATETIME],
	@currencyID [UNIQUEIDENTIFIER], 
	@BranchID [UNIQUEIDENTIFIER],
	@currencyValue [FLOAT],
	@ceNote NVARCHAR(250) = ''
AS
DECLARE  @ceNumber [FLOAT]

SELECT @ceNumber = MAX(ISNULL(Number, 0)) + 1 FROM ce000

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
SELECT	1,--Type 
	@ceNumber,--Number 
	@ceDate,--Date 
	sum(Debit), --Debit 
	sum(Debit), --Credit 
	@ceNote,--Notes 
	@currencyValue,--CurrencyVal 
	0,--IsPosted 
	0,--State 
	1,--Security 
	0,--Num1 
	0,--Num2 
	@BranchID,--Branch 
	@ceGuid,--GUID 
	@currencyID,--CurrencyGUID 
	0x0 , --TypeGUID
	@ceDate
	FROM #CurrencyItems WHERE Debit>0
	
	

INSERT INTO [en000]( [Number]
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
	  ,[CustomerGUID]
	  )
 SELECT 
		Number,
		@ceDate,
		Debit,
		Credit,
		Note,
		CurrencyValue,
		'',  --class
		0, --Num1 
		0, --Num2 
		0, --Vendor 
		UserNumber, --SalesMan 
		newid(),
		@ceGuid, --ParentGUID 
		AccountID, --AccountGUID 
		CurrencyID, --CurrencyGUID 
		CostID, --CostGUID 
		ContraID, --ContraAccGUID 
		CustID
FROM #CurrencyItems
ORDER BY Number

EXEC prcRestDistributeAccEn @ceGuid


UPDATE [CE000] 
	SET [IsPosted] = 1 
WHERE [Guid] = @ceGuid 

RETURN 1 
#########################################################
CREATE PROCEDURE prcRestGenerateChecks
	 @Date	[DATE]
	,@BranchID [UNIQUEIDENTIFIER]
	,@SaleID [UNIQUEIDENTIFIER]
	,@currencyid [UNIQUEIDENTIFIER]
	,@currencyValue [FLOAT]
	,@Language INT
AS
SET NOCOUNT ON 
DECLARE @checkPaid FLOAT
		,@paymentGuid [UNIQUEIDENTIFIER]
		,@chGuid  [UNIQUEIDENTIFIER]
		,@checkNumber NVARCHAR(250)
		,@checkType  [UNIQUEIDENTIFIER]
		,@IntNumber  NVARCHAR(250)
		,@AccountID  [UNIQUEIDENTIFIER]
		,@ContraAccID [UNIQUEIDENTIFIER]
		,@Note  NVARCHAR(250)
		,@chNotes1  NVARCHAR(250)
		,@chNotes2  NVARCHAR(250)
		,@Count [FLOAT]
		,@ceGuid  [UNIQUEIDENTIFIER]
		,@UserGuid [UNIQUEIDENTIFIER]
		,@DefCostGuid UNIQUEIDENTIFIER 
		,@BankGuid  UNIQUEIDENTIFIER
		,@Cost2Guid UNIQUEIDENTIFIER
		,@TypeName NVARCHAR(250)
		,@GenNote BIT 
		,@GenContraNote BIT
		,@CanFinishing BIT  
		,@ManualGenEntry BIT
		,@currencyID1 [UNIQUEIDENTIFIER]
		,@currencyValue1 [FLOAT]  
  		,@State INT 
		,@CustGuid [UNIQUEIDENTIFIER]

DECLARE checkCursor CURSOR FAST_FORWARD
	FOR	SELECT  PaymentGuid,
				Paid,
				Note,
				Number,
				IntNumber,
				DebitAcc,
				CreditAcc,
				TypeAcc,
				CurrencyID,
				CurrencyValue,
				CustID
	FROM #CheckItems

OPEN checkCursor

FETCH NEXT 
FROM checkCursor
INTO @paymentGuid, @checkPaid, @Note, @checkNumber, @IntNumber, @AccountID, @ContraAccID, @checkType, @currencyID1, @currencyValue1, @CustGuid
	

	 SET  @DefCostGuid = (SELECT  ISNULL([DefCostGuid], 0x0)
		FROM BT000  
    WHERE [Guid] = @SaleID )

	SET @BankGuid = (SELECT BankGUID FROM NT000 WHERE GUID = @checkType )
	SET @Cost2Guid = (SELECT DefaultCostcenter FROM NT000 WHERE GUID = @checkType) 
	SET @TypeName =  (SELECT Name FROM nt000 WHERE guid = @checkType)
    SET @GenNote  =  (SELECT bAutoGenerateNote FROM nt000 WHERE guid = @checkType)
	SET @GenContraNote  = (SELECT bAutoGenerateContraNote FROM nt000 WHERE guid = @checkType)
	SET @CanFinishing  = (SELECT bCanFinishing FROM nt000 WHERE guid = @checkType)
	SET @ManualGenEntry = (SELECT bManualGenEntry FROM NT000 WHERE GUID = @checkType)
	
			
	DECLARE @ChequeNum INT,  @Cheque_Num NVARCHAR(255),@InnerNum NVARCHAR(255)
	SET  @InnerNum = @checkNumber
	
	SELECT  @ChequeNum = ISNULL(CAST ( MAX(convert(int, case ISNUMERIC(num) when 1 then num else '' end )) + 1 AS nvarchar(255)), 1)
	FROM CH000 
		WHERE [TypeGUID] = @checkType  

	IF (NOT EXISTS(SELECT num FROM CH000 WHERE NUM = @checkNumber)) AND( @checkNumber <>'')
		SET @Cheque_Num  = 	@checkNumber	
	ELSE 
		SET @Cheque_Num = convert(NVARCHAR(255), @ChequeNum)  
			
	 
WHILE @@FETCH_STATUS = 0
BEGIN
	SELECT @Count = ISNULL(MAX(ISNULL(Number, 0)), 0) + 1 FROM ch000 WHERE TypeGUID=@checkType
	SET @chGuid = NEWID()
	UPDATE [POSPaymentsPackageCheck000] SET ChildID = @chGuid WHERE [Guid] = @paymentGuid --PK To Ch000

	SET @chNotes1 =  (CASE @GenNote WHEN 1 THEN ( [dbo].[fnStrings_get]('POS\RECEIVEDFROM', @language) + 
					 (SELECT Code +'-'+ Name FROM ac000 WHERE GUID = @ContraAccID)) + ' - ' +
					 (SELECT [CustomerName] FROM cu000 WHERE GUID = @CustGuid) + ' ' + @TypeName +' '+
					  [dbo].[fnStrings_get]('POS\NUMBER', @language)+':'+ @Cheque_Num+' '+
					 +[dbo].[fnStrings_get]('POS\INNERNUMBER', @language) +':'+@InnerNum+' '+
					 +[dbo].[fnStrings_get]('POS\DATEOFPAYMENT', @language) +':'+ CONVERT(nvarchar(255), @Date,105) +' '+  
					 + (CASE WHEN  @BankGuid <> 0x0  THEN  +[dbo].[fnStrings_get]('POS\DESTINATION', @language) +':'+
					 + (SELECT  Code +'-'+BankName FROM Bank000 WHERE Guid = @BankGuid)+' '  ELSE ' ' END)
					 ELSE ' ' END) 
					+ @Note 
			 

	SET @chNotes2 = (CASE @GenContraNote WHEN 1 THEN( [dbo].[fnStrings_get]('POS\RECEIVEDFROM', @language) + 
					(SELECT Code +'-'+ Name FROM ac000 WHERE GUID = @ContraAccID)) + ' - ' +
					 (SELECT [CustomerName] FROM cu000 WHERE GUID = @CustGuid) + ' ' + @TypeName +' '+
					  [dbo].[fnStrings_get]('POS\NUMBER', @language)+':'+ @Cheque_Num+' '+
					 +[dbo].[fnStrings_get]('POS\INNERNUMBER', @language) +':'+@InnerNum+' '+
					 +[dbo].[fnStrings_get]('POS\DATEOFPAYMENT', @language) +':'+ CONVERT(nvarchar(255), @Date,105) +' '+  
					 + (CASE WHEN  @BankGuid <> 0x0  THEN  +[dbo].[fnStrings_get]('POS\DESTINATION', @language) +':'+
					 + (SELECT  Code +'-'+BankName FROM Bank000 WHERE Guid = @BankGuid)+' '  ELSE ' ' END)
					 ELSE ' ' END) 
					+ @Note 
	 
	SET @State = CASE @CanFinishing WHEN 1 THEN 1 ELSE 0 END

	SET @ceGuid = newid()

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
		 SELECT @Count,
			   1, --Dir
			   @Date, --Date
			   @Date, --DueDate
			   @Date, --ColDate
			   @Cheque_Num,--@checkNumber, --Num
			   @BankGuid, --Bank
			   @chNotes1, --Notes
			   @checkPaid, --Val
			   @currencyValue1, --CurrencyVal
			   @State, --State
			   1, --Security
			   0, --PrevNum
			   @InnerNum, --IntNumber
			   0, --FileInt
			   0, --FileExt
			   @Date, --FileDate
			   '', --OrgName
			   @chGuid, --GUID
			   @checkType, --TypeGUID
			   @saleID, --ParentGUID
			   @ContraAccID, --AccountGUID
			   @currencyID1, --CurrencyGUID
			   ISNull(@DefCostGuid, 0x0), --Cost1GUID 
			   IsNull(@Cost2Guid, 0x0) ,--Cost2GUID 
			   @AccountID,
			   @BranchID,
			   @chNotes2,
			   @CustGuid

			   --Add Log File Record
				SET @UserGuid = [dbo].[fnGetCurrentUserGUID]()
				INSERT INTO  LoG000 (Computer,GUID,LogTime,RecGUID,RecNum,typeguid,Operation,OperationType,UserGUID) 
					VALUES(host_Name(),NEWID(),GETDATE(),@chGuid,@Count,@checkType,4,1,@UserGUID) 

				  --AddToChequeHistory 
			    DECLARE @s FLOAT  
			    --SET @s = @checkPaid * @currencyValue
				EXEC prcCheque_History_Add @chGuid, @Date, @State,33,@ceGuid,@AccountID,@ContraAccID,
			    --@s,
				@checkPaid,
				 5 , @currencyID, @currencyValue, 0x0 ,0.0 ,@Cost2Guid,@DefCostGuid, 0x0, @CustGUID
	 EXEC prcRestDistributeAccEn @ceGuid

	DELETE #CurrencyItems

	INSERT INTO #CurrencyItems (Debit,Credit,Note,CurrencyValue,CurrencyID,UserNumber,AccountID,CostID,ContraID) (SELECT	
			@checkPaid, 
			0.0, 
			@chNotes1, --'Check', 
			ISNULL(@currencyValue, 0) AS [CurrencyValue], 
			ISNULL(@currencyID, 0x0) AS [CurrencyID],
			0,
			@AccountID as AccountID,
			0x0 as Cost,
			@ContraAccID as contra) UNION ALL (SELECT	
			0.0, 
			@checkPaid , 
			@chNotes1, --'Check', 
			ISNULL(@currencyValue, 0) AS [CurrencyValue],
			ISNULL(@currencyID, 0x0) AS [CurrencyID],
			0,
			@ContraAccID as AccountID,
			0x0 as Cost,
			@AccountID as contra)

	IF (@ManualGenEntry = 0)					    
		EXEC prcNote_genEntry @chGuid, 0 -- Bassam, use procedure from Amn core for cheaks

	FETCH NEXT 
	FROM checkCursor
	INTO @PaymentGuid,@checkPaid, @Note, @checkNumber, @IntNumber, @AccountID, @ContraAccID, @checkType, @currencyID1, @currencyValue1, @CustGuid
END

CLOSE checkCursor
DEALLOCATE checkCursor

RETURN 1
#########################################################
#END