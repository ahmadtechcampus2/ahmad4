###########################
CREATE FUNCTION GetRestOrderByDepartmentID(@DepartmentID UNIQUEIDENTIFIER)
	RETURNS TABLE
AS
RETURN
	(SELECT ot.ParentID , t.DepartmentID , ot.TableID FROM RestOrderTableTemp000 ot
		INNER JOIN RestTable000 t ON ot.TableID = t.GUID
			WHERE   @DepartmentID = 0x0 or  t.DepartmentID = @DepartmentID
	UNION ALL
	SELECT ot.ParentID , t.DepartmentID , ot.TableID FROM RestOrderTable000 ot
		INNER JOIN RestTable000 t ON ot.TableID = t.GUID
			WHERE @DepartmentID = 0x0 or t.DepartmentID = @DepartmentID)
###########################
CREATE PROCEDURE prcRestOrdersMovement
	@StartDate    [DATETIME],   
	@EndDate      [DATETIME],
	@CustomerGuid [uniqueidentifier],
	@CashierGuid  [uniqueidentifier],
	@BranchGuid   [uniqueidentifier],
	@DriverGuid   [uniqueidentifier],
	@CaptinGuid   [uniqueidentifier],
	@TableGuid   [uniqueidentifier],
	@DepartmentGuid   [uniqueidentifier],
	@ShowCancelMat [BIT],
	@Out	      [BIT],
	@Delivery	  [BIT],
	@Table		  [BIT],
	@Ret	      [BIT],
	@Opened		  [BIT],
	@GroupBy	  [INT], 
	@TaxDetails	  [BIT] = 0,
	@ShowDetails  [BIT] = 1,
	@Pay		  [BIT] = 0 ,
	@withBills	  [BIT] = 1, 
	@withOutBills [BIT] = 1
AS
SET NOCOUNT ON

DECLARE @lang INT = dbo.fnConnections_GetLanguage()

CREATE TABLE #selectedOrders(
	[Number] [float] NULL DEFAULT ((0)),
	[Guid] [uniqueidentifier] ROWGUIDCOL  NOT NULL DEFAULT (newid()),
	[Type] [int] NULL DEFAULT ((0)),
	[State] [int] NULL DEFAULT ((0)),
	[CashierID] [uniqueidentifier] NULL DEFAULT (0x00),
	[FinishCashierID] [uniqueidentifier] NULL DEFAULT (0x00),
	[BranchID] [uniqueidentifier] NULL DEFAULT (0x00),
	[Date] [datetime] NULL DEFAULT ('1/1/1980'),
	[Notes] [nvarchar](250) NULL DEFAULT (''),
	[Cashed] [float] NULL DEFAULT ((0)),
	[Discount] [float] NULL DEFAULT ((0)),
	[Added] [float] NULL DEFAULT ((0)),
	[Tax] [float] NULL DEFAULT ((0)),	
	[DeliveringFees] [float] NULL DEFAULT ((0)),
	[SubTotal] [float] NULL DEFAULT ((0)),
	[CustomerID] [uniqueidentifier] NULL DEFAULT (0x00),
	[DeferredAccountID] [uniqueidentifier] NULL DEFAULT (0x00),
	[CurrencyID] [uniqueidentifier] NULL DEFAULT (0x00),
	[IsPrinted] [int] NULL DEFAULT ((0)),
	[HostName] [nvarchar](250) NULL DEFAULT (''),
	[BillNumber] [float] NULL DEFAULT ((0)),

	[DepartmentID] [uniqueidentifier] NULL DEFAULT (0x00),
	[GuestID] [uniqueidentifier] NULL DEFAULT (0x00),
	[PaymentsPackageID] [uniqueidentifier] NULL DEFAULT (0x00),
	[Opening] [datetime] NULL DEFAULT ('1/1/1980'),
	[Preparing] [datetime] NULL DEFAULT ('1/1/1980'),
	[Receipting] [datetime] NULL DEFAULT ('1/1/1980'),
	[Closing] [datetime] NULL DEFAULT ('1/1/1980'),
	[Version] [bigint] NULL DEFAULT ((0)),
	[Period] [bigint] NULL DEFAULT ((0)),
	[PrintTimes] [bigint] NULL DEFAULT ((0)),
	[ExternalcustomerName] [nvarchar](100) NULL DEFAULT (''),
	[Ordernumber] [float] NULL DEFAULT ((0)),
	[LastAdditionDate] [datetime] NULL DEFAULT ('1/1/1980'),
	[CustomerAddressID] [uniqueidentifier] NULL DEFAULT (0x00),
	[TableName]	[nvarchar](512) NULL DEFAULT (''),
	[TableCover] [int] NULL DEFAULT ((0)),
	[PointsCount] INT NULL DEFAULT ((0)),
)

