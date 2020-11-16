#######################################################
CREATE PROCEDURE prcGetNoneAmeenDataBase
AS
	SET NOCOUNT ON
	
	SELECT '[' + Name + ']' AS [dbName] FROM [sys].[databases] WHERE [Name] NOT IN ( 'master', 'tempdb', 'model', 'msdb', 'AmnConfig')
	RETURN

	DECLARE @s [NVARCHAR](2000)
	DECLARE
		@c CURSOR,
		@dbid [INT],
		@dbName [NVARCHAR](128)

	-- @collectionGUID and @InCollectionOnly should be used simultansiously:
	SET @c = CURSOR FAST_FORWARD FOR SELECT [database_id], '[' + name + ']' FROM [sys].[databases] WHERE DATABASEPROPERTYEX([name], 'Status') = 'ONLINE' AND has_dbaccess([name]) = 1

	OPEN @c FETCH FROM @c INTO @dbid, @dbName
	
	CREATE TABLE [#t]
	(
		[dbName]	[NVARCHAR](256) COLLATE ARABIC_CI_AI
	)
	
	WHILE @@FETCH_STATUS = 0
	BEGIN
		-- the sql script should insert a record for each valid ameen database from the cursor. this validation is aquired 
		-- when the database has the 'AmnDBVersion' as a property only then the database is valid as an ameen db
		IF @dbName NOT IN ( '[master]', '[tempdb]', '[model]', '[msdb]')
		BEGIN
			SET @s = ' 
				DECLARE @Cnt [INTEGER] '

			IF dbo.fnIsSQL2005() <> 1
				SET @s  = @s + '
				SELECT @Cnt = COUNT(*) from ' + @dbName + '..[sysProperties] WHERE [NAME] = ''AmnDBVersion'''
			ELSE 
				SET @s  = @s + '
				SELECT @Cnt = COUNT(*) from ' + @dbName + '[sys].[fn_listextendedproperty]( ''AmnDBVersion'', NULL, NULL, NULL, NULL, NULL, NULL))'

			SET @s = @s + ' IF @Cnt < 1 
					INSERT INTO [#t] ([dbName]) VALUES (''' + @dbName +''')'
			print @s
			EXEC ( @s)
		END
		FETCH FROM @c INTO @dbid, @dbName
	END
	
	CLOSE @c DEALLOCATE @c

	-- return result:
	SELECT
		[dbName]
	FROM 
		[#t]

	-- drop temp table:
	DROP TABLE [#t]
##########################################################
#END