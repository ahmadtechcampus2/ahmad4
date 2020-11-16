###########################################################################
CREATE FUNCTION fnIsAdmin(@UserGUID [UNIQUEIDENTIFIER] = 0x0)
	RETURNS [BIT]
AS BEGIN
	IF @UserGUID IS NULL OR @UserGUID = 0x0
		SET @UserGUID = [dbo].[fnGetCurrentUserGUID]()

	IF EXISTS(SELECT * FROM [vwUIX] WHERE [uiUserGUID] = @UserGUID AND [uiReportID] = 0 AND [uiSubID] = 0x0)
		RETURN 1

	RETURN 0
END

###########################################################################
#END