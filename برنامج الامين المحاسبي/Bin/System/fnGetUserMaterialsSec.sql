###########################################################################
CREATE FUNCTION fnGetUserMaterialsSec(@UserGUID [UNIQUEIDENTIFIER])
	RETURNS TABLE
AS
	RETURN (SELECT [mtGUID] AS [GUID], [mtSecurity] AS [SECURITY] from [vwMt])
###########################################################################
CREATE FUNCTION fnGetReadMatLastPrice(@UserGUID [UNIQUEIDENTIFIER])
	RETURNS [INT] 
AS BEGIN 
 RETURN [dbo].[fnGetUserSec](@UserGUID, 0x1A, 0x00, 1, 0) 
END
###########################################################################
#END