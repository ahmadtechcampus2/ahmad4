###########################################################################
CREATE FUNCTION fnGetFinal(@FinalGUID [UNIQUEIDENTIFIER], @AccGUID [UNIQUEIDENTIFIER])
	RETURNS [UNIQUEIDENTIFIER]
AS BEGIN
--  «»⁄ ÌŸÂ— «·Õ”«» «·Œ «„Ì «· «»⁄ ··Õ”«» «·Œ «„Ì «·–Ì ‰—”·Â ·Â

	DECLARE @Parent [UNIQUEIDENTIFIER]
	DECLARE @Final [UNIQUEIDENTIFIER]

	SELECT @Final = [acFinal], @Parent = [acParent] FROM [vwAc] WHERE [acGUID] = @AccGUID

	IF @Final <> @FinalGUID
	BEGIN
		SELECT @Parent = [acParent] FROM [vwAc] WHERE [acGUID] = @Final
		RETURN [dbo].[fnCompAcc](@Final, @Parent, @Final)
	END
	ELSE IF @Parent IS NULL
			RETURN @AccGUID
		ELSE
			RETURN [dbo].[fnCheckParent](@Final, @AccGUID, @Parent)

	RETURN NULL
END
###########################################################################
#END