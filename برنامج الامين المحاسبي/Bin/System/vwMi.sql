#########################################################
CREATE VIEW vwMi
AS
	SELECT
		[Type] AS [miType],
		[Number] AS [miNumber],
		[Unity] AS [miUnity],
		[Qty] AS [miQty],
		[Notes] AS [miNotes],
		[CurrencyVal] AS [miCurrencyVal],
		[Price] AS [miPrice],
		[Class] AS [miClass],
		[GUID] AS [miGUID],
		[Qty2] AS [miQty2],
		[Qty3] AS [miQty3],
		[ParentGUID] AS [miParent],
		[MatGUID] AS [miMatGUID],
		[StoreGUID] AS [miStoreGUID],
		[CurrencyGUID] AS [miCurrencyGUID],
		[ExpireDate] AS [miExpireDate],
		[ProductionDate] AS [miProductionDate],
		[Length] AS [miLength],
		[Width] AS [miWidth],
		[Height] AS [miHeight],
		[CostGUID] AS [miCostGUID],
		[Percentage] AS [miPercentage]
	FROM
		[mi000]

#########################################################
#END