#############################################################################
CREATE FUNCTION fnGetUserBillSec_Enter(@UserGUID [UNIQUEIDENTIFIER], @Type AS [UNIQUEIDENTIFIER])
	RETURNS [INT]
AS BEGIN
	RETURN [dbo].[fnGetUserBillSec](@UserGUID, @Type, 0)
END

#############################################################################
#END