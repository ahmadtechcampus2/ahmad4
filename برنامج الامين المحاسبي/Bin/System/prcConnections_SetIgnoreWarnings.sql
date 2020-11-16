##########################################################################################
CREATE PROCEDURE prcConnections_SetIgnoreWarnings
	@IsIgnoreWarnings [BIT] = 0
AS
/*
this procedure changes the ignore warnings of current connection.
If the IgnoreWarnings's value is 1, this help for scripts that executed by SQL Agent job to not marked the job as not successed if warnings are catched.
	0 - catch warnings
	1 - ignore warnings
*/
	SET NOCOUNT ON
	UPDATE [connections] SET [IgnoreWarnings] = ISNULL(@IsIgnoreWarnings, 0) WHERE [HostName] = HOST_NAME() AND [HostId] = HOST_ID()

##########################################################################################
#END