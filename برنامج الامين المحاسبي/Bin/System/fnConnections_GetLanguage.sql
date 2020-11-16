#########################################################
CREATE FUNCTION fnConnections_GetLanguage()
	RETURNS [INT]
AS BEGIN
/*
this function returns the language of current connection.
	0 - arabic
	1 - english
*/
	RETURN (ISNULL( (SELECT [Language] FROM [connections] WHERE [HostName] = HOST_NAME() AND [HostId] = HOST_ID()), 0))
END

#########################################################
#END