#########################################################################
## Â–« «·≈Ã—«¡ Ì” œ⁄Ì  «»⁄ „⁄·Ê„«  „·› ‰”Œ… «Õ Ì«ÿÌ…
CREATE  PROC prcRestoreFromFile_HeaderOnly @BackupFileName [NVARCHAR](1024)
AS
	SET NOCOUNT ON
	RESTORE HEADERONLY FROM disk = @BackupFileName
####################################################################
## Â–« «·≈Ã—«¡ Ì” Œœ„ ·Ã·» «·„⁄·Ê„«  «·„Â„… ⁄‰ „·› «·‰”Œ… «·«Õ Ì«ÿÌ…
CREATE  PROC prcRestoreFromFile @BackupFileName [NVARCHAR](1024)
AS
	SET NOCOUNT ON
	CREATE TABLE [#tmp]
	(
		[Name] [NVARCHAR](256) COLLATE ARABIC_CI_AI,
		[Description] [NVARCHAR](256) COLLATE ARABIC_CI_AI,
		[BackupType] [INT],
		[ExpirationDate] [DATETIME],
		[Compressed] [INT],
		[Position] [INT],
		[DeviceType] [INT],
		[UserName] [NVARCHAR](128) COLLATE ARABIC_CI_AI,
		[ServerName] [NVARCHAR](128) COLLATE ARABIC_CI_AI,
		[databaseName] [NVARCHAR](128) COLLATE ARABIC_CI_AI,
		[DatabaseVersion] [INT],
		[DatabaseCreationDate] [DATETIME],
		[BackupSize] [DEC](20,0),
		[FirstLsn] [DEC](25,0),
		[LastLsn] [DEC](25,0),
		[CheckPointLsn] [DEC](25,0),
		[DatabaseBackupLSN] [DEC](25,0),
		[BackupStartDate] [DATETIME],
		[BackupFinishDate] [DATETIME],
		[SortOrder] [INT],
		[CodePage] [INT],
		[UnicodeLocaleID] [INT],
		[UnicodeComarisonStyle] [INT],
		[CompatibilityLevel] [INT],
		[SoftwareVendorID] [INT],
		[SoftwareVersionMajor] [INT],
		[SoftwareVersionMinor] [INT],
		[SoftwareVersionBuild] [INT],
		[MachineName] [NVARCHAR](128) COLLATE ARABIC_CI_AI,
		[Flags] [INT],
		[BindingID] [UNIQUEIDENTIFIER],
		[RecoveryForkID] [UNIQUEIDENTIFIER],
		[Collation] [NVARCHAR](256) COLLATE ARABIC_CI_AI
	)

	IF [dbo].[fnIsSQL2005]() = 1 
	BEGIN 
		ALTER TABLE [#tmp]
		ADD 
			[FamilyGUID] [UNIQUEIDENTIFIER],
			[HasBulkLoggedData] [BIT],
			[IsSnapshot] [BIT],
			[IsReadOnly] [BIT],
			[IsSingleUser] [BIT],
			[HasBackupChecksums] [BIT],
			[IsDamaged] [BIT],
			[BeginsLogChain] [BIT],
			[HasIncompleteMetaData] [BIT],
			[IsForceOffline] [BIT],
			[IsCopyOnly] [BIT],
			[FirstRecoveryForkID] [UNIQUEIDENTIFIER],
			[ForkPointLSN] [DEC](25,0),
			[RecoveryModel] [NVARCHAR](60) COLLATE ARABIC_CI_AI, 
			[DifferentialBaseLSN] [DEC](25,0),
			[DifferentialBaseGUID] [UNIQUEIDENTIFIER],
			[BackupTypeDescription] [NVARCHAR](60) COLLATE ARABIC_CI_AI, 
			[BackupSetGUID] [UNIQUEIDENTIFIER]
 	END 
 	IF [dbo].[fnIsSQL2008]() = 1 
	BEGIN 
		ALTER TABLE [#tmp]
		ADD 
		 	[CompressedBackupSize] [BIGINT]
	END

 	IF [dbo].[fnIsSQL2012]() = 1 
	BEGIN 
		ALTER TABLE [#tmp]
		ADD 
		 	[containment] TINYINT NULL
	END

	IF [dbo].[fnIsSQL2016]() = 1 OR dbo.fnIsSQL2014SP1() = 1
	BEGIN 
		ALTER TABLE [#tmp]
		ADD 
		 	[KeyAlgorithm] [NVARCHAR] (32),
			[EncryptorThumbprint] [VARBINARY] (20),
			[EncryptorType] [NVARCHAR] (32)
	END

	INSERT INTO [#tmp] EXEC [prcRestoreFromFile_HeaderOnly] @BackupFileName

	SELECT
		[databaseName] AS [Name],
		[Description],
		[BackupStartDate] AS [Date],
		[Position]
	FROM
		[#tmp]

####################################################################
## Â–« «·≈Ã—«¡ Ì” Œœ„ ·Ã·» «·„·›«  «·›Ì“Ì«∆Ì… ·ﬁ«⁄œ… «·»Ì«‰«  «·Õ«·Ì…
CREATE  PROC prcGetDataBaseFile
AS
	SET NOCOUNT ON
	CREATE TABLE [#tmp]
	(
		[Name] [NVARCHAR](128)  COLLATE ARABIC_CI_AI,
		[FileId] [INT],
		[FileName] [NVARCHAR](260)  COLLATE ARABIC_CI_AI,
		[Filegroup] [NVARCHAR](128)  COLLATE ARABIC_CI_AI,
		[size] [NVARCHAR](18) COLLATE ARABIC_CI_AI,
		[MaxSize] [NVARCHAR](18) COLLATE ARABIC_CI_AI,
		[Growth] [NVARCHAR](18) COLLATE ARABIC_CI_AI,
		[usage] [NVARCHAR](9) COLLATE ARABIC_CI_AI
	)


	INSERT INTO [#tmp] EXEC [sp_HelpFile]

	SET NOCOUNT OFF
	SELECT
		[FileName] AS [Name],
		[FileId] AS [fId]
	FROM
		[#tmp]

##########################################################################
CREATE  PROC prcBackupFileList_ @BackupFileName [NVARCHAR](1024)
AS
	SET NOCOUNT ON
	RESTORE FILELISTONLY FROM disk = @BackupFileName

####################################################################
## Â–« «·≈Ã—«¡ Ì” Œœ„ ·Ã·» √”„«¡ „·›«  «·‰”Œ… «·«Õ Ì«ÿÌ… 
CREATE  PROC prcGetBackupfileList @BackupFileName [NVARCHAR](1024)
AS
	SET NOCOUNT ON
	CREATE TABLE [#tmp]
	(
		[LogicalName] [NVARCHAR](128)  COLLATE ARABIC_CI_AI,
		[PhysicalName] [NVARCHAR](260)  COLLATE ARABIC_CI_AI,
		[Type] [NCHAR](1),
		[FileGroupName] [NVARCHAR](128)  COLLATE ARABIC_CI_AI,
		[Size] [DEC](20,0),
		[MaxSize] [DEC](20,0)
	)

	IF [dbo].[fnIsSQL2005]() = 1
	BEGIN 
		ALTER TABLE [#tmp] ADD 
			[FileID] [BIGINT], 
			[CreateLSN] [DEC](25,0) NULL, 
			[DropLSN] [DEC](25,0) NULL,
			[UniqueID] [UNIQUEIDENTIFIER],
			[ReadOnlyLSN] [DEC](25,0) NULL,
			[ReadWriteLSN] [DEC](25,0) NULL,
			[BackupSizeInBytes] [BIGINT], 
			[SourceBlockSize] [INT],
			[FileGroupID] [INT],
			[LogGroupGUID] [UNIQUEIDENTIFIER],
			[DifferentialBaseLSN] [DEC](25,0) NULL,
			[DifferentialBaseGUID] [UNIQUEIDENTIFIER],
			[IsReadOnly] [BIT],
			[IsPresent][BIT]
	END 
	IF [dbo].[fnIsSQL2008]() = 1
	BEGIN
		ALTER TABLE [#tmp] ADD [TDEThumbprint] VARBINARY(32) NULL
 	END
	

	INSERT INTO [#tmp] EXEC [prcBackupFileList_] @BackupFileName

	SELECT
		[LogicalName] AS [Name]
	FROM
		[#tmp]

####################################################################
## Â–« «· «»⁄ Ì” œ⁄Ì  «»⁄ Ã„Ì⁄  ”ÃÌ·«  «·œŒÊ· ·ﬁÊ«⁄œ «·»Ì«‰« 
CREATE PROCEDURE repRestoreLogin_
AS
	SET NOCOUNT ON
	-- EXEC [sp_who]
	SELECT 
		-- [spid],
		[loginame],
		[hostprocess],
		[hostname],
		DB_NAME([dbid]) AS [dbName]
	FROM
		[master]..[sysprocesses]	

####################################################################
## Â–« «· «»⁄ „‰ √Ã· „⁄—›… «·„” Œœ„Ì‰ ·ﬁ«⁄œ… «·»Ì«‰«  «·Õ«·Ì… ⁄œ« «·„” Œœ„ «·Õ«·Ì
CREATE PROCEDURE repRestoreLogin @DBName [NVARCHAR](128)
AS
	SET NOCOUNT ON
	CREATE TABLE [#tmp]
	(
		-- [spid] [smallint],
		-- [ecid] [smallint],
		-- [status] [NVARCHAR]( 30) COLLATE ARABIC_CI_AI,
		[Loginame] [NVARCHAR](128) COLLATE ARABIC_CI_AI,
		[hostId] [NVARCHAR](128) COLLATE ARABIC_CI_AI,
		[hostname] [NVARCHAR](128) COLLATE ARABIC_CI_AI,
		-- [blk] [CHAR](5) COLLATE ARABIC_CI_AI,
		[dbname] [NVARCHAR](128) COLLATE ARABIC_CI_AI
		-- [cmd] [NVARCHAR](16) COLLATE ARABIC_CI_AI
	)
	INSERT INTO [#tmp] EXEC [repRestoreLogin_]

	SELECT [Loginame] AS [NAME]
	FROM [#tmp]
	WHERE
		[dbname] = @DBName AND
		[hostId] <> Host_Id() AND [hostname] <> Host_Name() 
####################################################################
## Â–« «· «»⁄ ÌﬁÊ„ »Õ–› „·› ‰”Œ… «Õ Ì«ÿÌ… „⁄  «—ÌŒÂ
CREATE PROCEDURE DeleteBackupFile @FileName [NVARCHAR](1000) 
AS 
	SET NOCOUNT ON
	DECLARE @DeviceStr [NVARCHAR](125) 
	SET @DeviceStr = 'AMN' + CAST( NEWID() AS [NVARCHAR](100)) 
	EXECUTE sp_Addumpdevice 'disk', @DeviceStr, @FileName, 2 
			 
	EXECUTE [sp_dropdevice] @DeviceStr, 'delfile' 
	IF( @@ERROR <> 0) 
		RETURN -1 
	DECLARE @MediaId [INT] 
	SELECT @MediaId  = [media_set_id] 
		FROM [msdb]..[backupmediafamily]  
		WHERE [physical_device_name] = @FileName 
	Print @MediaId  
	IF( @MediaId IS NULL) 
		RETURN 0 
	BEGIN TRANSACTION 
	DELETE FROM [msdb]..[backupfile]
		WHERE [backup_set_id] IN 
			 ( SELECT [backup_set_id] FROM [msdb]..[backupset] AS [BS]  
					WHERE [BS].[media_set_id] = @MediaId) 
	DELETE FROM [msdb]..[backupmediafamily] WHERE [media_set_id] = @MediaId 
		 
	DELETE FROM [msdb]..[restorefile] 
		WHERE [restore_history_id] IN 
			 (SELECT [restore_history_id] FROM [msdb]..[restorehistory] AS [RH]  
					INNER JOIN [msdb]..[backupset] AS [BS] 
					ON  
						[RH].[Backup_set_id] = [BS].[Backup_set_id] 
					WHERE [BS].[media_set_id] = @MediaId) 
	DELETE FROM [msdb]..[restorefilegroup] -- 4 
		WHERE [restore_history_id] IN 
			 ( SELECT [restore_history_id] FROM [msdb]..[restorehistory] AS [RH]  
					INNER JOIN [msdb]..[backupset] AS [BS] 
					ON  
						[RH].[Backup_set_id] = [BS].[Backup_set_id] 
					WHERE [BS].[media_set_id] = @MediaId) 
	DELETE FROM [msdb]..[restorehistory] -- 5 
		WHERE [Backup_set_id] IN 
			(SELECT [Backup_set_id] FROM [msdb]..[backupset] AS [BS] 
					WHERE [BS].[media_set_id] = @MediaId) 

	IF [dbo].[fnIsSQL2005]() = 1 
	BEGIN 

		DELETE FROM [msdb]..[backupfilegroup] -- 6
			WHERE [Backup_set_id] IN  
				(SELECT [Backup_set_id] FROM [msdb]..[backupset] AS [BS]  
						WHERE [BS].[media_set_id] = @MediaId)  
	END 
	
	DELETE FROM [msdb]..[backupset] WHERE [media_set_id] = @MediaId -- 7
	DELETE FROM [msdb]..[backupmediaset] WHERE [media_set_id] = @MediaId -- 8

	COMMIT TRANSACTION 
##########################################################################
#END