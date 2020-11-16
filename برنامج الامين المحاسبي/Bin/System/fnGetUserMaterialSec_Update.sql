CREATE FUNCTION fnGetUserMaterialSec_Update (@UserGUID [UNIQUEIDENTIFIER]) 
	RETURNS [INT]
AS BEGIN 
	RETURN [dbo].[fnGetUserSec](@UserGuid, 268537856, 0x0, 1, 2) 
END 

 