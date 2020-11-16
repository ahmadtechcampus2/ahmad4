#########################################################
CREATE VIEW vwExtended_Di
AS
SELECT
	[di].[Number] 		AS [diNumber], 
	[di].[Discount] 	AS [diDiscount], 
	[di].[Extra] 		AS [diExtra],
	[di].[CurrencyVal] 	AS [diCurrencyVal],
	[di].[Notes] 		AS [diNotes],
	[di].[Flag] 		AS [diFlag],
	[di].[GUID] 		AS [diGUID],
	[di].[ClassPtr] 	AS [diClassPtr],
	[di].[ParentGUID] 	AS [diParentGUID],
	[di].[AccountGUID] 	AS [diAccountGUID],
	[di].[CurrencyGUID] AS [diCurrencyGUID],
	[di].[CostGUID] 	AS [diCostGUID],
	[di].[ContraAccGUID]AS [diContraAccGUID],
	[bu].[TypeGUID] 	AS [buTypeGUID],
	[bu].[Date]			AS [buDate]
FROM
	[di000] AS [di] INNER JOIN [bu000] AS [bu] ON [di].[ParentGUID] = [bu].[GUID]

/*
select * from vwExtended_Di
*/
#########################################################
#END