#########################################################
CREATE FUNCTION fnCurrentUser_CanDo(@ReportID FLOAT, @PermType INT)
	RETURNS BIT 
AS BEGIN 
	DECLARE @UserGUID UNIQUEIDENTIFIER 
	SET @UserGUID = [dbo].[fnGetCurrentUserGUID]()

	IF EXISTS (SELECT * FROM us000 WHERE GUID = @UserGUID AND bAdmin = 1)
		RETURN 1
	IF EXISTS (SELECT * FROM uix WHERE UserGUID = @UserGUID AND ReportID = @ReportID AND PermType = @PermType AND Permission > 0)
		RETURN 1
	
	RETURN 0
END 
#########################################################
#END