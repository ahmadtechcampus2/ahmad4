################################################################
CREATE PROCEDURE prcRestGetFinishedOrder
	@Date    [DATETIME],
	@UserId	 [UNIQUEIDENTIFIER]
AS
	SET NOCOUNT ON
	
	DECLARE @Currencyname [NVARCHAR] (250)

	SELECT TOP 1 @Currencyname = Name 
	FROM my000
	WHERE CurrencyVal = 1 
    
	SELECT 
		o.[Guid] AS OrderID,
		o.Ordernumber AS OrderNumber,
		CONVERT(NVARCHAR(8), o.closing,108) AS OrderTime,
		us.LoginName AS UserName,
		cu.CustomerName AS Customer, 
		o.CustomerAddressID AS CustomerAddressID,
		'' AS OrderSalesMan,
		o.Notes AS Note,
		o.SubTotal AS Total,
		o.Discount AS TotalDiscount,
		o.Added AS TotalAdded,
		o.Tax AS OrderTax,
		o.SubTotal - o.Discount + o.Added + o.Tax AS NetTotal,
		@Currencyname AS CurrencyName,
		1 AS CurrencyVal,
		c.ChildID AS CheckID,
		CASE o.Type WHEN 4 THEN r.BillGUID ELSE 0x0 END AS ReturnBillID,
		CASE o.Type WHEN 4 THEN 0x0 ELSE r.BillGUID END AS BillID,
		o.PointsCount AS PointsCount
	FROM 
		RestOrder000 o
		INNER JOIN BillRel000 r ON o.Guid = r.ParentGUID
		LEFT JOIN cu000 AS cu ON o.CustomerID = cu.[GUID]
		LEFT JOIN POSPaymentsPackage000 p ON o.PaymentsPackageID = p.Guid
		LEFT JOIN POSPaymentsPackageCheck000 c ON p.Guid = c.ParentID
		LEFT JOIN us000 us ON us.[GUID] = o.FinishCashierID 
	WHERE 
		CAST(o.Opening AS DATE) = @Date AND CashierID = @UserId
	ORDER BY 
		o.Number DESC
####################################################################
CREATE  PROCEDURE prcRestGetFinisheditem
	@OrderGUID  [UNIQUEIDENTIFIER],
    @OrderCurrencyValue [FLOAT]
AS
	SET NOCOUNT ON
	IF (@OrderCurrencyValue = 0)
		SET @OrderCurrencyValue = 1

	SELECT  
		mt.[Name] AS MatName,
		Item.Qty AS MatQty,
		(CASE Item.Unity WHEN 1 THEN mt.Unity 
		                 WHEN 2 THEN mt.Unit2
						 WHEN 3 THEN mt.Unit3
						 ELSE ''
		END) AS MatUnit ,
		Item.MatPrice / @OrderCurrencyValue AS MatPrice,
		Item.Price * Item.Qty / @OrderCurrencyValue AS ItemTotal,
		'' AS ItemSalesMan,
		(Item.Discount * 100 / IIF((Item.Price * Item.Qty) = 0 , 1, (Item.Price * Item.Qty)))  AS ItemDisPercent,
		Item.Discount / @OrderCurrencyValue AS ItemDisVal,
		Item.Added * 100 / IIF((Item.Price * Item.Qty) = 0 , 1, (Item.Price * Item.Qty)) AS ItemAddedPercent,
		Item.Added / @OrderCurrencyValue AS ItemAddedVal,
		Item.Tax / @OrderCurrencyValue AS ItemTax,
		((Item.Price * Item.Qty) - Item.Discount + Item.Added) / @OrderCurrencyValue AS ItemNetPrice,
		((Item.Price * Item.Qty) - Item.Discount + Item.Added + Item.Tax) / @OrderCurrencyValue AS ItemNetPriceAndTax,
		'' AS ItemClass,
		Null AS ItemExpiryDate,
		'' AS ItemSN,
		mt.CompositionName AS  ItemComposit
	FROM 
		RestOrderItem000 Item
		INNER JOIN mt000 mt ON mt.[GUID] = Item.MatID
	WHERE 
		Item.ParentID = @OrderGUID
####################################################################
#END