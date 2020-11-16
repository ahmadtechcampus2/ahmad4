##################################
CREATE PROCEDURE prcConnectToServer
	@ServerName		NVARCHAR(256)
AS
	DECLARE @IsServerLinked INT
	SET @IsServerLinked = 0
	SELECT @IsServerLinked = COUNT(*) FROM master..SysServers WHERE srvName = @ServerName
	IF @IsServerLinked = 0
	BEGIN
		EXEC sp_AddLinkedServer @ServerName
	END
/*

prcConnectToServer 'ziadpc'
SELECT * FROM master..SysServers
SELECT * FROM eyad.master..SysServers

*/ 
##################################
#END