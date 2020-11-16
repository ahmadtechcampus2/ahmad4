###########################################################################
CREATE FUNCTION fnGetUserCustomerSec(@UserGUID [UNIQUEIDENTIFIER], @PermType [INT])
	RETURNS [INT]
AS BEGIN
	RETURN [dbo].[fnGetUserSec](@UserGUID, 0x10018000, 0x0, 1, @PermType)
END

###########################################################################
CREATE FUNCTION fnCanShowCustomer(@CustomerGUID [UNIQUEIDENTIFIER])
	RETURNS [BIT]
AS BEGIN
		
	DECLARE 
		@UserGUID [UNIQUEIDENTIFIER],
		@UserSec [INT]
		
	SET @UserGUID = [dbo].[fnGetCurrentUserGUID]()
	SET @UserSec = [dbo].[fnGetUserCustomerSec](@UserGUID, 1)
	
	IF EXISTS( SELECT * FROM [dbo].[fnGetUserCustomersSec](@UserGUID) WHERE GUID = @CustomerGUID AND [Security] > @UserSec)
		RETURN 0
	RETURN 1
END
###########################################################################
#END