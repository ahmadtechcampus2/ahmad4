#############################################################################
CREATE FUNCTION fnGetUserBillSec_ChangePrice(@UserGUID [UNIQUEIDENTIFIER], @Type AS [UNIQUEIDENTIFIER])
	RETURNS [INT]
AS BEGIN
	RETURN [dbo].[fnGetUserBillSec](@UserGUID, @Type, 7)
END

#############################################################################
#END