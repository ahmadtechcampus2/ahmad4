###########################################################################
CREATE FUNCTION fnCanShowStore(@StoreGUID [UNIQUEIDENTIFIER]) 
	RETURNS [BIT] 
AS BEGIN 
	DECLARE  
		@UserGUID [UNIQUEIDENTIFIER], 
		@UserSec [INT] 
		 
	SET @UserGUID = [dbo].[fnGetCurrentUserGUID]() 
	SELECT @UserSec = Permission					
					  FROM 
						ui000 
					  WHERE 
						userGuid = [dbo].[fnGetCurrentUserGUID]()
						AND ReportId = 268554240
						AND PermType = 1

	IF EXISTS( SELECT * FROM vwst WHERE stGUID = @StoreGUID AND stSecurity <= @UserSec) 
		RETURN 1 
	
	RETURN 0
END 
###########################################################################
#END