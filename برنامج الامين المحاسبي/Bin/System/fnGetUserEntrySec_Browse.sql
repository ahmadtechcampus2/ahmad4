#############################################################################
CREATE FUNCTION fnGetUserEntrySec_Browse(@UserGUID [UNIQUEIDENTIFIER], @Type AS [UNIQUEIDENTIFIER] = 0x0)
	RETURNS [INT]
AS BEGIN
	RETURN [dbo].[fnGetUserEntrySec](@UserGUID, @Type, 1)
END

#############################################################################
#END