CREATE TABLE #selectedOrdersItems(
	[Number] [float] NULL DEFAULT ((0)),
	[Guid] [uniqueidentifier] ROWGUIDCOL  NOT NULL DEFAULT (newid()),
	[State] [int] NULL DEFAULT ((0)),
	[Type] [int] NULL DEFAULT ((0)),
	[Qty] [float] NULL DEFAULT ((0)),
	[MatPrice] [float] NULL DEFAULT ((0)),
	[Price] [float] NULL DEFAULT ((0)),
	[PriceType] [int] NULL DEFAULT ((0)),
	[Unity] [int] NULL DEFAULT ((0)),
	[MatID] [uniqueidentifier] NULL DEFAULT (0x00),
	[Discount] [float] NULL DEFAULT ((0)),
	[Added] [float] NULL DEFAULT ((0)),
	[Tax] [float] NULL DEFAULT ((0)),
	[ParentID] [uniqueidentifier] NULL DEFAULT (0x00),
	[ItemParentID] [uniqueidentifier] NULL DEFAULT (0x00),
	[KitchenID] [uniqueidentifier] NULL DEFAULT (0x00),
	[PrinterID] [int] NULL DEFAULT ((0)),
	[AccountID] [uniqueidentifier] NULL DEFAULT (0x00),
	[Note] [nvarchar](250) NULL DEFAULT (''),
	[SpecialOfferID] [uniqueidentifier] NULL DEFAULT (0x00),
	[SpecialOfferIndex] [int] NULL DEFAULT ((0)),
	[OfferedItem] [int] NULL DEFAULT ((0)),
	[IsPrinted] [int] NULL DEFAULT ((0)),
	[BillType] [uniqueidentifier] NULL DEFAULT (0x00),
	[Vat] [float] NULL DEFAULT ((0)),
	[VatRatio] [float] NULL DEFAULT ((0)),
	[IsNew] [bit] NULL DEFAULT ((0)),
	[QtyDiff] [float] NULL DEFAULT ((0)),
	[ChangedQty] [float] NULL DEFAULT ((0))
)

IF @withOutBills = 0 
	SET @Opened = 0

