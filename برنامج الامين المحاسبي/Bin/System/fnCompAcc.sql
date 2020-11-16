###########################################################################
CREATE FUNCTION fnCompAcc(@FinalAcc [UNIQUEIDENTIFIER], @ParentAcc [UNIQUEIDENTIFIER], @AccGUID [UNIQUEIDENTIFIER])
	RETURNS [UNIQUEIDENTIFIER]
AS BEGIN

	DECLARE
		@Parent	[UNIQUEIDENTIFIER],
		@Acc	[UNIQUEIDENTIFIER],
		@Final	[UNIQUEIDENTIFIER]

	WHILE @FinalAcc <> @ParentAcc
	BEGIN
		IF @ParentAcc IS NULL
		BEGIN
			SELECT @Final = [acFinal] FROM [vwAc] WHERE [acGUID] = @AccGUID
			IF @Final IS NULL
				IF @FinalAcc = @AccGUID
					RETURN @AccGUID
				ELSE
					RETURN NULL
			ELSE IF @FinalAcc <> @Final
					RETURN NULL
				ELSE
					RETURN @AccGUID
		END

		SELECT @Parent = [acParent], @Acc = [acGUID] FROM [vwAc] WHERE [acGUID] = @ParentAcc
		RETURN [dbo].[fnCompAcc]( @FinalAcc, @Parent, @Acc)
	END
	RETURN @AccGUID
END

###########################################################################
#END