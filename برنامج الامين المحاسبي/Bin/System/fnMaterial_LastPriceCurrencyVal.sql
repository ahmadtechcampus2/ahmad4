###########################################################################
CREATE FUNCTION fnMaterial_LastPriceCurrencyVal(@MatGUID [UNIQUEIDENTIFIER], @CurrencyGUID [UNIQUEIDENTIFIER])
	RETURNS FLOAT 
AS BEGIN
/*
this function:
	- returns a currency value for specified currency in the last price date.
*/
	DECLARE @LastBillCurrencyValue FLOAT;
	DECLARE @LastPriceDate DATE;

	SELECT @LastPriceDate = ISNULL(LastPriceDate, GETDATE()) FROM mt000 WHERE guid = @MatGUID AND DisableLastPrice = 1

	;WITH LastBill AS
	(
		SELECT
			buNumber,
			buDate,
			buCurrencyVal
		FROM vwExtended_bi 
		WHERE
			btAffectLastPrice = 1 
			AND biMatPtr = @MatGUID 
			AND buCurrencyPtr = @CurrencyGUID
			AND buDate >= @LastPriceDate
	)
	SELECT TOP 1 @LastBillCurrencyValue = buCurrencyVal
	FROM
		LastBill L
	WHERE 
		buDate = (SELECT MAX(buDate) FROM LastBill)
		AND buNumber = (SELECT MAX(buNumber) FROM LastBill);

	IF @LastBillCurrencyValue IS NOT NULL
		RETURN @LastBillCurrencyValue;

	RETURN (ISNULL((SELECT [dbo].fnGetCurVal(@CurrencyGUID, @LastPriceDate)), 1));
END
###########################################################################
#END
