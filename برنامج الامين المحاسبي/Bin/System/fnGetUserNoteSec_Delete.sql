#############################################################################
CREATE FUNCTION fnGetUserNoteSec_Delete(@UserGUID [UNIQUEIDENTIFIER], @Type AS [UNIQUEIDENTIFIER])
	RETURNS [INT]
AS BEGIN
	RETURN [dbo].[fnGetUserNoteSec](@UserGUID, @Type, 3)
END

#############################################################################
#END