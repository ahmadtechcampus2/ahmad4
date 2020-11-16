#############################################################################
CREATE FUNCTION fnGetUserEntrySec_Modify(@UserGUID [UNIQUEIDENTIFIER], @Type AS [UNIQUEIDENTIFIER] = 0x0)
	RETURNS [INT]
AS BEGIN
	RETURN [dbo].[fnGetUserEntrySec](@UserGUID, @Type, 2)
END

#############################################################################
#END