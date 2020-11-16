#########################################################
CREATE FUNCTION fnGetCurrentUserGUID()
	RETURNS [UNIQUEIDENTIFIER]
AS BEGIN
/*
This function:
- returns the current user GUID.
*/

	DECLARE @result [UNIQUEIDENTIFIER]
	SET @result = (SELECT TOP 1 [UserGUID] FROM [Connections] WHERE [HostName] = HOST_NAME() AND [HostId] = HOST_ID())
	RETURN ISNULL(@result, 0x0)
END

#########################################################
#END