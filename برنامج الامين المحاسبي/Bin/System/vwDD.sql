#########################################################
CREATE VIEW vwDD
AS
	SELECT  
		[GUID] AS [ddGUID],
		[Number] AS [ddNumber],
		[ParentGUID] AS [ddParenrtGUID],
		[ADGuid] AS [ddADGUID],
		[Value] AS [ddValue],
		[CurrencyGUID] AS [ddCurrencyGUID],
		[CurrencyVal] AS [ddCurrencyVal],
		[ToDate] AS [ddToDate],
		[CostGUID] AS [ddCostGUID],
		[Notes] AS [ddNotes]
	FROM [dd000]
	
#########################################################
#END