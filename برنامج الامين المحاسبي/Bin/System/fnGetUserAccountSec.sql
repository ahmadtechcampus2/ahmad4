###########################################################################
CREATE FUNCTION fnGetUserAccountSec(@UserGUID [UNIQUEIDENTIFIER], @PermType [INT])
	RETURNS [INT]
AS BEGIN
	RETURN [dbo].[fnGetUserSec](@UserGUID, 0x10017000, 0x0, 1, @PermType)
END

###########################################################################
#END