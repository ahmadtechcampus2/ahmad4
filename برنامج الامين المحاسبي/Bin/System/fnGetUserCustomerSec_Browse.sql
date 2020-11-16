###########################################################################
CREATE FUNCTION fnGetUserCustomerSec_Browse(@UserGUID [UNIQUEIDENTIFIER])
	RETURNS [INT]
AS BEGIN
	RETURN [dbo].[fnGetUserCustomerSec](@UserGUID, 1)
END

###########################################################################
#END