###############################################################################
CREATE PROCEDURE prcPOSGetFinishedOrder
	@Date    [DATETIME],
	@UserId  [UNIQUEIDENTIFIER]
AS
	SET NOCOUNT ON

	DECLARE @Currencyname [NVARCHAR] (250);

	SELECT TOP 1 @Currencyname = [Name] FROM my000
	WHERE CurrencyVal = 1 

	CREATE TABLE #FinishedOrder ( 
		 OrderID		 [UNIQUEIDENTIFIER],
		 OrderNumber	 [INT],
		 OrderTime		 [NVARCHAR] (8),
		 UserName		 [NVARCHAR] (250),
		 Customer		 [NVARCHAR] (250),
		 CustomerAddressID [UNIQUEIDENTIFIER],
		 OrderSalesMan   [NVARCHAR] (250),
		 Note			 [NVARCHAR] (MAX),
		 Total			 [FLOAT],
		 TotalDiscount	 [FLOAT],
		 TotalAdded		 [FLOAT],
		 OrderTax		 [FLOAT],
		 NetTotal		 [FLOAT],	
		 CurrencyName	 [NVARCHAR] (250),
		 CurrencyVal	 [FLOAT], 
		 CheckID		 [UNIQUEIDENTIFIER],
		 ReturnBillID	 [UNIQUEIDENTIFIER],
		 BillID			 [UNIQUEIDENTIFIER],
		 [PointsCount]	 [INT])

	INSERT INTO #FinishedOrder
	SELECT 
		o.[Guid] AS OrderID,
		o.[Number] AS OrderNumber,
		CONVERT(NVARCHAR(8), o.[Date],108) AS OrderTime,
		us.LoginName AS UserName,
		cu.[CustomerName] AS Customer,
		o.CustomerAddressID AS CustomerAddressID,
		ISNULL(co.[Name],'') AS OrderSalesMan,
	    o.[Notes] AS Note,
		(o.[SubTotal] ) / (CASE o.[CurrencyValue] WHEN 0 THEN 1 ELSE o.[CurrencyValue] END ) AS Total,
		(o.[Discount]) / (CASE o.[CurrencyValue] WHEN 0 THEN 1 ELSE o.[CurrencyValue] END ) AS TotalDiscount,
		(o.[Added]) / (CASE o.[CurrencyValue] WHEN 0 THEN 1 ELSE o.[CurrencyValue] END ) AS TotalAdded,
		(SELECT SUM(Tax) FROM POSOrderItems000 WHERE ParentID = o.[Guid]) / (CASE o.[CurrencyValue] WHEN 0 THEN 1 ELSE o.[CurrencyValue] END ) AS OrderTax,
		(o.[SubTotal] - o.[Discount] + o.[Added] + o.[Tax] + ((SELECT SUM(Tax) FROM POSOrderItems000 WHERE ParentID = o.[Guid]))) / (CASE o.[CurrencyValue] WHEN 0 THEN 1 ELSE o.[CurrencyValue] END ) AS NetTotal,
		ISNULL(my.Name, @Currencyname),
		o.CurrencyValue,
		c.ChildID AS CheckID,
		NULL,
		NULL,
		o.PointsCount
	FROM 
		POSOrder000 AS o
		LEFT JOIN cu000 AS cu ON o.CustomerID = cu.[GUID]
		LEFT JOIN POSPaymentsPackage000 p ON o.PaymentsPackageID = p.[Guid]
		LEFT JOIN POSPaymentsPackageCheck000 c ON p.Guid = c.ParentID
		LEFT JOIN us000 us ON us.[GUID] = o.FinishCashierID 
		LEFT JOIN my000 my ON my.[GUID] = o.CurrencyID
		LEFT JOIN Co000 co ON o.SalesManID = co.[GUID]
	WHERE 
		CAST(o.[Date] AS DATE) = @Date 
		AND 
		o.CashierID = @UserId
		AND
		(o.[Type] = 0 OR o.[Type] = 1)
	ORDER BY o.Number DESC
 
	UPDATE BT 
	SET BT.ReturnBillID = R.BillGUID 
	FROM #FinishedOrder BT 
	INNER JOIN BillRel000 R ON BT.OrderID = R.ParentGUID
	WHERE R.[TYPE] = 2

	UPDATE BT 
	SET BT.BillID = R.BillGUID 
	FROM #FinishedOrder BT 
	INNER JOIN BillRel000 R ON BT.OrderID = R.ParentGUID
	WHERE R.[TYPE] = 1

	SELECT * FROM #FinishedOrder
	ORDER BY OrderNumber DESC 
################################################################################
CREATE PROCEDURE prcPOSGetFinisheditem
	@OrderGUID  [UNIQUEIDENTIFIER],
	@OrderCurrencyVal [FLOAT]
AS
	SET NOCOUNT ON

	IF (@OrderCurrencyVal = 0)
		SET @OrderCurrencyVal = 1;

	SELECT  
		mt.Name AS MatName,
		IIF(Item.[Type] = 1, -1 * Item.Qty, Item.Qty) AS MatQty,
		(CASE Item.Unity WHEN 1 THEN mt.Unity 
		                 WHEN 2 THEN mt.Unit2
						 WHEN 3 THEN mt.Unit3
						 ELSE ''
		END) AS MatUnit ,
		IIF(Item.[Type] = 1, -1 * Item.MatPrice, Item.MatPrice)  / @OrderCurrencyVal AS MatPrice,
		IIF(Item.[Type] = 1, -1 * Item.Price * Item.Qty,Item.Price * Item.Qty) / @OrderCurrencyVal AS ItemTotal,
		ISNULL(co.[Name], '') AS ItemSalesMan,
		Item.Discount * 100 / IIF((Item.Price * Item.Qty) = 0, 1, (Item.Price * Item.Qty)) AS ItemDisPercent,
		Item.Discount / @OrderCurrencyVal AS ItemDisVal,
		Item.Added * 100 / IIF((Item.Price * Item.Qty) = 0, 1, (Item.Price * Item.Qty)) AS ItemAddedPercent,
		Item.Added / @OrderCurrencyVal AS ItemAddedVal,
		Item.Tax / @OrderCurrencyVal AS ItemTax,
		IIF(Item.[Type] = 1, -1, 1) * ((Item.Price * Item.Qty) - Item.Discount + Item.Added) / @OrderCurrencyVal AS ItemNetPrice,
		IIF(Item.[Type] = 1, -1, 1) * ((Item.Price * Item.Qty)  - Item.Discount + Item.Added + Item.Tax) / @OrderCurrencyVal AS ItemNetPriceAndTax,
		item.ClassPtr AS ItemClass,
		Item.ExpirationDate AS ItemExpiryDate,
		Item.SerialNumber AS ItemSN,
		mt.CompositionName AS  ItemComposit
	FROM 
		POSOrderItems000 Item
		INNER JOIN mt000 mt ON mt.[GUID] = Item.MatID
		LEFT JOIN Co000 co ON co.[Guid]  = Item.SalesmanID
	WHERE 
		Item.ParentID = @OrderGUID
		AND
		Item.[State] <> 1
	ORDER BY Item.Number
################################################################################
#END
