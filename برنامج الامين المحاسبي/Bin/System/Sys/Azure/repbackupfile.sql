#########################################################################
## Â–« «·≈Ã—«¡ Ì” œ⁄Ì  «»⁄ „⁄·Ê„«  „·› ‰”Œ… «Õ Ì«ÿÌ…
CREATE  PROC prcRestoreFromFile_HeaderOnly @BackupFileName [NVARCHAR](1024)
AS
	EXECUTE prcNotSupportedInAzure
####################################################################
## Â–« «·≈Ã—«¡ Ì” Œœ„ ·Ã·» «·„⁄·Ê„«  «·„Â„… ⁄‰ „·› «·‰”Œ… «·«Õ Ì«ÿÌ…
CREATE  PROC prcRestoreFromFile @BackupFileName [NVARCHAR](1024)
AS
	EXECUTE prcNotSupportedInAzure
####################################################################
## Â–« «·≈Ã—«¡ Ì” Œœ„ ·Ã·» «·„·›«  «·›Ì“Ì«∆Ì… ·ﬁ«⁄œ… «·»Ì«‰«  «·Õ«·Ì…
CREATE  PROC prcGetDataBaseFile
AS
	EXECUTE prcNotSupportedInAzure
##########################################################################
CREATE  PROC prcBackupFileList_ @BackupFileName [NVARCHAR](1024)
AS
	EXECUTE prcNotSupportedInAzure

####################################################################
## Â–« «·≈Ã—«¡ Ì” Œœ„ ·Ã·» √”„«¡ „·›«  «·‰”Œ… «·«Õ Ì«ÿÌ… 
CREATE  PROC prcGetBackupfileList @BackupFileName [NVARCHAR](1024)
AS
	EXECUTE prcNotSupportedInAzure
####################################################################
## Â–« «· «»⁄ Ì” œ⁄Ì  «»⁄ Ã„Ì⁄  ”ÃÌ·«  «·œŒÊ· ·ﬁÊ«⁄œ «·»Ì«‰« 
CREATE PROCEDURE repRestoreLogin_
AS
	SET NOCOUNT ON
	-- EXEC [sp_who]
	SELECT 
		-- [spid],
		[login_name] AS loginame,
		[host_process_id] as hostprocess,
		[host_name] as hostname,
		DB_NAME([database_id]) AS [dbName]
	FROM
		[sys].[dm_exec_sessions]

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
	EXECUTE prcNotSupportedInAzure
##########################################################################
#END