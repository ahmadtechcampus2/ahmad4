##########################################################
## ≈÷«›… „Â„… ‰”Œ «Õ Ì«ÿÌ
## -------------------------------------------------------
## Edited by: Eyad al-akhras (16:30 11/02/2002)
##########################################################
create Procedure RepAddBackupJob
	@JobName [NVARCHAR](256),
	@JobType [int],
	@JobTime [int],
	@Jobday [int],
	@JobStartDate [int],
	@DBName [NVARCHAR](256),
	@Dir [NVARCHAR](256),
	@BkNum [INT],
	@Occurance		[INT]= 1   , --1 Once Only, 2 Every 
	@HoursNumber [INT] = 1--Number of hours   
As
SET NOCOUNT ON
DECLARE @Command [NVARCHAR]( 255)
SELECT @Command = 'Execute [RepDoBackupJob] @JobType = '+ 
					CAST(@JobType AS [NChar](10))+ 
						', @DBName = '''+  @DBName 
						+  ''', @DirName = ''' + @Dir 
						+  ''', @BkNum = ' +CAST(@BkNum AS [NVARCHAR](10)) 
EXEC [dbo].[prcAddJob] 	@JobName, @JobType, @JobTime, @Jobday, @JobStartDate, @DBName, @Command,@Occurance,@HoursNumber  
###########################################################
## ⁄„· ‰”Œ… «Õ Ì«ÿÌ… „‰ ﬁ»· „Â„…
CREATE PROCEDURE repDoBackupJob
	@JobType [int],
	@DBName [NVARCHAR](256),
	@DirName [NVARCHAR](1000),
	@BkNum [INT],
	@SaveTimeToFileName BIT = 0
As
SET NOCOUNT ON
	DECLARE 
		@DateStr [NVARCHAR](20),
		@DayStr [NVARCHAR](8),
		@MonthStr [NVARCHAR](8),
		@TimeStr [NVARCHAR](20),
		@FileName [NVARCHAR](1000)

	SET @TimeStr = ''
	IF @SaveTimeToFileName = 1
	BEGIN
		DECLARE @part INT 

		SET @part = DATEPART(hour, GetDate())
		IF (@part > 9)
			SELECT @TimeStr = CAST(@part AS [NVARCHAR](5)) 
		ELSE
			SELECT @TimeStr = '0' + CAST(@part AS [NVARCHAR](5)) 

		SET @part = DATEPART(minute, GetDate())
		IF (@part > 9)
			SELECT @TimeStr = @TimeStr + CAST(@part AS [NVARCHAR](5)) 
		ELSE
			SELECT @TimeStr = @TimeStr + '0' + CAST(@part AS [NVARCHAR](5)) 
	 
		SET @part = DATEPART(second, GetDate())
		IF (@part > 9)
			SELECT @TimeStr = @TimeStr + CAST(@part AS [NVARCHAR](5)) 
		ELSE
			SELECT @TimeStr = @TimeStr + '0' + CAST(@part AS [NVARCHAR](5)) 
		SET @TimeStr = '-' + @TimeStr
	END 

	IF (Month( GetDate()) > 9)
	SELECT @MonthStr = CAST( Month( GetDate()) AS [NVARCHAR](5)) 
ELSE
	SELECT @MonthStr = '0' + CAST( Month( GetDate()) AS [NVARCHAR](5)) 

		IF (DAY( GetDate()) > 9)
	SELECT @DayStr = CAST( DAY( GetDate()) AS [NVARCHAR](5)) 
ELSE
	SELECT @DayStr = '0' + CAST( DAY( GetDate()) AS [NVARCHAR](5)) 

SELECT @DateStr =  CAST( YEAR( GetDate()) AS [NVARCHAR](10)) +
							  @MonthStr + @DayStr + @TimeStr + '.dat'

SELECT @FileName =
			CASE @JobType
				WHEN 16 THEN @DirName + '\AMJB_' + @DBName + '_' +  @DateStr
				WHEN 8 THEN @DirName + '\AWJB_'+ @DBName + '_' +  @DateStr
				ELSE @DirName + '\ADJB_'+ @DBName + '_' +  @DateStr
			END

	IF( EXISTS( SELECT * FROM
	[msdb].[dbo].[BackupMediaFamily] as [bmf]
	INNER JOIN
	[msdb].[dbo].[BackupSet] as [bs]
	on
	[bs].[Media_Set_id] = [bmf].[Media_Set_id]
	WHERE [bs].[database_name] = @DbName
	AND [bmf].[physical_Device_name] = @FileName))
		RETURN 0
		--Backup DataBase @DBName To Disk = @FileName
			--with DIFFERENTIAL
	ELSE
		BACKUP DATABASE @DBName TO DISK = @FileName
	
	IF (@BkNum <= 0)
	RETURN 0
EXEC [repDeleteExtraJobBackup] @JobType, @BkNum, @DBName
################################################################
## Õ–› „Â„… ‰”Œ «Õ Ì«ÿÌ
create Procedure RepDeleteBackupJob
	@JobName [NVARCHAR](256)
As
	SET NOCOUNT ON
	IF (EXISTS (SELECT  *
			  FROM [msdb].[dbo].[sysjobs]
			  WHERE [Name] = @JobName))
	EXECUTE [msdb].[dbo].[sp_delete_job] @job_name = @JobName

################################################################
## Ì” Œœ„ „‰ RepGetJobSchedule
CREATE PROCEDURE RepGetResultOfJobSchedule
	@job_guid uniqueidentifier
AS 
	SET NOCOUNT ON
	
	UPDATE [#sysschedules] SET [job_id] = @job_guid

	SELECT 
		CAST( [sjs].[freq_type] AS [NVARCHAR](10)) AS [type],
		CAST( [sjs].[freq_interval] AS [NVARCHAR](10)) AS [Interval], 
		CAST( [sjs].[active_start_date] AS [NVARCHAR](10)) AS [SDate], 
		CAST( [sjs].[active_start_time] AS [NVARCHAR](10)) AS [STime],
		CAST ([sjs].[freq_subday_interval] AS [INT] ) AS [HoursNumber],
		CAST( [js].[last_run_date] AS [NVARCHAR](10)) AS [RunDate],
		CAST( [js].[last_run_time] AS [NVARCHAR](10)) AS [RunTime],
		CAST( [js].[last_run_outcome] AS [NVARCHAR](10)) AS [RunStat], 
		CAST( [sj].[enabled] AS [NVARCHAR](10)) AS [Enable] 
	FROM [#sysschedules] AS [sjs]
		INNER JOIN [msdb].[dbo].[sysjobs] AS [sj] ON [sjs].[job_id] = [sj].[job_id]
		INNER JOIN [msdb].[dbo].[sysjobservers] AS [js]	ON [sjs].[job_id] = [js].[job_id]
	WHERE [sj].[job_id] =  @job_guid

################################################################
## ≈Õ÷«— ÃœÊ·… „Â„…
CREATE PROCEDURE RepGetJobSchedule
	@jobName [NVARCHAR](256) 
AS  
	SET NOCOUNT ON 

	CREATE TABLE [#sysschedules]
	(
		[schedule_id] [INT],
		[schedule_name] [SYSNAME],
		[enabled] [INT],
		[freq_type] [INT],
		[freq_interval] [INT],
		[freq_subday_type] [INT],
		[freq_subday_interval] [INT],
		[freq_relative_interval] [INT],
		[freq_recurrence_factor] [INT],
		[active_start_date] [INT],
		[active_end_date] [INT],
		[active_start_time] [INT],
		[active_end_time] [INT],
		[date_created] [DATETIME],
		[schedule_description] [NVARCHAR](4000) COLLATE ARABIC_CI_AI,
		[next_run_date] [INT],
		[next_run_time] [INT]
	)

	IF [dbo].[fnIsSQL2005]() = 1 
	BEGIN 
		ALTER TABLE [#sysschedules]
		ADD 
			[schedule_uid] [UNIQUEIDENTIFIER],
			[job_count] [INT]
	END 
	
	DECLARE @job_guid AS [UNIQUEIDENTIFIER]
	SET @job_guid = ( SELECT TOP 1 [job_id] FROM [msdb].[dbo].[sysjobs] WHERE [NAME] = @jobName )

	IF ISNULL( @job_guid, 0x00) != 0x00
		INSERT INTO [#sysschedules] EXEC [msdb].[dbo].[sp_help_jobschedule] @job_guid

	ALTER TABLE [#sysschedules]
	ADD 
		[job_id] [UNIQUEIDENTIFIER] DEFAULT 0X0 

	EXEC [RepGetResultOfJobSchedule] @job_guid

################################################################
##Ã⁄· ‰”Œ… «Õ Ì«ÿÌ… œ«∆„…
CREATE PROCEDURE repMakePremanentBackup
				@FileName [NVARCHAR](255),
				@Perm [int]
AS
SET NOCOUNT ON
DECLARE @st [NVARCHAR](50)
IF( @Perm <> 0)
	SET @st = 'PERMANENT'
update [msdb]..[backupmediaset]
	set [description] = @st
where
	[media_set_id]
	in(
		Select [media_set_id]
		from [msdb]..[backupmediafamily]
		where [physical_device_name] = @FileName
	  )
################################################################
##·Õ–› «·‰”Œ «·«Õ Ì«ÿÌ… «·≈÷«›Ì…
CREATE PROCEDURE repDeleteExtraJobBackup
			@JobType [INT],
			@BkNum [INT],
			@DBName [NVARCHAR](1000) = ''
AS
SET NOCOUNT ON
IF( @BkNum < 1)
	RETURN 0
DECLARE @Name [NVARCHAR]( 1000), @Num [INT]
DECLARE @c CURSOR, @FileName [NVARCHAR]( 1000)
SELECT @Name =
	case @JobType
		when 16 then 	'%AMJB_' + @DBName + '_%'   
		when 8 then 	'%AWJB_' + @DBName + '_%'   
		when 4 then	'%ADJB_' + @DBName + '_%'   
	end
SET @Num = 0
SET @c = CURSOR FAST_FORWARD FOR
SELECT [physical_device_name]
FROM
	[msdb]..[backupmediaset] AS [bms]
INNER JOIN
	[msdb]..[backupmediafamily] AS [bmf]
ON
	[bms].[media_set_id] = [bmf].[media_set_id]
INNER JOIN
	[msdb]..[backupset] AS [bs]
ON
	[bs].[media_set_id] = [bmf].[media_set_id]
WHERE
	[physical_device_name] LIKE @Name AND
	[bms].[description] IS NULL
ORDER BY
	[bs].[backup_start_date]
DESC
OPEN @c FETCH NEXT FROM @c INTO @FileName

WHILE @@FETCH_STATUS = 0
BEGIN
	SET @Num = @Num +1
	if( @Num > @BkNum)
		EXEC [DeleteBackupFile] @FileName
	FETCH NEXT FROM @c INTO @FileName
END

CLOSE @c
DEALLOCATE @c
################################################################
##≈Õ÷«— „·›«  «·‰”Œ «·«Õ Ì«ÿÌ 
CREATE PROCEDURE prcGetBackupFiles
				@DbName [NVARCHAR](255)
AS 
SET NOCOUNT ON
CREATE TABLE [#BackupTbl]( 
							[Name] [NVARCHAR](256) COLLATE ARABIC_CI_AI ,
							[Description] [NVARCHAR](256) COLLATE ARABIC_CI_AI ,
							[Permanent] [NVARCHAR](256) COLLATE ARABIC_CI_AI ,
							[Date] [DATETIME],
							[Position] [INT]
						)
INSERT INTO [#BackupTbl]
SELECT 
	[bmf].[physical_Device_Name],
	ISNULL( [bs].[description], ''), 
	ISNULL( [bms].[description], ''), 
	[bs].[Backup_start_date], 
	[bs].[Position]
	  FROM [msdb]..[backupmediafamily] AS [bmf] INNER JOIN [msdb]..[backupSet] AS [bs] 
	  ON ( [bs].[Media_Set_id] = [bmf].[Media_Set_id] ) 
	  INNER JOIN [msdb]..[backupmediaSet] AS [bms]
	  ON ( [bs].[Media_Set_id] = [bms].[Media_Set_id] ) 
	  WHERE [bs].[database_name] = @DbName

SELECT * FROM [#BackupTbl]
			  ORDER BY [Date]
################################################################
CREATE PROCEDURE prc_SJ_DeleteJob 
	@JobGUID UNIQUEIDENTIFIER 
AS 
	SET NOCOUNT ON

	IF (EXISTS (SELECT * FROM [msdb].[dbo].[sysjobs] WHERE [job_id] = @JobGUID))
	EXECUTE [msdb].[dbo].[sp_delete_job] @job_id = @JobGUID
################################################################
CREATE PROCEDURE prc_SJ_AddJob 
	@JobName [NVARCHAR](256)
AS 
	SET NOCOUNT ON
	
	IF EXISTS (SELECT * FROM [msdb].[dbo].[sysjobs] WHERE [name] = @JobName) 
	BEGIN
		RAISERROR (N'SJ_E1201: There is already a job with this name.', 16, 1) 
		RETURN
	END

	IF NOT EXISTS(SELECT * FROM [msdb].[dbo].[syscategories] WHERE [name] = N'[Ameen SJ]')
		EXECUTE [msdb].[dbo].[sp_add_category] @name = N'[Ameen SJ]'

	DECLARE @JobID UNIQUEIDENTIFIER 
	SET @JobID = NULL 
	EXECUTE [msdb].[dbo].[sp_add_job] @job_id = @JobID OUTPUT , @job_name = @JobName , @owner_login_name = NULL, @description = N'Job added from Al-Ameen Program.', @category_name = N'[Ameen SJ]', @enabled = 1, @notify_level_email = 0, @notify_level_page = 0, @notify_level_netsend = 0, @notify_level_eventlog = 2, @delete_level= 0 
	
	SELECT @JobID AS JobID
################################################################
CREATE PROCEDURE prc_SJ_AddJobStep
	@JobID UNIQUEIDENTIFIER,
	@JobStepName [NVARCHAR](256),
	@DBName [NVARCHAR](256), 
	@Command [NVARCHAR](max),
	@JobType [INT], -- type of job 4: d, 8: w, 16: m
	@OnSuccessAction INT,	-- 1 = Quit With Success, 2 = Quit With Failure, 3 = Goto Next Step, 4 = Goto Step
	@OnFailAction INT	-- 1 = Quit With Success, 2 = Quit With Failure, 3 = Goto Next Step, 4 = Goto Step
AS 
	SET NOCOUNT ON
	
	IF NOT EXISTS (SELECT * FROM [msdb].[dbo].[sysjobs] WHERE [job_id] = @JobID) 
	BEGIN
		RAISERROR (N'SJ_E1202: The job is not found.', 16, 1) 
		RETURN
	END
	IF EXISTS (SELECT * FROM [msdb].[dbo].[sysjobsteps] WHERE [job_id] = @JobID AND step_name = @JobStepName) 
	BEGIN
		RAISERROR (N'SJ_E1203: There is already a job step with this name.', 16, 1) 
		RETURN
	END

	DECLARE 
		@RetryNum INT,
		@RetryInter INT; 

	SET @RetryNum = 3;
	SET @RetryInter = 1;

	DECLARE 
		@jobstep_uid UNIQUEIDENTIFIER,
		@jobstep_id INT;

	EXECUTE [msdb].[dbo].[sp_add_jobstep] 
		@job_id = @JobID, 
		@step_name = @JobStepName, 
		@command = @Command, 
		@database_name = @DBName, 
		-- @additional_parameters = @param,
		@server = N'', 
		@database_user_name = N'', 
		@subsystem = N'TSQL', 
		@cmdexec_success_code = 0, 
		@flags = 0, 
		@retry_attempts = @RetryNum, 
		@retry_interval = @RetryInter, 
		@output_file_name = N'', 
		@on_success_step_id = 0, 
		@on_success_action = @OnSuccessAction, 
		@on_fail_step_id = 0, 
		@on_fail_action = @OnFailAction,
		@step_uid = @jobstep_uid OUTPUT

	IF ISNULL(@jobstep_uid, 0x0) = 0x0
	BEGIN
		RAISERROR (N'SJ_E1207: The job strp is not added.', 16, 1) 
		RETURN
	END	
	SET @Command = (SELECT REPLACE(@command,'%TaskID', '''' + CAST(@jobstep_uid AS NVARCHAR(MAX)) + ''''));
	SELECT @jobstep_id = step_id FROM [msdb].[dbo].[sysjobsteps] WHERE Job_id = @JobID AND step_uid = @jobstep_uid
		
		EXECUTE [msdb].[dbo].sp_update_jobstep 
			@job_id = @JobID, 
		@step_id = @jobstep_id,
		@command = @Command
		
	SELECT @jobstep_uid AS step_uid
################################################################		 
CREATE PROCEDURE prc_SJ_SetJobFirstStep
	@JobID UNIQUEIDENTIFIER
AS 
	SET NOCOUNT ON
	
	IF NOT EXISTS (SELECT * FROM [msdb].[dbo].[sysjobs] WHERE [job_id] = @JobID) 
	BEGIN
		RAISERROR (N'SJ_E1202: The job is not found.', 16, 1) 
		RETURN
	END
	EXECUTE [msdb].[dbo].[sp_update_job] @job_id = @JobID, @start_step_id = 1
################################################################		 
CREATE PROCEDURE prc_SJ_SetJobSchedule
	@JobID			UNIQUEIDENTIFIER,
	@JobType		[INT], -- type of job 4: d, 8: w, 16: m
	@JobStartTime	[INT], 
	@JobStartDate	[INT], 
	-- @JobEndTime	[INT], 
	@JobEndDate		[INT], 
	@Jobday			[INT], 
	@IsOnce			[BIT] = 1, --0 Once Only, 1 Every 
	@HoursNumber	[INT]  = 250,--Number of hours 
	@freqRelativeInterval [INT] = 0
AS 
	SET NOCOUNT ON
	
	IF NOT EXISTS (SELECT * FROM [msdb].[dbo].[sysjobs] WHERE [job_id] = @JobID) 
	BEGIN
		RAISERROR (N'SJ_E1202: The job is not found.', 16, 1) 
		RETURN
	END

	IF @Jobday = 0 
		SET @Jobday = 1 

	-- Add the job schedules 
	IF (@IsOnce = 0)
	BEGIN 
		EXECUTE [msdb].[dbo].[sp_add_jobschedule] 
			@job_id = @JobID, 
			@name = N'Schedule 1', 
			@enabled = 1, 
			@freq_type = @JobType, 
			@active_start_date = @JobStartDate, 
			@active_start_time = @JobStartTime, 
			@freq_interval = @Jobday, 
			@freq_subday_type = 1, 
			@freq_subday_interval = 0, 
			@freq_relative_interval = @freqRelativeInterval, 
			@freq_recurrence_factor = 1, 
			@active_end_date = @JobEndDate, -- 99991231, 
			@active_end_time = 235959
	END ELSE BEGIN
		EXECUTE [msdb].[dbo].[sp_add_jobschedule] 
			@job_id = @JobID, 
			@name = N'Schedule 1', 
			@enabled = 1, 
			@freq_type = @JobType , 
			@active_start_date = @JobStartDate, 
			@active_start_time = @JobStartTime, 
			@freq_interval = @Jobday, 
			@freq_subday_type = 8, 
			@freq_subday_interval = @HoursNumber, 
			@freq_relative_interval = @freqRelativeInterval, 
			@freq_recurrence_factor = 1, 
			@active_end_date = @JobEndDate, -- 99991231, 
			@active_end_time = 235959 
	END 
################################################################		 
CREATE PROCEDURE prc_SJ_EnableJob
	@JobID UNIQUEIDENTIFIER,
	@Enable BIT = 1 -- 0: disable, 1 : enable 
AS 
	SET NOCOUNT ON
	
	IF NOT EXISTS (SELECT * FROM [msdb].[dbo].[sysjobs] WHERE [job_id] = @JobID) 
	BEGIN
		RAISERROR (N'SJ_E1202: The job is not found.', 16, 1) 
		RETURN
	END
	IF EXISTS (SELECT * FROM [msdb].[dbo].[sysjobs] WHERE [job_id] = @JobID AND [Enabled] = @Enable) 
	BEGIN
		RAISERROR (N'SJ_E1204: The job is already enabled/disabled.', 16, 1) 
		RETURN
	END

	EXECUTE [msdb].[dbo].[sp_update_job] @job_id = @JobID, @enabled = @Enable
################################################################		 
CREATE PROCEDURE prc_SJ_ExecuteJob
	@JobID UNIQUEIDENTIFIER
AS 
	SET NOCOUNT ON
	
	IF NOT EXISTS (SELECT * FROM [msdb].[dbo].[sysjobs] WHERE [job_id] = @JobID) 
	BEGIN
		RAISERROR (N'SJ_E1202: The job is not found.', 16, 1) 
		RETURN
	END
	if NOT EXISTS(SELECT *
					FROM msdb.dbo.sysjobactivity AS sja
					INNER JOIN msdb.dbo.sysjobs AS sj ON sja.job_id = sj.job_id AND sj.Job_id = @JobID
					WHERE sja.start_execution_date IS NOT NULL
					   AND sja.stop_execution_date IS NULL
			)
	EXECUTE [msdb].[dbo].[sp_start_job] @job_id = @JobID
################################################################		 
CREATE PROCEDURE prc_SJ_StopJob
	@JobID UNIQUEIDENTIFIER
AS 
	SET NOCOUNT ON
	
	IF NOT EXISTS (SELECT * FROM [msdb].[dbo].[sysjobs] WHERE [job_id] = @JobID) 
	BEGIN
		RAISERROR (N'SJ_E1202: The job is not found.', 16, 1) 
		RETURN
	END
	if EXISTS(SELECT *
					FROM msdb.dbo.sysjobactivity AS sja
					INNER JOIN msdb.dbo.sysjobs AS sj ON sja.job_id = sj.job_id AND sj.Job_id = @JobID
					WHERE sja.start_execution_date IS NOT NULL
					   AND sja.stop_execution_date IS NULL
			)
	EXECUTE [msdb].[dbo].[sp_stop_job] @job_id = @JobID
################################################################
CREATE PROCEDURE prc_SJ_GetJobSchedule
	@dbname NVARCHAR(MAX)
as 
	SET NOCOUNT ON
	DECLARE @start INT 
	SET @start = LEN(@dbname) + 13
	SELECT 
		DISTINCT
		[sjs].Job_id AS Job_id,
		SUBSTRING ([name], @start, LEN([name])) AS [name],	
		[sjs].[freq_type]  AS [type],
		[sjs].[freq_interval]  AS [Interval], 
		[sjs].[active_start_date]  AS [SDate], 
		[sjs].[active_start_time]  AS [STime],
		[sjs].[freq_subday_interval] AS  [HoursNumber],
		[js].[last_run_date] AS  [RunDate],
		[js].[last_run_time] AS  [RunTime],
		[js].[last_run_outcome]  AS [RunStat], 
		[sj].[enabled]  AS [Enable],
		[sjs].active_end_date AS active_end_date,
		dbo.fn_SJ_ISRunning([sjs].Job_id) AS IsRunning,
		[sj].[date_created] AS [DateCreated]
	FROM 
		(SELECT		
			s.schedule_id,
			enabled,
			freq_type,
			freq_interval,
			freq_subday_type,
			freq_subday_interval,
			freq_relative_interval,
			freq_recurrence_factor,
			active_start_date,
			active_end_date,
			active_start_time,
			active_end_time,
			js.job_id  
		FROM
			msdb.dbo.sysjobschedules AS js
			JOIN msdb.dbo.sysschedules AS s ON js.schedule_id = s.schedule_id) AS [sjs]
	INNER JOIN [msdb].[dbo].[sysjobs] AS [sj] ON [sjs].[job_id] = [sj].[job_id]
	INNER JOIN [msdb].[dbo].[sysjobservers] AS [js]	ON [sjs].[job_id] = [js].[job_id]
	INNER JOIN [msdb].[dbo].[sysjobsteps] AS jstep ON [jstep].[job_id] = [sj].[job_id] 
	WHERE database_name = @dbname AND SUBSTRING ([name], 0,12)='[Ameen SJ]['
	ORDER BY [sj].[date_created]

	EXEC msdb.dbo.sp_help_job @category_name = '[Ameen SJ]';
####################################################################
CREATE PROCEDURE prc_SJ_DeleteJopSteps
	@Job_id UNIQUEIDENTIFIER
AS 
	SET NOCOUNT ON
	
	IF NOT EXISTS (SELECT * FROM msdb.dbo.SysJobSteps WHERE job_id = @Job_id)
	BEGIN
		RAISERROR (N'SJ_E1202: The job is not found.', 16, 1) 
		RETURN
	END
	DECLARE @step_id INT 
	SET @step_id = (SELECT TOP 1 step_id FROM Msdb.dbo.SysJobSteps WHERE job_id = @Job_id)
	WHILE ISNULL(@step_id, 0) != 0
	BEGIN
		EXEC [msdb].dbo.sp_delete_jobstep @job_id = @Job_id, @step_id = @step_id 
		SET @step_id = (SELECT TOP 1 step_id FROM msdb.dbo.SysJobSteps WHERE job_id = @Job_id)
	END
######################################################################
CREATE PROCEDURE prc_SJ_ModifyJob 
	@JobID UNIQUEIDENTIFIER,
	@JobName [NVARCHAR](256)
AS 
	SET NOCOUNT ON
	
	IF EXISTS (SELECT * FROM [msdb].[dbo].[sysjobs] WHERE [name] = @JobName AND job_id <> @JobID) 
	BEGIN
		RAISERROR (N'SJ_E1201: There is already a job with this name.', 16, 1) 
		RETURN
	END
	EXEC msdb.dbo.sp_update_job @job_id = @JobID, @new_name = @JobName
########################################################################
CREATE PROCEDURE prc_SJ_DeleteSchedule 
@JobID UNIQUEIDENTIFIER
AS
	SET NOCOUNT ON

	DECLARE @sch_id int
	SET @sch_id = (SELECT schedule_id  FROM msdb.dbo.sysjobschedules WHERE job_id = @JobID)
	EXEC msdb.dbo.sp_delete_schedule
		@schedule_id = @sch_id,
		@force_delete = 1
#################################################################################
CREATE PROCEDURE prc_SJ_GetJobSteps
	@JobID UNIQUEIDENTIFIER
AS 
	SET NOCOUNT ON 

	SELECT 
		js.step_id,
		js.step_uid,
		js.step_name,
		js.[on_fail_action]
	FROM 
		[msdb].[dbo].[sysjobsteps] js
	WHERE 
		js.job_id = @JobID
	ORDER BY  
		js.step_id
#############################################################################
CREATE  PROCEDURE prc_SJ_GetStepOption
	@JobID UNIQUEIDENTIFIER,
	@step_uid UNIQUEIDENTIFIER
AS  
	SET NOCOUNT ON 

	SELECT	
		Name,
		value
	FROM 
		ScheduledJobOptions000 sjop
	WHERE  
		sjop.JobGUID = @JobID 
		AND 
		TaskGuid = @step_uid 
####################################################################
CREATE PROCEDURE prc_SJ_AddJobServer
	@JobID UNIQUEIDENTIFIER
AS 
	EXECUTE [msdb].[dbo].[sp_add_jobserver] @job_id = @JobID, @server_name = N'(local)'
##################################################################################
CREATE PROCEDURE prcGetJobHistory
	@JobID UNIQUEIDENTIFIER='3DD17B8E-A2EA-4847-B97D-646C9F9500A9'
AS
	SET NOCOUNT ON

	SELECT
		0 AS GroupID,
		ROW_NUMBER() OVER(ORDER BY instance_id) AS Number,
		instance_id,
		step_id,
		CAST(ISNULL(step_name,'')AS NVARCHAR(250)) AS step_name,
		run_status,
		run_date,
		run_time,
		0 AS OperationType,
		CAST(0x AS UNIQUEIDENTIFIER) AS UserGuid,
		0 AS MinDate,
		0 AS MinTime
	INTO 
		#Result
	FROM 
		msdb.dbo.sysjobhistory 
	WHERE 
		job_id = @JobID
		AND run_status <> 2;
	
	DECLARE 
		@Cnt INT = (SELECT COUNT(*) FROM #Result),
		@Counter INT = 1,
		@GroupID INT = 1;

	WHILE (@Counter <= @Cnt)
	BEGIN
		DECLARE 
			@stepID INT,
			@InstanceID INT;
		
		SELECT 
			@stepID = step_id,
			@InstanceID = instance_id
		FROM
			#Result 
		WHERE Number = @Counter;

		UPDATE #Result
			SET GroupID = @GroupID
		WHERE 
			instance_id = @InstanceID;
		SET @Counter = @Counter + 1;

		IF @stepID = 0
			SET @GroupID = @GroupID + 1;
	END

	UPDATE R
	SET 
		MinDate = (SELECT MIN(run_date) FROM #Result WHERE GroupID = R.GroupID),
		MinTime = (SELECT MIN(run_time) FROM #Result WHERE GroupID = R.GroupID)
	FROM #Result R

	INSERT INTO #Result
	SELECT
		(SELECT ISNULL(MAX(GroupID), 0) + 1 FROM #Result),
		-1,
		-1,
		CONVERT(VARCHAR(250), ''),
		-1,
		OperationDate,
		OperationTime,
		SMH.Operation,
		SMH.UserGuid,
		OperationDate AS MinDate,
		OperationTime AS MinTime
	FROM
		ScheduledMaintenanceHistory000 SMH
	WHERE 
		JobID = @JobID
	ORDER BY
		OperationDate,
		OperationTime;

	SELECT
			GroupID,
			 step_id,
			 step_name,
			 run_status,
			 Run_date AS RunDate, 
			 run_time AS RunTime, 
			 OperationType, 
			 UserGuid 
	FROM #Result 
		WHERE step_id<=0
	ORDER BY MinDate, MinTime, GroupID, step_id;

	SELECT 
			GroupID,
			 step_id,
			 step_name,
			 run_status,
			 Run_date AS RunDate, 
			 run_time AS RunTime, 
			 OperationType, 
			 UserGuid 
	FROM #Result 
		WHERE step_id> 0
	ORDER BY MinDate, MinTime, GroupID, step_id;
##################################################################################
CREATE PROCEDURE prc_SJ_GetJobScheduleDesktop
	@dbname NVARCHAR(MAX)
as 
	SET NOCOUNT ON
	DECLARE @start INT 
	SET @start = LEN(@dbname) + 13
	SELECT 
		DISTINCT
		[sjs].Job_id AS Job_id,
		SUBSTRING ([name], @start, LEN([name])) AS name,	
	 case   when (jstep.[last_run_outcome] <> js.[last_run_outcome] & js.last_run_outcome and js.last_run_outcome<> 0) then 5 else js.last_run_outcome EnD  AS [RunStat], 
	--	 js.last_run_outcome AS [RunStat],
		[sj].[enabled]  AS Enable
	FROM 
		(SELECT		
			s.schedule_id,
			enabled,
			js.job_id
  
		FROM
			msdb.dbo.sysjobschedules AS js
			JOIN msdb.dbo.sysschedules AS s ON js.schedule_id = s.schedule_id) as [sjs]
	INNER JOIN [msdb].[dbo].[sysjobs] AS [sj] ON [sjs].[job_id] = [sj].[job_id]
	INNER JOIN [msdb].[dbo].[sysjobservers] AS [js]	ON [sjs].[job_id] = [js].[job_id]
	INNER JOIN [msdb].[dbo].[sysjobsteps] AS jstep ON [jstep].[job_id] = [sj].[job_id] 
	WHERE database_name = @dbname and SUBSTRING ([name], 0,12)='[Ameen SJ][' 
##############################################################################################
CREATE FUNCTION fn_SJ_ISRunning
	(@JobID UNIQUEIDENTIFIER)
RETURNS INT
AS BEGIN
	IF  EXISTS(SELECT * FROM msdb.dbo.sysjobactivity AS sja
					INNER JOIN msdb.dbo.sysjobs AS sj ON sja.job_id = sj.job_id AND sj.Job_id = @JobID
					WHERE sja.start_execution_date IS NOT NULL
					   AND sja.stop_execution_date IS NULL)
	BEGIN
		RETURN 1;
	END
	RETURN 0;
END
############################################################################################
CREATE FUNCTION fnCompareTwoDateForShrinkDatabase(@DateCheck DATETIME,@DateCheck2 DATETIME,@numberofday INT)
RETURNS INT 
AS 
BEGIN
	DECLARE @d INT=(SELECT DATEDIFF(day, @DateCheck, @DateCheck2));
	IF @d >= @numberofday 
	RETURN	1;
	ELSE
		RETURN 0;
	RETURN 0;
END
############################################################################################
#END
