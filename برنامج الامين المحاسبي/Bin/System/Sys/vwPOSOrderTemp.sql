################################################################################
CREATE VIEW vwPOSOrderTemp
AS
	SELECT 
		[Order].[Type],
		[Order].[Number],
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
		[Order].[SubTotal],
		[CustomerID],
		[Customer].[CustomerName] AS [CustomerName], 
		[DeferredAccountID],
		[CurrencyID],
		[Currency].[Code] AS [CurrencyCode],
		[Currency].[Name] AS [CurrencyName],
		[Currency].[CurrencyVal] AS [CurrencyVal],
		[Order].[IsPrinted],
		[Order].[BillNumber]


	FROM POSOrderTemp000	[Order]
	LEFT JOIN POSOrderItems000 Items	ON [Order].[Guid] = [Items].[ParentID]
	LEFT JOIN Cu000 AS Customer ON [Order].[CurrencyID] = [Customer].[Guid]
	LEFT JOIN My000 AS Currency ON [Order].[CurrencyID] = [Currency].[Guid]
################################################################################
#END

