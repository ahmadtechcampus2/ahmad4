#############################################################################
CREATE FUNCTION fnGetUserEntrySec_Delete(@UserGUID [UNIQUEIDENTIFIER], @Type AS [UNIQUEIDENTIFIER] = 0x0)
	RETURNS [INT]
AS BEGIN
	RETURN [dbo].[fnGetUserEntrySec](@UserGUID, @Type, 3)
END

#############################################################################
#END