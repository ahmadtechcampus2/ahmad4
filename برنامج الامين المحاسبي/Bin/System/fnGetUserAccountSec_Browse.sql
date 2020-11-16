###########################################################################
CREATE FUNCTION fnGetUserAccountSec_Browse(@UserGUID [UNIQUEIDENTIFIER])
	RETURNS [INT]
AS BEGIN
	RETURN [dbo].[fnGetUserAccountSec](@UserGUID, 1)
END

###########################################################################
#END 