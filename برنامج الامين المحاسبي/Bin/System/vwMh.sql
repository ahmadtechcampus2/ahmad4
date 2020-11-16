#########################################################
CREATE VIEW vwMh
AS
	SELECT 
		[GUID] AS [mhGUID],
		[CurrencyGUID] AS [mhCurrencyGUID],
		[CurrencyVal] AS [mhCurrencyVal],
		[Date]  AS [mhDate]
	FROM 
		[mh000]
#########################################################
#END