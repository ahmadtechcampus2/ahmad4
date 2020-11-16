###########################################################################
CREATE FUNCTION fnGetUserStoreSec(@UserGUID [UNIQUEIDENTIFIER], @PermType [INT])
	RETURNS [INT]
AS BEGIN
	RETURN [dbo].[fnGetUserSec](@UserGUID, 0x1001D000, 0x0, 1, @PermType)
END

###########################################################################
#END