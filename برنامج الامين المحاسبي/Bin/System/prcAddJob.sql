####################################################################
CREATE Procedure prcAddJob 
	@JobName		[NVARCHAR]( 256), --name of job
	@JobType		[INT], -- type of job 4: d, 8: w, 16: m
	@JobTime		[INT], 
	@Jobday			[INT], 
	@JobStartDate	[INT], 
	@DBName			[NVARCHAR]( 256), 
	@Command		[NVARCHAR]( max),
	@Occurance		[INT] = 2, --1 Once Only, 2 Every 
	@HoursNumber [INT]  = 250,--Number of hours 
	@FreqRelativeInterval [INT] = 0
AS
/*
	this procedure Add Job To database
	this job Execute the Command
*/

	SET NOCOUNT ON
	
	SET XACT_ABORT ON 
	BEGIN TRANSACTION 

	DECLARE @JobID [BINARY](16) 
	DECLARE @ReturnCode [INT] 
	DECLARE @RetryNum [INT] 
	DECLARE @RetryInter [INT] 

	IF(@JobType = 4) 
	BEGIN
		SELECT @RetryNum = 23 
		SELECT @RetryInter = 60 

	END ELSE BEGIN 
		SELECT @RetryNum = 4 
		SELECT @RetryInter = 1440 
	END 

	SET @ReturnCode = 0
--	IF (SELECT COUNT(*) FROM msdb.dbo.syscategories WHERE name = N'[Uncategorized (Local)]') < 1 
	IF NOT EXISTS(SELECT * FROM [msdb].[dbo].[syscategories] WHERE [name] = N'[Uncategorized (Local)]')
		EXECUTE [msdb].[dbo].[sp_add_category] @name = N'[Uncategorized (Local)]'

	-- Delete the job with the same name (if it exists) 
	SELECT @JobID = [job_id] FROM [msdb].[dbo].[sysjobs] WHERE ([name] = @JobName)
	IF (@JobID IS NOT NULL) 
	BEGIN -- Check if the job is a multi-server job 
		IF (EXISTS (SELECT * FROM [msdb].[dbo].[sysjobservers] WHERE ([job_id] = @JobID) AND ([server_id] <> 0))) 
		BEGIN -- There is, so abort the script 
			RAISERROR (N'Unable to import job : '' since there is already a multi-server job with this name.', 16, 1) 
			GOTO QuitWithRollback 
		END 
		ELSE -- Delete the [local] job 
			EXECUTE [msdb].[dbo].[sp_delete_job] @job_name = @JobName 
		SELECT @JobID = NULL 
	END

	-- Add the job 
	EXECUTE @ReturnCode = [msdb].[dbo].[sp_add_job] @job_id = @JobID OUTPUT , @job_name = @JobName , @owner_login_name = NULL, @description = N'No description available.', @category_name = N'[Uncategorized (Local)]', @enabled = 1, @notify_level_email = 0, @notify_level_page = 0, @notify_level_netsend = 0, @notify_level_eventlog = 2, @delete_level= 0 
	IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback

	-- Add the job steps 
	EXECUTE @ReturnCode = [msdb].[dbo].[sp_add_jobstep] @job_id = @JobID, @step_id = 1, @step_name = N'Step 1', @command = @Command, @database_name = @DBName, @server = N'', @database_user_name = N'', @subsystem = N'TSQL', @cmdexec_success_code = 0, @flags = 0, @retry_attempts = @RetryNum, @retry_interval = @RetryInter, @output_file_name = N'', @on_success_step_id = 0, @on_success_action = 1, @on_fail_step_id = 0, @on_fail_action = 2 
	IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback

	EXECUTE @ReturnCode = [msdb].[dbo].[sp_update_job] @job_id = @JobID, @start_step_id = 1
	IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback

	-- Add the job schedules 
	IF (@Occurance = 1 )
	BEGIN 
	EXECUTE @ReturnCode = [msdb].[dbo].[sp_add_jobschedule] @job_id = @JobID, @name = N'Schedule 1', @enabled = 1, @freq_type = @JobType , @active_start_date = @JobStartDate, @active_start_time = @JobTime, @freq_interval = @Jobday, @freq_subday_type = 1, @freq_subday_interval = 0, @freq_relative_interval = @FreqRelativeInterval, @freq_recurrence_factor = 1, @active_end_date = 99991231, @active_end_time = 235959
	IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
	END 
	
	IF (@Occurance = 2)
	BEGIN
	EXECUTE @ReturnCode = [msdb].[dbo].[sp_add_jobschedule] @job_id = @JobID, @name = N'Schedule 1', @enabled = 1, @freq_type = @JobType , @active_start_date = @JobStartDate, @active_start_time = @JobTime, @freq_interval = @Jobday, @freq_subday_type = 8, @freq_subday_interval = @HoursNumber, @freq_relative_interval = @FreqRelativeInterval, @freq_recurrence_factor = 1, @active_end_date = 99991231, @active_end_time = 235959 
	IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback 
	END 
	-- Add the Target Servers 
	EXECUTE @ReturnCode = [msdb].[dbo].[sp_add_jobserver] @job_id = @JobID, @server_name = N'(local)'
	IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
	COMMIT TRANSACTION 

	RETURN

QuitWithRollback: 
	IF (@@TRANCOUNT > 0)
		ROLLBACK TRANSACTION

#######################################################################
#END