###########################################################################################
CREATE PROCEDURE prcDropDatabase 
	@dbName SYSNAME 
AS
	SET NOCOUNT ON 

	DECLARE @spid [INT] 

	SET @spid = ( SELECT [spid] FROM [master]..[sysprocesses] WHERE [dbid] = DB_ID( @dbName) AND [hostname] = HOST_NAME() AND [hostprocess] = HOST_ID())
	
	DECLARE @sql NVARCHAR(250)
	SET @sql = ' KILL ' + CAST( @spid AS NVARCHAR(250)) + 
	' DROP DATABASE ' + @dbName

	EXEC (@sql)

###########################################################################################
#END