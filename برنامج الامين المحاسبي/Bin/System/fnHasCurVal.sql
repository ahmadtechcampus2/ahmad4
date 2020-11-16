###############################################################################
CREATE FUNCTION fnHasCurVal(
		@CurGuid	[UNIQUEIDENTIFIER],
		@Date		[DATETIME])
RETURNS [INT]
AS 
BEGIN
IF( EXISTS (SELECT * FROM [vwMh] WHERE [mhCurrencyGUID] = @CurGuid AND [mhDate] <= @Date))
	RETURN 1
RETURN 0
END
###############################################################################
#END