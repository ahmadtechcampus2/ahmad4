##################################################################################
CREATE PROCEDURE prcConnections_SetExclusive
	@Mode [BIT] = 1 -- to set exclusive mode, 0 to end the mode.
AS
/*
This procedure:
	- set the exclusive flag for current spid, if possible.
	- returns 1 if succesfull, 0 if not.
*/
	-- SET XACT_ABORT ON

	SET NOCOUNT ON
	
	EXEC [prcConnections_Clean]

	IF @Mode = 0
		UPDATE [Connections] SET [Exclusive] = 0 -- WHERE SPID = @@SPID
	ELSE BEGIN
		IF EXISTS (SELECT * FROM [Connections] WHERE [Exclusive] = 1 AND [HostName] = HOST_NAME() AND [HostId] = HOST_ID())
			RETURN 1
		ELSE IF NOT EXISTS (SELECT * FROM [Connections] WHERE [Exclusive] = 1)
		BEGIN
			UPDATE [Connections] SET [Exclusive] = 1 WHERE [HostName] = HOST_NAME() AND [HostId] = HOST_ID()
			RETURN 1
		END
	END
	RETURN 0

##################################################################################
#END