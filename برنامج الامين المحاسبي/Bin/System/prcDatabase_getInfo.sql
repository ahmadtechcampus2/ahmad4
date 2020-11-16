#########################################################
CREATE PROC prcDatabase_getInfo
AS
	SET NOCOUNT ON 
	
	DECLARE @t TABLE (
		[rowNumber] [INT] IDENTITY(1, 1),
		[data] [NVARCHAR](1024) COLLATE ARABIC_CI_AI,
		[value] [NVARCHAR](255) COLLATE ARABIC_CI_AI NOT NULL DEFAULT '',
		[tabCount] [INT] NOT NULL DEFAULT 0)
	DECLARE
		@dbname [NVARCHAR](128),
		@language [INT]
	SET @dbName = db_name()
	SET @language = [dbo].[fnConnections_getLanguage]()
	-- insert database name:
	INSERT INTO @t ([data], [value]) SELECT [dbo].[fnStrings_get]('DBINFO\DBNAME', @language), @dbName
	-- insert total size:
	INSERT INTO @t ([data], [value]) SELECT [dbo].[fnStrings_get]('DBINFO\DBSIZE', @language), CAST(CAST((SELECT SUM([size]) * 8.0 / 1024.0 FROM [sysfiles]) AS [DECIMAL](12, 2)) AS [NVARCHAR](50)) + ' [mb]'
	-- insert file info:
	INSERT INTO @t ([data]) SELECT [dbo].[fnStrings_get]('DBINFO\FILES', @language)
 	INSERT INTO @t ([data], [value], [tabCount]) SELECT RTRIM([filename]), CAST([size] * 8 AS [NVARCHAR](255)) + ' [kb]', 1 FROM [sysfiles] ORDER BY [fileid]
	-- insert creation date:
 	INSERT INTO @t ([data], [value]) SELECT [dbo].[fnStrings_get]('DBINFO\FILES\CREATIONDATE', @language), [create_date] FROM [sys].[databases] WHERE [name] = @dbName
	-- insert amndbversion:
 	INSERT INTO @t ([data], [value]) SELECT [dbo].[fnStrings_get]('DBINFO\FILES\VERSION', @language), CAST([value] AS [NVARCHAR](128)) FROM [dbo].[fnListExtProp]( 'amnDBVersion') 
	-- insert last backup info:
	INSERT INTO @t ([data]) SELECT [dbo].[fnStrings_get]('DBINFO\BACKUPINFO', @language)
	IF EXISTS(SELECT * FROM [msdb]..[backupset] WHERE [database_name] = @dbname)
	BEGIN
		DECLARE @div [INT]
		SET @div = ISNULL(DATEDIFF([d], (SELECT TOP 1 [backup_finish_date] FROM [msdb]..[backupset] WHERE [database_name] = @dbname ORDER BY [backup_finish_date] DESC), GETDATE()), 0)
		IF @div = 0
	 		INSERT INTO @t ([data], [value], [tabCount]) SELECT TOP 1 [dbo].[fnStrings_get]('DBINFO\BACKUPINFO\LASTBACKUPDATE', @language), CAST([backup_finish_date] AS [NVARCHAR](128)) + [dbo].[fnStrings_get]('DBINFO\BACKUPINFO\INTHISDAY', @language), 1 FROM [msdb]..[backupset] WHERE [database_name] = @dbname ORDER BY [backup_finish_date] DESC
	 	ELSE
	 		INSERT INTO @t ([data], [value], [tabCount]) SELECT TOP 1 [dbo].[fnStrings_get]('DBINFO\BACKUPINFO\LASTBACKUPDATE', @language), CAST([backup_finish_date] AS [NVARCHAR](128)) + [dbo].[fnStrings_get]('DBINFO\BACKUPINFO\FROM', @language) + CAST(@div AS [NVARCHAR](7)) + [dbo].[fnStrings_get]('DBINFO\BACKUPINFO\DAY', @language), 1 FROM [msdb]..[backupset] WHERE [database_name] = @dbname ORDER BY [backup_finish_date] DESC
	 	
	 	INSERT INTO @t ([data], [value], [tabCount]) SELECT TOP 1 [dbo].[fnStrings_get]('DBINFO\BACKUPINFO\FROMTHISPC', @language), [machine_name], 1 FROM [msdb]..[backupset] WHERE [database_name] = @dbname ORDER BY [backup_finish_date] DESC
		INSERT INTO @t ([data], [value], [tabCount]) SELECT TOP 1 [dbo].[fnStrings_get]('DBINFO\BACKUPINFO\TOFILE', @language), [physical_device_name], 1	FROM [msdb]..[backupmediafamily] WHERE [media_set_id] = (SELECT TOP 1 [media_set_id] FROM [msdb]..[backupset] WHERE [database_name] = @dbname ORDER BY [backup_finish_date] DESC)
	END ELSE
	 	INSERT INTO @t ([data], [value], [tabCount]) SELECT [dbo].[fnStrings_get]('DBINFO\BACKUPINFO\NONE', @language), '', 1
	-- inset more details section:
	INSERT INTO @t (data) SELECT dbo.fnStrings_get('DBINFO\DETAILS', @language)
	-- insert recursive triggers
	-- insert recovery model
 	INSERT INTO @t ([data], [value], [tabCount]) SELECT [dbo].[fnStrings_get]('DBINFO\DETAILS\RECOVERYMODEL', @language), CAST(DATABASEPROPERTYEX(@dbname , 'Recovery' ) AS [NVARCHAR](128)), 1
	-- insert collation
 	INSERT INTO @t ([data], [value], [tabCount]) SELECT [dbo].[fnStrings_get]('DBINFO\DETAILS\DEFAULTLANGUAGE', @language), CAST(DATABASEPROPERTYEX(@dbname, 'Collation') AS [NVARCHAR](128)), 1
	IF databaseproperty(@dbname, 'IsSingleUser') = 1
	 	INSERT INTO @t ([data], [value], [tabCount]) SELECT [dbo].[fnStrings_get]('DBINFO\DETAILS\SINGLEUSERMODE', @language), [dbo].[fnStrings_get]('MISC\YES', @language), 1
	ELSE
	 	INSERT INTO @t ([data], [value], [tabCount]) SELECT [dbo].[fnStrings_get]('DBINFO\DETAILS\SINGLEUSERMODE', @language), [dbo].[fnStrings_get]('MISC\NO', @language), 1
	-- insert auto-shrink:
	IF databaseproperty(@dbname, 'IsAutoShrink') = 1
	 	INSERT INTO @t ([data], [value], [tabCount]) SELECT [dbo].[fnStrings_get]('DBINFO\DETAILS\ISAUTOSHRINK', @language), [dbo].[fnStrings_get]('MISC\YES', @language), 1
	ELSE
	 	INSERT INTO @t ([data], [value], [tabCount]) SELECT [dbo].[fnStrings_get]('DBINFO\DETAILS\ISAUTOSHRINK', @language), [dbo].[fnStrings_get]('MISC\NO', @language), 1
	-- insert recursive triggers
	IF databaseproperty(@dbname, 'IsRecursiveTriggersEnabled') = 1
	 	INSERT INTO @t ([data], [value], [tabCount]) SELECT [dbo].[fnStrings_get]('DBINFO\DETAILS\RECURSIVETRIGGERS', @language), [dbo].[fnStrings_get]('MISC\YES', @language), 1
	ELSE
	 	INSERT INTO @t ([data], [value], [tabCount]) SELECT [dbo].[fnStrings_get]('DBINFO\DETAILS\RECURSIVETRIGGERS', @language), [dbo].[fnStrings_get]('MISC\NO', @language), 1
	SELECT [data], [value], [tabCount] FROM @t ORDER BY [rowNumber]
#########################################################
#END