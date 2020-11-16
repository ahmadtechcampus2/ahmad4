###########################################################################
CREATE FUNCTION fnBuCu_Fixed(@CurGUID [UNIQUEIDENTIFIER])
	RETURNS TABLE  
AS
	RETURN
		(SELECT
				*,
				[buTotal] * [FixedCurrencyFactor] AS [FixedBuTotal],
				[buTotalDisc] * [FixedCurrencyFactor] AS [FixedBuTotalDisc],
				[buTotalExtra] * [FixedCurrencyFactor] AS [FixedBuTotalExtra],
				[buItemsDisc] * [FixedCurrencyFactor] AS [FixedbuItemsDisc],
				[buFirstPay]* [FixedCurrencyFactor] AS [FixedbuFirstPay],
				[buProfits]* [FixedCurrencyFactor] AS [FixedbuProfits],
				[buVAT]* [FixedCurrencyFactor] AS [FixedbuVAT],
				ISNULL((SELECT [cuCustomerName] FROM [vwCu] WHERE [cuGuid] = [buCustPtr]), 0x0) AS [cuCustomerName],
				ISNULL((SELECT [cuLatinName] FROM [vwCu] WHERE [cuGuid] = [buCustPtr]), 0x0) AS [cuLatinName]
			FROM
				(
					SELECT
						*,
						[dbo].[fnCurrency_fix](1, [buCurrencyPtr], [buCurrencyVal], @CurGUID, [buDate]) AS [FixedCurrencyFactor]
					FROM	[vwBu]
				) AS [bu])
/*
select buguid, buCustPtr, cuCustomerName from vwExtended_biCu
select buguid, buCustPtr, cuCustomerName from fnBuCu_Fixed( 'EB39D008-2083-46D9-B6EE-E3141BF6CC76')
*/
###########################################################################
#END