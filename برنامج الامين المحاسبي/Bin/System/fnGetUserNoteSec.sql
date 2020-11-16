#############################################################################
CREATE FUNCTION fnGetUserNoteSec(@UserGUID [UNIQUEIDENTIFIER], @Type AS [UNIQUEIDENTIFIER], @PermType [INT])
	RETURNS [INT]
AS BEGIN
	RETURN [dbo].[fnGetUserSec](@UserGUID, 0x10015000, @Type, 1, @PermType)
END

#############################################################################
#END