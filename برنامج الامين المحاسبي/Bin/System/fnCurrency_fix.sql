###########################################################################
CREATE FUNCTION fnCurrency_Fix(@Value AS [FLOAT], @OldCurGUID [UNIQUEIDENTIFIER], @OldCurVal [FLOAT], @NewCurGUID [UNIQUEIDENTIFIER], @NewCurDate AS [DATETIME] = NULL)
	RETURNS [FLOAT]
AS BEGIN
	DECLARE
		@newCurVal [FLOAT],
		@Result [FLOAT]

	IF @OldCurGUID = @NewCurGUID
		SET @Result = @Value / (CASE @OldCurVal WHEN 0 THEN 1 ELSE @OldCurVal END)

	ELSE BEGIN
		IF @NewCurDate IS NOT NULL
			SET @newCurVal = (SELECT TOP 1 [CurrencyVal] FROM [mh000] WHERE [CurrencyGUID] = @NewCurGUID AND [Date] <= @NewCurDate ORDER BY [Date] DESC)

		IF @newCurVal IS NULL
			SET @newCurVal = (SELECT [CurrencyVal] FROM [my000] WHERE [GUID] = @newCurGUID)
		SET @Result = @Value / (CASE @NewCurVal WHEN 0 THEN 1 ELSE @NewCurVal END)
	END
	RETURN @Result 
END

###########################################################################
#END 