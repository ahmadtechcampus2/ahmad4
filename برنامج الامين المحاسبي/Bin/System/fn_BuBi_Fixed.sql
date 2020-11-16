###########################################################################
CREATE FUNCTION fn_bubi_Fixed(@CurGUID [UNIQUEIDENTIFIER])
	RETURNS TABLE 
AS 
	RETURN 
		(SELECT 
			*, 
			[buTotal] * [FixedCurrencyFactor] AS [FixedBuTotal], 
			[buTotalDisc]* [FixedCurrencyFactor] AS [FixedBuTotalDisc], 
			[buTotalExtra]* [FixedCurrencyFactor] AS [FixedBuTotalExtra], 
			[buItemsDisc]* [FixedCurrencyFactor] AS [FixedbuItemsDisc], 
			[buFirstPay]* [FixedCurrencyFactor] AS [FixedbuFirstPay], 
			
			[biPrice]* [FixedCurrencyFactor] AS [FixedBiPrice], 
			[buBonusDisc]* [FixedCurrencyFactor] AS [FixedBuBonusDisc], 
			
			[biDiscount]* [FixedCurrencyFactor] AS [FixedBiDiscount], 
			[biBonusDisc]* [FixedCurrencyFactor] AS [FixedBiBonusDisc], 
			[biExtra]* [FixedCurrencyFactor] AS [FixedBiExtra], 
			[biTotalTaxValue] * [FixedCurrencyFactor] AS [FixedBiVAT], 
			[biProfits]* [FixedCurrencyFactor] AS [FixedBiProfits], 
			[buTotalTaxValue] * [FixedCurrencyFactor] AS [FixedBuVAT], 
			[buTotalSalesTax] * [FixedCurrencyFactor] AS [FixedBuTotalSalesTax], 
			[buItemsExtra] * [FixedCurrencyFactor] AS [FixedbuItemExtra],
			[biLCDisc] * [FixedCurrencyFactor] AS [FixedBiLCDisc],
			[biLCExtra] * [FixedCurrencyFactor] AS [FixedBiLCExtra],
			[TotalDiscountPercent] *[FixedCurrencyFactor] AS [FixedTotalDiscountPercent],
			[TotalExtraPercent] * [FixedCurrencyFactor] AS [FixedTotalExtraPercent],
			[DIDiscount]* [FixedCurrencyFactor] AS [FixedDIDiscount],
			[DIExtra] * [FixedCurrencyFactor] AS [FixedDIExtra]
		FROM 
			(SELECT 
			*, 
			[dbo].[fnCurrency_fix](1, [biCurrencyPtr], [biCurrencyVal], @CurGUID, [buDate]) AS [FixedCurrencyFactor]
		FROM 
			[vwBuBi_Address]) AS [bu])
###########################################################################
#END