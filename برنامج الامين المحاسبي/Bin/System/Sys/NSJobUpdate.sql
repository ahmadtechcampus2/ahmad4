################################################################################
CREATE PROCEDURE NSPrcDeleteDbJob 
AS
    SET nocount ON
	DECLARE @DBName NVARCHAR(max) = DB_NAME()
    DECLARE @jobGuid UNIQUEIDENTIFIER
    DECLARE deletejob_cursor CURSOR FOR
      SELECT JOB_ID
      FROM MSDB..SYSJOBS 
					WHERE JOB_ID IN (
										SELECT DISTINCT JOB_ID FROM MSDB..SYSJOBSTEPS 
														WHERE DATABASE_NAME = @DBName
									)
					AND MSDB..SYSJOBS.[name] like '![Ameen NS SJ!]%' ESCAPE '!' 

    OPEN deletejob_cursor

    FETCH next FROM deletejob_cursor INTO @jobGuid

    WHILE @@FETCH_STATUS = 0
      BEGIN
          EXEC msdb..Sp_delete_job
            @job_id = @jobGuid;

          FETCH next FROM deletejob_cursor INTO @jobGuid;
      END

    CLOSE deletejob_cursor;

    DEALLOCATE deletejob_cursor; 
################################################################################
CREATE PROCEDURE NSPrcAddjob @JobName NVARCHAR(MAX),@Time INT,@Type INT ,@Day INT,@FrequencyRelativeInterval INT, @command NVARCHAR(MAX)
AS
	DECLARE @DBName NVARCHAR(max) = DB_NAME()
	IF NOT EXISTS(SELECT sj.job_id FROM msdb.dbo.sysjobs AS sj
		INNER JOIN [msdb].[dbo].[sysjobsteps] AS jstep ON [jstep].[job_id] = [sj].[job_id] 
		WHERE database_name = @DBName
		AND sj.name = @JobName)
	BEGIN
		DECLARE @FDATE DATETIME = (SELECT [dbo].fnDate_Amn2Sql((SELECT [dbo].[fnOption_get]('AmnCfg_FPDate', GETDATE()))))
		DECLARE @FPDate INT = DATEPART(year, @FDATE) * 10000 + DATEPART(month, @FDATE) * 100 + DATEPART(day, @FDATE)
		DECLARE @EDATE DATETIME = (SELECT [dbo].fnDate_Amn2Sql((SELECT [dbo].[fnOption_get]('AmnCfg_EPDate', GETDATE()))))
		DECLARE @EPDate INT = DATEPART(year, @EDATE) * 10000 + DATEPART(month, @EDATE) * 100 + DATEPART(day, @EDATE)
		
		DECLARE @JobID UNIQUEIDENTIFIER
	
		EXECUTE prc_SJ_AddJob @JobName

		set @JobID = (SELECT sj.job_id FROM msdb.dbo.sysjobs AS sj
		WHERE sj.name = @JobName)

		EXECUTE prc_SJ_AddJobStep @JobID , 'AccountBalances', @DBName ,@command , @Type, 1, 2
		EXECUTE prc_SJ_SetJobFirstStep @JobID
		EXECUTE prc_SJ_SetJobSchedule @JobID, @Type, @Time, @FPDate, @EPDate, @Day , 0 , 250,@FrequencyRelativeInterval
		EXECUTE prc_SJ_AddJobServer @JobID
	END
################################################################################
CREATE PROCEDURE NSPrcAddDateNotificationjobIfNotExist
AS
	DECLARE @JobStatus INT = (SELECT [dbo].[fnOption_get]('NS_JOBSTATUS', '2'))
	DECLARE @JobName NVARCHAR(MAX) = '[Ameen NS SJ][' + DB_NAME() + ']Date Notification'
	IF @JobStatus <> 0
		RETURN;
	DECLARE @hour INT = (SELECT [dbo].[fnOption_get]('NS_StartHour', '00'))
	DECLARE @minute INT =  (SELECT [dbo].[fnOption_get]('NS_StartMinute', '00')) 
	DECLARE @Time INT = @hour * 10000 + @minute * 100
	DECLARE @Type INT = 4 -- daily
	DECLARE @Day INT = 1
	DECLARE @FrequencyRelativeInterval INT = 0
	DECLARE @command NVARCHAR(MAX) = 'Execute NSPrcSchedulevent 6,0 ; Execute NSPrcSchedulevent 4,1 ; Execute NSPrcSchedulevent 0,5 ; Execute NSPrcSchedulevent 2, 30 ; Execute NSPrcSchedulevent 1, -6'
	EXEC NSPrcAddjob @JobName,@Time,@Type,@Day,@FrequencyRelativeInterval,@command
################################################################################
CREATE PROCEDURE NSPrcAddAccountBalancesJobsIfNotExist 
AS
	DECLARE @DBName NVARCHAR(max) = DB_NAME()
	DECLARE @NSAccountBalancesGuid UNIQUEIDENTIFIER
	DECLARE @Name NVARCHAR(max)
    DECLARE @Type INT
    DECLARE @Day INT
    DECLARE @FrequencyRelativeInterval INT
    DECLARE @Time INT
    DECLARE createjob_cursor CURSOR FOR
      SELECT [parentguid],
             [type],
             [day],
             [frequencyrelativeinterval],
             Datepart(hour, [time]) * 10000 + Datepart(minute, [time]) * 100 +
             Datepart(
             second, [time]),
			 ac.[Name]
      FROM   nsaccountbalancesjob000 NSAccjob INNER JOIN NSAccountBalancesScheduling000 AC on ac.[Guid] = NSAccjob.[ParentGuid]


    OPEN createjob_cursor

    FETCH next FROM createjob_cursor INTO @NSAccountBalancesGuid, @Type, @Day,
    @FrequencyRelativeInterval, @Time,@Name

    WHILE @@FETCH_STATUS = 0
      BEGIN
	  DECLARE @JobName NVARCHAR(MAX) = '[Ameen NS SJ][' + @DBName + ']' + @Name
	  DECLARE @command NVARCHAR(MAX) = 'EXEC NSPrcSchedulingEvent 1, ''' + convert(nvarchar(50), @NSAccountBalancesGuid) + ''''
	  EXEC NSPrcAddjob @JobName,@Time,@Type,@Day,@FrequencyRelativeInterval,@command

      FETCH next FROM createjob_cursor INTO @NSAccountBalancesGuid, @Type,
          @Day,
          @FrequencyRelativeInterval, @Time,@Name
      END

    CLOSE createjob_cursor;

    DEALLOCATE createjob_cursor; 
################################################################################
CREATE PROCEDURE NSPrcUpdateDBNSJob
AS
	SET NOCOUNT ON 
	exec NSPrcDeleteDbJob

	EXEC NSPrcAddAccountBalancesJobsIfNotExist

	EXEC NSPrcAddDateNotificationjobIfNotExist
################################################################################
#END
