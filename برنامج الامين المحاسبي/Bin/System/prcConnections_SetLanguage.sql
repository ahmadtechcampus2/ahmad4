##########################################################################################
CREATE PROCEDURE prcConnections_SetLanguage
	@Language [INT] = 0
AS
/*
this procedure changes the language of current connection.
	0 - arabic
	1 - english
*/
	SET NOCOUNT ON
	UPDATE [connections] SET [Language] = ISNULL(@Language, 0) WHERE [HostName] = HOST_NAME() AND [HostId] = HOST_ID()

##########################################################################################
#END