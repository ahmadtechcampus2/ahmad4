#########################################################
CREATE PROCEDURE prcSetCurVal
		@CurGuid	[UNIQUEIDENTIFIER],
		@Date		[DATETIME],
		@Val		[FLOAT],
		@Force		[INT]
AS 
IF( EXISTS (SELECT * FROM [vwMh] WHERE [mhCurrencyGUID] = @CurGuid AND [mhDate] = @Date))
BEGIN
	IF( @Force <> 0)
		UPDATE 	[mh000]
			SET [CurrencyVal] = @Val
		WHERE 
			[CurrencyGUID] = @CurGuid AND [Date] = @Date
END
ELSE
	INSERT INTO [mh000] VALUES( NEWID(), @CurGuid, @Val, @Date)

#########################################################
#END