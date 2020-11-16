################################################################################
CREATE FUNCTION fnPriceDifferences(@Date DateTime)  
RETURNS int   
AS
BEGIN
	DECLARE @ZerAccuracy INT = dbo.fnOption_GetInt('AmnCfg_PricePrec', '2')
	DECLARE @TotalDiffrence TABLE(  
		[Balance]		[FLOAT],
		[CurBalance]	[FLOAT])   

	INSERT INTO @TotalDiffrence
		SELECT 	
			SUM([enDebit]) - SUM([enCredit]),
			(sum([dbo].[fnCurrency_fix]([enDebit], [enCurrencyPtr], [enCurrencyVal], [acCurrencyPtr], [endate])) 
				- sum([dbo].[fnCurrency_fix]([enCredit], [enCurrencyPtr], [enCurrencyVal], [acCurrencyPtr], [endate])))*
                 [dbo].[fnGetCurVal]([acCurrencyPtr], @Date)
		FROM
			[vwCeEn] INNER JOIN [vwac] On [enAccount] = [acGuid]
		WHERE 
			[enDate] = @Date 
		GROUP BY 
			[acGuid], [acCode], [acName], [acLatinName], [acSecurity], [acCurrencyPtr]

	IF EXISTS(SELECT * FROM @TotalDiffrence WHERE ROUND([Balance], @ZerAccuracy) != ROUND([CurBalance], @ZerAccuracy))
		 RETURN 1 
	RETURN 0
 END
################################################################################
#END
