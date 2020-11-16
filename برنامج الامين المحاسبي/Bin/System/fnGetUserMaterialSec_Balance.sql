###########################################################################
CREATE FUNCTION fnGetUserMaterialSec_Balance(@UserGUID [UNIQUEIDENTIFIER])
	RETURNS [INT]
AS BEGIN
	RETURN [dbo].[fnGetUserSec](@UserGuid, 0x11, 0x0, 1, 0)
END

###########################################################################
#END