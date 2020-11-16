#############################################################################
CREATE FUNCTION fnGetUserBillSec_GenEntry(@UserGUID [UNIQUEIDENTIFIER], @Type AS [UNIQUEIDENTIFIER])
	RETURNS [INT]
AS BEGIN
	RETURN [dbo].[fnGetUserBillSec](@UserGUID, @Type, 5)
END

#############################################################################
#END