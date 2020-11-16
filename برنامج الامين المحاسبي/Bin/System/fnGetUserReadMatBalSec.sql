##########################################################
CREATE FUNCTION fnGetUserReadMatBalSec ( @UserGUID AS [UNIQUEIDENTIFIER])
RETURNS [INT]
AS
BEGIN
	RETURN [dbo].[fnGetUserSec]( @UserGUID, 17, 0x0, 1, 0)
END

/*
select dbo.fnGetUserReadMatBalSec (0x0)
*/
##########################################################
#END