###############################################################################
CREATE PROC prcDatabase_ReplaceGuids
AS 
/* 
this procedure 
	- assume the presence of #guids table with following structure: 
		CREATE TABLE #GUID(oldGuid UNIQUEIDENTIFIER, newGuid UNIQUEIDENTIFIER) 
	- depending on #guids, it updates the oldGuid to newGuid where found in each uniqueidentifier column in all db tables. 
*/ 
	IF [dbo].[fnObjectExists]('#Guid') = 0 
	BEGIN 
		RAISERROR ('redundant table: #Guid not found ... execution cannot proceed unless table is provided.', 16, 1) 
		RETURN 
	END 
	DECLARE 
		@c_tables CURSOR, 
		@table [NVARCHAR](128), 
		@field [NVARCHAR](128), 
		@SQL [NVARCHAR](2000) 
	SET @c_tables = CURSOR FAST_FORWARD FOR 
						SELECT [t].[name], [c].[name] 
						FROM [sysobjects] [t] INNER JOIN [syscolumns] [c] ON [t].[id] = [c].[id] WHERE [t].[xtype] = 'U' AND [c].[xtype] = 36 
						ORDER BY [t].[id] 
	OPEN @c_tables FETCH FROM @c_tables INTO @table, @field 
	WHILE @@FETCH_STATUS = 0 
	BEGIN 
		SET @SQL = ' 
			ALTER TABLE %0 DISABLE TRIGGER ALL 
			UPDATE %0 SET %1 = [g].[newGuid] FROM %0 AS [x] INNER JOIN [#guid] AS [g] ON [x].%1 = [g].[oldGuid] 
			ALTER TABLE %0 ENABLE TRIGGER ALL' 
		EXEC [prcExecuteSQL] @SQL, @table, @field 
		FETCH FROM @c_tables INTO @table, @field 
	END 

	CLOSE @c_tables DEALLOCATE @c_tables 


###############################################################################
#END