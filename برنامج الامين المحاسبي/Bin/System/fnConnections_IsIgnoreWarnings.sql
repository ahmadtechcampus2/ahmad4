#########################################################
CREATE FUNCTION fnConnections_IsIgnoreWarnings()
	RETURNS [BIT]
AS BEGIN
/*
this function returns the ignore warnings state of current connection.
	0 - catch warnings
	1 - ignore warnings
*/
	RETURN (ISNULL( (SELECT [IgnoreWarnings] FROM [connections] WHERE [HostName] = HOST_NAME() AND [HostId] = HOST_ID()), 0))
END

#########################################################
#END