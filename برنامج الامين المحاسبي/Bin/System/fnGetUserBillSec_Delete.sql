#############################################################################
CREATE FUNCTION fnGetUserBillSec_Delete(@UserGUID [UNIQUEIDENTIFIER], @Type AS [UNIQUEIDENTIFIER])
	RETURNS [INT]
AS BEGIN
	RETURN [dbo].[fnGetUserBillSec](@UserGUID, @Type, 3)
END
#############################################################################
CREATE FUNCTION fnGetUserBillSec_DeleteUnPosted (@UserGUID [UNIQUEIDENTIFIER], @Type AS [UNIQUEIDENTIFIER]) 
	RETURNS [INT] 
AS BEGIN 
	RETURN [dbo].[fnGetUserBillSec](@UserGUID, @Type, 11) 
END 
#############################################################################
#END