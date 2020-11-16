###########################################################################
CREATE FUNCTION fnExtended_BiCu_Fixed(@CurGUID [UNIQUEIDENTIFIER])
	RETURNS TABLE
AS 
	RETURN
		(SELECT
			*,
			[buTotal] * [FixedCurrencyFactor] AS [FixedBuTotal],
			[buTotalDisc] * [FixedCurrencyFactor] AS [FixedBuTotalDisc],
			[buTotalExtra] * [FixedCurrencyFactor] AS [FixedBuTotalExtra],
			[buItemsDisc] * [FixedCurrencyFactor] AS [FixedbuItemsDisc],
			[buItemsExtra] * [FixedCurrencyFactor] AS [FixedbuItemsExtra],
			[buFirstPay] * [FixedCurrencyFactor] AS [FixedbuFirstPay],
			((([biUnitPrice] - [biUnitDiscount] + [biUnitExtra]) * [biQty]) + [biVat]) * [FixedCurrencyFactor] AS [FixedBiTotal],
			[biPrice] * [FixedCurrencyFactor] AS [FixedBiPrice],
			[biDiscount] * [FixedCurrencyFactor] AS [FixedBiDiscount],
			[biBonusDisc] * [FixedCurrencyFactor] AS [FixedBiBonusDisc],
			[biExtra]* [FixedCurrencyFactor] AS [FixedBiExtra],
			[biVAT] * [FixedCurrencyFactor] AS [FixedBiVAT],
			[biProfits] * [FixedCurrencyFactor] AS [FixedBiProfits],
			[buVAT] * [FixedCurrencyFactor] AS [FixedBuVAT],
			[biUnitDiscount] * [FixedCurrencyFactor] AS [FixedbiUnitDiscount],
			[buBonusDisc] * [FixedCurrencyFactor] AS [FixedbuBonusDisc]
		FROM(
			SELECT
				*,
				[dbo].[fnCurrency_fix](1, [biCurrencyPtr], [biCurrencyVal], @CurGUID, [buDate]) AS [FixedCurrencyFactor]
			FROM
				[vwExtended_biCu]) AS X)

###########################################################################
#END