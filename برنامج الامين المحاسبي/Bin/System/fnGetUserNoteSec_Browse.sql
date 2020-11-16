#############################################################################
CREATE FUNCTION fnGetUserNoteSec_Browse(@UserGUID [UNIQUEIDENTIFIER], @Type AS [UNIQUEIDENTIFIER])
	RETURNS [INT]
AS BEGIN
	RETURN [dbo].[fnGetUserNoteSec](@UserGUID, @Type, 1)
END

#############################################################################
#END