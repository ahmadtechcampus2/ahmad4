################################################################################
CREATE VIEW vwDiscountRecord
AS 
	SELECT 	  
		[DTC].[Name],
		[DTC].[UsePoint], 
		[DTC].[CollectPoint],
		[DTC].[SpendPoint],
		[DC].[CustomerGuid], 
		[DC].[Code], 
		[DC].[Guid] AS [CardID], 
		[DC].[StartDate], 
		[DC].[EndDate], 
		[DT].[Guid] AS [DiscountID],
		[DT].[Account]	as [DiscountAcc], 
		[DT].[Value], 
		[DT].[Type] AS [DiscountType], 
		[DT].[DonateCond] AS [CondValue], 
		[DCS].[Name] AS [StateName], 
		[DCS].[state] ,
		[DTC].[IsFinishedDate]
	FROM   
		[DiscountCard000]  [DC]  
		INNER JOIN [DiscountTypesCard000] [DTC] on [DTC].[Guid] = [DC].[Type] 
		INNER JOIN [DiscountTypes000] [DT]  on [DTC].[DiscType] = [DT].[Guid] 
		INNER JOIN [DiscountCardStatus000] [DCS] on [DCS].[guid] = [DC].[state]
################################################################################
#END
