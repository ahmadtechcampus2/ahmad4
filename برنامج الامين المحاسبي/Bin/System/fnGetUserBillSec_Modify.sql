#############################################################################
CREATE FUNCTION fnGetUserBillSec_Modify(@UserGUID [UNIQUEIDENTIFIER], @Type AS [UNIQUEIDENTIFIER])
	RETURNS [INT]
AS BEGIN
	RETURN [dbo].[fnGetUserBillSec](@UserGUID, @Type, 2)
END
#############################################################################
CREATE FUNCTION fnGetUserBillSec_ModifyUnPosted (@UserGUID [UNIQUEIDENTIFIER], @Type AS [UNIQUEIDENTIFIER]) 
	RETURNS [INT] 
AS BEGIN 
	RETURN [dbo].[fnGetUserBillSec](@UserGUID, @Type, 10) 
END 
#############################################################################
#END