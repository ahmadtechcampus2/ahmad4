#########################################################
CREATE VIEW vwEn
AS
	SELECT
		[GUID] AS [enGUID],
		[ParentGUID] AS [enParent],
		[Number] AS [enNumber],
		[AccountGUID] AS [enAccount],
		[Date] AS [enDate],
		[Debit] AS [enDebit],
		[Credit] AS [enCredit],
		[Notes] AS [enNotes],
		[CurrencyGUID] AS [enCurrencyPtr],
		[CurrencyVal] AS [enCurrencyVal],
		[CostGUID] AS [enCostPoint],
		[Class] AS [enClass],
		[Num1] AS [enNum1],
		[Num2] AS [enNum2],
		[Vendor] AS [enVendor],
		[SalesMan] AS [enSalesMan],   
		[ContraAccGUID] AS [enContraAcc],
		[BiGUID] AS [enBiGUID],
		[LCGUID] AS [enLCGUID],
		[CustomerGUID] AS [enCustomerGUID],
		[Type] AS [enType],
		[GCCOriginDate] AS [enGCCOriginDate],
		[GCCOriginNumber] AS [enGCCOriginNumber],
		[ParentVATGuid] AS [enParentVATGuid],
		[AddedValue] AS [enAddedValue]
	FROM 
		[en000]
#########################################################
#END
