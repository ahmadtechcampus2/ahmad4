###########################################################################
CREATE FUNCTION fnExtended_En_Fixed(@CurGUID [UNIQUEIDENTIFIER])
	RETURNS TABLE
AS
	RETURN(
		SELECT
			*,
			[dbo].[fnCurrency_fix]([enDebit], [enCurrencyPtr], [enCurrencyVal], @CurGUID, [enDate]) AS [FixedEnDebit],
			[dbo].[fnCurrency_fix]([enCredit], [enCurrencyPtr], [enCurrencyVal],  @CurGUID, [enDate]) AS [FixedEnCredit]
		FROM
			[vwExtended_en])

###########################################################################
#END