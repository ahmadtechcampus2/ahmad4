###################################
CREATE VIEW vwOcur 
AS 
	SELECT  
		[GUID]			AS [ocGUID],
		[CurrencyGUID]	AS [ocCurrencyGUID],
		[CurrencyVal]	AS [ocCurrencyVal],
		[Value]			AS [ocValue],
		[ParentGUID]	AS [ocParentGUID]
	FROM 
		[ocur000]
###################################
#END