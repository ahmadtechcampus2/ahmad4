#########################################################
CREATE VIEW vwMnFm
AS 
	SELECT
		[mn].[Type] AS [mnType],
		[mn].[Number] AS [mnNumber],
		[mn].[Date] AS [mnDate],
		[mn].[InDate] AS [mnInDate],
		[mn].[OutDate] AS [mnOutDate],
		[mn].[Qty] AS [mnQty],
		[mn].[Notes] AS [mnNotes],
		[mn].[Security] AS [mnSecurity],
		[mn].[Flags] AS [mnFlags],
		[mn].[PriceType] AS [mnPriceType],
		[mn].[CurrencyVal] AS [mnCurrencyVal],
		[mn].[UnitPrice] AS [mnUnitPrice],
		[mn].[TotalPrice] AS [mnTotalPrice],
		[mn].[GUID] AS [mnGUID],
		[mn].[FormGUID] AS [mnFormGUID],
		[mn].[InStoreGUID] AS [mnInStoreGUID],
		[mn].[OutStoreGUID] AS [mnOutStoreGUID],
		[mn].[InAccountGUID] AS [mnInAccountGUID],
		[mn].[OutAccountGUID] AS [mnOutAccountGUID],
		[mn].[InCostGUID] AS [mnInCostGUID],
		[mn].[OutCostGUID] AS [mnOutCostGUID],
		[mn].[InTempAccGUID] AS [mnInTempAccGUID],
		[mn].[OutTempAccGUID] AS [mnOutTempAccGUID],
		[mn].[CurrencyGUID] AS [mnCurrencyGUID],
		[mn].[LOT] AS [mnLOT],
		[mn].[ProductionTime] AS [mnProductionTime],
		[mn].[BranchGUID] AS [mnBranchGUID],
		
		[fm].[Number] AS [fmNumber],
		[fm].[Code] AS [fmCode],
		[fm].[Name] AS [fmName],
		[fm].[Designer] AS [fmDesigner],
		[fm].[LatinName] AS [fmLatinName],
		[fm].[GUID] AS [fmGUID]
	FROM
		[vbMn] AS [mn] INNER JOIN [vtFm] AS [fm]
		ON [mn].[FormGUID] = [fm].[GUID]

#########################################################
#END


		
		