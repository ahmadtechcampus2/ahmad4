##########################################################
CREATE PROCEDURE prcTransfareScheduledTasks
	@NEWDB	NVARCHAR(100),
	@OLDDB	NVARCHAR(100),
	@UPDATE [BIT] = 0
AS	
	DECLARE @JOB_ID UNIQUEIDENTIFIER, @S_ID INT, @CUR CURSOR 
	SET @CUR = CURSOR FOR SELECT JOB_ID, STEP_ID FROM MSDB..SYSJOBSTEPS WHERE DATABASE_NAME = @OLDDB ORDER BY JOB_ID, STEP_ID
	
	OPEN @CUR
	FETCH FROM @CUR INTO @JOB_ID, @S_ID
	
	IF @UPDATE = 1
	BEGIN
		WHILE @@FETCH_STATUS = 0
		BEGIN
			EXEC MSDB..SP_UPDATE_JOBSTEP @JOB_ID = @JOB_ID, @STEP_ID = @S_ID, @DATABASE_NAME = @NEWDB
			FETCH FROM @CUR INTO @JOB_ID, @S_ID
		END
		
		CLOSE @CUR
		
		RETURN
	END
	
	WHILE @@FETCH_STATUS = 0
	BEGIN
		DECLARE	
			-- @STEP_ID INT,
			@STEP_NAME SYSNAME,
			@SUBSYSTEM NVARCHAR(40),
			@COMMAND NVARCHAR(3200),
			@CMDEXEC_SUCCESS_CODE INT,
			@ON_SUCCESS_ACTION TINYINT,
			@ON_SUCCESS_STEP_ID INT,
			@ON_FAIL_ACTION TINYINT,
			@ON_FAIL_STEP_ID INT,
			@SERVER SYSNAME,
			@DATABASE_NAME SYSNAME,
			@DATABASE_USER_NAME SYSNAME,
			@RETRY_ATTEMPTS INT,
			@RETRY_INTERVAL INT,
			@OS_RUN_PRIORITY INT,
			@OUTPUT_FILE_NAME NVARCHAR(200),
			@FLAGS INT
		
		SELECT 
			-- @STEP_ID = STEP_ID, 
			@STEP_NAME = STEP_NAME, 
			@SUBSYSTEM = SUBSYSTEM, 
			@COMMAND = COMMAND, 
			@CMDEXEC_SUCCESS_CODE = CMDEXEC_SUCCESS_CODE, 
			@ON_SUCCESS_ACTION = ON_SUCCESS_ACTION, 
			@ON_SUCCESS_STEP_ID = ON_SUCCESS_STEP_ID, 
			@ON_FAIL_ACTION = ON_FAIL_ACTION, 
			@ON_FAIL_STEP_ID = ON_FAIL_STEP_ID, 
			@SERVER = SERVER, 
			@DATABASE_NAME = DATABASE_NAME, 
			@DATABASE_USER_NAME = DATABASE_USER_NAME, 
			@RETRY_ATTEMPTS = RETRY_ATTEMPTS, 
			@RETRY_INTERVAL = RETRY_INTERVAL, 
			@OS_RUN_PRIORITY = OS_RUN_PRIORITY, 
			@OUTPUT_FILE_NAME = OUTPUT_FILE_NAME, 
			@FLAGS = FLAGS 
		FROM MSDB..SYSJOBSTEPS
		WHERE 
			JOB_ID = @JOB_ID AND STEP_ID = @S_ID
		
		SET @STEP_NAME = @STEP_NAME + ' ' + CAST(NEWID() AS VARCHAR(40))
		
			EXEC MSDB..SP_ADD_JOBSTEP 
				@JOB_ID,
			NULL,
			NULL,
				@STEP_NAME,
				@SUBSYSTEM,
				@COMMAND,
				NULL,
				@CMDEXEC_SUCCESS_CODE,
				@ON_SUCCESS_ACTION,
				@ON_SUCCESS_STEP_ID,
				@ON_FAIL_ACTION,
				@ON_FAIL_STEP_ID,
				@SERVER,
				@NEWDB,
				@DATABASE_USER_NAME,
				@RETRY_ATTEMPTS,
				@RETRY_INTERVAL,
				@OS_RUN_PRIORITY,
				@OUTPUT_FILE_NAME,
				@FLAGS
			
		EXEC MSDB..SP_UPDATE_JOBSTEP @JOB_ID = @JOB_ID, @STEP_ID = @S_ID, @on_success_action = 3, @on_fail_action = 3
		
		FETCH FROM @CUR INTO @JOB_ID, @S_ID
	END
	
	CLOSE @CUR DEALLOCATE @CUR
##########################################################
CREATE PROCEDURE CopyPartproCh
	@DestDBName [NVARCHAR](255),
	@Notes [NVARCHAR](255)
