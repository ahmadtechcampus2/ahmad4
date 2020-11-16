###############################################################################
CREATE FUNCTION fnPOSGetOrderDiscAdded
(
	 @OrderID [UNIQUEIDENTIFIER]
)
RETURNS   TABLE 
AS 
RETURN 
(
	SELECT  * FROM (
		SELECT   
			ParentID,
			SUM( IIF ([Type] = 0 , price * Qty , 0)) AS [SalesOrderSubTotal], 
			SUM( IIF ([Type] = 1 , price * Qty , 0)) AS [ReturnSalesOrderSubTotal] , 
			SUM( IIF ([Type] = 0 , price * Qty + Added , 0)) AS [SalesOrderSubTotalWithAdded] , 
			SUM( IIF ([Type] = 1 , price * Qty + Added , 0)) AS [ReturnSalesSubTotalWithAdded] , 
			SUM( IIF ([Type] = 0 , price * Qty - Discount , 0)) AS [SalesOrderSubTotalWithDisc] , 
			SUM( IIF ([Type] = 1 , price * Qty - Discount , 0))  AS [ReturnSalesOrderSubTotalWithDisc]
		FROM  POSOrderItems000
		WHERE  ParentID = @OrderID AND [State] <> 1 
		GROUP BY ParentID
	) t
	OUTER APPLY (
		SELECT   
			ISNULL(SUM(IIF (OrderType = 0 , ISNULL(Value, 0) , 0) ), 0) AS [SalesOrderAdded] , 
			ISNULL(SUM(IIF (OrderType = 1 , ISNULL(Value, 0) , 0) ), 0) AS [ReturnSalesAdded]
		FROM  POSOrderAdded000  added
		WHERE t.ParentID = added.ParentID 
	) added
	OUTER APPLY (
		SELECT    
			ISNULL(SUM(IIF (OrderType = 0 , ISNULL(Value, 0) , 0) ), 0) AS [SalesDiscount] , 
			ISNULL(SUM(IIF (OrderType = 1 , ISNULL(Value, 0) , 0) ), 0) AS [ReturnSalesDisount]
		FROM  POSOrderDiscount000 discount
		WHERE t.ParentID = discount.ParentID 
	) discount
)

###############################################################################
CREATE PROCEDURE prcPOSOrdersMovements
	@StartDate    [DATETIME],   
	@EndDate      [DATETIME],
	@CustomerGuid [uniqueidentifier],
	@CashierGuid  [uniqueidentifier],
	@BranchGuid   [uniqueidentifier],
	@Sale	      [INT],
	@Book	      [INT],
	@extention    [INT],
	@retrieveBook [INT],
	@cancelBook   [INT],
	@GroupBy	  [INT],
	@Pay		[BIT] = 0,
	@ShowDetails [BIT] = 1,
	@CurrencyGUID [UNIQUEIDENTIFIER] = 0x0,
	@withBills	  [BIT] = 1, 
	@withOutBills [BIT] = 1
AS
SET NOCOUNT ON

DECLARE @lang INT = dbo.fnConnections_GetLanguage()

IF ISNULL(@CurrencyGUID, 0x0) = 0x0 
	SET @CurrencyGUID = dbo.fnGetDefaultCurr()

DECLARE @IsMainCurrency BIT = 0 
IF EXISTS(SELECT 1 FROM my000 WHERE GUID = @CurrencyGUID AND CurrencyVal = 1 )
	SET @IsMainCurrency = 1
	
CREATE TABLE #PayDetails
(
	OrderID UNIQUEIDENTIFIER NOT NULL PRIMARY KEY
)

SELECT  [Order].[GUID] , 
		[Order].[Number] [OrderNumber] , 
		[Order].[Type] [OrderType] , 
		[Date] [OrderDate] , 
		[Order].[Notes] [OrderNotes] , 
		LTRIM(RIGHT(CONVERT(VARCHAR(20), [Date], 100), 7)) AS [OrderOpeningTime] , 
		[Discount] [TotalDiscount] , 
		[Added] [TotalAdded], 
		[ItemsDiscount] , 
		[ItemsAdded],
		([Discount] - [ItemsDiscount])  [OrderDiscount],
		([Added] - [ItemsAdded])  [OrderAdded],	
		[OrderItems].[Tax] [OrderTax],
		[SubTotal] [OrderSubtotal] , 
		[SubTotal] + [Added] + [OrderItems].[Tax] - [Discount] [OrderNetTotal],
		[Payment] , 
		[PaymentsPackageID] , 
		ISNULL([Cu].[GUID], 0x0) as [CuID],
		ISNULL([Cu].[CustomerName], '') as [CuName],
		ISNULL([Br].[GUID], 0x0) as [BrID],
		ISNULL([Br].[Name], '') as [BrName],
		ISNULL([Us].[LoginName], '') as [UsName],
		CASE @IsMainCurrency 
			WHEN 0 THEN CASE 
							WHEN @CurrencyGUID = CurrencyID  THEN [CurrencyValue]
							ELSE dbo.fnGetCurVal(@CurrencyGUID, [Date]) 
						END
			ELSE 1 
		END [HistoryCurVal],
		[CurrencyValue],
		ISNULL(PointsCount, 0) AS [PointsCount]
		INTO #selectedOrders
		FROM vbPosorder [Order]
		CROSS APPLY (
			SELECT ParentID, 
			SUM(ISNULL(Added, 0) ) [ItemsAdded] , 
			SUM(ISNULL(Discount, 0) ) [ItemsDiscount], 
			SUM(ISNULL(Tax,0)) [Tax]  
			FROM POSOrderItems000 WHERE ParentID =[Order].GUID
			GROUP BY ParentID
		) [OrderItems]
		LEFT JOIN [Cu000] [Cu] on  [Cu].[Guid]=[Order].[CustomerID]
		LEFT JOIN [Br000] [Br] on  [Br].[Guid]=[Order].[BranchID]
		LEFT JOIN [us000] [Us] on  [Us].[Guid]=[Order].[FinishCashierID]
		WHERE   (@CustomerGuid=0x0 OR @CustomerGuid=[Order].CustomerID)
				AND	(@BranchGuid=0x0 OR @BranchGuid=[Order].BranchID)
				AND (@CashierGuid=0x0 OR @CashierGuid=[Order].[FinishCashierID])
				AND ([Order].[Date] BETWEEN @StartDate AND @EndDate)
				AND ((@sale=1 AND [Order].[Type]=0) OR (@extention=1 AND [Order].[Type]=1) OR (@book=1 AND [Order].[Type]=2) OR (@retrieveBook=1 AND [Order].[Type]=3) OR (@cancelBook=1 AND [Order].[Type]=4))
				AND (  ( @withBills = 1 AND EXISTS ( SELECT 1 FROM BillRel000 rel WHERE rel.ParentGUID = [Order].Guid ) ) 
					OR ( @withOutBills = 1 AND NOT EXISTS ( SELECT 1 FROM BillRel000 rel WHERE rel.ParentGUID = [Order].Guid ) ) 
					)

