#############################################################################
CREATE FUNCTION fnGetUserNoteSec_Modify(@UserGUID [UNIQUEIDENTIFIER], @Type AS [UNIQUEIDENTIFIER])
	RETURNS [INT]
AS BEGIN
	RETURN [dbo].[fnGetUserNoteSec](@UserGUID, @Type, 2)
END

#############################################################################
#END