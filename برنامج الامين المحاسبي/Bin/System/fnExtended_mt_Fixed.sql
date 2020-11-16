######################################################### 
CREATE FUNCTION fnExtended_mt_fixed(@priceType [INT], @pricePolicy [INT], @useUnit [INT], @curGUID [UNIQUEIDENTIFIER], @curDate [DATETIME])
	RETURNS TABLE
AS
	RETURN
		(SELECT
			*,
			(CASE @PriceType
				WHEN 2 THEN 
					[dbo].[fnCurrency_fix]([price], (SELECT TOP 1 [guid] FROM [my000] WHERE [currencyVal] = 1), 1, @curGUID, @curDate) 
				ELSE 
					[dbo].[fnCurrency_fix]([price], (SELECT TOP 1 [guid] FROM [my000] WHERE [currencyVal] = 1), 1, @curGUID, @curDate) 
					* ([dbo].fnGetCurVal(mtCurrencyPtr, @curDate) / (CASE mtCurrencyVal when 0 THEN 1 ELSE mtCurrencyVal END))

			END) AS [fixedPrice]
		FROM
			[fnExtended_mt](@priceType, @pricePolicy, @useUnit))
#########################################################
CREATE FUNCTION fnExtended_mt_Price_fixed(@priceType [INT], @pricePolicy [INT], @useUnit [INT], @curGUID [UNIQUEIDENTIFIER], @curDate [DATETIME], @mtGUID [UNIQUEIDENTIFIER])
	RETURNS FLOAT
AS
BEGIN
	RETURN
		ISNULL((
			SELECT
				TOP 1 [fixedPrice]
			FROM
				fnExtended_mt_fixed(@priceType, @pricePolicy, @useUnit, @curGUID, @curDate) WHERE mtGUID = @mtGUID), 0)
END 
#########################################################
#END