ALTER TABLE #selectedOrders
ADD CONSTRAINT PK_ORDERGUID PRIMARY KEY ([GUID]);
-- Featch Order Pay Names
IF @Pay = 1 
BEGIN
	DECLARE @colsNull NVARCHAR(MAX) = '' , @cols NVARCHAR(MAX) = '' ,  
	@colsSum NVARCHAR(MAX) = '' , @colsDef NVARCHAR(MAX) = '' , 
	@query  AS NVARCHAR(MAX) = '', @QuotedName NVARCHAR(30) = ''

	SELECT @QuotedName = QUOTENAME(PayName) ,
	 @cols = @cols + N',' + @QuotedName , 
	 @colsNull = @colsNull + N',ISNULL(' + @QuotedName  + N',0) AS ' + @QuotedName ,	 
	 @colsSum = @colsSum +  N', SUM(ISNULL(' + @QuotedName  + N',0)) AS ' + @QuotedName , 
	 @colsDef = @colsDef + N',' + @QuotedName + ' FLOAT NOT NULL ' 
	 FROM 
	(
		SELECT  'Check' + CAST(nt.SortNum AS NVARCHAR(3))  [PayName] FROM nt000 nt
		WHERE EXISTS ( SELECT 1 FROM POSPaymentsPackageCheck000 ch WHERE ch.Type = nt.GUID  )
		UNION ALL
		SELECT  'Currency' + CAST(Number AS NVARCHAR(3)) FROM my000 my 
		WHERE EXISTS( SELECT 1 FROM POSPaymentsPackageCurrency000 Cur WHERE Cur.CurrencyID = my.GUID )
		UNION ALL 
		SELECT TOP 1 'Deffered' FROM POSPaymentsPackage000 WHERE DeferredAccount != 0x0	
		UNION ALL 
		SELECT TOP 1 'Points' FROM POSPaymentsPackagePoints000 
	)t

	IF ISNULL(@cols, '') <> ''
	BEGIN
		SET @cols = STUFF(@cols,1,1,'')
		SET @colsDef = STUFF(@colsDef,1 ,1 ,'')

		SET @query = ' ALTER TABLE #PayDetails ADD  ' + @colsDef 
		EXEC sp_executesql @query
		SET @query = ' SELECT  OrderID  ' + @colsNull +   ' FROM 
					(	
						SELECT  [Order].[Guid] [OrderID], ''Currency'' + CAST(my.Number AS NVARCHAR) [PayName], cur.Paid - cur.Returned [PayTotal]
							FROM #selectedOrders  [Order]
							INNER JOIN POSPaymentsPackage000 pack ON [Order].PaymentsPackageID = pack.[Guid]
							INNER JOIN POSPaymentsPackageCurrency000 cur ON pack.[Guid] = cur.ParentID
							INNER JOIN my000 my ON my.GUID = cur.CurrencyID
							UNION ALL
							SELECT  [Order].[Guid], ''Check'' + CAST(nt.SortNum AS NVARCHAR), 
							( ( ch.paid * IIF (NewVoucher = 1 , -1 , 1 ) ) / ch.CurrencyValue ) * SIGN(OrderNetTotal)
							FROM  #selectedOrders [Order]
							INNER JOIN POSPaymentsPackageCheck000 ch ON (ch.ParentID = [Order].PaymentsPackageID)   
							INNER JOIN nt000 nt ON nt.GUID = ch.Type
							UNION ALL
							SELECT [Order].[Guid], ''Check'' + CAST(nt.SortNum AS NVARCHAR), ReturnVoucherValue / ch.CurrencyVal
							FROM  #selectedOrders [Order]
							INNER JOIN POSPaymentsPackage000 pack  ON PaymentsPackageID = pack.Guid
							INNER JOIN ch000 ch ON ch.GUID = ReturnVoucherID
							INNER JOIN nt000 nt ON nt.GUID = ch.TypeGUID
							UNION ALL
							SELECT [Order].[Guid], ''Deffered'', pack.DeferredAmount / [HistoryCurVal] 
							FROM  #selectedOrders [Order]
							INNER JOIN POSPaymentsPackage000 pack ON [Order].PaymentsPackageID = pack.[Guid]
							UNION ALL
							SELECT [Order].[Guid], ''Points'', PointsValue / [HistoryCurVal]  
							FROM #selectedOrders [Order]
							INNER JOIN POSPaymentsPackagePoints000 pp ON pp.ParentGUID = [Order].PaymentsPackageID
							UNION ALL
							SELECT [Order].[Guid] , '''' , 0.0
							FROM  #selectedOrders  [Order]
							WHERE [Order].PaymentsPackageID = 0x0 
					) x
					PIVOT ( SUM ( PayTotal) FOR [PayName] IN (' + @cols + N')) p'		
		INSERT INTO #PayDetails EXEC sp_executesql @query;
	END
	ELSE
		SET @Pay = 0
	END

IF (@GroupBy = 0)
BEGIN
	IF @Pay = 0 
		INSERT INTO #PayDetails SELECT [GUID] FROM #selectedOrders

	SELECT  [Rel].ParentGUID  , ' - ' + CAST(bu.buNumber AS NVARCHAR(15)) + ' ' +  
				IIF ( @lang = 0 ,  btAbbrev  , btlatinAbbrev)   AS [BillNum]
	INTO #rel
	FROM  [vwbu] [bu]
	INNER JOIN [BillRel000] [Rel] ON   buGUID = [Rel].BillGUID
	WHERE EXISTS ( SELECT 1 FROM #selectedOrders o WHERE  o.GUID = [Rel].ParentGUID )

	SELECT
		[OrderNumber], 
		[OrderType],	
		[OrderDate], 
		[OrderOpeningTime],
		[OrderNotes], 
		[TotalDiscount] / [HistoryCurVal] [TotalDiscount], 
		[TotalAdded]	/ [HistoryCurVal] [TotalAdded], 
		[OrderAdded]	/ [HistoryCurVal] [OrderAdded], 
		[OrderDiscount] / [HistoryCurVal] [OrderDiscount], 
		[ItemsAdded]	/ [HistoryCurVal] [ItemsAdded], 
		[ItemsDiscount] / [HistoryCurVal] [ItemsDiscount],
		[OrderTax]		/ [HistoryCurVal] [OrderTax], 
		[OrderSubTotal] / [HistoryCurVal] [OrderSubTotal],
		[OrderNetTotal]	/ [HistoryCurVal] [OrderNetTotal],
		[Payment]		/ [HistoryCurVal] [Payment], 
		[PointsCount],
		[CuID], [CuName], [BrId], [BrName], [UsName],
		[CustomerSubscribtionCode], 
		ISNULL( [BuyPoints], 0) , 
		ISNULL( [ReturnedPoints], 0),
		STUFF( (
				 SELECT BillNum
				 FROM   #rel
				 WHERE  [Order].GUID = ParentGUID
				 FOR XML PATH(''), TYPE 
				).value('.', 'NVARCHAR(MAX)'),1 ,3 , ''
			 ) BillNum	,
		[pd].*
	FROM #selectedOrders [Order]
		INNER JOIN #PayDetails pd ON [pd].[OrderID] = [Order].[Guid]
		OUTER APPLY (
			SELECT 
				CustomerNumber AS [CustomerSubscribtionCode], 
				SUM(IIF ( Type = 0  , Points , 0)) BuyPoints, 
				SUM(IIF ( Type = 1  , Points , 0)) ReturnedPoints
			FROM scpurchases000 
			WHERE  [Order].GUID = OrderID  
			GROUP BY  OrderID, CustomerNumber
		) t
	ORDER BY [OrderNumber]

--Fetch Order items

	IF @ShowDetails = 1 
		SELECT mt.Guid as [MtGuid],
			[Item].ParentID [OrderGuid],
			isnull(mt.code, '')  [MtCode],
			isnull(mt.name, '')  [MtName],
			isnull(mt.LatinName, '')  [MtLatinName],
			CASE [Item].Unity WHEN 1 THEN mt.Unity WHEN 2 THEN mt.Unit2 WHEN 3 THEN mt.Unit3 ELSE mt.Unity END [Unit],
			[Item].Qty [Qty],
			[Item].Price	 / [HistoryCurVal] [Price],
			[Item].Added	 / [HistoryCurVal] [Added],
			[Item].Discount  / [HistoryCurVal] [Discount],
			[Item].Tax		 / [HistoryCurVal] [Tax],
			([Item].MatPrice  * [Item].Qty) / [HistoryCurVal] [MatPrice],
			(CASE [Item].[Type] WHEN 0 THEN  (Price * [Item].Qty) + Added + Tax - Discount 
								WHEN 1 THEN -1 * ( (Price * [Item].Qty) + Added + Tax - Discount)  
			 END
			) / [HistoryCurVal] [Total],
			[Item].[Type] [Type],
			co.Name [SalesmanName],
			co.Name [SalesmanLatinName], 
			[Item].[Note],
			[Item].[SerialNumber],
			[Item].[ClassPtr],
			[Item].[ExpirationDate]
		FROM #selectedOrders [Order]
		INNER JOIN  POSOrderItems000 [Item] ON [Item].ParentID = [Order].[GUID]
		INNER JOIN mt000 mt ON mt.[GUID] = [Item].MatID
		LEFT JOIN co000 co ON co.Guid = Item.SalesmanID

END
ELSE 
BEGIN

	DECLARE @orderDate AS NVARCHAR(300) = ''
	IF (@GroupBy = 1)
		SET @orderDate = 'RIGHT(''0''+CAST(MONTH([OrderDate]) AS nvarchar(2)),2) + ''-'' + CAST(YEAR([OrderDate]) AS nvarchar(4))'
	ELSE IF (@GroupBy = 2)
		SET @orderDate = 'CAST (CONVERT(date, [OrderDate]) AS nvarchar(12))'
	ELSE IF (@GroupBy = 3)
		SET @orderDate = 'CAST(CONVERT(date, [OrderDate]) AS nvarchar(12)) + '' '' +  CAST(DATEPART(HOUR, [OrderDate]) AS nvarchar(2)) + '' ''  + RIGHT(CONVERT(VARCHAR(30), [OrderDate], 9),2)'	
	ELSE IF (@GroupBy = 4)
		SET @orderDate = 'CAST(DATEPART(HOUR, [OrderDate]) AS nvarchar(2)) + '' ''  + RIGHT(CONVERT(VARCHAR(30), [OrderDate], 9),2)'

	SET  @query  = N'
		SELECT ' + @orderDate + ' AS [OrderDate],
		COUNT(*) AS BillCount,
		SUM( [TotalDiscount]  / [HistoryCurVal] ) [TotalDiscount], 
		SUM( [TotalAdded]	  / [HistoryCurVal] ) [TotalAdded], 
		SUM( [OrderAdded]     / [HistoryCurVal] ) [OrderAdded], 
		SUM( [OrderDiscount]  / [HistoryCurVal] ) [OrderDiscount], 
		SUM( [ItemsAdded]     / [HistoryCurVal] ) [ItemsAdded], 
		SUM( [ItemsDiscount]  / [HistoryCurVal] ) [ItemsDiscount] , 
		SUM( [OrderTax]		  / [HistoryCurVal] ) [OrderTax], 		
		SUM( [OrderSubTotal]  / [HistoryCurVal] ) [OrderSubTotal],
		SUM( [OrderNetTotal]  / [HistoryCurVal] ) [OrderNetTotal],
		SUM( [PointsCount]) [PointsCount] ' 
		+ ISNULL(@colsSum,'') + N' FROM #selectedOrders [Order] ' +
		IIF(@Pay = 1, 'LEFT JOIN #PayDetails pd ON pd.OrderID = [Order].[Guid]','') + '		
		GROUP BY ' + @orderDate + ' ORDER BY BillCount DESC '

	EXEC sp_executesql @query
END
################################################################################	
CREATE PROCEDURE prcPOSTotalsByPayType
	@CashierGuid  [uniqueidentifier],
	@showGroups [BIT],
	@showCur [BIT],
	@showNotes [BIT],
	@showDefAcc [BIT],
	@showVoucher [BIT],
	@showCurDetails [BIT],
	@showBillDetails [BIT],
	@showChecksDetails [BIT],
	@showVoucherDetails [BIT]
AS
	SET NOCOUNT ON
	DECLARE @MainCurrencyID [UNIQUEIDENTIFIER],
			@POSCurrencyID  [UNIQUEIDENTIFIER],
			@CalcCurrencyVal [BIT] = 0

	SELECT TOP 1 @POSCurrencyID = ISNULL([Value], 0x0)
	FROM FileOP000 
    WHERE [Name] = 'AmnPOS_DefaultCurrencyID'

	IF(@POSCurrencyID <> 0x0)
	BEGIN 
		SELECT TOP 1 @MainCurrencyID = [GUID] 
		FROM [MY000] 
		WHERE CurrencyVal = 1 
		IF(@MainCurrencyID <> @POSCurrencyID)
			SET @CalcCurrencyVal = 1
	END

	DECLARE @selectedOrders TABLE 
	( 
		[GUID] [uniqueidentifier]
	)

	INSERT INTO @selectedOrders
	SELECT 
		[GUID] 
	FROM 
		POSOrder000 [Order]
	WHERE
	    (@CashierGuid = 0x0 OR @CashierGuid = [Order].CashierID) AND ([Order].[Serial] = 0)

	IF (@showBillDetails = 1)
	BEGIN
		SELECT 
			bu.buNumber AS Number, 
			CONVERT(date, bu.buDate) AS [Date],
			bt.[btBillType], 
			bt.btAbbrev AS Abbrev, 
			bt.btLatinAbbrev AS LatinAbbrev,
			bt.btName, 
			bt.btLatinName, 
			cu.cuCustomerName, 
			cu.cuLatinName,
			IIF(@CalcCurrencyVal = 1, [dbo].fnGetFixedValue((bu.buTotal - bu.buTotalDisc + buTotalExtra + buVAT), [Order].[Date]),
			   (bu.buTotal - bu.buTotalDisc + buTotalExtra + buVAT) )  AS Total
		FROM 
			vwBu bu
			CROSS APPLY (SELECT TOP 1 [Type], BillGUID, ParentGUID FROM BillRel000 WHERE BillGUID = bu.buGUID) rel 
			INNER JOIN POSOrder000 [Order] ON [Order].[Guid] = REL.ParentGUID  
			INNER JOIN vwBt bt ON bu.buType = bt.btGUID
			INNER JOIN @selectedOrders sel ON sel.[Guid] = [Order].[Guid]
			LEFT JOIN  vwCu cu ON bu.buCustPtr = cu.cuGUID
		ORDER BY
			bt.btBillType, bt.btAbbrev, bu.buNumber
	RETURN
	END

	ELSE
	IF (@showChecksDetails = 1)
	BEGIN
		SELECT
			ch.Number AS Number,
			nt.[Name], 
			nt.LatinName,
			chk.Paid / (CASE  chk.CurrencyValue WHEN 0 THEN 1 ELSE chk.CurrencyValue END ) AS Total,
			ch.Num AS  ChKNumber      
		FROM 
			POSOrder000 [Order]
			INNER JOIN pospaymentspackage000 pack ON pack.[GUID]=[Order].PaymentsPackageID
			INNER JOIN pospaymentspackageCheck000 chk ON chk.ParentID=pack.[GUID]
			INNER JOIN ch000 ch ON chk.ChildID=ch.[GUID]
			INNER JOIN nt000 nt ON nt.[GUID] = chk.[Type]
			INNER JOIN @selectedOrders sel ON sel.[Guid] = [Order].[Guid]
		ORDER BY nt.[Name], ch.Number
	RETURN
	END
	ELSE
	IF (@showVoucherDetails = 1)
	BEGIN	
		SELECT
			ch.Number AS Number,
			nt.[Name],
			nt.LatinName,
			ch.Val / (CASE  ch.CurrencyVal WHEN 0 THEN 1 ELSE ch.CurrencyVal  END ) AS Total,
			ch.Num AS  ChKNumber    
		FROM 
			POSOrder000 [Order]
			INNER JOIN pospaymentspackage000 pack ON pack.[GUID] = [Order].PaymentsPackageID
			INNER JOIN ch000 ch ON ch.[GUID] = pack.ReturnVoucherID 
			INNER JOIN nt000 nt ON nt.[GUID] = ch.TypeGUID
			INNER JOIN  @selectedOrders sel ON sel.[Guid] = [Order].[Guid]
		WHERE  ch.[State] = 1 
		ORDER BY nt.Name, ch.Number
	RETURN
	END
	ELSE
	BEGIN
	DECLARE @master TABLE 
	( 
		[ID] [INT]
	)
	DECLARE @showPoints bit 
	SET @showPoints = 0
	IF (@showCur = 1) AND EXISTS(
								SELECT 
									1
								FROM 
									POSOrder000 [Order] 
									INNER JOIN POSPaymentsPackage000 [Pack] ON [Order].PaymentsPackageID = [Pack].[Guid]
									INNER JOIN POSPaymentsPackagePoints000 pp  ON [Pack].[Guid] = [pp].ParentGuid
									INNER JOIN  @selectedOrders sel ON sel.[Guid] = [Order].[Guid]
								HAVING ISNULL(SUM(pp.PointsValue), 0) > 0)
		SET @showPoints = 1

	IF @showGroups = 1
		INSERT INTO @master VALUES (0)
	IF @showCurDetails = 1
		INSERT INTO @master VALUES (1)
	IF @showCur = 1
		INSERT INTO @master VALUES (2)
	IF @showNotes = 1
		INSERT INTO @master VALUES (3)
	IF @showDefAcc = 1
		INSERT INTO @master VALUES (4)
	IF @showPoints = 1 
		INSERT INTO @master VALUES (5)
	DECLARE @ReturnVouchers TABLE 
	( 
		[UserID] [UNIQUEIDENTIFIER],
        [ReturnVoucherType] [UNIQUEIDENTIFIER]
	)

	INSERT INTO @ReturnVouchers (UserID, ReturnVoucherType)
	SELECT UserID, [Value] 
	FROM UserOP000
	WHERE 
	([Name] = 'AmnPOS_ReturnVoucherType' AND ( UserID = @CashierGuid OR @CashierGuid = 0x0))

	SELECT [ID] FROM @master

	;WITH TotalGroup AS
	(
	SELECT 
		 0 [Type],
		 0 buNumber,
		 '' btAbbrev,
		 '' btLatinAbbrev, 
		 [gr].[Name] [Name], 
		 [gr].LatinName LatinName, 
		 SUM(
		  (CASE [item].[TYPE] 
				WHEN 1 THEN  -1 * ( (([item].Price * [item].Qty) + [item].Tax - [item].Discount + [item].Added)
								    +(ISNULL(D.ReturnSalesAdded, 0) *  ([item].Price * [item].Qty + [item].Added))
								     / IIF(ISNULL( D.ReturnSalesSubTotalWithAdded, 0) = 0, 1, D.ReturnSalesSubTotalWithAdded ))
									 -  ((ISNULL(D.ReturnSalesDisount, 0 )  *   ([item].Price * [item].Qty - [item].Discount) )
									 / IIF(ISNULL( D.ReturnSalesOrderSubTotalWithDisc, 0) = 0, 1, D.ReturnSalesOrderSubTotalWithDisc ))

				ELSE  (([item].Price * [item].Qty) + [item].Tax - [item].Discount + [item].Added) 
								+(ISNULL(D.SalesOrderAdded, 0 ) *  ([item].Price * [item].Qty + [item].Added))
								/ IIF( ISNULL(D.SalesOrderSubTotalWithAdded, 0) = 0, 1, D.SalesOrderSubTotalWithAdded )
								- ( (ISNULL(D.SalesDiscount, 0 )  *  ([item].Price * [item].Qty - [item].Discount) )
								/  IIF( ISNULL(D.SalesOrderSubTotalWithDisc, 0) = 0, 1, D.SalesOrderSubTotalWithDisc))
			END) 
		 ) AS Total,
					
		1 Equal,
		[Order].[Date] AS OrderDate
	FROM
		POSOrder000 [Order] 
		INNER JOIN  @selectedOrders sel    ON sel.[Guid] = [Order].[Guid] 
		INNER JOIN POSOrderItems000 [Item] ON [Order].[Guid] = [Item].[ParentID]
		INNER JOIN mt000 [Mt] ON [Item].[MatID] = [Mt].[GUID]
		INNER JOIN gr000 [gr] ON [Mt].[GroupGUID] = [gr].[GUID]
		OUTER APPLY dbo.fnPOSGetOrderDiscAdded([Order].[GUID]) D
	WHERE
		 (@showGroups = 1)
		 AND 
		 ([Order].[Type] = 0 OR [Order].[Type] = 1 )
		 AND
		 ([item].[State] <> 1)
	GROUP BY
		[gr].[Name],
		[gr].LatinName,
		[Order].[Date] 
		)

	SELECT
		[Type],
	    buNumber,
		btAbbrev,
		btLatinAbbrev, 
		[Name], 
		LatinName,
		SUM(IIF(@CalcCurrencyVal = 1, dbo.fnGetFixedValue(Total,OrderDate), Total )) AS Total,
	    Equal
	FROM TotalGroup
	GROUP BY
		[Type],
	    buNumber,
		btAbbrev,
		btLatinAbbrev, 
		[Name], 
		LatinName,
	    Equal

	UNION

	SELECT 
		1 [Type], 
		[Order].[Number] buNumber, 
		'' btAbbrev, 
		'' btLatinAbbrev, 
		[My].[Name], 
		[My].LatinName, 
	    [Cur].Paid - [Cur].Returned AS Total,
		Equal / IIF(@CalcCurrencyVal = 1, dbo.fnGetCurVal(@PosCurrencyID,[order].[date]), 1) AS Equal
	FROM 
		POSOrder000 [Order] 
		INNER JOIN POSPaymentsPackage000 [Pack] ON [Order].PaymentsPackageID = [Pack].[Guid]
		INNER JOIN POSPaymentsPackageCurrency000 [Cur] ON [Pack].[Guid] = [Cur].ParentID
		INNER JOIN  @selectedOrders sel ON sel.[Guid] = [Order].[Guid]
		INNER JOIN my000 [My] ON [Cur].CurrencyID = [My].[GUID]
	WHERE 
		 @showCurDetails = 1

	UNION

	SELECT 
		2 [Type],
		0 buNumber, 
		'' btAbbrev, 
		'' btLatinAbbrev, 
		[My].[Name], 
		[My].LatinName, 
		SUM(Cur.Paid - Cur.Returned ) AS Total, 
		Cur.Equal / IIF(@CalcCurrencyVal = 1, dbo.fnGetCurVal(@PosCurrencyID,[order].[date]), 1) AS Equal
	FROM 
		POSOrder000 [Order] 
		INNER JOIN POSPaymentsPackage000 [Pack] ON [Order].PaymentsPackageID = [Pack].[Guid]
		INNER JOIN POSPaymentsPackageCurrency000 [Cur] ON [Pack].[Guid] = [Cur].ParentID
		INNER JOIN  @selectedOrders sel ON sel.[Guid] = [Order].[Guid]
		INNER JOIN my000 [My] ON [Cur].CurrencyID = [My].[GUID]
	WHERE 
		 @showCur = 1
		 
	GROUP BY 
		[My].[Name],
		[My].LatinName,
		Cur.Equal / IIF(@CalcCurrencyVal = 1, dbo.fnGetCurVal(@PosCurrencyID,[order].[date]), 1)
	
	UNION

	SELECT 
		3 [Type], 
		0 buNumber, 
		'' btAbbrev, 
		'' btLatinAbbrev, 
		[Nt].Name, 
		[Nt].LatinName, 
		SUM( (CASE Ch.[Type] WHEN rtv.ReturnVoucherType THEN -1 ELSE 1 END) * Paid / [Ch].CurrencyValue ) AS Total, 
		[Ch].CurrencyValue / IIF(@CalcCurrencyVal = 1, dbo.fnGetCurVal(@PosCurrencyID,[order].[date]), 1) AS  Equal
	FROM 
		POSOrder000 [Order] 
		INNER JOIN  @selectedOrders sel ON sel.[Guid] = [Order].[Guid]
		INNER JOIN POSPaymentsPackage000 [Pack] ON [Order].PaymentsPackageID = [Pack].[Guid]
		INNER JOIN POSPaymentsPackageCheck000 [Ch] ON [Pack].[Guid] = [Ch].ParentID
		INNER JOIN @ReturnVouchers rtv ON  rtv.UserID = [Order].FinishCashierID 
		INNER JOIN nt000 [Nt] ON [Ch].[Type] = [Nt].[GUID]
	
	WHERE 
		 @showNotes = 1
		AND
		 NOT EXISTS (
		              SELECT 1 FROM POSPaymentsPackage000 P
					   WHERE P.ReturnVoucherID = ch.ChildID  )
	GROUP BY 
		[Nt].[Name],
		[Nt].LatinName,
		[Ch].CurrencyValue / IIF(@CalcCurrencyVal = 1, dbo.fnGetCurVal(@PosCurrencyID, [order].[date]), 1)

	UNION

	SELECT 
		4 [Type], 
		0 buNumber, 
		'' btAbbrev, 
		'' btLatinAbbrev, 
		[Acc].[Name], 
		[Acc].LatinName, 
		SUM(IIF(@CalcCurrencyVal = 1, [dbo].fnGetFixedValue(DeferredAmount, [Order].[Date]), DeferredAmount) ) AS Total, 
		1 Equal
	FROM 
		POSOrder000 [Order] 
		INNER JOIN  @selectedOrders sel ON sel.[Guid] = [Order].[Guid]
		INNER JOIN POSPaymentsPackage000 [Pack] ON [Order].PaymentsPackageID = [Pack].[Guid]
		INNER JOIN cu000 [Cu] ON [Pack].[DeferredAccount] = [Cu].[GUID]
		INNER JOIN ac000 [Acc] ON [Cu].[AccountGUID] = [Acc].[GUID]
	WHERE 
		 @showDefAcc = 1 
	GROUP BY 
		[Acc].Name, [Acc].LatinName
	HAVING SUM(DeferredAmount) <> 0

	UNION

	SELECT 
		5 [Type],
		0 buNumber, 
		'' btAbbrev, 
		'' btLatinAbbrev, 
		'' [Name], 
		'' LatinName, 
		ISNULL(SUM(pp.PointsValue), 0) AS Total, 
		1 AS Equal
	FROM 
		POSOrder000 [Order] 
		INNER JOIN POSPaymentsPackage000 [Pack] ON [Order].PaymentsPackageID = [Pack].[Guid]
		INNER JOIN POSPaymentsPackagePoints000 pp  ON [Pack].[Guid] = [pp].ParentGuid
		INNER JOIN  @selectedOrders sel ON sel.[Guid] = [Order].[Guid]
	WHERE 
		  @showPoints = 1
	HAVING ISNULL(SUM(pp.PointsValue), 0) > 0
    ORDER BY 
		[Type],
		btAbbrev,
		buNumber
END
################################################################################
CREATE PROCEDURE repPOSPaidOrders
	@startDate [DateTime],
	@endDate   [DateTime],
	@CashierGuid  [UNIQUEIDENTIFIER],
	@SalesManGuid [UNIQUEIDENTIFIER],
	@showGroups [BIT],
	@showMats [BIT],
	@showCurDetails [BIT],
	@showChecksDetails [BIT],
	@showCreditPaymentsDetails [BIT]
	
AS
	SET NOCOUNT ON
	DECLARE @selectedOrders TABLE 
	( 
		[GUID] [UNIQUEIDENTIFIER]
	)
	INSERT INTO @selectedOrders
	SELECT 
		[GUID]
	FROM 
		POSOrder000 [Order]
	WHERE 
	    (@CashierGuid = 0x0 OR @CashierGuid=[Order].FinishCashierID)
		AND (@SalesManGuid = 0x0 OR @SalesManGuid = [Order].SalesManID)
		AND ([Order].[Date] BETWEEN @startDate AND @endDate)
	DECLARE @language [INT]		
	SET @language = [dbo].[fnConnections_getLanguage]() 
	
    DECLARE @master TABLE 
	( 
		[ID] [UNIQUEIDENTIFIER] ,
		[Type] [INT],
		[OrderDate] [DATETIME],
		[Note] NVARCHAR(1000),
		[FinalTotal]  [FLOAT],
		[UserName] NVARCHAR(500),
		[SalesManName] NVARCHAR(500),
		[ParentID] [UNIQUEIDENTIFIER],
		[SortNum] [INT] DEFAULT 0
	)
	INSERT INTO 
			@master (ID, [Type], OrderDate, Note, FinalTotal, UserName, SalesManName, ParentID)
	SELECT 
			NEWID(),
			1,
			[Order].[Date],
			'',
			[Order].SubTotal + [Order].Added + (SELECT  Sum(( IIF([Type] = 1 , -1, 1 ) * Tax )) FROM POSOrderItems000 WHERE ParentID = [Order].[Guid] ) - [Order].Discount,
			us.LoginName,
			ISNULL(CO.[Name],''),
			0x0
	FROM  
		 POSOrder000 [Order]  
		INNER JOIN @selectedOrders SEL ON [Order].[Guid] = SEL.[GUID]
		INNER JOIN us000 us ON [Order].FinishCashierID  = us.[GUID]
		LEFT JOIN co000 CO ON [Order].SalesManID = CO.[GUID]
	WHERE 
		[Order].[TYPE] = 0 OR [Order].[TYPE] = 1 
	
	IF(@@ROWCOUNT = 0)
	INSERT INTO @master (ID, [Type], OrderDate, Note, FinalTotal, UserName, SalesManName, ParentID)
	VALUES (NEWID(), 1 , 0x0, '' , 0 , '' , '' ,0x0)
	DECLARE @NetSalesGuid [uniqueidentifier]
	SELECT TOP(1) @NetSalesGuid =  ID from @master
	 
	INSERT INTO 
		@master (ID, [Type], OrderDate, Note, FinalTotal, UserName, SalesManName, ParentID)
	SELECT 
		NEWID(),
		2,
		[Order].[Date],
		'',
		(ISNULL( (Cur.Paid - Cur.Returned) * [Cur].Equal, 0)),
		us.LoginName,
		ISNULL(CO.[Name],''),
		0x0
	FROM
		 POSOrder000 [Order] ​
		INNER JOIN POSPaymentsPackage000 [Pack] ON [Order].PaymentsPackageID = [Pack].[Guid]​
		INNER JOIN POSPaymentsPackageCurrency000 [Cur] ON [Pack].[Guid] = [Cur].ParentID​
		INNER JOIN @selectedOrders SEL ON [Order].[Guid] = SEL.[GUID]
		INNER JOIN us000 us ON [Order].FinishCashierID  = us.[GUID]
		LEFT JOIN co000 CO ON [Order].SalesManID = CO.[GUID]
	IF(@@ROWCOUNT = 0)
    INSERT INTO @master (ID, [Type], OrderDate, Note, FinalTotal, UserName, SalesManName, ParentID)
	VALUES ( NEWID() , 2 , 0x0, '' , 0 , '' , '' , 0x0 )

	DECLARE @CashGuid [uniqueidentifier]
	SELECT TOP(1) @CashGuid = ID FROM @master
	WHERE [TYPE] = 2

	DECLARE @ReturnVouchers TABLE 
	( 
		[UserID] [UNIQUEIDENTIFIER],
        [ReturnVoucherType] [UNIQUEIDENTIFIER]
	)

	INSERT INTO @ReturnVouchers (UserID, ReturnVoucherType)
	SELECT UserID, [Value] 
	FROM UserOP000
	WHERE 
	([Name] = 'AmnPOS_ReturnVoucherType' AND ( UserID = @CashierGuid OR @CashierGuid = 0x0))
		
	INSERT INTO
		@master  (ID, [Type], OrderDate, Note, FinalTotal, UserName, SalesManName, ParentID)
	SELECT
		 NEWID(),
		 3,
		 [Order].[Date],
		 '',
		 ISNULL(((CASE CHK.[Type] WHEN RVT.ReturnVoucherType THEN -1 ELSE 1 END) * CHK.Paid) , 0),
		 us.LoginName,
		 ISNULL(CO.[Name],''),
		 0x0
	FROM 
		POSOrder000 [ORDER]​
		INNER JOIN POSPaymentsPackage000 [Pack] ON [Order].PaymentsPackageID = [Pack].[Guid]​
		INNER JOIN POSPaymentsPackageCheck000 CHK ON CHK.ParentID = [Pack].[Guid]
		INNER JOIN nt000 NT ON CHK.[Type] = NT.[GUID]​
		INNER JOIN @selectedOrders SEL ON [Order].[Guid] = SEL.[GUID]
		INNER JOIN us000 us ON [Order].FinishCashierID  = us.[GUID]
		INNER JOIN @ReturnVouchers RVT ON RVT.UserID = us.[GUID]
		LEFT JOIN co000 CO ON [Order].SalesManID = CO.[GUID]
	UNION ALL
	SELECT
			 NEWID(),
			 3,
			 [Order].[Date],
			 '',
			ISNULL(ch.Val ,0) ,
			us.LoginName,
			ISNULL(CO.Name,''),
			0x0
	FROM 
			POSOrder000 [Order] 
			INNER JOIN pospaymentspackage000 pack ON pack.[GUID] = [Order].PaymentsPackageID
			INNER JOIN ch000 ch ON ch.[GUID] = pack.ReturnVoucherID
			INNER JOIN nt000 nt ON nt.[GUID] = ch.TypeGUID
			INNER JOIN us000 us ON [Order].FinishCashierID  = us.[GUID]
			INNER JOIN @selectedOrders SEL ON [Order].[Guid] = SEL.[GUID]
			LEFT JOIN co000 CO ON [Order].SalesManID = CO.[GUID]
	
	 
   
   IF(@@ROWCOUNT = 0)
   INSERT INTO @master (ID, [Type], OrderDate, Note, FinalTotal, UserName, SalesManName, ParentID)
   VALUES (NEWID(), 3 , 0x0,'' , 0 , '' , '' , 0x0 )
	DECLARE @CheckGuid [uniqueidentifier]
	SELECT TOP (1) @CheckGuid = ID 
	FROM @master
	WHERE [TYPE] = 3

	---Deferred Pay
	INSERT INTO 
			@master (ID, [Type], OrderDate, Note, FinalTotal, UserName, SalesManName, ParentID)
	SELECT 
			NEWID(),
			4,
			[Order].[Date],
			'',
			(ISNULL(PACK.DEFERREDAMOUNT, 0) ),
			us.LoginName,
			ISNULL(CO.Name,''),
			0x0
	FROM 
		POSOrder000 [Order] ​
		INNER JOIN POSPaymentsPackage000 [Pack] ON [Order].PaymentsPackageID = [Pack].[Guid]​
		INNER JOIN cu000 [Cu] ON [Pack].[DeferredAccount] = [Cu].[GUID]​
		INNER JOIN ac000 [Acc] ON [Cu].[AccountGUID] = [Acc].[GUID]​
		INNER JOIN @selectedOrders SEL ON [Order].[Guid] = SEL.[GUID]	
		INNER JOIN us000 us ON [Order].FinishCashierID  = us.[GUID]
		LEFT JOIN co000 CO ON [Order].SalesManID = CO.[GUID]
	WHERE 
		PACK.DeferredAmount != 0
   IF(@@ROWCOUNT = 0)
   INSERT INTO @master (ID, [Type], OrderDate, Note, FinalTotal, UserName, SalesManName, ParentID)
   VALUES ( NEWID() , 4 , 0x0, '' , 0 , '' , '' , 0x0 )
	DECLARE @CreditPaymentGuid [uniqueidentifier]
	SELECT TOP (1)  @CreditPaymentGuid = ID  FROM @master
	WHERE [TYPE] = 4

	INSERT INTO 
			@master (ID, [Type], OrderDate, Note, FinalTotal, UserName, SalesManName, ParentID)
		
	SELECT
			 NEWID(),
			 15,
			 [Order].[Date],
			 '',
			ISNULL([Order].payment, 0) ,
			us.LoginName,
			ISNULL(CO.[Name],''),
			0x0
	FROM 
			 POSOrder000 [Order] 
			INNER JOIN us000 us ON [Order].FinishCashierID  = us.[GUID]
			INNER JOIN @selectedOrders SEL ON [Order].[Guid] = SEL.[GUID]
			LEFT JOIN co000 CO ON [Order].SalesManID = CO.[GUID]
	WHERE [Order].[TYPE] = 2 

	--Loyalty Card Pay
	INSERT INTO 
			@master (ID, [Type], OrderDate, Note, FinalTotal, UserName, SalesManName, ParentID)
		
	SELECT
			 NEWID(),
			 17,
			 [Order].[Date],
			 '',
			ISNULL(pp.PointsValue, 0) ,
			us.LoginName,
			ISNULL(CO.[Name],''),
			0x0
	FROM 
			POSOrder000 [Order] 
			INNER JOIN POSPaymentsPackage000 [Pack] ON [Order].PaymentsPackageID = [Pack].[Guid]​
			INNER JOIN POSPaymentsPackagePoints000 pp ON pp.ParentGUID = [Pack].[Guid]
			INNER JOIN us000 us ON [Order].FinishCashierID  = us.[GUID]
			INNER JOIN @selectedOrders SEL ON [Order].[Guid] = SEL.[GUID]
			LEFT JOIN co000 CO ON [Order].SalesManID = CO.[GUID]


	IF( @showGroups = 1 )
	BEGIN
		INSERT INTO @master (ID, [Type], OrderDate, Note, FinalTotal, UserName, SalesManName, ParentID)
		SELECT 
		    gr.[GUID],
			5,
			[Order].[Date],
		    (CASE 
				WHEN @language <> 0 AND gr.LatinName <> ''
				THEN gr.LatinName 
				ELSE gr.[Name]
			 END),
			(CASE [item].[TYPE] 
				WHEN 1 THEN  -1 * ( (([item].Price * [item].Qty) + [item].Tax - [item].Discount + [item].Added)
								    +(ISNULL(D.ReturnSalesAdded, 0) *  ([item].Price * [item].Qty + [item].Added))
								     / IIF(ISNULL( D.ReturnSalesSubTotalWithAdded, 0) = 0, 1, D.ReturnSalesSubTotalWithAdded ))
									 -  ((ISNULL(D.ReturnSalesDisount, 0 )  *   ([item].Price * [item].Qty - [item].Discount) )
									 / IIF(ISNULL( D.ReturnSalesOrderSubTotalWithDisc, 0) = 0, 1, D.ReturnSalesOrderSubTotalWithDisc ))

						ELSE  (([item].Price * [item].Qty) + [item].Tax - [item].Discount + [item].Added) 
								+(ISNULL(D.SalesOrderAdded, 0 ) *  ([item].Price * [item].Qty + [item].Added))
								/ IIF( ISNULL(D.SalesOrderSubTotalWithAdded, 0) = 0, 1, D.SalesOrderSubTotalWithAdded )
								- ( (ISNULL(D.SalesDiscount, 0 )  *  ([item].Price * [item].Qty - [item].Discount) )
								/  IIF( ISNULL(D.SalesOrderSubTotalWithDisc, 0) = 0, 1, D.SalesOrderSubTotalWithDisc))
			END) 
			 ,
			us.LoginName,
			ISNULL(CO.[Name],''),
			@NetSalesGuid
		FROM POSOrder000 [order]
			INNER JOIN POSOrderItems000 [item] ON [order].[GUID] = item.ParentID
			INNER JOIN MT000 MT ON [item].MatID = MT.[GUID]
			INNER JOIN gr000 GR ON MT.GroupGUID = GR.[GUID]
			INNER JOIN @selectedOrders SEL ON [Order].[Guid] = SEL.[GUID]	
			INNER JOIN us000 us ON [Order].FinishCashierID  = us.[GUID]
			LEFT JOIN co000 CO ON [Order].SalesManID = CO.[GUID]
			OUTER APPLY dbo.fnPOSGetOrderDiscAdded([order].[GUID]) D
		WHERE ([Order].[Type] = 0 OR [Order].[Type] = 1) AND [item].[State] <> 1

	IF(@showMats = 1) 
		INSERT INTO @master (ID, [Type], OrderDate, Note, FinalTotal, UserName, SalesManName, ParentID)
		SELECT 
			NEWID(),
			6,
			[Order].[Date],
			(CASE 
					WHEN @language <> 0 AND MT.LatinName <> '' 
					THEN Mt.LatinName 
					ELSE Mt.[Name]
			END),
			(CASE [item].[TYPE] 
				WHEN 1 THEN  -1 * ( (([item].Price * [item].Qty) + [item].Tax - [item].Discount + [item].Added)
								    +(ISNULL(D.ReturnSalesAdded, 0) *  ([item].Price * [item].Qty + [item].Added))
								     / IIF(ISNULL( D.ReturnSalesSubTotalWithAdded, 0) = 0, 1, D.ReturnSalesSubTotalWithAdded ))
									 -  ((ISNULL(D.ReturnSalesDisount, 0 )  *   ([item].Price * [item].Qty - [item].Discount) )
									 / IIF(ISNULL( D.ReturnSalesOrderSubTotalWithDisc, 0) = 0, 1, D.ReturnSalesOrderSubTotalWithDisc ))

						ELSE  (([item].Price * [item].Qty) + [item].Tax - [item].Discount + [item].Added) 
								+(ISNULL(D.SalesOrderAdded, 0 ) *  ([item].Price * [item].Qty + [item].Added))
								/ IIF( ISNULL(D.SalesOrderSubTotalWithAdded, 0) = 0, 1, D.SalesOrderSubTotalWithAdded )
								- ( (ISNULL(D.SalesDiscount, 0 )  *  ([item].Price * [item].Qty - [item].Discount) )
								/  IIF( ISNULL(D.SalesOrderSubTotalWithDisc, 0) = 0, 1, D.SalesOrderSubTotalWithDisc))
			END) ,
			us.LoginName,
			ISNULL(CO.[Name],''),
			MT.GroupGUID
		FROM 
			POSOrder000 [Order] 
			INNER JOIN POSOrderItems000 [item] ON [item].ParentID = [Order].[Guid]
			INNER JOIN MT000 MT ON [item].MatID = MT.[GUID]
			INNER JOIN @selectedOrders SEL ON [Order].[Guid] = SEL.[GUID]	
			INNER JOIN us000 us ON [Order].FinishCashierID  = us.[GUID]
			LEFT JOIN co000 CO ON [Order].SalesManID = CO.[GUID]
			OUTER APPLY dbo.fnPOSGetOrderDiscAdded([order].[GUID]) D
		WHERE 
			([Order].[Type] = 0 OR [Order].[Type] = 1 ) AND [item].[State] <> 1
	END
	ELSE
	BEGIN
	INSERT INTO @master (ID, [Type], OrderDate, Note, FinalTotal, UserName, SalesManName, ParentID)
		
		SELECT
			 NEWID(),
			 7,
			 [Order].[Date],
			 '',
			Item.Price * Item.Qty ,
			us.LoginName,
			ISNULL(CO.[Name],''),
			@NetSalesGuid
		FROM 
			POSOrder000 [Order] 
			INNER JOIN @selectedOrders SEL ON [Order].[Guid] = SEL.[GUID]
			INNER JOIN POSOrderItems000 Item ON [Order].[Guid] = Item.ParentID
			INNER JOIN us000 us ON [Order].FinishCashierID   = us.[GUID]
			LEFT JOIN co000 CO  ON [Order].SalesManID = CO.[GUID]
		WHERE 
			([Order].[Type] = 0 OR [Order].[Type] = 1)
			AND
			(Item.[Type] <> 1)
			AND
			(Item.[State] <> 1)
		UNION ALL
	    SELECT 
			NewID(),
			8,
			[Order].[Date],
			'',
		    Item.Price * Item.Qty,
			US.LoginName,
			ISNULL(CO.[Name],''),
			@NetSalesGuid
		FROM  
			POSOrder000 [Order] 
			INNER JOIN @selectedOrders SEL ON [Order].[Guid] = SEL.[GUID]
			INNER JOIN POSOrderItems000 Item ON [Order].[Guid] = Item.ParentID
			INNER JOIN us000 US ON [Order].FinishCashierID   = US.[GUID]
			LEFT JOIN co000 CO  ON [Order].SalesManID = CO.[GUID]
			 
		WHERE
			([Order].[Type] = 0 OR [Order].[Type] = 1)
			AND
			(Item.[Type] = 1 )
			AND
			(Item.[State] <> 1)
		UNION ALL
		--Discount Item
		SELECT 
				NEWID(),
				9,
				[Order].[Date],
				'',
				IIF(Item.[Type] = 1 , -1 * Item.Discount , Item.Discount),
				US.LoginName,
				ISNULL(CO.[Name],''),
				@NetSalesGuid
		FROM 
			POSOrder000 [Order]
			INNER JOIN @selectedOrders SEL ON [Order].[Guid] = SEL.[GUID]
			INNER JOIN POSOrderItems000 Item ON [Order].[Guid] = Item.ParentID
			INNER JOIN us000 US ON [Order].FinishCashierID   = US.[GUID]
			LEFT JOIN co000 CO ON [Order].SalesManID = CO.[GUID]
		WHERE 
			([Order].[TYPE] = 0 OR [Order].[TYPE] = 1) 
			AND
			(Item.[State] <> 1)
		UNION ALL
		--Discount Order
		SELECT 
				NEWID(),
				9,
				[Order].[Date],
				'',
				IIF(dis.OrderType = 1, -1, 1 ) * (ISNULL(dis.[Value], 0)),
				US.LoginName,
				ISNULL(CO.[Name],''),
				@NetSalesGuid
		FROM 
			POSOrder000 [Order]
			INNER JOIN @selectedOrders SEL ON [Order].[Guid] = SEL.[GUID]
			LEFT JOIN POSOrderDiscount000 dis  ON [Order].[GUID] = dis.ParentID
			INNER JOIN us000 US ON [Order].FinishCashierID   = US.[GUID]
			LEFT JOIN co000 CO ON [Order].SalesManID = CO.[GUID]
		WHERE 
			[Order].[TYPE] = 0 OR [Order].[TYPE] = 1 
        UNION ALL
		--Added Items
		SELECT 
				NEWID(),
				10,
				[Order].[Date],
				'',
				IIF(Item.[Type] = 1 , -1 * Item.Added , Item.Added),
				US.LoginName,
				ISNULL(CO.[Name],''),
				@NetSalesGuid
		FROM  
			 POSOrder000 [Order] 
			INNER JOIN @selectedOrders SEL ON [Order].[Guid] = SEL.[GUID]
			INNER JOIN POSOrderItems000 Item ON [Order].[Guid] = Item.ParentID
			INNER JOIN us000 US ON [Order].FinishCashierID   = US.[GUID]
			LEFT JOIN co000 CO  ON [Order].SalesManID = CO.[GUID]
		WHERE
			([Order].[TYPE] = 0 OR [Order].[TYPE] = 1 )
			AND
			(Item.[State] <> 1)
		UNION ALL
		--Added Orders
		SELECT 
				NEWID(),
				10,
				[Order].[Date],
				'',
				IIF(Added.OrderType = 1 , -1 , 1 ) * ISNULL(Added.[Value], 0),
				US.LoginName,
				ISNULL(CO.[Name],''),
				@NetSalesGuid
		FROM  
			 POSOrder000 [Order] 
			INNER JOIN @selectedOrders SEL ON [Order].[Guid] = SEL.[GUID]
			LEFT JOIN POSOrderAdded000 Added ON [Order].[GUID] = Added.ParentID
			INNER JOIN us000 US ON [Order].FinishCashierID   = US.[GUID]
			LEFT JOIN co000 CO  ON [Order].SalesManID = CO.[GUID]
		WHERE
			[Order].[TYPE] = 0 OR [Order].[TYPE] = 1 
		UNION ALL
		
		SELECT
			 NEWID(),
			 11,
			 [Order].[Date],
			 '',
			 IIF(Item.[Type] = 1, -1 * Item.Tax, Item.Tax),
			 US.LoginName,
			 ISNULL(CO.[Name],''),
			 @NetSalesGuid
		FROM 
			POSOrder000 [Order] 
			INNER JOIN @selectedOrders SEL ON [Order].[Guid] = SEL.[GUID]
			INNER JOIN POSOrderItems000 Item ON [Order].[Guid] = Item.ParentID
			INNER JOIN us000 US ON [Order].FinishCashierID   = US.[GUID]
			LEFT JOIN co000 CO ON [Order].SalesManID = CO.[GUID]
		WHERE
			([Order].[TYPE] = 0 OR [Order].[TYPE] = 1 )
			AND
			(Item.[State] <> 1)
	END
	IF(@showCurDetails = 1)
	BEGIN
			INSERT INTO @master (ID, [Type], OrderDate, Note, FinalTotal, UserName, SalesManName, ParentID)
			SELECT 
						NEWID(),
						12,
						[Order].[Date],
						(CASE 
							WHEN @language <> 0 AND MY.LatinName <> '' 
							THEN MY.LatinName 
							ELSE MY.[Name]
					    END),
						ISNULL(Cur.Paid - Cur.Returned, 0), 
						US.LoginName,
						ISNULL(CO.[Name],''),
						@CashGuid
			FROM
				 POSOrder000 [Order] ​
				INNER JOIN POSPaymentsPackage000 [Pack] ON [Order].PaymentsPackageID = [Pack].[Guid]​
				INNER JOIN POSPaymentsPackageCurrency000 [Cur] ON [Pack].[Guid] = [Cur].ParentID​
				INNER JOIN my000 MY ON [Cur].CurrencyID = [My].[GUID]​
				INNER JOIN @selectedOrders SEL ON [Order].[Guid] = SEL.[GUID]
				INNER JOIN us000 us ON [Order].FinishCashierID  = us.[GUID]
				LEFT JOIN co000 CO ON [Order].SalesManID = CO.[GUID]
	END
	
	IF(@showChecksDetails = 1)
	BEGIN
	    INSERT INTO @master  (ID, [Type], OrderDate, Note, FinalTotal, UserName, SalesManName, ParentID, [SortNum] )
		SELECT
				NEWID(),
				13,
				[Order].[Date],
				(CASE 
					WHEN @language <> 0 AND NT.LatinName <> '' 
					THEN NT.LatinName 
					ELSE NT.[Name]
				END),
				(CASE CHK.[Type] WHEN RVT.ReturnVoucherType THEN -1 ELSE 1 END) * CHK.Paid/CHK.CurrencyValue , 
				US.LoginName,
				ISNULL(CO.[Name],''),
				@CheckGuid,
				NT.sortNum
		FROM
			POSOrder000 [ORDER]​
			INNER JOIN POSPaymentsPackage000 [Pack] ON [Order].PaymentsPackageID = [Pack].[Guid]​
			INNER JOIN POSPaymentsPackageCheck000 CHK ON CHK.ParentID = [Pack].[Guid]
			INNER JOIN nt000 NT ON CHK.[Type] = NT.[GUID]​
			INNER JOIN @selectedOrders SEL ON [Order].[Guid] = SEL.[GUID]
			INNER JOIN us000 US ON [ORDER].FinishCashierID   = US.[GUID]
			INNER JOIN @ReturnVouchers RVT ON RVT.UserID = us.[GUID]
			LEFT JOIN co000 CO  ON [Order].SalesManID = CO.[GUID]
		UNION ALL 
		SELECT
			 NEWID(),
			 16,
			 [Order].[Date],
			 '',
			ISNULL(ch.Val, 0),
			us.LoginName,
			ISNULL(CO.[Name],''),
			@CheckGuid,
			NT.sortNum
		FROM 
			POSOrder000 [Order] 
			INNER JOIN pospaymentspackage000 pack ON pack.[GUID] = [Order].PaymentsPackageID
			INNER JOIN ch000 ch ON ch.[GUID] = pack.ReturnVoucherID
			INNER JOIN nt000 nt ON nt.[GUID] = ch.TypeGUID
			INNER JOIN us000 us ON [Order].FinishCashierID   = us.[GUID]
			INNER JOIN @selectedOrders SEL ON [Order].[Guid] = SEL.[GUID]
			LEFT JOIN co000 CO ON [Order].SalesManID = CO.[GUID]
		
	END
	IF(@showCreditPaymentsDetails = 1)
	BEGIN
		INSERT INTO @master (ID,[Type],OrderDate,Note,FinalTotal,UserName,SalesManName,ParentID)
		SELECT 
				NEWID(),
				14,
				[Order].[Date],
				(CASE 
					WHEN @language <> 0 AND ACC.LatinName <> ''
					THEN ACC.LatinName 
					ELSE ACC.[Name]
				END), 
				(PACK.DeferredAmount ),
				US.LoginName,
				ISNULL(CO.[Name],''),
				@CreditPaymentGuid
		FROM 
				POSOrder000 [Order] 
				INNER JOIN POSPaymentsPackage000 [Pack] ON [Order].PaymentsPackageID = [Pack].[Guid]​
				INNER JOIN cu000 [Cu] ON [Pack].[DeferredAccount] = [Cu].[GUID]​
				INNER JOIN ac000 [Acc] ON [Cu].[AccountGUID] = [Acc].[GUID]​
				INNER JOIN @selectedOrders SEL ON [Order].[Guid] = SEL.[GUID]
				INNER JOIN us000 US ON [ORDER].FinishCashierID = US.[GUID]​
				LEFT JOIN co000 CO ON [Order].SalesManID = CO.[GUID]
		WHERE  
				PACK.DeferredAmount != 0
	END
	DECLARE @MainCurrencyID [UNIQUEIDENTIFIER],
			@POSCurrencyID  [UNIQUEIDENTIFIER],
			@CalcCurrencyVal [BIT] = 0
	SELECT TOP 1 @POSCurrencyID = ISNULL([Value], 0x0) 
	FROM FileOP000 
    WHERE [Name] = 'AmnPOS_DefaultCurrencyID'
	IF(@POSCurrencyID <> 0x0)
	BEGIN 
		SELECT TOP 1 @MainCurrencyID = [GUID] 
		FROM [MY000]  
		WHERE CurrencyVal = 1 
		IF(@MainCurrencyID <> @POSCurrencyID)
			SET @CalcCurrencyVal = 1
	END
	
	SELECT 
			[ID],
			[Note] AS [Note],
			[Type] AS [Type],
			ISNULL(IIF([Type] = 12 OR [Type] = 13 OR @CalcCurrencyVal = 0 ,[FinalTotal],[dbo].fnGetFixedValue([FinalTotal], OrderDate)), 0) AS Total,
			[UserName] AS CashierName ,
			[SalesManName] AS SalesManName,
			[ParentID]
	FROM @master 
	ORDER BY [TYPE],[SortNum]
################################################################################	
CREATE PROCEDURE prcPOSOrderMovementDetail
	@BranchGuid   [UNIQUEIDENTIFIER], 
	@CashierGuid  [UNIQUEIDENTIFIER], 
	@CostID		  [UNIQUEIDENTIFIER], 
	@StartDate    [DATETIME],    
	@EndDate      [DATETIME], 
	@RMat	      [INT], 
	@Sale	      [INT], 
	@Book	      [INT], 
	@extention    [INT], 
	@Gift		  [INT]	 
AS 
SET NOCOUNT ON 

DECLARE @ItemTotal FLOAT ,@ItemSubTotal FLOAT;

CREATE TABLE [#SecViol]([Type] [INT], [Cnt] [INT])
CREATE TABLE [#BillsTypesTbl] 
(  
		[TypeGuid]    [UNIQUEIDENTIFIER],  
		[Sec]         [INT],                
		[ReadPrice]   [INT],                
		[UnPostedSec] [INT]
)              

INSERT INTO [#BillsTypesTbl] EXEC prcGetBillsTypesList2 0x0 

CREATE TABLE [#Result]
(
	[OrderNumber] [FLOAT],  
	[OrderType] [INT], 
	[OrderID] [UNIQUEIDENTIFIER],  
	[OrderDate] [DATETIME],  
	[OrderNotes]  NVARCHAR(250),  
	[OrderDiscount] [FLOAT],  
	[OrderAdded] [FLOAT],  
	[OrderTax] [FLOAT],  
	[OrderSubTotal] [FLOAT], 
	[PaymentsID] [UNIQUEIDENTIFIER], 
	[CuID] [UNIQUEIDENTIFIER],  
	[CuName] NVARCHAR(250), 
	[BrID] [UNIQUEIDENTIFIER], 
	[BrName]  NVARCHAR(250), 
	[AcID] [UNIQUEIDENTIFIER], 
	[AcName]  NVARCHAR(MAX),
	[usGuid]  [UNIQUEIDENTIFIER], 
	[UsName]  NVARCHAR(MAX), 
	[SalesManID] [UNIQUEIDENTIFIER], 
	[SalesManName]  NVARCHAR(MAX), 
	ItemID [UNIQUEIDENTIFIER], 
	[MatCode]  NVARCHAR(100), 
	[MatName]  NVARCHAR(250), 
	[ItemQty] [FLOAT], 
	[ItemPrice][FLOAT],
	[ItemDiscount] [FLOAT], 
	[ItemAdded] [FLOAT], 
	[ItemSubTotal] [FLOAT], 
	[ItemTotal] [FLOAT], 
	[ItemType] [INT], 
	[SpecialOfferIndex] [INT],
	[typeGUID]		[UNIQUEIDENTIFIER],
    [Security]		[INT],
	[UserSecurity]	[INT],
	[ceGuid]		[UNIQUEIDENTIFIER],
	[ceSecurity]	[INT],
	[coGuid]		[UNIQUEIDENTIFIER],
	[coSecurity]	[INT],
	[stGuid]		[UNIQUEIDENTIFIER],
	[stSecurity]	[INT]
)

INSERT INTO
		 #Result
SELECT 
	[Order].[Number],  
	[Order].[Type], 
	[Order].[GUID],  
	[Order].[Date],  
	[Order].[Notes],  
	[Order].[Discount],  
	[Order].[Added],  
	(SELECT SUM(Tax)FROM POSOrderItems000 WHERE ParentID=[Order].[GUID]) [OrderTax],  
	[Order].[SubTotal],
	[Order].[PaymentsPackageID] , 
	ISNULL([Cu].[GUID], 0x0), 
	ISNULL([Cu].[CustomerName], ''), 
	ISNULL([Br].[GUID], 0x0) , 
	ISNULL([Br].[Name], ''), 
	ISNULL([Ac].[GUID], 0x0), 
	ISNULL([Ac].[Name], ''),
	ISNULL([Us].[Guid],0x0),
	ISNULL([Us].[LoginName], '') , 
	ISNULL([Co].[GUID], 0x0) , 
	ISNULL([Co].[Name], '') , 
	[Mat].[GUID] , 
	[Mat].[Code], 
	[Mat].[Name], 
	[Items].[Qty], 
	[Items].[Price], 
	[Items].[Discount], 
	[Items].[Added], 
	[Items].[Price] * (CASE WHEN [Items].[Qty]>0 THEN [Items].[Qty] ELSE 1 END) AS ItemSubTotal, 
	[Items].[Price] * (CASE WHEN [Items].[Qty]>0 THEN [Items].[Qty] ELSE 1 END) + [Items].[Added] + [Items].[Tax] - [Items].[Discount]   AS ItemTotal, 
	[Items].[Type], 
	[Items].[SpecialOfferIndex],
	bttbl.TypeGuid,
	ISNULL(bu.Security, 0),
    CASE bu.IsPosted WHEN 1 THEN bttbl.Sec ELSE bttbl.UnPostedSec END,
	ce.[Guid],
	ce.[Security],
	co.[Guid],
	co.[Security],
	st.[Guid],
	st.[Security]
FROM 
	POSOrder000 [Order]
	INNER  JOIN billrel000 rel  on rel.[ParentGUID]= [Order].[GUID]
	INNER JOIN bu000 bu on rel.[billguid]=bu.[GUID]
	INNER JOIN [#BillsTypesTbl] bttbl ON  bttbl.TypeGuid = bu.Typeguid
	INNER JOIN  st000 st ON st.[GUID] = bu.storeguid
	LEFT JOIN [Cu000] [Cu] ON  [Cu].[Guid]=[Order].[CustomerID] 
	LEFT JOIN [Ac000] [Ac] ON  [Ac].[Guid]=[Order].[DeferredAccountID] 
	LEFT JOIN [Br000] [Br] ON  [Br].[Guid]=[Order].[BranchID] 
	LEFT JOIN [us000] [Us] ON  [Us].[Guid]=[Order].[FinishCashierID] 
	INNER JOIN POSOrderItems000 items ON [items].[ParentID]=[Order].[GUID] 
	INNER JOIN [Mt000] [Mat] ON [Items].[MatID]=[Mat].[Guid] 
	LEFT JOIN Co000 Co ON [Items].[SalesmanID] = Co.[Guid] 
	LEFT JOIN en000 en  ON en.CostGUID =co.[GUID]
	LEFT JOIN ce000 ce On en.ParentGuid=ce.Guid
	LEFT JOIN er000 er On er.EntryGuid=ce.Guid
WHERE 
		(@BranchGuid=0x0 OR @BranchGuid=br.[GUID]) 
		AND (@CashierGuid=0x0 OR @CashierGuid=us.[GUID]) 
		AND ([Order].[Date] BETWEEN @StartDate AND @EndDate) 
		AND ((@sale=1 AND [Order].[Type]=0) OR (@extention=1 AND [Order].[Type]=1) OR (@book=1 AND [Order].[Type]>1)) 
		AND (([Items].[Type] = 0) OR ([Items].[Type] = 1 AND @RMat=1) OR ([Items].[Type] = 2 AND @Gift=1)) 
		AND (Items.SalesmanID=@CostID OR @CostID=0x0) 

EXEC [prcCheckSecurity]

SELECT * FROM #Result 
ORDER BY 
	[BrID], [usGuid] ,[OrderNumber] 
################################################################################
#END
