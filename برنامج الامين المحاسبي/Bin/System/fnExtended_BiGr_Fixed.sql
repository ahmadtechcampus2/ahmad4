###########################################################################
CREATE FUNCTION fnExtended_BiGr_Fixed(@CurGUID [UNIQUEIDENTIFIER])
	RETURNS TABLE
AS
	RETURN(
		SELECT
			*,
			[FixedCurrencyFactor] * [buTotal] AS [FixedBuTotal],
			[FixedCurrencyFactor] * [buTotalDisc] AS [FixedBuTotalDisc],
			[FixedCurrencyFactor] * [buTotalExtra] AS [FixedBuTotalExtra],
			[FixedCurrencyFactor] * [buItemsDisc] AS [FixedbuItemsDisc],
			[FixedCurrencyFactor] * [buFirstPay] AS [FixedbuFirstPay],
			[FixedCurrencyFactor] * ((([biUnitPrice] - [biUnitDiscount] + [biUnitExtra]) * [biQty]) +[biVat]) AS [FixedBiTotal],
			[FixedCurrencyFactor] * [biPrice] AS [FixedBiPrice],
			[FixedCurrencyFactor] * [biUnitPrice]  AS [FixedbiUnitPrice],
			[FixedCurrencyFactor] * [biUnitDiscount] AS [FixedbiUnitDiscount],
			[FixedCurrencyFactor] * [biUnitExtra] AS [FixedbiUnitExtra],
			[FixedCurrencyFactor] * [biDiscount] AS [FixedBiDiscount],
			[FixedCurrencyFactor] * [biBonusDisc] AS [FixedBiBonusDisc],
			[FixedCurrencyFactor] * [biExtra] AS [FixedBiExtra],
			[FixedCurrencyFactor] * [biVAT] AS [FixedBiVAT],
			[FixedCurrencyFactor] * [biProfits] AS [FixedBiProfits],
			[FixedCurrencyFactor] * [buVAT] AS [FixedBuVAT]
		FROM
			(SELECT 
			*, 
			[dbo].[fnCurrency_fix](1, [buCurrencyPtr], [buCurrencyVal], @CurGUID, [buDate]) AS [FixedCurrencyFactor]
		FROM 
			[vwExtended_BiGr])AS [r])

###########################################################################
#END
