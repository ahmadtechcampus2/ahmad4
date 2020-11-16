######################################################### 
CREATE FUNCTION fnDatabase_inUse(@dbName [NVARCHAR](128) = '')
	RETURNS [BIT]
AS BEGIN
/*
This function returns 1 if the database @dbName is used in connections other than the current one
*/

	DECLARE @result [BIT]

	if isnull(@dbName, '') = ''
		set @dbName = db_name()

	IF EXISTS(
		SELECT * FROM sys.dm_exec_sessions WHERE ([host_name] <> Host_Name()) OR (([host_name] = Host_Name()) AND ([host_process_id] <> Host_Id())))
		SET @result = 1
	ELSE
		SET @result = 0

	RETURN @result

END

#########################################################
#END