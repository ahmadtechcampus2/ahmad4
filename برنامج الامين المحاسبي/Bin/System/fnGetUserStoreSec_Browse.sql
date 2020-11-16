###########################################################################
CREATE FUNCTION fnGetUserStoreSec_Browse(@UserGUID [UNIQUEIDENTIFIER])
	RETURNS [INT]
AS BEGIN
	RETURN [dbo].[fnGetUserStoreSec](@UserGUID, 1)
END

###########################################################################
#END