IF (@Opened = 1)
BEGIN
INSERT INTO #selectedOrders
SELECT
	[Order].Number, [Order].Guid, [Order].Type, [Order].State, [Order].CashierID, [Order].FinishCashierID, 
	[Order].BranchID, [Order].Date, [Order].Notes, [Order].Cashed, [Order].Discount, [Order].Added, 
	[Order].Tax, [Order].DeliveringFees, [Order].SubTotal, [Order].CustomerID, [Order].DeferredAccountID, [Order].CurrencyID, 
	[Order].IsPrinted, [Order].HostName, [Order].BillNumber, [Order].DepartmentID, [Order].GuestID, [Order].PaymentsPackageID, [Order].Opening, 
	[Order].Preparing, [Order].Receipting, [Order].Closing, [Order].Version, [Order].Period, 
	[Order].PrintTimes, [Order].ExternalcustomerName, [Order].Ordernumber, [Order].LastAdditionDate, [Order].CustomerAddressID,
	[RT].Code , [RT].Cover, PointsCount
	FROM vwRestAllOrders [Order]
			LEFT JOIN [RestVendor000] [Ven] ON [Ven].[GUID]=[Order].[GuestID]
			LEFT JOIN dbo.fnGetRestOrderTables(@TableGuid) [RT] ON [RT].ParentGuid=[order].[GUID]
	WHERE	(@CustomerGuid=0x0 OR @CustomerGuid=[Order].CustomerID)
				AND	(@BranchGuid=0x0 OR @BranchGuid=[Order].BranchID)
				AND (@CashierGuid=0x0 OR @CashierGuid=[Order].CashierID)
				AND ([Order].[Closing] BETWEEN @StartDate AND @EndDate)
				AND (@DriverGuid=0x0 OR @DriverGuid = [Ven].GUID)
				AND (@CaptinGuid=0x0 OR @CaptinGuid = [Ven].GUID)
				AND (@DepartmentGuid=0x0 OR DepartmentID = @DepartmentGuid)
				AND (@TableGuid=0x0 OR ISNULL([RT].[ParentGuid], 0x0) <> 0x0)
				AND ((@Out=1 AND [Order].[Type]=2) OR (@Delivery=1 AND [Order].[Type]=3) OR (@Table=1 AND [Order].[Type]=1) OR (@Ret=1 AND [Order].[Type]=4))
				AND ( (@withBills = 1 AND [Order].BillNumber != '') 
				OR  ( @withOutBills = 1 AND [Order].BillNumber = '')  ) 
	
		INSERT INTO #selectedOrdersItems
		SELECT 
			Number, Guid, State, Type, Qty, MatPrice, Price, PriceType, Unity, MatID, Discount, Added, Tax, 
			ParentID, ItemParentID, KitchenID, PrinterID, AccountID, Note, SpecialOfferID, SpecialOfferIndex, OfferedItem, IsPrinted, BillType, Vat, VatRatio, IsNew, QtyDiff, [ChangedQty]
		FROM vwRestAllOrdersItems Items WHERE EXISTS(SELECT 1 FROM #selectedOrders [Orders] WHERE [Orders].[Guid] = [Items].[ParentID])
END
ELSE
BEGIN
	INSERT INTO #selectedOrders
	SELECT 
	[Order].Number, [Order].Guid, [Order].Type, [Order].State, [Order].CashierID, [Order].FinishCashierID, 
	[Order].BranchID, [Order].Date, [Order].Notes, [Order].Cashed, [Order].Discount, [Order].Added, 
	[Order].Tax, [Order].DeliveringFees, [Order].SubTotal, [Order].CustomerID, [Order].DeferredAccountID, [Order].CurrencyID, 
	[Order].IsPrinted, [Order].HostName, [Order].BillNumber, [Order].DepartmentID, [Order].GuestID, [Order].PaymentsPackageID, [Order].Opening, 
	[Order].Preparing, [Order].Receipting, [Order].Closing, [Order].Version, [Order].Period, 
	[Order].PrintTimes, [Order].ExternalcustomerName, [Order].Ordernumber, [Order].LastAdditionDate, [Order].CustomerAddressID,
	[RT].Code , [RT].Cover, PointsCount  
	FROM RestOrder000 [Order]
			LEFT JOIN [RestVendor000] [Ven] ON [Ven].[GUID]=[Order].[GuestID]
			LEFT JOIN dbo.fnGetRestOrderTables(@TableGuid) [RT] ON [RT].ParentGuid=[order].[GUID]
	WHERE       (@CustomerGuid=0x0 OR @CustomerGuid=[Order].CustomerID)
				AND	(@BranchGuid=0x0 OR @BranchGuid=[Order].BranchID)
				AND (@CashierGuid=0x0 OR @CashierGuid=[Order].CashierID)
				AND ([Order].[Opening] BETWEEN @StartDate AND @EndDate)
				AND (@DriverGuid=0x0 OR @DriverGuid = [Ven].GUID)
				AND (@CaptinGuid=0x0 OR @CaptinGuid = [Ven].GUID)
				AND (@DepartmentGuid=0x0 OR DepartmentID = @DepartmentGuid)
				AND (@TableGuid=0x0 OR ISNULL([RT].[ParentGuid], 0x0) <> 0x0)
				AND ((@Out=1 AND [Order].[Type]=2) OR (@Delivery=1 AND [Order].[Type]=3) OR (@Table=1 AND [Order].[Type]=1) OR (@Ret=1 AND [Order].[Type]=4))
				AND ( (@withBills = 1 AND [Order].BillNumber != '') 
				OR  ( @withOutBills = 1 AND [Order].BillNumber = '')  ) 
	
		INSERT INTO #selectedOrdersItems
		SELECT 
			Number, Guid, State, Type, Qty, MatPrice, Price, PriceType, Unity, MatID, Discount, Added, Tax, 
			ParentID, ItemParentID, KitchenID, PrinterID, AccountID, Note, SpecialOfferID, SpecialOfferIndex, OfferedItem, IsPrinted, BillType, Vat, VatRatio, IsNew, QtyDiff, [ChangedQty]
		FROM RestOrderItem000 Items WHERE EXISTS(SELECT 1 FROM #selectedOrders [Orders] WHERE [Orders].[Guid] = [Items].[ParentID])
END

IF @TaxDetails = 1
BEGIN 
	DECLARE @colsNull NVARCHAR(MAX) = '' , @query  AS NVARCHAR(MAX) , 
	@cols NVARCHAR(MAX) = '' ,  @QuotedName NVARCHAR(15) , @colsSum NVARCHAR(MAX) = '' , 
	@colsDef NVARCHAR(MAX) = ''
	
	SELECT @QuotedName = QUOTENAME('Tax' + CAST(Number AS NVARCHAR(250))) ,
	 @cols = @cols + N',' + @QuotedName , 
	 @colsNull = @colsNull + N',ISNULL(' + @QuotedName  + N',0) AS ' + @QuotedName ,	 
	 @colsSum = @colsSum +  N', SUM(ISNULL(' + @QuotedName  + N',0)) AS ' + @QuotedName , 
	 @colsDef = @colsDef + N',' + @QuotedName + ' FLOAT NOT NULL ' 
	FROM RestTaxes000
	
	IF ISNULL(@cols, '') <> ''
	BEGIN
		SET @cols = STUFF(@cols,1,1,'')
		SET @colsDef = STUFF(@colsDef,1 ,1 ,'')

		CREATE TABLE #TaxDetails
		(
			OrderID UNIQUEIDENTIFIER NOT NULL PRIMARY KEY
		)

		IF @Opened = 1 
		BEGIN 
			CREATE TABLE #RestDiscTaxTemp
			(
				OrderID UNIQUEIDENTIFIER NOT NULL  , 
				CalculatedValue FLOAT NOT NULL, 
				AbbrevName NVARCHAR(10) NOT NULL
			)

			DECLARE	   
			@discountDiscount     FLOAT,
		    @discountExtra        FLOAT,
		    @discountType         INT,
		    @discountNotes        NVARCHAR(250),
		    @discountAccountGUID  UNIQUEIDENTIFIER,
		    @PaerentTaxID         UNIQUEIDENTIFIER,
			@taxes				  FLOAT = 0.0,
			@IsAded				  BIT,
			@IsDisc				  BIT,
			@IsApplyOnPrevTax	  BIT, 
			@salesOrderItemsTotal   FLOAT , 
			@DeliveringFees			FLOAT , 
			@orderSalesAdded		FLOAT , 
			@orderSalesDiscount		FLOAT , 
			@OrderID UNIQUEIDENTIFIER, 
			@PreviousOrderID UNIQUEIDENTIFIER = 0x0 , 
			@Number INT

		DECLARE discountCursor CURSOR FAST_FORWARD 
			FOR 
		         (  SELECT  RD.[Type],
		                        CASE 	 
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
						  o.SubTotal , 
						  o.Added , 
						  o.Discount , 
						  o.DeliveringFees , 
						  RD.ParentID ,
		                  RT.Number Number							 
		                 FROM   RestDiscTaxTemp000 RD
		            INNER JOIN RestTaxes000 rt ON  RT.Guid = RD.ParentTaxID
					INNER JOIN RestOrderTemp000 o ON ParentID =  o.guid 
		             WHERE   ISNULL(RD.ParentTaxID, 0X0) <> 0x0	 )		                	
					ORDER BY [ParentID] , rt.Number	
					
				OPEN discountCursor 
				FETCH NEXT FROM discountCursor 
				INTO  @discountType, @discountDiscount, @discountAccountGUID, @discountNotes, 
		    @PaerentTaxID, @IsAded, @IsDisc, @IsApplyOnPrevTax, @salesOrderItemsTotal , @orderSalesAdded , 
			@orderSalesDiscount , @DeliveringFees , @OrderID , @Number

		WHILE @@FETCH_STATUS = 0
		BEGIN
		IF	@PreviousOrderID <> @OrderID 
			SET @taxes = 0

			IF (@discountDiscount < 1)
			BEGIN
			    SET @discountDiscount = (@salesOrderItemsTotal + ((@DeliveringFees + @orderSalesAdded) * @IsAded) - (@orderSalesDiscount * @IsDisc) + (@taxes) * @IsApplyOnPrevTax) * (@discountDiscount) 
				SET @taxes = @taxes + @discountDiscount
			END
			   
			INSERT INTO #RestDiscTaxTemp 
			VALUES (@OrderID , @discountDiscount , 'Tax' + CAST(@Number AS NVARCHAR(3)))

			SET @PreviousOrderID = @OrderID

			FETCH NEXT FROM discountCursor 
					INTO  @discountType, @discountDiscount, @discountAccountGUID, @discountNotes, 
			    @PaerentTaxID, @IsAded, @IsDisc, @IsApplyOnPrevTax, @salesOrderItemsTotal , @orderSalesAdded , 
			 @orderSalesDiscount , @DeliveringFees , @OrderID , @Number
			END 
			CLOSE discountCursor 
			DEALLOCATE discountCursor

		END 
		
		SET @query = ' ALTER TABLE #TaxDetails ADD  ' + @colsDef 
		EXEC sp_executesql @query

		SET @query = ' SELECT ParentID AS OrderID   ' + @colsNull + ' FROM 
					(	
						SELECT 	ParentID  , CalculatedValue , ''Tax'' + CAST(t.Number	AS NVARCHAR(10)) AS [AbbrevName]	
						FROM RestDiscTax000 rdt 
						INNER JOIN RestTaxes000 t ON t.Guid = rdt.ParentTaxID ' + 
						IIF(@Opened = 1 , 'UNION ALL   
						SELECT OrderID , CalculatedValue , [AbbrevName] 
						FROM  #RestDiscTaxTemp ','') + 
					') x
					PIVOT ( SUM(CalculatedValue) FOR AbbrevName IN (' + @cols + N')) p'	
					
		INSERT INTO #TaxDetails EXEC sp_executesql @query;
	END
	ELSE
		SET @TaxDetails = 0
END

IF @Pay = 1 
BEGIN
	DECLARE @colsNull1 NVARCHAR(MAX) = '' , @cols1 NVARCHAR(MAX) = '' ,  
	@colsSum1 NVARCHAR(MAX) = '' , @colsDef1 NVARCHAR(MAX) = ''

	SELECT @QuotedName = QUOTENAME(PayName) ,
	 @cols1 = @cols1 + N',' + @QuotedName , 
	 @colsNull1 = @colsNull1 + N',ISNULL(' + @QuotedName  + N',0) AS ' + @QuotedName ,	 
	 @colsSum1 = @colsSum1 +  N', SUM(ISNULL(' + @QuotedName  + N',0)) AS ' + @QuotedName , 
	 @colsDef1 = @colsDef1 + N',' + @QuotedName + ' FLOAT NOT NULL ' 
	 FROM 
	(
		SELECT   'Check' + CAST(Number AS NVARCHAR)  [PayName] FROM RestCheckItem000 ci
		WHERE EXISTS ( SELECT 1 FROM POSPaymentsPackageCheck000 ch WHERE ch.Type = ci.CheckID )
		UNION ALL
		SELECT  'Currency' + CAST(Number AS NVARCHAR) FROM my000 my 
		WHERE EXISTS(SELECT 1 FROM POSPaymentsPackageCurrency000 WHERE CurrencyID = my.GUID )
		UNION ALL 
		SELECT TOP 1 'Deffered' FROM POSPaymentsPackage000 WHERE DeferredAccount != 0x0		
		UNION ALL 
		SELECT TOP 1 'Points' FROM POSPaymentsPackagePoints000 
	)t

	IF ISNULL(@cols1, '') <> ''
	BEGIN
		SET @cols1 = STUFF(@cols1,1,1,'')
		SET @colsDef1 = STUFF(@colsDef1,1 ,1 ,'')

		CREATE TABLE #PayDetails
		(
			OrderID UNIQUEIDENTIFIER NOT NULL PRIMARY KEY
		)

		SET @query = ' ALTER TABLE #PayDetails ADD  ' + @colsDef1 
		EXEC sp_executesql @query
		print @colsNull1
		SET @query = ' SELECT  OrderID  ' + @colsNull1 +   ' FROM 
					(	
						SELECT  [Order].[Guid] [OrderID], ''Currency'' + CAST(my.Number AS NVARCHAR) [PayName], cur.Paid - cur.Returned [PayTotal]
							FROM #selectedOrders [Order]
							INNER JOIN POSPaymentsPackage000 pack ON [Order].PaymentsPackageID = pack.[Guid]
							INNER JOIN POSPaymentsPackageCurrency000 cur ON pack.[Guid] = cur.ParentID
							INNER JOIN my000 my ON my.GUID = cur.CurrencyID
							UNION ALL
							SELECT  [Order].[Guid] , ''Check'' + CAST(ci.Number AS NVARCHAR), ch.Paid 
							FROM  #selectedOrders [Order]
							INNER JOIN POSPaymentsPackage000 pack ON [Order].PaymentsPackageID = pack.[Guid]
							INNER JOIN POSPaymentsPackageCheck000 ch ON pack.[Guid] = ch.ParentID
							INNER JOIN RestCheckItem000 ci ON ci.CheckID = ch.Type
							UNION ALL
							SELECT   [Order].[Guid] , ''Deffered'' , pack.DeferredAmount 
							FROM  #selectedOrders [Order]
							INNER JOIN POSPaymentsPackage000 pack ON pack.[Guid] = [Order].PaymentsPackageID
							UNION ALL
							SELECT [Order].[Guid], ''Points'', PointsValue 
							FROM #selectedOrders [Order]
							INNER JOIN POSPaymentsPackagePoints000 pp ON pp.ParentGUID = [Order].PaymentsPackageID
					) x
					PIVOT ( SUM ( PayTotal)   FOR [PayName] IN (' + @cols1 + N')) p'		
		INSERT INTO #PayDetails EXEC sp_executesql @query;
	END
	ELSE
		SET @Pay = 0
	END

IF (@GroupBy = 0)
BEGIN
SELECT
		[Order].[Ordernumber] [OrderNumber], 
		[Order].[Type] [OrderType],
		[Order].[GUID] [OrderID], 
		[Order].[Opening] [OrderDate], 
		[Order].[Closing] [OrderClosingDate], 
		LTRIM(RIGHT(CONVERT(VARCHAR(20), [Order].[Opening], 100), 7)) AS OrderOpeningTime,
		[Order].[Notes] [OrderNotes], 
		[Order].[Discount] [TotalDiscount], 
		[Order].[Added] [TotalAdded], 
		[Order].[Added] - [OrderItems].ItemsAdded  [OrderAdded], 
		[Order].[Discount] - [OrderItems].[ItemsDiscount] [OrderDiscount], 
		[OrderItems].[ItemsAdded]  [ItemsAdded], 
		[OrderItems].[ItemsDiscount] [ItemsDiscount], 
		[Order].tax [OrderTax], 
		[Order].[DeliveringFees] [OrderDeliveringFees], 
		[Order].[SubTotal] [OrderSubTotal],
		([SubTotal] + [Added] + [Order].tax + [DeliveringFees] - [Discount]) [OrderNetTotal],
		ISNULL([Cu].[GUID], 0x0) as [CuID],
		ISNULL([Cu].[CustomerName], '') as [CuName],
		ISNULL([Br].[GUID], 0x0) as [BrID],
		ISNULL([Br].[Name], '') as [BrName],
		ISNULL([Us].[LoginName], '') as [UsName],
		ISNULL([Ven].[Name], '') as [VendorName],
		ISNULL([Ven].[LatinName], '') as [VendorLatinName],
		ISNULL([TableName], '') as [TableName],
		ISNULL([TableCover], '') as [TableCover],
		ISNULL([Dp].Name,'') as [DepartmentName],
		ISNULL([Order].PointsCount, 0) AS [PointsCount]
		INTO #Result
	FROM #selectedOrders [Order]
		CROSS APPLY (
			SELECT 
				ParentID, 
				SUM(ISNULL(Added, 0)) [ItemsAdded] , 
				SUM(ISNULL(Discount, 0)) [ItemsDiscount]
			FROM #selectedOrdersItems WHERE ParentID =[Order].GUID
			GROUP BY ParentID
		) [OrderItems]
		LEFT JOIN [Cu000] [Cu] on  [Cu].[Guid]=[Order].[CustomerID]
		LEFT JOIN [Br000] [Br] on  [Br].[Guid]=[Order].[BranchID]
		LEFT JOIN [us000] [Us] on  [Us].[Guid]=[Order].[FinishCashierID]
		LEFT JOIN [RestVendor000] [Ven] on  [Ven].[Guid]=[Order].[GuestID]
		LEFT JOIN [RestDepartment000] [Dp] on [Dp].GUID = [Order].DepartmentID	
	ORDER BY [Order].Number

	SELECT  [Rel].ParentGUID  , ' - ' + CAST(bu.buNumber AS NVARCHAR(15)) + ' ' +  
				IIF ( @lang = 0 ,  btAbbrev  , btlatinAbbrev)   AS [BillNum]
	INTO #rel
	FROM  [vwbu] [bu]
	INNER JOIN [BillRel000] [Rel] ON   buGUID = [Rel].BillGUID
	WHERE EXISTS ( SELECT 1 FROM #Result r WHERE  r.[OrderID] = [Rel].ParentGUID )

	SET @query = 'SELECT r.* ' + ISNULL( @colsNull,'')  + ISNULL( @colsNull1,'') + 
	',STUFF( (
				SELECT BillNum
				FROM   #rel
				WHERE  r.[OrderID] = ParentGUID
				FOR XML PATH(''''), TYPE 
			 ).value(''.'', ''NVARCHAR(MAX)''),1 ,3 , ''''
		   ) BillNum	
	FROM #Result  r ' +  
	IIF( @TaxDetails = 1 , ' LEFT JOIN #TaxDetails tx  ON tx.OrderID = r.OrderID ' , '' ) + 
	IIF( @Pay		 = 1 , ' LEFT JOIN #PayDetails pd  ON pd.OrderID = r.OrderID ' , '' ) + 
	' ORDER BY [OrderDate] , [OrderNumber]' 
	EXEC sp_executesql @query

	IF @ShowDetails = 1 
	BEGIN 
	--Fetch Order items
		SELECT mt.Guid as [MtGuid],
				[Item].ParentID [OrderGuid],
				isnull(mt.code, '')  [MtCode],
				isnull(mt.name, '')  [MtName],
				isnull(mt.LatinName, '')  [MtLatinName],
				CASE [Item].Unity WHEN 1 THEN mt.Unity WHEN 2 THEN mt.Unit2 WHEN 3 THEN mt.Unit3 ELSE mt.Unity END [Unit],
				[Item].Qty [Qty],
				([Item].MatPrice  * [Item].Qty) [MatPrice],
				[Item].Price [Price],
				[Item].Added [Added],
				[Item].Discount [Discount],
				[Item].Tax [Tax],
				CASE [Item].[Type]	WHEN 0 THEN ( Price * [Item].Qty) + Added + Tax - Discount 
									WHEN 1 THEN -1 * (( Price * [Item].Qty) + Added + Tax - Discount) 
				END [Total],
				[Item].[Type] [Type],
				[Item].[Note] [Note]
		FROM #selectedOrdersItems [Item]
		INNER JOIN mt000 mt ON mt.[GUID] = [Item].MatID
		WHERE EXISTS (SELECT 1 FROM #selectedOrders o WHERE  [Item].[ParentID] = o.Guid)
		AND (([Item].[Type] <> 1 AND @ShowCancelMat = 0) OR @ShowCancelMat = 1)				
	END
END
ELSE 
BEGIN 
	SELECT 
		[Order].[Guid], 
		ISNULL(SUM([Item].[Added]),0)  [SumAdded] , 
		ISNULL(SUM([Item].[Discount]),0)  [SumDisc]
	INTO #OrderDiscTax  
	FROM #selectedOrders [Order] 
	INNER JOIN #selectedOrdersItems [Item] ON [Order].[Guid] = [Item].[ParentID]
	GROUP BY [Order].[Guid]
	DECLARE @orderDate AS NVARCHAR(300) = ''
	IF (@GroupBy = 1)
		SET @orderDate = 'RIGHT(''0''+CAST(MONTH([Order].[Opening]) AS nvarchar(2)),2) + ''-'' + CAST(YEAR([Order].[Opening]) AS nvarchar(4))'
	ELSE IF (@GroupBy = 2)
		SET @orderDate = 'CAST (CONVERT(date, [Order].[Opening]) AS nvarchar(12))'
	ELSE IF (@GroupBy = 3)
		SET @orderDate = 'CAST(CONVERT(date, [Order].[Opening]) AS nvarchar(12)) + '' '' +  CAST(DATEPART(HOUR, [Order].[Opening]) AS nvarchar(2)) + '' ''  + RIGHT(CONVERT(VARCHAR(30), [Order].[Opening], 9),2)'	
	ELSE IF (@GroupBy = 4)
		SET @orderDate = 'CAST(DATEPART(HOUR, [Order].[Opening]) AS nvarchar(2)) + '' ''  + RIGHT(CONVERT(VARCHAR(30), [Order].[Opening], 9),2)'

	SET  @query  = N'
	SELECT ' + @orderDate + ' AS [OrderDate],		
		SUM([Order].[Discount]) [TotalDiscount], 
		SUM([Order].[Added]) [TotalAdded], 
		SUM([Order].[Added] - [SumAdded] ) [OrderAdded], 
		SUM([Order].[Discount] - [SumDisc]) [OrderDiscount], 
		SUM([SumAdded])  [ItemsAdded], 
		SUM([SumDisc]) [ItemsDiscount] ' + ISNULL(@colsSum,'') + N',  
		SUM([Order].[Tax]) [OrderTax],  
		SUM([Order].[DeliveringFees]) [OrderDeliveringFees],
		COUNT(*) AS BillCount,
		SUM([Order].[SubTotal]) [OrderSubTotal],
		SUM([SubTotal] + [Added] + [Tax] + [DeliveringFees] - [Discount]) [OrderNetTotal]  ' + ISNULL(@colsSum1,'') + N',
		SUM(PointsCount) [PointsCount]
		FROM #selectedOrders [Order] 
		INNER JOIN #OrderDiscTax ot on [Order].[Guid] = ot.[Guid] ' +
		IIF(@TaxDetails = 1 ,	'LEFT JOIN #TaxDetails tx  ON tx.[OrderID] = [Order].[Guid]','') + 	
		IIF(@Pay = 1		,	'LEFT JOIN #PayDetails pd ON pd.OrderID = [Order].[Guid]','') + '		
		LEFT JOIN [Cu000] [Cu] on  [Cu].[Guid]=[Order].[CustomerID]
		LEFT JOIN [Br000] [Br] on  [Br].[Guid]=[Order].[BranchID]
		LEFT JOIN [us000] [Us] on  [Us].[Guid]=[Order].[FinishCashierID]
		LEFT JOIN [RestVendor000] [Ven] on  [Ven].[Guid]=[Order].[GuestID]
		LEFT JOIN dbo.fnGetRestOrderTables(0x0) [RT] ON [RT].ParentGuid=[order].[GUID]
		GROUP BY ' + @orderDate + ' ORDER BY BillCount DESC '

	EXEC sp_executesql @query
END
	
###########################
#END