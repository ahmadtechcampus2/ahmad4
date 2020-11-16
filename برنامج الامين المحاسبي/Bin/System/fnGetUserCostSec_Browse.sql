###########################################################################
CREATE FUNCTION fnGetUserCostSec_Browse(@UserGUID [UNIQUEIDENTIFIER])
	RETURNS [INT]
AS BEGIN
	RETURN [dbo].[fnGetUserCostSec](@UserGUID, 1)
END

###########################################################################
#END