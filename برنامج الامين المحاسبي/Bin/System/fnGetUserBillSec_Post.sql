#############################################################################
CREATE FUNCTION fnGetUserBillSec_Post(@UserGUID [UNIQUEIDENTIFIER], @Type AS [UNIQUEIDENTIFIER])
	RETURNS [INT]
AS BEGIN
	RETURN [dbo].[fnGetUserBillSec](@UserGUID, @Type, 4)
END

#############################################################################
#END