#########################################################
CREATE PROCEDURE prcDatabase_copyTo
	@newName [NVARCHAR](128),
	@override [bit] = 0
AS
/*
This procedure:
	- create a database called @newName by copying this db
	- can delete @newName database if exists when @override
*/
	declare
		@thisDB [NVARCHAR](128),
		@dbDir [NVARCHAR](255)
	set @thisDB = db_name()
	set @dbDir = (select left([fileName], len([fileName]) - len(@thisDB)- 4) from [sysfiles] where [groupid] = 1)
	if exists(select * from [master].[databases] where [name] = @newName)
	begin
		if @override = 0
		begin
			-- database exists and caller didn't override, so:
			raiserror ('AMNEXXX: can''t create database, "%s" already exists is system catalog', 16, 1, @newName)
			return
		end else if (select [dbo].[fnDatabase_inUse](@newName)) = 1
		begin
			-- database is in use and connot be drop right now:
			raiserror ('AMNEXXX: can''t create database, "%s" currently in use', 16, 1, @newName)
			return
		end else begin
			-- drop the database:
			exec [prcExecuteSQL] 'drop database %0', @newName
			if @@error != 0
				return
		end
	end
	exec [prcExecuteSQL] 'create database %0', @newName
	if @@error != 0
		return
	
	exec [prcExecuteSQL] 'backup database %0 to disk = ''%0.bak'' with init', @thisDB
	if @@error != 0
		return
	exec [prcExecuteSQL] 'restore database %0 from disk = ''%1.bak'' with move ''%1'' to ''%2%0.mdf'', move ''%1_log'' to ''%2%0_log.ldf'', replace', @newName, @thisDB, @dbDir
	if @@error != 0
		return
 
#########################################################
#end