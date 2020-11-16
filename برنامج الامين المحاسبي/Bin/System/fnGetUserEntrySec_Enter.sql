#############################################################################
CREATE FUNCTION fnGetUserEntrySec_Enter(@UserGUID [UNIQUEIDENTIFIER], @Type AS [UNIQUEIDENTIFIER] = 0x0)
	RETURNS [INT]
AS BEGIN
	RETURN [dbo].[fnGetUserEntrySec](@UserGUID, @Type, 0)
END

#############################################################################
#END