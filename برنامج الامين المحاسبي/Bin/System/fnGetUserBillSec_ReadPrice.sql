#############################################################################
CREATE FUNCTION fnGetUserBillSec_ReadPrice(@UserGUID [UNIQUEIDENTIFIER], @Type AS [UNIQUEIDENTIFIER])
	RETURNS [INT]
AS BEGIN
	RETURN [dbo].[fnGetUserBillSec](@UserGUID, @Type, 8)
END

#############################################################################
#END