###############################################################################
CREATE FUNCTION fnGetCurVal(
		@CurGuid	[UNIQUEIDENTIFIER],
		@Date		[DATETIME])
RETURNS [FLOAT]
AS  
BEGIN 
	DECLARE @CurVal [FLOAT]
	SET @CurVal = -1 
	SET @CurVal = (
		SELECT TOP 1 [mhCurrencyVal] 
		FROM [vwMh] WHERE [mhCurrencyGUID] = @CurGuid AND [mhDate] <= @Date 
		ORDER BY [mhDate] DESC)
	IF (@CurVal = -1) OR (@CurVal IS NULL) 
		SELECT @CurVal = [CurrencyVal] FROM [my000] WHERE [GUID] = @CurGuid 
	RETURN @CurVal 
END 
###############################################################################
#END