###########################################################################
CREATE FUNCTION fnExtended_bi_Fixed(@CurGUID [UNIQUEIDENTIFIER])
	RETURNS TABLE 
AS 
	RETURN 
		(SELECT 
			*, 
			[buProfits] * [FixedCurrencyFactor] AS [FixedBuProfits],
			[buTotal] * [FixedCurrencyFactor] AS [FixedBuTotal], 
			ISNULL([buTotalDisc]* [FixedCurrencyFactor], 0) AS [FixedBuTotalDisc], 
			[buTotalExtra] * [FixedCurrencyFactor] AS [FixedBuTotalExtra], 
			[buItemsDisc] * [FixedCurrencyFactor] AS [FixedbuItemsDisc], 
			[buFirstPay] * [FixedCurrencyFactor] AS [FixedbuFirstPay], 
			((([biUnitPrice] - [biUnitDiscount] + [biUnitExtra]) * [biQty]) + [biTotalTaxValue] )* [FixedCurrencyFactor] AS [FixedBiTotal],
			[biPrice] * [FixedCurrencyFactor] AS [FixedBiPrice], 
			[biUnitPrice] * [FixedCurrencyFactor] AS [FixedbiUnitPrice], 
			[biUnitDiscount] * [FixedCurrencyFactor] AS [FixedbiUnitDiscount], 
			[biUnitExtra] * [FixedCurrencyFactor] AS [FixedbiUnitExtra], 
			[biDiscount] * [FixedCurrencyFactor] AS [FixedBiDiscount], 
			[biBonusDisc] * [FixedCurrencyFactor] AS [FixedBiBonusDisc], 
			[biExtra] * [FixedCurrencyFactor] AS [FixedBiExtra], 
			[biTotalTaxValue] * [FixedCurrencyFactor] AS [FixedBiVAT], 
			[biProfits] * [FixedCurrencyFactor] AS [FixedBiProfits], 
			[buTotalTaxValue] * [FixedCurrencyFactor] AS [FixedBuVAT],
			[buTotalSalesTax] * [FixedCurrencyFactor] AS [FixedBuTotalSalesTax],
			[buItemsExtra] * [FixedCurrencyFactor] AS [FixedbuItemExtra],
			[biLCDisc] * [FixedCurrencyFactor] AS [FixedBiLCDisc],
			[biLCExtra] * [FixedCurrencyFactor] AS [FixedBiLCExtra]

		FROM 
			[fnExtended_bi_Fixed2](@CurGUID)) 
###########################################################################
#END

