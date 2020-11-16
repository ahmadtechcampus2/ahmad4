#############################################################################
CREATE FUNCTION fnGetUserBillSec_Browse(@UserGUID [UNIQUEIDENTIFIER], @Type AS [UNIQUEIDENTIFIER] = 0x0)
	RETURNS [INT]
AS BEGIN
	RETURN [dbo].[fnGetUserBillSec](@UserGUID, @Type, 9)
END
#############################################################################
CREATE FUNCTION fnGetUserBillSec_BrowseUnPosted (@UserGUID [UNIQUEIDENTIFIER], @Type AS [UNIQUEIDENTIFIER] = 0x0) 
	RETURNS [INT] 
AS BEGIN 
	RETURN [dbo].[fnGetUserBillSec](@UserGUID, @Type, 1) 
END 
#############################################################################
#END