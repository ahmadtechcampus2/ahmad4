##########################################################################
CREATE FUNCTION fnCanShowObject(@ObjGuid UNIQUEIDENTIFIER)
	RETURNS [BIT]
AS 
	BEGIN
		DECLARE @UserSec [INT] 		 

		SELECT @UserSec = uiPermission
		FROM vwUIX
		WHERE
			uiUserGUID = [dbo].[fnGetCurrentUserGUID]() 
			 AND
			uiReportID = 268529664
			 AND
			uiPermType = 1

		IF EXISTS(SELECT * FROM vwac WHERE acGuid = @ObjGuid AND acSecurity <= @UserSec)
			RETURN 1
		RETURN 0
	END

##########################################################################
#END