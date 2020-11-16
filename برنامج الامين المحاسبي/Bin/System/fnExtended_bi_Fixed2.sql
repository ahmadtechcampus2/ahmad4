###########################################################################
CREATE FUNCTION fnExtended_bi_Fixed2(@CurGUID UNIQUEIDENTIFIER)
	RETURNS TABLE 
AS 
	RETURN 
		(SELECT 
			*, 
			[dbo].[fnCurrency_fix](1, [buCurrencyPtr], [buCurrencyVal], @CurGUID, [buDate]) AS [FixedCurrencyFactor]
		FROM 
			[vwExtended_bi_address])
###########################################################################
#END  