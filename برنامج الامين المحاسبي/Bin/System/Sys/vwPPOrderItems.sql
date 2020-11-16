##################################################################################
CREATE VIEW vwPPOrderItems
AS
	SELECT 
		[PPO].[GUID] As [ppoGuid], 
		[PPO].[Number] As [ppoNumber], 
		[PPO].[OrderNum] As [ppoOrderNum], 
		[PPO].[Supplier] As [ppoSupplier], 
		[PPO].[Date] As [ppoDate], 
		[PPO].[CurrencyGUID] As [ppoCurrencyGUID],
		[PPO].[CurrencyVal] As [ppoCurrencyVal],
		[PPO].[Notes] As [ppoNotes], 
		ISNULL( [PPO].[POGuid], 0x0) As [ppoPOGuid], 
		[PPO].[TypeGuid] As [ppoPOTypeGuid], 
		[PPO].[Type] As [ppoType],
		[PPO].[Security] As [ppoSecurity],
		[PPO].[IsNotAvailableQuantity] AS [ppoIsNotAvailableQuantity],  
		[PPI].[Guid] As [ppiGuid],
		[PPI].[SOGuid] As [ppiSOGuid], 
		[PPI].[SOIGuid] As [ppiSOIGuid], 
		[PPI].[PreparationDate] AS [PreparationDate], 
		[PPI].[MatGuid] As [ppiMatGuid],
		[PPI].[Type] As [ppiType],
		[PPI].[Quantity] AS [ppiQuantity],
		[Ot].[Name] As [OtName],
		[Ot].[LatinName] As [OtLatinName],
		[Ot].[Abbrev] As [OtAbbrev],
		[Ot].[LatinAbbrev] As [OtLatinAbbrev]
	FROM 
		[ppo000] As [PPO] INNER JOIN [ppi000] As [PPI]
		ON [PPO].[Guid] = [PPI].[PPOGuid]
		INNER JOIN (SELECT * FROM [vbBt] WHERE [Type] = 6) As [Ot] ON [Ot].[Guid] = [PPO].[TypeGuid]

##################################################################################
#END
