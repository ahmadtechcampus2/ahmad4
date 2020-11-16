###########################################################################
CREATE FUNCTION fn_bubi_Fixed2(@CurGUID [UNIQUEIDENTIFIER])
	RETURNS TABLE 
AS 
	RETURN 
		(SELECT 
			*, 
			[dbo].[fnCurrency_fix](1, [biCurrencyPtr], [biCurrencyVal], @CurGUID, [buDate]) AS [FixedCurrencyFactor]
		FROM 
			[vwBuBi])
###########################################################################
#END