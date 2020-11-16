###########################################################################
CREATE FUNCTION fnBu_Fixed(@CurGUID [UNIQUEIDENTIFIER])
	RETURNS TABLE
AS
	RETURN(
		select *,
			[buTotal] * [FixedCurrencyFactor] AS [FixedBuTotal],
			ISNULL([buTotalDisc] * [FixedCurrencyFactor],0) AS [FixedBuTotalDisc],
			[buTotalExtra] * [FixedCurrencyFactor] AS [FixedBuTotalExtra],
			[buItemsDisc] * [FixedCurrencyFactor] AS [FixedbuItemsDisc],
			[buFirstPay] * [FixedCurrencyFactor] AS [FixedbuFirstPay],
			[buProfits] * [FixedCurrencyFactor] AS [FixedbuProfits],
			[buTotalTaxValue] * [FixedCurrencyFactor] AS [FixedbuVAT],
			buTotalSalesTax * FixedCurrencyFactor AS FixedBuTotalSalesTax,
			[buItemsExtra] * [FixedCurrencyFactor] AS [FixedbuItemsExtra]
		from

		(
		SELECT
			*,
			[dbo].[fnCurrency_fix](1, [buCurrencyPtr], [buCurrencyVal], @CurGUID, [buDate]) AS [FixedCurrencyFactor]
		FROM
			[vwBu]) x)

###########################################################################
#END
