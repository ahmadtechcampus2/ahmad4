###########################################################################
CREATE FUNCTION fnCheckParentAcc(@FinalAcc [UNIQUEIDENTIFIER], @AccGUID [UNIQUEIDENTIFIER], @AccParent [UNIQUEIDENTIFIER])
	RETURNS [UNIQUEIDENTIFIER]
AS BEGIN
	DECLARE
		@Parent	[UNIQUEIDENTIFIER],
		@Num	[UNIQUEIDENTIFIER],
		@Final	[UNIQUEIDENTIFIER]

	WHILE @AccParent IS NOT NULL
	BEGIN
		SELECT
			@Parent = @AccParent,
			@Num = @AccGUID

		SELECT
			@AccGUID = [acGUID],
			@AccParent = [acParent],
			@Final = [acFinal]
		FROM
			[vwAc]
		WHERE
			[acGUID] = @Parent

		IF @Final <> @FinalAcc
		BEGIN
			SET @AccGUID = @Num
			BREAK
		END
	END
	RETURN @AccGUID
END

###########################################################################
#END