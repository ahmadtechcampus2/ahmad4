###############################################################################
CREATE FUNCTION fnGetUserAccountSec_readBalance(@UserGUID [UNIQUEIDENTIFIER])
	RETURNS [INT]
AS BEGIN
	RETURN [dbo].[fnGetUserSec](@UserGUID, 18, 0x0, 1, 0)
END

###############################################################################
#END