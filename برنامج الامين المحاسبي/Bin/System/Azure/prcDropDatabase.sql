###########################################################################################
CREATE PROCEDURE prcDropDatabase 
	@dbName SYSNAME 
AS
	SET NOCOUNT ON 
	DECLARE @spid [INT] 
	SET @spid = ( SELECT [session_id] FROM [sys].[dm_exec_sessions] WHERE [database_id] = DB_ID( @dbName) AND [host_name] = HOST_NAME() AND [host_process_id] = HOST_ID())
	
	DECLARE @sql NVARCHAR(250)

	SET @sql = 'KILL ' + CAST( @spid AS NVARCHAR(250))
	EXEC (@sql)

	SET @sql = 'DROP DATABASE ' + @dbName
	EXEC (@sql)


###########################################################################################
#END