AS
	DECLARE 
		@SQL NVARCHAR(MAX), 
		@C CURSOR,
			@Guid UNIQUEIDENTIFIER,
			@Temp FLOAT

	SELECT * INTO #RESULT FROM ch000 WHERE [State] = 2

	SET @C = CURSOR FAST_FORWARD FOR SELECT GUID FROM #RESULT
	OPEN @C FETCH FROM @C INTO @GUID
	WHILE @@FETCH_STATUS = 0 
	BEGIN 
		SET @Temp = dbo.fnCheck_GetCollectedValue(@GUID)
		SET @SQL = 'UPDATE #RESULT SET VAL = (VAL) - (' + CAST(@Temp AS NVARCHAR(250)) + '), NOTES = N''' + CAST(@Notes AS NVARCHAR(255)) + ''' WHERE GUID = ''' + CAST( @GUID AS NVARCHAR(250)) + '''' 
		EXEC (@SQL)

		FETCH @C INTO @GUID 
	END
	CLOSE @C 
	DEALLOCATE @C

	SET @SQL = ' ALTER TABLE ' + @DestDBName + '..ch000 DISABLE TRIGGER ALL 
		UPDATE ' + @DestDBName + '..ch000 SET TransferCheck = 1, TransferState = State
		DELETE ' + @DestDBName + '..ch000 FROM ' + @DestDBName + '..ch000 ch INNER JOIN #RESULT r ON r.GUID = ch.GUID WHERE r.VAL <= 0

		UPDATE ' + @DestDBName + '..ch000 SET VAL = r.VAL, State = 0, Notes = r.Notes FROM ' + @DestDBName + '..ch000 ch INNER JOIN #RESULT r ON r.GUID = ch.GUID WHERE r.VAL > 0
		DELETE ' + @DestDBName + '..ChequeHistory000 WHERE ChequeGUID NOT IN (SELECT GUID FROM ' + @DestDBName + '..ch000) ' 
	 EXEC (@SQL)
	 SET @SQL = 'ALTER TABLE '+ @DestDBName + '..ch000 ENABLE TRIGGER ALL'
	 EXEC (@SQL)
##########################################################
CREATE PROCEDURE CopyPartproFA

	@DestDBName [NVARCHAR](255)

AS

	 DECLARE @SQL NVARCHAR (2000), @C CURSOR, @Guid UNIQUEIDENTIFIER

	 SELECT * INTO #RESULT  FROM FavAcc000

	 SET @SQL = ' ALTER TABLE '+ @DestDBName + '..FavAcc000 DISABLE TRIGGER ALL 

	   INSERT INTO '+ @DestDBName +'..FavAcc000 SELECT * FROM #RESULT ' 

	 EXEC (@SQL)

	 SET @SQL = 'ALTER TABLE '+ @DestDBName + '..FavAcc000 ENABLE TRIGGER ALL'

	 EXEC (@SQL)
##########################################################
CREATE  PROCEDURE prc_SJ_TransfareCopyScheduledTasks	
	@NEWDB	NVARCHAR(MAX),
	@OLDDB	NVARCHAR(MAX),
	@newDate DATE,
	@IsSJFromNotificationSystem bit = 0
AS
	SET NOCOUNT ON
	DECLARE @JOB_ID UNIQUEIDENTIFIER, @CUR CURSOR ,@JobID UNIQUEIDENTIFIER,@Job_NAME NVARCHAR(MAX)
	DECLARE @start INT 

	IF (@IsSJFromNotificationSystem = 0)
	BEGIN
	SET @start = LEN(@OLDDB) + 13
	SET @CUR = CURSOR FOR 
					SELECT JOB_ID,SUBSTRING ([name], @start, LEN([name])) AS [name] FROM MSDB..SYSJOBS 
					WHERE JOB_ID IN (
										SELECT DISTINCT JOB_ID FROM MSDB..SYSJOBSTEPS 
														WHERE DATABASE_NAME = @OLDDB
									)
					AND MSDB..SYSJOBS.[name] like '![Ameen SJ!]%' ESCAPE '!' 
	END
	ELSE 
	BEGIN
	SET @start = LEN(@OLDDB) + 16
	SET @CUR = CURSOR FOR 
					SELECT JOB_ID,SUBSTRING ([name], @start, LEN([name])) AS [name] FROM MSDB..SYSJOBS 
					WHERE JOB_ID IN (
										SELECT DISTINCT JOB_ID FROM MSDB..SYSJOBSTEPS 
														WHERE DATABASE_NAME = @OLDDB
									)
					AND MSDB..SYSJOBS.[name] like '![Ameen NS SJ!]%' ESCAPE '!' 
	END

	OPEN @CUR;
	FETCH FROM @CUR INTO @JOB_ID,@Job_NAME
	WHILE @@FETCH_STATUS = 0
		BEGIN
		DECLARE @Job_name2 NVARCHAR(MAX)

		IF (@IsSJFromNotificationSystem = 0)
		SET @Job_NAME2 = '[Ameen SJ]['+@NEWDB+']'+@Job_NAME
		
		ELSE 
		SET @Job_NAME2 = '[Ameen NS SJ]['+@NEWDB+']'+@Job_NAME

		IF EXISTS (SELECT * FROM msdb.dbo.SYSJOBS WHERE NAME =@Job_NAME2)
		BEGIN
				FETCH FROM @CUR INTO @JOB_ID, @Job_NAME
				continue
				
		END
		
		 SET @JobID = NULL 
		EXECUTE [msdb].[dbo].[sp_add_job] @job_id = @JobID OUTPUT , @job_name = @Job_NAME2 , @owner_login_name = NULL, @description = N'Job added from Al-Ameen Program.', @category_name = N'[Ameen SJ]', @enabled = 1, @notify_level_email = 0, @notify_level_page = 0, @notify_level_netsend = 0, @notify_level_eventlog = 2, @delete_level= 0 

		 DECLARE @STEP_ID INT,
				@STEP_NAME SYSNAME,
				@SUBSYSTEM NVARCHAR(40),
				@COMMAND NVARCHAR(3200),
				@CMDEXEC_SUCCESS_CODE INT,
				@ON_SUCCESS_ACTION TINYINT,
				@ON_SUCCESS_STEP_ID INT,
				@ON_FAIL_ACTION TINYINT,
				@ON_FAIL_STEP_ID INT,
				@SERVER SYSNAME,
				@DATABASE_NAME SYSNAME,
				@DATABASE_USER_NAME SYSNAME,
				@RETRY_ATTEMPTS INT,
				@RETRY_INTERVAL INT,
				@OS_RUN_PRIORITY INT,
				@OUTPUT_FILE_NAME NVARCHAR(200),
				@FLAGS INT,
				@JobType		[INT], -- type of job 4: d, 8: w, 16: m
				@JobStartTime	[INT], 
				@JobStartDate	[INT], 
				@JobEndTime	[INT], 
				@JobEndDate		[INT], 
				@Jobday			[INT], 
				@HoursNumber	[INT]  = 250,--Number of hours ,
				@enabled1        [BIT],
				@freq_subday_type1 [INT],
				@STEPUID UNIQUEIDENTIFIER,
				@freqRelativeInterval int = 0

				DECLARE @C CURSOR 
				SET @C = CURSOR FOR 
									SELECT STEP_ID, STEP_NAME, SUBSYSTEM, COMMAND 
										,CMDEXEC_SUCCESS_CODE, ON_SUCCESS_ACTION, ON_SUCCESS_STEP_ID
										,ON_FAIL_ACTION, ON_FAIL_STEP_ID, SERVER, DATABASE_NAME, DATABASE_USER_NAME, 
										RETRY_ATTEMPTS, RETRY_INTERVAL
										, OS_RUN_PRIORITY, OUTPUT_FILE_NAME,FLAGS ,STEP_UID
										FROM MSDB..SYSJOBSTEPS
									WHERE  job_id=@JOB_ID
									--return 


				OPEN @C 
				FETCH FROM @C INTO @STEP_ID, @STEP_NAME, @SUBSYSTEM, @COMMAND, @CMDEXEC_SUCCESS_CODE, @ON_SUCCESS_ACTION, @ON_SUCCESS_STEP_ID, @ON_FAIL_ACTION, @ON_FAIL_STEP_ID, @SERVER, @DATABASE_NAME, @DATABASE_USER_NAME, @RETRY_ATTEMPTS, @RETRY_INTERVAL, @OS_RUN_PRIORITY, @OUTPUT_FILE_NAME, @FLAGS,@STEPUID
				WHILE @@FETCH_STATUS = 0
				BEGIN
				    DECLARE @Str [NVARCHAR](max),
							@step_uid1 UNIQUEIDENTIFIER,
							@step_name2 NVARCHAR(MAX),
							@param NVARCHAR(MAX)


					EXEC MSDB..SP_ADD_JOBSTEP 
						@job_id=@JobID,
						@step_id=@STEP_ID,
						@step_name=@STEP_NAME,
						@subsystem=@SUBSYSTEM,
						@command=@COMMAND,
						@additional_parameters=NULL,
						@cmdexec_success_code=@CMDEXEC_SUCCESS_CODE,
						@on_success_action=@ON_SUCCESS_ACTION,
						@on_success_step_id=@ON_SUCCESS_STEP_ID,
						@on_fail_action=@ON_FAIL_ACTION,
						@on_fail_step_id=@ON_FAIL_STEP_ID,
						@server=@SERVER,
						@database_name=@NEWDB,
						@database_user_name=@DATABASE_USER_NAME,
						@retry_attempts=@RETRY_ATTEMPTS,
						@retry_interval=@RETRY_INTERVAL,
						@os_run_priority=@OS_RUN_PRIORITY,
						@output_file_name=@OUTPUT_FILE_NAME,
						@flags=@FLAGS,
						@step_uid=@step_uid1 OUTPUT
			        
					
						
						SET @Command = (SELECT REPLACE(@command,CAST(@STEPUID AS NVARCHAR(MAX)),  + CAST(@step_uid1 as NVARCHAR(MAX))));
					
						SET @param = CAST (@step_uid1 AS VARCHAR(250))

						EXECUTE [msdb].[dbo].sp_update_jobstep 
											@job_id = @JobID, 
											@step_id=@STEP_ID,
											@command = @Command
										
											--@step_name=@step_name2
					

					

						SET  @Str='INSERT INTO '+@NEWDB+'..[ScheduledJobOptions000](GUID,JobGUID,TASKGUID,NAME,VALUE)
									SELECT NEWID(),'''+CAST(@JobID AS NVARCHAR(MAX))+''','''+CAST(@step_uid1 AS NVARCHAR(MAX))+''',NAME,VALUE FROM [ScheduledJobOptions000]
									WHERE JOBGUID='''+CAST(@JOB_ID AS NVARCHAR(MAX))+''' AND TASKGUID='''+CAST(@STEPUID AS NVARCHAR(MAX))	+''''
							
						
									
						EXEC(@Str)
					FETCH FROM @C INTO @STEP_ID, @STEP_NAME, @SUBSYSTEM, @COMMAND, @CMDEXEC_SUCCESS_CODE, @ON_SUCCESS_ACTION, @ON_SUCCESS_STEP_ID, @ON_FAIL_ACTION, @ON_FAIL_STEP_ID, @SERVER, @DATABASE_NAME, @DATABASE_USER_NAME, @RETRY_ATTEMPTS, @RETRY_INTERVAL, @OS_RUN_PRIORITY, @OUTPUT_FILE_NAME, @FLAGS, @STEPUID
				END
							
				CLOSE @C
				DEALLOCATE @C
				EXECUTE [msdb].[dbo].[sp_update_job] @job_id = @JobID, @start_step_id = 1

				SELECT	 
						@enabled1 = enabled, 
						@JobType = freq_type, 
						@JobStartDate = active_start_date, 
						@JobStartTime=active_start_time  , 
						@Jobday = freq_interval , 
						@JobEndDate=active_end_date, -- 99991231, 
						@JobEndTime=active_end_time ,
						@freq_subday_type1=freq_subday_type,
						@HoursNumber=freq_subday_interval,
						@freqRelativeInterval = freq_relative_interval


				FROM msdb.dbo.sysjobschedules AS js
				JOIN msdb.dbo.sysschedules AS s ON js.schedule_id = s.schedule_id AND job_id=@JOB_ID

				
				DECLARE  @startdate int ,@endDate int
				
				SET @startdate= CONVERT(int,CONVERT(varchar(10), CAST(CONVERT(NVARCHAR(MAX),YEAR(@newDate)) +'-'+ CONVERT(NVARCHAR(MAX),MONTH(@newDate))+'-' + CONVERT(NVARCHAR(MAX),DAY(@newDate))  as DATE) ,112))
				SET @endDate= CONVERT(int,CONVERT(varchar(10),CAST((CONVERT(NVARCHAR(MAX),YEAR(@newDate)) + CONVERT(NVARCHAR(MAX), MONTH(CONVERT(DATETIME, CONVERT(varchar(8), @JobENDDate)))) + CONVERT(NVARCHAR(MAX), DAY(CONVERT(DATETIME, CONVERT(varchar(8), @JobENDDate))))) as DATE) ,112))
	
				
				EXECUTE [msdb].[dbo].[sp_add_jobschedule] 
						@job_id = @JobID, 
						@name = N'Schedule 1', 
						@enabled = @enabled1, 
						@freq_type = @JobType , 
						@active_start_date = @startdate, 
						@active_start_time = @JobStartTime, 
						@freq_interval = @Jobday, 
						@freq_subday_type = @freq_subday_type1, 
						@freq_subday_interval = @HoursNumber, 
						@freq_relative_interval = @freqRelativeInterval, 
						@freq_recurrence_factor = 1, 
						@active_end_date = @endDate, -- 99991231, 
						@active_end_time = 235959 

				EXECUTE [msdb].[dbo].[sp_add_jobserver] @job_id = @JobID, @server_name = N'(local)'
			
			FETCH FROM @CUR INTO @JOB_ID, @Job_NAME
	END	
	CLOSE @CUR
	DEALLOCATE @CUR;
###########################################################################################################
#END
