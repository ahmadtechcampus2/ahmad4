#############################################################################
CREATE FUNCTION fnGetUserEntrySec_Modiy(@UserGUID UNIQUEIDENTIFIER, @Type AS UNIQUEIDENTIFIER = 0x400)
	RETURNS INT
AS BEGIN
	RETURN dbo.fnGetUserEntrySec(@UserGUID, @Type, 2)
END

#############################################################################
#END