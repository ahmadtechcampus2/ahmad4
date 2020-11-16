###########################################################################
CREATE FUNCTION fnGetUserMaterialSec_Browse(@UserGUID [UNIQUEIDENTIFIER])
	RETURNS [INT]
AS BEGIN
	RETURN [dbo].[fnGetUserMaterialSec](@UserGUID, 1)
END

###########################################################################
#END