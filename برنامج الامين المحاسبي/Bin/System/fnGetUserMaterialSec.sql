###########################################################################
CREATE FUNCTION fnGetUserMaterialSec(@UserGUID [UNIQUEIDENTIFIER], @PermType [INT])
	RETURNS [INT]
AS BEGIN
	RETURN [dbo].[fnGetUserSec](@UserGUID, 0x10019000, 0x0, 1, @PermType)
END

###########################################################################