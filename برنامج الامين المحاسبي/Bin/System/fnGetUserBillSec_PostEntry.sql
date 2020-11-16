#############################################################################
CREATE FUNCTION fnGetUserBillSec_PostEntry(@UserGUID [UNIQUEIDENTIFIER], @Type AS [UNIQUEIDENTIFIER])
	RETURNS [INT]
AS BEGIN
	RETURN [dbo].[fnGetUserBillSec](@UserGUID, @Type, 6)
END

#############################################################################
#END