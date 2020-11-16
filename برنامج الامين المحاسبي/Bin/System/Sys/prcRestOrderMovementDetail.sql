###########################
CREATE VIEW vwRestOrdersWithVat
AS
	SELECT V1.*, V2.ItemsVat FROM RestOrder000 V1 INNER JOIN
	(SELECT [Order].Guid, SUM(ISNULL(item.vat, 0)) ItemsVat FROM RestOrder000 [Order]
		INNER JOIN RestOrderItem000 item ON [Order].Guid = item.ParentID
			GROUP BY [Order].Guid)
			AS V2 ON V1.Guid = v2.Guid
###########################
CREATE FUNCTION fnRestGetPayType(@ID UNIQUEIDENTIFIER)
 RETURNS INT
AS
BEGIN
	DECLARE @payType INT
	SET @payType = 1
	
	SELECT @payType = CASE WHEN (ISNULL(DeferredAmount,0) > 0 
		OR ISNULL(ReturnVoucherValue, 0) > 0
		OR ISNULL(ch.Paid, 0) > 0) THEN 2 ELSE 1 END FROM RestOrder000 r
			INNER JOIN POSPaymentsPackage000 p ON p.GUID=r.PaymentsPackageID
			LEFT JOIN POSPaymentsPackageCheck000 ch ON ch.ParentID=p.GUID	
	WHERE r.GUID=@ID
	
	return @payType
END
###########################
CREATE PROCEDURE prcRestOrderMovementDetail
	@BranchGuid   [uniqueidentifier],
	@CashierGuid  [uniqueidentifier],
	@StartDate    [DATETIME],   
	@EndDate      [DATETIME],
	@Outer	      [int],
	@Table	      [int],
	@Delivery	  [int],
	@Return       [int],
	@CustomerID   [uniqueidentifier],
	@DriverID     [uniqueidentifier],
	@CaptinID	  [uniqueidentifier],
	@TableID	  [uniqueidentifier]
AS
SET NOCOUNT ON

SELECT
	[Order].[Number] [OrderNumber], 
	[Order].[Type] [OrderType],
	[Order].[GUID] [OrderID], 
	[Order].[Closing] [OrderDate], 
	[Order].[Notes] [OrderNotes], 
	[Order].[Discount] [OrderDiscount], 
	[Order].[Added] [OrderAdded], 
	([Order].[Tax] + [Order].[ItemsVat]) [OrderTax], 
	[Order].[SubTotal] [OrderSubTotal],
	[Order].[PaymentsPackageID] [PaymentsID],
	dbo.fnRestGetPayType([Order].[GUID]) PayType,
	ISNULL([Cu].[GUID], 0x0) as [CuID],
	ISNULL([Cu].[CustomerName], '') as [CuName],
	ISNULL([Br].[GUID], 0x0) as [BrID],
	ISNULL([Br].[Name], '') as [BrName],
	ISNULL([Us].[LoginName], '') as [UsName],
	ISNULL([Vn].[Name], '') as [VnName],
	ISNULL([RT].[Code], '') AS [TbCode],
	ISNULL([RT].[Cover], 0) AS [TbCover],
	[Mat].[GUID] ItemID,
	[Mat].[Code],
	[Mat].[Name],
	[Items].[Qty] [ItemQty],
	[Items].[Price] [ItemPrice],
	[Items].[Discount] [ItemDiscount],
	[Items].[Added] [ItemAdded],
	[Items].[Price] * (CASE when [Items].[Qty]>0 then [Items].[Qty] ELSE 1 END) AS ItemSubTotal,
	[Items].[Price] * (
			CASE when [Items].[Qty]>0 then [Items].[Qty] ELSE 1 END) + [Items].[Added] + [Items].[Tax] - [Items].[Discount]  
	AS ItemTotal,
	[Items].[Type] [ItemType],
	[Items].[SpecialOfferIndex]
FROM vwRestOrdersWithVat [Order]
	LEFT JOIN [Cu000] [Cu] on  [Cu].[Guid]=[Order].[CustomerID]
	LEFT JOIN [Br000] [Br] on  [Br].[Guid]=[Order].[BranchID]
	LEFT JOIN [us000] [Us] on  [Us].[Guid]=[Order].[FinishCashierID]
	LEFT JOIN [RestVendor000] [Vn] ON [Vn].[GUID]=[Order].[GuestID]
	LEFT JOIN dbo.fnGetRestOrderTables(@TableID) [RT] ON [RT].ParentGuid=[order].[GUID]
	INNER JOIN RestOrderItem000 items ON [items].[ParentID]=[Order].GUID
	INNER JOIN [Mt000] [Mat] on [Items].[MatID]=[Mat].[Guid]
WHERE (@BranchGuid=0x0 OR @BranchGuid=br.GUID)
		AND (@CashierGuid=0x0 OR @CashierGuid=us.GUID)
		AND ([Order].[Closing] BETWEEN @StartDate AND @EndDate)
		AND ((@Table = [Order].[Type]) OR (@Outer = [Order].[Type]) OR (@Delivery = [Order].[Type]) OR (@Return = [Order].[Type]))
		AND (@CustomerID=0x0 OR @CustomerID = [Cu].GUID)
		AND (@DriverID=0x0 OR @DriverID = [Vn].GUID)
		AND (@CaptinID=0x0 OR @CaptinID = [Vn].GUID)
ORDER BY br.GUID, us.GUID, [Order].[Type], [Order].Number
###########################
#END