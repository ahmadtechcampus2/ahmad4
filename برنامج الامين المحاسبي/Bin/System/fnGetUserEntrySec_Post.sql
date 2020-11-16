#############################################################################
CREATE FUNCTION fnGetUserEntrySec_Post(@UserGUID [UNIQUEIDENTIFIER], @EntryType AS [UNIQUEIDENTIFIER] = 0x0)
	RETURNS [INT]
AS BEGIN
	RETURN [dbo].[fnGetUserEntrySec](@UserGUID, @EntryType, 4) -- fnGetUserModifySec fnGetUserPostEntrySec fnGetUserPostSec
END

#############################################################################
#END