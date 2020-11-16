#########################################################
CREATE VIEW vwMx
AS
	SELECT
		[GUID] AS [mxGUID],
		[Type] AS [mxType],
		[Number] AS [mxNumber],
		[Discount] AS [mxDiscount],
		[Extra] AS [mxExtra],
		[CurrencyVal] AS [mxCurrencyVal],
		[Notes] AS [mxNotes],
		[Flag] AS [mxFlag],
		[ParentGUID] AS [mxParentGUID],
		[AccountGUID] AS [mxAccountGUID],
		[CurrencyGUID] AS [mxCurrencyGUID],
		[Class] AS [mxClass],
		[CostGUID] AS [mxCostGUID],
		[ContraAccGUID] AS [mxContraAccGUID]
	FROM [Mx000]


#########################################################
#END