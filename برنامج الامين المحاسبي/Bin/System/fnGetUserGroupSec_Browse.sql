###########################################################################
CREATE FUNCTION fnGetUserGroupSec_Browse(@UserGUID [UNIQUEIDENTIFIER])
	RETURNS [INT]
AS BEGIN
	RETURN [dbo].[fnGetUserGroupSec](@UserGUID, 1)
END

###########################################################################
#END