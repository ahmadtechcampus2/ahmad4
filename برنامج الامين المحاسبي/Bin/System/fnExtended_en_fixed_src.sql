#########################################################
CREATE FUNCTION fnExtended_En_Fixed_Src( @SrcGUID [UNIQUEIDENTIFIER] = 0x0, @CurGUID [UNIQUEIDENTIFIER] = 0x0)
	RETURNS TABLE

AS  
	RETURN ( 
			SELECT 
				*,
				[dbo].[fnCurrency_fix]([enDebit], [enCurrencyPtr], [enCurrencyVal], @CurGUID, [enDate]) AS [FixedEnDebit],  
				[dbo].[fnCurrency_fix]([enCredit], [enCurrencyPtr], [enCurrencyVal],  @CurGUID, [enDate]) AS [FixedEnCredit]
			FROM
				[dbo].[fnExtended_En_Src]( @SrcGUID))

#########################################################
#END