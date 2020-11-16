#########################################################
CREATE VIEW vwPOSLoyaltyCardType
AS 
	SELECT 
		lct.*,
		(SELECT TOP 1 GUID FROM my000 WHERE CurrencyVal = 1 ORDER BY [Number]) AS MainCurrencyGUID
	FROM 
		POSLoyaltyCardType000 lct
#########################################################
#END
