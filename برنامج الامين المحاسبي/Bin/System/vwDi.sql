#########################################################
CREATE VIEW vwDi
AS
	SELECT
		[Guid]		AS  [diGuid],
		[ParentGUID] AS [diParent],
		[Number] AS [diNumber],
		[AccountGUID] AS [diAccount],
		[Discount] AS [diDiscount],
		[Extra] AS [diExtra],
		[CurrencyGUID] AS [diCurrencyPtr],
		[CurrencyVal] AS [diCurrencyVal],
		[CostGUID] AS [diCostGUID],
		[ContraAccGUID] AS [diContraAccGUID],
		[Notes] AS [diNotes],
		[Flag] AS [diFlag],
		[classPtr] as [diClassPtr]
	FROM
		[di000]

#########################################################
#END