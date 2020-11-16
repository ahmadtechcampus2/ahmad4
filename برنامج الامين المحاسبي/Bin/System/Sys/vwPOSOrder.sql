################################################################################
CREATE VIEW vwPOSOrder 
AS
	SELECT 
		[Order].[Type],
		[Order].[Number],
		[Order].[Serial],
		[Order].[Guid] AS [ID],
		[Order].[CashierID],
		[Order].[FinishCashierID],
		[Order].[BranchID],
		[Order].[State],
		[Order].[Date],
		[Order].[Notes],
		[Order].[Payment],
		[Order].[Cashed],
		[Order].[Discount],
		[Order].[Added],
		[Order].[Tax],
		[Order].[Discount]  + sum([Items].[Discount]) as [TotalDiscount],
		[Order].[Added]+ sum( [Items].[Added])  as [TotalAdded],
		[Order].[Tax]+ sum([Items].[Tax] ) as [TotalTax],
		[Order].[SubTotal],
		[CustomerID],
		[Customer].[CustomerName] AS [CustomerName],
		[Customer].[Number] AS  [CustomerNumber], 
		[DeferredAccountID],
		[CurrencyID],
		[Currency].[Code] AS [CurrencyCode],
		[Currency].[Name] AS [CurrencyName],
		[Currency].[CurrencyVal] AS [CurrencyVal],
		[Order].[IsPrinted],
		[Order].[HostName],
		[Order].[BillNumber],
		[Order].[PaymentsPackageID],
		[Order].[UserBillsID]

	FROM POSOrder000	[Order]
	LEFT JOIN POSOrderItems000 Items	ON [Order].[Guid] = [Items].[ParentID]
	LEFT JOIN Cu000 AS Customer ON [Order].[CurrencyID] = [Customer].[Guid]
	LEFT JOIN My000 AS Currency ON [Order].[CurrencyID] = [Currency].[Guid]
	group by 
		[Order].[Type],
		[Order].[Number],
		[Order].[Serial],
		[Order].[Guid],
		[Order].[CashierID],
		[Order].[FinishCashierID],
		[Order].[BranchID],
		[Order].[State],
		[Order].[Date],
		[Order].[Notes],
		[Order].[Payment],
		[Order].[Cashed],
		[Order].[Discount],
		[Order].[Added],
		[Order].[Tax],
		[Order].[SubTotal],
		[CustomerID],
		[Customer].[CustomerName],
		[Customer].[Number], 
		[DeferredAccountID],
		[CurrencyID],
		[Currency].[Code],
		[Currency].[Name],
		[Currency].[CurrencyVal] ,
		[Order].[IsPrinted],
		[Order].[HostName],
		[Order].[BillNumber],
		[Order].[PaymentsPackageID],
		[Order].[UserBillsID]
################################################################################
#END
