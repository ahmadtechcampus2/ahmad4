#############################################################################
CREATE FUNCTION fnGetUserEntrySec(@UserGUID [UNIQUEIDENTIFIER], @Type AS [UNIQUEIDENTIFIER] = 0x0, @PermType [INT])
	RETURNS [INT]
AS BEGIN
	DECLARE @result [INT]
	
	IF ISNULL(@Type, 0x0) = 0x0
		SELECT @result = [dbo].[fnGetUserSec](@UserGUID, 0x10014000, 0x0, 1, @PermType)
	ELSE
		SET @result = [dbo].[fnGetUserSec](@UserGUID, 0x10016000, @Type, 1, @PermType)
		
	RETURN @result
END

#############################################################################
#END