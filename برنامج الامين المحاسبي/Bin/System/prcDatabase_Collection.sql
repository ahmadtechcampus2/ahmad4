#########################################################
CREATE PROC prcDatabase_Collection
	@CollectionGUID [UNIQUEIDENTIFIER] = 0x0,
	@InCollectionOnly [BIT] = 0
AS
/*
this procedure:
	- is usually used in Multi-DB reporting layer, when dbc and dbcd tables are used.
r	- returns info about ameen databases available on the server
	- has two ways to function:
		1. DBCollection Preparation Mode:
			- when the caller needs to get data about all valid ameen dbs in order to setup a collection
			- this mode is available by ignoring the procedures' parameters, or by sending only CollectionGUID, where a collection edition is in progress.
		2. MDBR Execution Mode: (multiple database reports)
			- when the caller needs to get only databases boud to a specific collection
			- this mode is available by sending the CollectionGUID and specifiying InCollectionOnly
	- uses collectionGUID and InCollectionOnly to return only those dbs requested.
*/
	DECLARE
		@c CURSOR,
		@dbid [INT],
		@dbName [NVARCHAR](128),
		@currentDBVersion [NVARCHAR](128),
		@currentUserName [NVARCHAR](128),
		@currentUserPassword [NVARCHAR](250),
		@InCollection [BIT],
		@sql [NVARCHAR](2000)
	-- @collectionGUID and @InCollectionOnly should be used simultansiously:
	IF ISNULL(@collectionGUID, 0x0) <> 0x0 AND @InCollectionOnly <> 0
		SET @c = CURSOR FAST_FORWARD FOR 
		SELECT [d].[database_id], '[' + [d].[name] + ']' 
		FROM [sys].[databases] AS [d] INNER JOIN [dbcd] AS [c] ON [d].[database_id] = [c].[dbid] WHERE DATABASEPROPERTYEX([d].[name], 'Status') = 'ONLINE' AND [c].[parentGUID] = @collectionGUID
	ELSE
		SET @c = CURSOR FAST_FORWARD FOR SELECT [database_id], '[' + name + ']' FROM [sys].[databases] WHERE DATABASEPROPERTYEX([name], 'Status') = 'ONLINE'
	OPEN @c FETCH FROM @c INTO @dbid, @dbName
	
	-- create the result buffer
	CREATE TABLE [#databases](
		[GUID] [UNIQUEIDENTIFIER] DEFAULT 0x0,
		[dbid] [INT],
		[dbName] [NVARCHAR](128)	COLLATE ARABIC_CI_AI,
		[amnName] [NVARCHAR](128) COLLATE ARABIC_CI_AI,
		[FPDate] [NVARCHAR](50),
		[EPDate] [NVARCHAR](50),
		[VersionNeedsUpdating] [BIT] NOT NULL DEFAULT 0,
		[UserIsNotDefined] [BIT] NOT NULL DEFAULT 0,
		[PasswordError] [BIT] NULL DEFAULT 0,
		[ExcludeEntries] [BIT] NOT NULL DEFAULT 0,
		[ExcludeFPBills] [BIT] NOT NULL DEFAULT 0,
		[InCollection] [BIT] NOT NULL DEFAULT 0,
		[Order] [INT] NOT NULL DEFAULT 0
	)
	SET @currentDBVersion = (SELECT TOP 1 CAST([value] AS [NVARCHAR](128)) FROM dbo.fnListExtProp( 'amnDBVersion') )
	SET @currentUserName = [dbo].[fnGetCurrentUserName]()
	SET @currentUserPassword = [dbo].[fnGetCurrentUserPassword]()
	WHILE @@FETCH_STATUS = 0
	BEGIN
		-- the sql script should insert a record for each valid ameen database from the cursor. this validation is aquired 
		-- when the database has the 'AmnDBVersion' as a property only then the database is valid as an ameen db
		SET @SQL = '
			DECLARE 
				@amndbVersion [NVARCHAR](128), 
				@amndbName [NVARCHAR](128), 
				@FPDate [NVARCHAR](50), 
				@EPDate [NVARCHAR](50),
				@VersionNeedsUpdating [BIT],
				@UserIsNotDefined [BIT],
				@PasswordError [BIT] ' 
		SET @SQL = @SQL + '
			SET @amndbVersion = (SELECT TOP 1 CAST([value] AS [NVARCHAR](128)) FROM ' + @dbName + '[sys].[fn_listextendedproperty]( ''amnDBVersion'', NULL, NULL, NULL, NULL, NULL, NULL)) '
					
		SET @SQL = @SQL + '
			IF @amndbVersion IS NOT NULL AND ISNULL(@amndbVersion, '''') <= ''' + @currentDBVersion + '''
			BEGIN ' 
			SET @SQL = @SQL + '
				SET @amndbName = (SELECT TOP 1 CAST(VALUE AS [NVARCHAR](50)) FROM ' + @dbName + '[sys].[fn_listextendedproperty]( ''AmnDBName'', NULL, NULL, NULL, NULL, NULL, NULL)) '
			SET @SQL = @SQL + '
				IF NOT EXISTS(SELECT * FROM ' + @dbName + '..[sysobjects] WHERE [name] = ''op000'' AND [xtype] = ''U'')
					SET @amnDBVersion = 0
				ELSE BEGIN
					SET @FPDate = (SELECT TOP 1 [value] FROM ' + @dbName + '..[op000] WHERE [name] = ''AmnCfg_FPDate'')
					SET @EPDate = (SELECT TOP 1 [value] FROM ' + @dbName + '..[op000] WHERE [name] = ''AmnCfg_EPDate'')
				END
				SELECT
					@VersionNeedsUpdating = 0,
					@UserIsNotDefined = 0,
					@PasswordError = 0
				
				IF @amndbVersion < ''' + @currentDBVersion + '''
					SET @VersionNeedsUpdating = 1
				IF EXISTS(SELECT * FROM ' + @dbName + '..[sysobjects] WHERE [name] = ''us000'' AND [xtype] = ''U'')
				BEGIN
					IF NOT EXISTS(SELECT * FROM ' + @dbName + '..[us000] WHERE [loginName] = ''' + @currentUserName + ''')
						SET @UserIsNotDefined = 1						
					IF @UserIsNotDefined = 1 OR NOT EXISTS(SELECT * FROM ' + @dbName + '..[us000] WHERE [loginName] = ''' + @currentUserName + ''' AND [Password] = ''' + @currentUserPassword + ''')
						SET @PasswordError = 1
				END
				INSERT INTO [#Databases]([dbid], [dbName], [amnName], [FPDate], [EPDate], [VersionNeedsUpdating], [UserIsNotDefined], [PasswordError]) VALUES(' + CAST(@dbid AS [NVARCHAR](7)) + ', ''' + @dbName + ''', @amndbName, @FPDate, @EPDate, @VersionNeedsUpdating, @UserIsNotDefined, @PasswordError)
	
			END'
		EXEC (@SQL)
		FETCH FROM @c INTO @dbid, @dbName
	END
	
	CLOSE @c DEALLOCATE @c
	IF @CollectionGUID <> 0x0
		UPDATE [#databases] SET	
				[GUID] = [c].[GUID],
				[InCollection] = 1,
				[ExcludeEntries] = [c].[ExcludeEntries],
				[ExcludeFPBills] = [c].[ExcludeFPBills],
				[Order] = [c].[Order]
			FROM [#databases] AS [d] INNER JOIN [dbcd] AS [c] ON [d].[dbid] = [c].[dbid]
			WHERE [c].[parentGUID] = @CollectionGUID
	-- return result:
	SELECT
		[GUID],
		[dbid],
		[dbName],
		[amnName],
		[dbo].[fnDate_Amn2Sql]([FPDate]) AS [FPDate],
		[dbo].[fnDate_Amn2Sql]([EPDate]) AS [EPDate],
		[ExcludeEntries],
		[ExcludeFPBills],
		[InCollection],
		[VersionNeedsUpdating],
		[UserIsNotDefined],
		[PasswordError],
		[Order]
	FROM 
		[#databases]
	ORDER BY 
		[order]
	-- drop temp table:
	DROP TABLE [#databases]

#########################################################
#END