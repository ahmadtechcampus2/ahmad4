#############################################################################
CREATE FUNCTION fnGetUserNoteSec_Enter(@UserGUID [UNIQUEIDENTIFIER], @Type AS [UNIQUEIDENTIFIER])
	RETURNS [INT]
AS BEGIN
	RETURN [dbo].[fnGetUserNoteSec](@UserGUID, @Type, 0)
END

#############################################################################
#END