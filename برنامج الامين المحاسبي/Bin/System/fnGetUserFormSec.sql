###########################################################################
CREATE FUNCTION fnGetUserFormSec
(
	@UserGUID [UNIQUEIDENTIFIER], 
	@PermType [INT]
)
RETURNS [INT] 
AS BEGIN 
	DECLARE 
		@RID_FORMCARD AS [INT]
	SET @RID_FORMCARD = 0x20002080
	RETURN [dbo].[fnGetUserSec](@UserGUID, @RID_FORMCARD, 0x0, 1, @PermType) 
END 
###########################################################################
CREATE FUNCTION fnGetUserManufBrowswSec
(
	@UserGUID [UNIQUEIDENTIFIER], 
	@PermType [INT]
)
RETURNS [INT] 
AS BEGIN 
	DECLARE 
		@RID_MANUFACTURE AS [INT]
	SET @RID_MANUFACTURE = 0x20002040
	RETURN [dbo].[fnGetUserSec](@UserGUID, @RID_MANUFACTURE, 0x0, 1, @PermType) 
END 
###########################################################################
#END