################################################################################
CREATE TRIGGER trg_Op000_NSUpdateJobs
	ON [op000] FOR UPDATE
	NOT FOR REPLICATION
AS
	IF @@ROWCOUNT = 0 RETURN
	SET NOCOUNT ON
	IF NOT(UPDATE([Value]))
		RETURN 

	DECLARE @FPDate INT = NULL
	DECLARE @EPDate INT= NULL
	
	IF (EXISTS (SELECT Value FROM [inserted] WHERE [name] = 'AmnCfg_FPDate'))
	BEGIN 
		DECLARE @FDATE DATE = (SELECT TOP 1 CAST([Value] AS DATE) FROM op000 WHERE [Name] ='AmnCfg_FPDate' AND [Type] = 0)
		SET @FPDate = DATEPART(year, @FDATE) * 10000 + DATEPART(month, @FDATE) * 100 + DATEPART(day, @FDATE)
	END	
	
	IF (EXISTS (SELECT Value FROM [inserted] WHERE [name] = 'AmnCfg_EPDate'))
	BEGIN
		DECLARE @EDATE DATE = (SELECT TOP 1 CAST([Value] AS DATE) FROM op000 WHERE [Name] ='AmnCfg_EPDate' AND [Type] = 0)
		SET @EPDate = DATEPART(year, @EDATE) * 10000 + DATEPART(month, @EDATE) * 100 + DATEPART(day, @EDATE)
	END

	IF ((@FPDate != NULL) OR (@EPDate != NULL))
	BEGIN 
			UPDATE 
			[msdb].[dbo].sysschedules 
			SET active_start_date = ISNULL(@FPDate,active_start_date) , active_end_date = ISNULL(@EPDate,active_end_date)
			WHERE schedule_uid in (SELECT schedule_uid FROM msdb.dbo.sysjobschedules AS jsc
			INNER JOIN msdb.dbo.sysschedules AS s ON jsc.schedule_id = s.schedule_id
			INNER JOIN [msdb].[dbo].[sysjobs] AS [sj] ON [jsc].[job_id] = [sj].[job_id]
			INNER JOIN [msdb].[dbo].[sysjobservers] AS [js]	ON [jsc].[job_id] = [js].[job_id]
			INNER JOIN [msdb].[dbo].[sysjobsteps] AS jstep ON [jstep].[job_id] = [sj].[job_id]
			WHERE [jstep].database_name =  DB_NAME())
	END
################################################################################
#END
