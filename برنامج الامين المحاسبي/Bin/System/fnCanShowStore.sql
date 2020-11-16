###########################################################################
CREATE FUNCTION fnCanShowStore(@StoreGUID [UNIQUEIDENTIFIER]) 
	RETURNS [BIT] 
AS BEGIN 
	DECLARE  
		@UserGUID [UNIQUEIDENTIFIER], 
		@UserSec [INT] 
		 
	SET @UserGUID = [dbo].[fnGetCurrentUserGUID]()

	SELECT @UserSec = uiPermission
	FROM vwUIX
	WHERE
	uiUserGUID = [dbo].[fnGetCurrentUserGUID]() AND
	uiReportID = 268554240 AND
	uiPermType = 1

	IF EXISTS( SELECT * FROM vwst WHERE stGUID = @StoreGUID AND stSecurity <= @UserSec) 
		RETURN 1 
	
	RETURN 0
END 
###########################################################################
#END