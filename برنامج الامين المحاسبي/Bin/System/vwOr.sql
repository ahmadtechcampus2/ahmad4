#########################################################
CREATE VIEW vtOr
AS
	SELECT * FROM [or000]

#########################################################
CREATE VIEW vbOr
AS
	SELECT *
	FROM [vtOr]

#########################################################
CREATE VIEW vcOr
AS
	SELECT * FROM [vbOr]

#########################################################
CREATE VIEW vwOr
AS
	SELECT 
		[Type] AS [orType],
		[Number] AS [orNumber],
		[GUID] AS [orGUID],
		[TableGUID] AS [orTableGUID],
		[Cover] AS [orCover],
		[Vendor] AS [orVendor],
		[OrderId] AS [orOrderId],
		[DiscAmnt] AS [orDiscAmnt],
		[DiscRatio] AS [orDiscRatio],
		[ExtraAmnt] AS [orExtraAmnt],
		[ExtraRatio] AS [orExtraRatio],
		[Total] AS [orTotal],
		[OrderState] AS [orOrderState],
		[DepartGUID] AS [orDepartment],
		[Date] AS [orDate],
		[PrepareTime] AS [orPrepareTime],
		[StartPrepare] AS [orStartPrepare],
		[EndPrepare] AS [orEndPrepare],
		[StartDelivery] AS [orStartDelivery],
		[EndDelivery] AS [orEndDelivery],
		[RecievedTime] AS [orRecievedTime],
		[PrintPointer] AS [orPrintPointer],
		[MatPointer] AS [orMatPointer],
		[AddTax] AS [orAddTax],
		[Notes] AS [orNotes],
		[ExpectedTime] AS [orExpectedTime],
		[Branch] AS [orBranch],
		[ExpDeliveryTime] AS [orExpDeliveryTime],
		[ExpWaitingTime] AS [orExpWaitingTime],
		[Payment] AS [orPayment],  		
		[PayType]	AS [orPayType],
		[CustGUID] AS [orCustGUID],
		[CashierUserGUID] AS [orCashierUserGUID],
		[FinishUserGUID] AS [orFinishUserGUID],
		[version] AS [orVersion],		
		[AccountGUID] AS [orAccountGUID],
		[GroupTax] AS [orGroupTax],
		[currencyGuid] AS [orCurrencyGUID],
		[currencyVal] AS [orCurrencyVal],
		[otGuid] AS [orOtGUID],
		[GenNotes] AS [orGenNotes],
		[Vat]	AS [orVat],
		[counter] AS [orCounter],
		[ItemDisc] AS [orItemDisc],
		[DepartGuid] AS [orDepartGuid],
		[TotalRSales] AS [orTotalRSales],
		[ItemDiscRSales]	AS [orItemDiscRSales], 
		[OpeningTime]	AS [orOpeningTime],
		[ClosingTime]	AS [orClosingTime],
		[IsPrinted]	AS [orIsPrinted]
		
	 FROM 
		[vbOr]







#########################################################
#END