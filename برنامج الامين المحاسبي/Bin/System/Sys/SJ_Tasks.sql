################################################################
CREATE PROC prc_SJ_GetSQLServerAgentState 
AS 
	SET NOCOUNT ON 
	DECLARE @agent NVARCHAR(512)
	SELECT @agent = COALESCE(N'SQLAgent$' + CONVERT(SYSNAME, SERVERPROPERTY('InstanceName')), 
	  N'SQLServerAgent');

	EXEC master.dbo.xp_servicecontrol 'QueryState', @agent;
################################################################
CREATE PROC prc_SJ_Clean
AS 
	SET NOCOUNT ON 

	IF NOT EXISTS (SELECT TOP 1 * FROM ScheduledJobOptions000)
		RETURN 

	DELETE sjo
	FROM 
		ScheduledJobOptions000 sjo 
		LEFT JOIN [msdb].[dbo].[sysjobs] job ON sjo.JobGUID = job.job_id 
	WHERE 
		job.job_id IS NULL 

	DELETE sjo
	FROM 
		ScheduledJobOptions000 sjo 
		LEFT JOIN [msdb].[dbo].[sysjobsteps] job_s ON sjo.TaskGUID = job_s.step_uid 
	WHERE 
		job_s.step_uid IS NULL 
	
	DELETE sjo
	FROM 
		ScheduledJobOptions000 sjo 
		LEFT JOIN bt000 bt ON sjo.Value = CAST(bt.guid AS NVARCHAR(250))
	WHERE 
		sjo.Name LIKE '%BillType%'
		AND 
		bt.guid IS NULL 

	DELETE sjo
	FROM 
		ScheduledJobOptions000 sjo 
		LEFT JOIN et000 et ON sjo.Value = CAST(et.guid AS NVARCHAR(250))
	WHERE 
		sjo.Name LIKE '%EntryType%'
		AND 
		et.guid IS NULL 

	DELETE sjo
	FROM 
		ScheduledJobOptions000 sjo 
		LEFT JOIN nt000 nt ON sjo.Value = CAST(nt.guid AS NVARCHAR(250))
	WHERE 
		sjo.Name LIKE '%ChequeType%'
		AND 
		nt.guid IS NULL 

	DELETE sjo
	FROM 
		ScheduledJobOptions000 sjo 
		LEFT JOIN mt000 mt ON sjo.Value = CAST(mt.guid AS NVARCHAR(250))
	WHERE 
		sjo.Name LIKE '%MatGUID%'
		AND 
		mt.guid IS NULL 

	DELETE sjo
	FROM 
		ScheduledJobOptions000 sjo 
		LEFT JOIN gr000 gr ON sjo.Value = CAST(gr.guid AS NVARCHAR(250))
	WHERE 
		sjo.Name LIKE '%GroupGUID%'
		AND 
		gr.guid IS NULL 

	DELETE sjo
	FROM 
		ScheduledJobOptions000 sjo 
		LEFT JOIN co000 co ON sjo.Value = CAST(co.guid AS NVARCHAR(250))
	WHERE 
		sjo.Name LIKE '%CostGUID%'
		AND 
		co.guid IS NULL 

	DELETE sjo
	FROM 
		ScheduledJobOptions000 sjo 
		LEFT JOIN st000 st ON sjo.Value = CAST(st.guid AS NVARCHAR(250))
	WHERE 
		sjo.Name LIKE '%StoreGUID%'
		AND 
		st.guid IS NULL 
################################################################
CREATE PROC prc_SJ_Init 
AS 
	SET NOCOUNT ON 

	DECLARE @UserGUID UNIQUEIDENTIFIER 
	SELECT TOP 1 @UserGUID = [GUID] FROM [us000] WHERE [bAdmin] = 1
	IF ISNULL(@UserGUID, 0X0) = 0X0 
	BEGIN
		RAISERROR (N'No admin user in Al-Ameen System.', 16, 1) 
		RETURN 
	END 
	EXEC prcConnections_add @UserGUID
	EXEC prcConnections_SetIgnoreWarnings 1
################################################################
CREATE PROC prc_SJ_Finalize
AS 
	SET NOCOUNT ON 

	EXEC prcConnections_SetIgnoreWarnings 0
################################################################
CREATE PROC prc_SJ_FillOptions 
	@TaskID UNIQUEIDENTIFIER 
AS 
	SET NOCOUNT ON 
	DELETE #Options
	INSERT INTO #Options SELECT [Name], [Value] FROM ScheduledJobOptions000 WHERE TaskGuid = @TaskID
################################################################
CREATE FUNCTION fn_SJ_GetScheduleType(@TaskID UNIQUEIDENTIFIER)
	RETURNS INT 
AS 
BEGIN 
	RETURN (
		SELECT		
			ISNULL(freq_type, -1)
		FROM
			msdb.dbo.sysjobschedules AS jsc
			INNER JOIN msdb.dbo.sysschedules AS s ON jsc.schedule_id = s.schedule_id
			INNER JOIN [msdb].[dbo].[sysjobs] AS [sj] ON [jsc].[job_id] = [sj].[job_id]
			INNER JOIN [msdb].[dbo].[sysjobservers] AS [js]	ON [jsc].[job_id] = [js].[job_id]
			INNER JOIN [msdb].[dbo].[sysjobsteps] AS jstep ON [jstep].[job_id] = [sj].[job_id] 
		WHERE 
			jstep.step_uid = @TaskID)
END 
################################################################
CREATE PROC prc_RegenerateEntries 
	@SrcGUID UNIQUEIDENTIFIER,
	@FromDate DATE,
	@EndDate DATE,
	@UseOutBalanceAVGPrice BIT = 0
AS 
	SET NOCOUNT ON 
	
	CREATE TABLE #Bills	(
		BuGuid UNIQUEIDENTIFIER,
		[btName] [NVARCHAR](256)COLLATE ARABIC_CI_AI,
		BtGuid UNIQUEIDENTIFIER,
		buNumber INT,
		ceGuid UNIQUEIDENTIFIER,
		bAutoEntry BIT,
		ceNumber INT,
		BillCount INT,
		buDate DATETIME)
	
		EXEC prcDisableTriggers 'ce000'
		ALTER TABLE [ce000] ENABLE TRIGGER [trg_ce000_delete] -- necessary for er000 handling
		EXEC prcDisableTriggers 'en000'
		EXEC prcDisableTriggers 'bu000'
		EXEC prcDisableTriggers 'bi000'
		ALTER TABLE [en000] ENABLE TRIGGER [trg_en000_delete]

	INSERT INTO #Bills EXEC prcGenEntriesPrepare @SrcGUID, @FromDate, @EndDate, 0
	DECLARE 
		@b_cursor CURSOR,
		@BuGuid UNIQUEIDENTIFIER,
		@BtGuid UNIQUEIDENTIFIER,
		@ceGuid UNIQUEIDENTIFIER,
		@bAutoEntry BIT,
		@bAutoPost BIT,
		@ceNumber INT

	SET @b_cursor = CURSOR FAST_FORWARD FOR SELECT BuGuid, BtGuid, ceGuid, bt.bAutoEntry, bt.bAutoEntry, ceNumber FROM #Bills b INNER JOIN bt000 bt ON b.BtGuid = bt.GUID 
	OPEN @b_cursor FETCH NEXT FROM @b_cursor INTO @BuGuid, @BtGuid, @ceGuid, @bAutoEntry, @bAutoPost, @ceNumber
	WHILE @@FETCH_STATUS = 0
	BEGIN 
		IF ((ISNULL(@ceGuid, 0x0) != 0x0) OR (@bAutoEntry = 1))
		BEGIN 
			EXEC prcBill_GenEntry @BuGuid, @ceNumber, 1, @UseOutBalanceAVGPrice
			IF @bAutoPost = 1
			BEGIN 
				EXEC prcBill_Post1 @BuGuid, 1
			END 
		END 
		FETCH NEXT FROM @b_cursor INTO @BuGuid, @BtGuid, @ceGuid, @bAutoEntry, @bAutoPost, @ceNumber
	END CLOSE @b_cursor DEALLOCATE @b_cursor

	EXEC prcGenEntriesFinalize
################################################################
CREATE PROC prc_SJ_RepriceBills 
	@TaskID UNIQUEIDENTIFIER 
AS 
	SET NOCOUNT ON 
	
	IF ISNULL(@TaskID, 0x0) = 0x0
	BEGIN 
		RAISERROR (N'No task is passed.', 16, 1) 
		RETURN
	END  

	DECLARE @Return INT 
	EXEC @Return = prc_SJ_Init
	IF @Return <> 0
		RETURN 
	
	CREATE TABLE #Options([Name] NVARCHAR(250), [Value] NVARCHAR(250)) 
	EXEC prc_SJ_FillOptions @TaskID
	IF NOT EXISTS (SELECT * FROM #Options)
	BEGIN
		RAISERROR (N'No options found.', 16, 1) 
		RETURN 
	END 
	IF NOT EXISTS (SELECT * FROM #Options WHERE Name LIKE 'REP_BillType_%')
	BEGIN
		RAISERROR (N'No bill types found.', 16, 1) 
		RETURN 
	END 
	
	DECLARE 
		@SrcGUID			UNIQUEIDENTIFIER,  
		@FromDate			DATE,  
		@EndDate			DATE,  
		@MaterialGUID		UNIQUEIDENTIFIER,
		@GroupGUID			UNIQUEIDENTIFIER,
		@StoreGUID			UNIQUEIDENTIFIER,  
		@CostGUID			UNIQUEIDENTIFIER,
		@PriceType			INT,
		@IsFromStartDate	BIT,
		@IsDiscExtraByVal	BIT,
		@Flag				INT

	SET @SrcGUID = NEWID()

	INSERT INTO RepSrcs(IdTbl, IdType, IdSubType)
	SELECT @SrcGUID, CAST(Value AS UNIQUEIDENTIFIER), 2 /*BILLS*/
	FROM #Options 
	WHERE Name LIKE 'REP_BillType_%' 

	SELECT TOP 1 @PriceType = CAST(Value AS INT) FROM #Options WHERE Name = 'REP_PriceType' 
	IF @PriceType IS NULL 
	BEGIN 
		RAISERROR (N'Price type must supplied.', 16, 1) 
		RETURN 
	END 

	DECLARE @FirstPeriodDate DATE 
	SET @FirstPeriodDate = ISNULL((SELECT TOP 1 CAST(Value AS DATETIME) FROM op000 WHERE Name = 'AmnCfg_FPDate' AND Type = 0), GETDATE())

	SET @IsFromStartDate = ISNULL((SELECT TOP 1 CAST(Value AS BIT) FROM #Options WHERE Name = 'REP_IsFromStartDate'), 1) 
	IF @IsFromStartDate = 1
	BEGIN
		SET @FromDate = @FirstPeriodDate
		SET @EndDate = GETDATE()
	END ELSE BEGIN 
		DECLARE @SchedualType INT 
		SET @SchedualType = dbo.fn_SJ_GetScheduleType(@TaskID)
		IF (@SchedualType = -1)
		BEGIN 
			RAISERROR (N'No step attatched the task.', 16, 1) 
			RETURN 
		END 
		SET @EndDate = (
			CASE @SchedualType 
				WHEN 8 /*W*/ THEN DATEADD (DAY, -1, GETDATE()) 
				WHEN 16 /*M*/ THEN DATEADD(DAY, -DAY(GETDATE()), GETDATE())
				ELSE DATEADD (DAY, -1, GETDATE()) 
			END)

		SET @FromDate = (
			CASE @SchedualType 
				WHEN 8 /*W*/ THEN DATEADD (WEEK, -1, GETDATE()) 
				WHEN 16 /*M*/ THEN DATEADD(DAY, -DAY(@EndDate) + 1, @EndDate)
				ELSE @EndDate
			END)
	END 
	IF @EndDate < @FromDate
		SET @EndDate = @FromDate
	IF @EndDate < @FirstPeriodDate
		RETURN 
	IF @FromDate < @FirstPeriodDate
		SET @FromDate = @FirstPeriodDate

	SET @MaterialGUID = ISNULL((SELECT TOP 1 CAST(Value AS UNIQUEIDENTIFIER) FROM #Options WHERE Name = 'REP_MatGUID'), 0x0) 
	SET @GroupGUID = ISNULL((SELECT TOP 1 CAST(Value AS UNIQUEIDENTIFIER) FROM #Options WHERE Name = 'REP_GroupGUID'), 0x0) 
	SET @StoreGUID = ISNULL((SELECT TOP 1 CAST(Value AS UNIQUEIDENTIFIER) FROM #Options WHERE Name = 'REP_StoreGUID'), 0x0) 
	SET @CostGUID = ISNULL((SELECT TOP 1 CAST(Value AS UNIQUEIDENTIFIER) FROM #Options WHERE Name = 'REP_CostGUID'), 0x0) 

	SET @IsDiscExtraByVal = ISNULL((SELECT TOP 1 CAST(Value AS BIT) FROM #Options WHERE Name = 'REPO_IsDiscExtraByVal'), 0) 
	SET @Flag = ISNULL((SELECT TOP 1 CAST(Value AS INT) FROM #Options WHERE Name = 'REPO_Flag'), 0) 
	
	BEGIN TRAN

	EXEC @Return = prcBill_rePrice @SrcGUID, @FromDate, @EndDate, @MaterialGUID, @GroupGUID, @StoreGUID, @CostGUID, 0, 0, 100, @PriceType, @IsDiscExtraByVal, @Flag
	IF @Return != 0
		GOTO exitMe	
	
	EXEC @Return = prc_RegenerateEntries @SrcGUID, @FromDate, @EndDate, 0
	IF @Return != 0
		GOTO exitMe	

	COMMIT TRAN 

	exitMe:
		IF @@TRANCOUNT != 0
			ROLLBACK TRAN
		EXEC prc_SJ_Finalize		
################################################################
CREATE PROC prc_SJ_Backup
	@TaskID UNIQUEIDENTIFIER 
AS 
	SET NOCOUNT ON 
	
	IF ISNULL(@TaskID, 0x0) = 0x0
	BEGIN 
		RAISERROR (N'No task is passed.', 16, 1) 
		RETURN 
	END  
	
	CREATE TABLE #Options([Name] NVARCHAR(250), [Value] NVARCHAR(250)) 
	EXEC prc_SJ_FillOptions @TaskID
	
	DECLARE 
		@BackupNum			INT,
		@DbName				NVARCHAR(250),
		@BackupDir			NVARCHAR(500)

	SET @BackupNum = ISNULL((SELECT TOP 1 CAST(Value AS INT) FROM #Options WHERE Name = 'BAK_Num'), 0) 
	SET @DbName = (SELECT db_name())
	SET @BackupDir = ISNULL((SELECT TOP 1 Value FROM op000 WHERE Name = 'AmnCfg_BackupDir'	AND Computer = Host_Name() AND Type = 2), '')
	IF @BackupDir = ''
	BEGIN 
		SET @BackupDir = ISNULL((SELECT TOP 1 Value FROM op000 WHERE Name = 'AmnCfg_BackupDir' AND Type = 0), '')
		IF @BackupDir = ''
		BEGIN 
			SET @BackupDir = ISNULL((SELECT TOP 1 Value FROM #Options WHERE Name = 'BAK_DefaultDir'), '') 
			IF @BackupDir = ''
			BEGIN
				RAISERROR (N'Backup dir is not supplied.', 16, 1) 
				RETURN 
			END
		END 		
	END 
	DECLARE @SchedualType INT 
	SET @SchedualType = dbo.fn_SJ_GetScheduleType(@TaskID)
	IF (@SchedualType = -1)
	BEGIN 
		RAISERROR (N'No step attatched the task.', 16, 1) 
		RETURN 
	END 
	
	EXEC repDoBackupJob 
		@JobType = @SchedualType,
		@DBName = @DbName,
		@DirName = @BackupDir,
		@BkNum = @BackupNum,
		@SaveTimeToFileName = 1
################################################################
CREATE PROC prc_SJ_RepriceMaterials
	@TaskID UNIQUEIDENTIFIER 
AS 
	SET NOCOUNT ON 
	
	IF ISNULL(@TaskID, 0x0) = 0x0
	BEGIN 
		RAISERROR (N'No task is passed.', 16, 1) 
		RETURN 
	END  
	DECLARE @Return INT 
	EXEC @Return = prc_SJ_Init
	IF @Return <> 0
		RETURN 
	
	CREATE TABLE #Options (
		[Name] NVARCHAR(250), 
		[Value] NVARCHAR(250)) 
	
	EXEC prc_SJ_FillOptions @TaskID

	DECLARE 
		@PreserveLastPrice	BIT,
		@IsCalcQty			BIT,
		@IsCalcCP			BIT,
		@IsCalcLP			BIT,
		@IsCalcAvgPrice		BIT

	SET @PreserveLastPrice  = ISNULL((SELECT TOP 1 CAST(Value AS BIT) FROM #Options WHERE Name = 'REPM_PreserveLast'),		0) 
	SET @IsCalcQty			= ISNULL((SELECT TOP 1 CAST(Value AS BIT) FROM #Options WHERE Name = 'REPM_IsCalcQty'),			1) 
	SET @IsCalcCP			= ISNULL((SELECT TOP 1 CAST(Value AS BIT) FROM #Options WHERE Name = 'REPM_IsCalcCP'),			1) 
	SET @IsCalcLP			= ISNULL((SELECT TOP 1 CAST(Value AS BIT) FROM #Options WHERE Name = 'REPM_IsCalcLP'),			1) 
	SET @IsCalcAvgPrice		= ISNULL((SELECT TOP 1 CAST(Value AS BIT) FROM #Options WHERE Name = 'REPM_IsCalcAvgPrice'),	1) 
	
	BEGIN TRAN 

	EXEC @Return = prcBill_rePost 0, @PreserveLastPrice, 0x0, @IsCalcQty, @IsCalcCP, @IsCalcLP, @IsCalcAvgPrice 
	IF @Return != 0
		GOTO exitMe	

	COMMIT TRAN 

	exitMe:
		IF @@TRANCOUNT != 0
			ROLLBACK TRAN
		EXEC prc_SJ_Finalize		
################################################################
CREATE PROC prc_SJ_OutBalanceAveragePrice
	@TaskID UNIQUEIDENTIFIER 
AS 
	SET NOCOUNT ON 
	
	IF ISNULL(@TaskID, 0x0) = 0x0
	BEGIN 
		RAISERROR (N'No task is passed.', 16, 1) 
		RETURN 
	END  
	DECLARE @Return INT 
	EXEC @Return = prc_SJ_Init
	IF @Return <> 0
		RETURN 
	
	CREATE TABLE #Options([Name] NVARCHAR(250), [Value] NVARCHAR(250)) 
	EXEC prc_SJ_FillOptions @TaskID

	DECLARE 
		@FromDate			DATE,  
		@EndDate			DATE,  
		@GroupGUID			UNIQUEIDENTIFIER,
		@IsFromStartDate	BIT,
		@IgnoreBalancedMats BIT 

	SET @IsFromStartDate = ISNULL((SELECT TOP 1 CAST(Value AS BIT) FROM #Options WHERE Name = 'AVG_IsFromStartDate'), 1) 
	SET @EndDate = DATEADD(D, -DAY(GETDATE()) + 1, DATEADD(M, -1, GETDATE())) 
	
	IF @IsFromStartDate = 1
	BEGIN
		SELECT TOP 1 @FromDate = CAST(Value AS DATE) FROM op000 WHERE Name = 'AmnCfg_FPDate' AND Type = 0
		IF @FromDate IS NULL
		BEGIN 
			SET @FromDate = @EndDate
		END ELSE BEGIN 
			SET @FromDate = DATEADD(D, -DAY(@FromDate) + 1, @FromDate)
		END 
	END ELSE BEGIN 
		SET @FromDate = @EndDate
	END 
	IF @FromDate > @EndDate
		SET @FromDate = @EndDate

	SET @GroupGUID = ISNULL((SELECT TOP 1 CAST(Value AS UNIQUEIDENTIFIER) FROM #Options WHERE Name = 'AVG_GroupGUID'), 0x0) 
	SET @IgnoreBalancedMats = ISNULL((SELECT TOP 1 CAST(Value AS BIT) FROM #Options WHERE Name = 'AVG_IgnoreBalancedMats'), 0) 
	
	BEGIN TRAN 

	EXEC @Return = prcOutbalanceAveragePrice @FromDate, @EndDate, @GroupGUID, @IgnoreBalancedMats
	IF @Return != 0
		GOTO exitMe	

	COMMIT TRAN 

	exitMe:
		IF @@TRANCOUNT != 0
			ROLLBACK TRAN
		EXEC prc_SJ_Finalize
################################################################
CREATE PROC prc_SJ_PostEntries
	@TaskID UNIQUEIDENTIFIER 
AS 
	SET NOCOUNT ON 
	
	IF ISNULL(@TaskID, 0x0) = 0x0
	BEGIN 
		RAISERROR (N'No task is passed.', 16, 1) 
		RETURN 
	END  
	
	DECLARE @Return INT 
	EXEC @Return = prc_SJ_Init
	IF @Return <> 0
		RETURN 
	
	CREATE TABLE #Options([Name] NVARCHAR(250), [Value] NVARCHAR(250)) 
	EXEC prc_SJ_FillOptions @TaskID
	IF NOT EXISTS (SELECT * FROM #Options)
	BEGIN
		RAISERROR (N'No options found.', 16, 1) 
		RETURN 
	END 
	IF NOT EXISTS (SELECT * FROM #Options WHERE Name LIKE 'PE_BillType_%' OR Name LIKE 'PE_EntryType_%' OR Name LIKE 'PE_ChequeType_%')
	BEGIN
		RAISERROR (N'No types found.', 16, 1) 
		RETURN 
	END 
	
	DECLARE 
		@BillsSrcGUID		UNIQUEIDENTIFIER,  
		@EntriesSrcGUID		UNIQUEIDENTIFIER,  
		@ChequesSrcGUID		UNIQUEIDENTIFIER,  
		@FromDate			DATE,  
		@EndDate			DATE,  
		@IsFromStartDate	BIT 

	SET @BillsSrcGUID = NEWID()
	INSERT INTO RepSrcs(IdTbl, IdType, IdSubType)
	SELECT @BillsSrcGUID, CAST(Value AS UNIQUEIDENTIFIER), 2 /*BILLS*/
	FROM #Options 
	WHERE Name LIKE 'PE_BillType_%' 

	SET @EntriesSrcGUID = NEWID()
	INSERT INTO RepSrcs(IdTbl, IdType, IdSubType)
	SELECT @EntriesSrcGUID, CAST(Value AS UNIQUEIDENTIFIER), 0
	FROM #Options 
	WHERE Name LIKE 'PE_EntryType_%' 

	SET @ChequesSrcGUID = NEWID()
	INSERT INTO RepSrcs(IdTbl, IdType, IdSubType)
	SELECT @ChequesSrcGUID, CAST(Value AS UNIQUEIDENTIFIER), 0
	FROM #Options 
	WHERE Name LIKE 'PE_ChequeType_%' 

	DECLARE @FirstPeriodDate DATE 
	SET @FirstPeriodDate = ISNULL((SELECT TOP 1 CAST(Value AS DATETIME) FROM op000 WHERE Name = 'AmnCfg_FPDate' AND Type = 0), GETDATE())

	SET @IsFromStartDate = ISNULL((SELECT TOP 1 CAST(Value AS BIT) FROM #Options WHERE Name = 'PE_IsFromStartDate'), 1) 
	IF @IsFromStartDate = 1
	BEGIN
		SET @FromDate = @FirstPeriodDate
		SET @EndDate = GETDATE()
	END ELSE BEGIN 
		DECLARE @SchedualType INT 
		SET @SchedualType = dbo.fn_SJ_GetScheduleType(@TaskID)
		IF (@SchedualType = -1)
		BEGIN 
			RAISERROR (N'No step attatched the task.', 16, 1) 
			RETURN 
		END 
		SET @EndDate = (
			CASE @SchedualType 
				WHEN 8 /*W*/ THEN DATEADD (DAY, -1, GETDATE()) 
				WHEN 16 /*M*/ THEN DATEADD(DAY, -DAY(GETDATE()), GETDATE())
				ELSE DATEADD (DAY, -1, GETDATE()) 
			END)

		SET @FromDate = (
			CASE @SchedualType 
				WHEN 8 /*W*/ THEN DATEADD (WEEK, -1, GETDATE()) 
				WHEN 16 /*M*/ THEN DATEADD(DAY, -DAY(@EndDate) + 1, @EndDate)
				ELSE @EndDate
			END)
	END 
	IF @EndDate < @FromDate
		SET @EndDate = @FromDate
	IF @EndDate < @FirstPeriodDate
		RETURN 
	IF @FromDate < @FirstPeriodDate
		SET @FromDate = @FirstPeriodDate

	BEGIN TRAN 

	EXEC @Return = prcBondCarryover @EntriesSrcGUID, @BillsSrcGUID, @ChequesSrcGUID, @FromDate, @EndDate
	IF @Return != 0
		GOTO exitMe	

	COMMIT TRAN 

	exitMe:
		IF @@TRANCOUNT != 0
			ROLLBACK TRAN
		EXEC prc_SJ_Finalize
################################################################
CREATE PROC prc_SJ_RegenerateEntries
	@TaskID UNIQUEIDENTIFIER 
AS 
	SET NOCOUNT ON 

	IF ISNULL(@TaskID, 0x0) = 0x0
	BEGIN 
		RAISERROR (N'No task is passed.', 16, 1) 
		RETURN 
	END  
	
	DECLARE @Return INT 
	EXEC @Return = prc_SJ_Init
	IF @Return <> 0
		RETURN 
	
	CREATE TABLE #Options([Name] NVARCHAR(250), [Value] NVARCHAR(250)) 
	EXEC prc_SJ_FillOptions @TaskID
	IF NOT EXISTS (SELECT * FROM #Options)
	BEGIN
		RAISERROR (N'No options found.', 16, 1) 
		RETURN 
	END 
	IF NOT EXISTS (SELECT * FROM #Options WHERE Name LIKE 'REGE_BillType_%')
	BEGIN
		RAISERROR (N'No bill types found.', 16, 1) 
		RETURN 
	END 
	
	DECLARE 
		@SrcGUID				UNIQUEIDENTIFIER,  
		@FromDate				DATE,  
		@EndDate				DATE,  
		@IsFromStartDate		BIT,
		@UseOutBalanceAVGPrice	BIT 

	SET @SrcGUID = NEWID()
	INSERT INTO RepSrcs(IdTbl, IdType, IdSubType)
	SELECT @SrcGUID, CAST(Value AS UNIQUEIDENTIFIER), 2 /*BILLS*/
	FROM #Options 
	WHERE Name LIKE 'REGE_BillType_%' 

	DECLARE @FirstPeriodDate DATE 
	SET @FirstPeriodDate = ISNULL((SELECT TOP 1 CAST(Value AS DATETIME) FROM op000 WHERE Name = 'AmnCfg_FPDate' AND Type = 0), GETDATE())

	SET @IsFromStartDate = ISNULL((SELECT TOP 1 CAST(Value AS BIT) FROM #Options WHERE Name = 'REGE_IsFromStartDate'), 1) 
	IF @IsFromStartDate = 1
	BEGIN
		SET @FromDate = @FirstPeriodDate
		SET @EndDate = GETDATE()
	END ELSE BEGIN 
		DECLARE @SchedualType INT 
		SET @SchedualType = dbo.fn_SJ_GetScheduleType(@TaskID)
		IF (@SchedualType = -1)
		BEGIN 
			RAISERROR (N'No step attatched the task.', 16, 1) 
			RETURN 
		END 
		SET @EndDate = (
			CASE @SchedualType 
				WHEN 8 /*W*/ THEN DATEADD (DAY, -1, GETDATE()) 
				WHEN 16 /*M*/ THEN DATEADD(DAY, -DAY(GETDATE()), GETDATE())
				ELSE DATEADD (DAY, -1, GETDATE()) 
			END)

		SET @FromDate = (
			CASE @SchedualType 
				WHEN 8 /*W*/ THEN DATEADD (WEEK, -1, GETDATE()) 
				WHEN 16 /*M*/ THEN DATEADD(DAY, -DAY(@EndDate) + 1, @EndDate)
				ELSE @EndDate
			END)
	END 
	IF @EndDate < @FromDate
		SET @EndDate = @FromDate
	IF @EndDate < @FirstPeriodDate
		RETURN 
	IF @FromDate < @FirstPeriodDate
		SET @FromDate = @FirstPeriodDate
	
	SET @UseOutBalanceAVGPrice = ISNULL((SELECT TOP 1 CAST(Value AS BIT) FROM #Options WHERE Name = 'REGE_UseOutBalanceAVGPrice'), 0) 

	BEGIN TRAN 

	EXEC @Return = prc_RegenerateEntries @SrcGUID, @FromDate, @EndDate, @UseOutBalanceAVGPrice
	IF @Return != 0
		GOTO exitMe	

	COMMIT TRAN 

	exitMe:
		IF @@TRANCOUNT != 0
			ROLLBACK TRAN
		EXEC prc_SJ_Finalize
################################################################
CREATE PROC prc_SJ_GenerateEntries
	@TaskID UNIQUEIDENTIFIER 
AS 
	SET NOCOUNT ON 

	IF ISNULL(@TaskID, 0x0) = 0x0
	BEGIN 
		RAISERROR (N'No task is passed.', 16, 1) 
		RETURN 
	END  
	
	DECLARE @Return INT 
	EXEC @Return = prc_SJ_Init
	IF @Return <> 0
		RETURN 
	
	CREATE TABLE #Options([Name] NVARCHAR(250), [Value] NVARCHAR(250)) 
	EXEC prc_SJ_FillOptions @TaskID
	IF NOT EXISTS (SELECT * FROM #Options)
	BEGIN
		RAISERROR (N'No options found.', 16, 1) 
		RETURN 
	END 
	IF NOT EXISTS (SELECT * FROM #Options WHERE Name LIKE 'GEPB_BillType_%')
	BEGIN
		RAISERROR (N'No bill types found.', 16, 1) 
		RETURN 
	END 
	
	DECLARE 
		@FromDate				DATE,  
		@EndDate				DATE,  
		@IsFromStartDate		BIT

	DECLARE @FirstPeriodDate DATE 
	SET @FirstPeriodDate = ISNULL((SELECT TOP 1 CAST(Value AS DATETIME) FROM op000 WHERE Name = 'AmnCfg_FPDate' AND Type = 0), GETDATE())

	SET @IsFromStartDate = ISNULL((SELECT TOP 1 CAST(Value AS BIT) FROM #Options WHERE Name = 'GEPB_IsFromStartDate'), 1) 
	IF @IsFromStartDate = 1
	BEGIN
		SET @FromDate = @FirstPeriodDate
		SET @EndDate = GETDATE()
	END ELSE BEGIN 
		DECLARE @SchedualType INT 
		SET @SchedualType = dbo.fn_SJ_GetScheduleType(@TaskID)
		IF (@SchedualType = -1)
		BEGIN 
			RAISERROR (N'No step attatched the task.', 16, 1) 
			RETURN 
		END 
		SET @EndDate = (
			CASE @SchedualType 
				WHEN 8 /*W*/ THEN DATEADD (DAY, -1, GETDATE()) 
				WHEN 16 /*M*/ THEN DATEADD(DAY, -DAY(GETDATE()), GETDATE())
				ELSE DATEADD (DAY, -1, GETDATE()) 
			END)

		SET @FromDate = (
			CASE @SchedualType 
				WHEN 8 /*W*/ THEN DATEADD (WEEK, -1, GETDATE()) 
				WHEN 16 /*M*/ THEN DATEADD(DAY, -DAY(@EndDate) + 1, @EndDate)
				ELSE @EndDate
			END)
	END 
	IF @EndDate < @FromDate
		SET @EndDate = @FromDate
	IF @EndDate < @FirstPeriodDate
		RETURN 
	IF @FromDate < @FirstPeriodDate
		SET @FromDate = @FirstPeriodDate
	
	CREATE TABLE #bills(
		BuGUID UNIQUEIDENTIFIER, 
		BtGUID UNIQUEIDENTIFIER, 
		BuDate DATE, 
		Branch UNIQUEIDENTIFIER, 
		TypeGUID UNIQUEIDENTIFIER,
		BuNumber INT,
		bGenerate BIT,
		bPost BIT)
	
	INSERT INTO #bills
	SELECT 
		bu.GUID,
		bt.GUID,
		bu.Date,
		bu.Branch,
		bu.TypeGUID,
		bu.Number,
		1,
		0  
	FROM 
		bu000 bu 
		INNER JOIN bt000 bt ON bu.TypeGUID = bt.GUID 
		INNER JOIN #Options op ON op.Value = CAST(bt.guid AS NVARCHAR(250))
		LEFT JOIN er000 er ON er.ParentGUID = bu.GUID 
		LEFT JOIN ce000 ce ON ce.GUID = er.EntryGUID
	WHERE 
		op.Name LIKE 'GEPB_BillType_Gen_%'
		AND 
		bu.Date BETWEEN @FromDate AND @EndDate
		AND
		ce.GUID IS NULL

	UPDATE #bills
	SET bPost = 1
	FROM 
		#bills bu 
		INNER JOIN bt000 bt ON bu.BtGUID = bt.GUID 
		INNER JOIN #Options op ON op.Value = CAST(bt.guid AS NVARCHAR(250))
	WHERE 
		op.Name LIKE 'GEPB_BillType_Post_%'

	INSERT INTO #bills
	SELECT 
		bu.GUID,
		bt.GUID,
		bu.Date,
		bu.Branch,
		bu.TypeGUID,
		bu.Number,
		0,
		1  
	FROM 
		bu000 bu 
		INNER JOIN bt000 bt ON bu.TypeGUID = bt.GUID 
		INNER JOIN #Options op ON op.Value = CAST(bt.guid AS NVARCHAR(250))
		LEFT JOIN #bills bi ON bu.GUID = bi.BuGUID 
	WHERE 
		op.Name LIKE 'GEPB_BillType_Post_%'
		AND 
		bu.Date BETWEEN @FromDate AND @EndDate
		AND 
		bi.BuGUID IS NULL
		AND
		bu.IsPosted = 0

	DECLARE 
		@b_cursor CURSOR,
		@BuGUID UNIQUEIDENTIFIER, 
		@bGenerate BIT,
		@bPost BIT

	SET @b_cursor = CURSOR FAST_FORWARD FOR 
		SELECT BuGuid, bGenerate, bPost
		FROM 
			#bills
		ORDER BY 
			BuDate, Branch, TypeGUID, BuNumber

	BEGIN TRAN 

	EXEC @Return = prcMaintain_GenAndPost_Prepare
	IF @Return != 0
		GOTO exitMe	

	OPEN @b_cursor FETCH NEXT FROM @b_cursor INTO @BuGUID, @bGenerate, @bPost
	WHILE @@FETCH_STATUS = 0
	BEGIN 
		IF @bGenerate = 1
		BEGIN 
			EXEC prcBill_GenEntry @BuGuid
		END 
		IF @bPost = 1 
		BEGIN 
			EXEC @Return = prcBill_Post1 @BuGuid, 1
			IF @Return != 0
				GOTO exitMe	
		END 
		FETCH NEXT FROM @b_cursor INTO @BuGUID, @bGenerate, @bPost
	END CLOSE @b_cursor DEALLOCATE @b_cursor

	EXEC @Return = prcMaintain_GenAndPost_Finish

	COMMIT TRAN 

	exitMe:
		IF @@TRANCOUNT != 0
			ROLLBACK TRAN
		EXEC prc_SJ_Finalize
################################################################
CREATE PROC prc_SJ_ManRePriceBills
	@TaskID UNIQUEIDENTIFIER 
AS 
	SET NOCOUNT ON 
	
	IF ISNULL(@TaskID, 0x0) = 0x0
	BEGIN 
		RAISERROR (N'No task is passed.', 16, 1) 
		RETURN 
	END  
	CREATE TABLE #Options([Name] NVARCHAR(250), [Value] NVARCHAR(250))

	EXEC prc_SJ_FillOptions @TaskID
	
	DECLARE 
		@StageCount	INT,
		@IsFromStartDate BIT,
		@FromDate DATE,
		@EndDate DATE
		
	SET @StageCount = ISNULL((SELECT TOP 1 CAST(Value AS INT) FROM #Options WHERE Name = 'MRB_StageCount'), 0)

	SET @IsFromStartDate = ISNULL((SELECT TOP 1 CAST(Value AS BIT) FROM #Options WHERE Name = 'MRB_IsFromStartDate'), 1) 
	SET @EndDate = GETDATE()
	IF @IsFromStartDate = 1
	BEGIN
		SET @FromDate = ISNULL((SELECT TOP 1 CAST(Value AS DATETIME) FROM op000 WHERE Name = 'AmnCfg_FPDate'), GETDATE())
	END ELSE BEGIN 
		DECLARE @SchedualType INT 
		SET @SchedualType = dbo.fn_SJ_GetScheduleType(@TaskID)
		IF (@SchedualType = -1)
		BEGIN 
			RAISERROR (N'No step attatched the task.', 16, 1) 
			RETURN 
		END 
		SET @FromDate = (
			CASE @SchedualType 
				WHEN 8 /*W*/ THEN DATEADD (WEEK, -1, GETDATE()) 
				WHEN 16 /*M*/ THEN DATEADD (MONTH, -1, GETDATE()) 
				ELSE DATEADD (DAY, -1, GETDATE()) 
			END)
	END 

	EXEC  prcManufac_RePriceBills @FromDate,@EndDate,1,@StageCount
##############################################################################################
CREATE PROC prc_SJ_ManReGenBills
	@TaskID UNIQUEIDENTIFIER 
AS 
	SET NOCOUNT ON 
	
	IF ISNULL(@TaskID, 0x0) = 0x0
	BEGIN 
		RAISERROR (N'No task is passed.', 16, 1) 
		RETURN 
	END  
	CREATE TABLE #Options([Name] NVARCHAR(250), [Value] NVARCHAR(250))

	EXEC prc_SJ_FillOptions @TaskID
	
	DECLARE 
		@PriceType	INT,
		@IsFromStartDate BIT,
		@FromDate DATE,
		@EndDate DATE
		
	SET @PriceType = ISNULL((SELECT TOP 1 CAST(Value AS INT) FROM #Options WHERE Name = 'MRG_PricePolicy'), 0)

	SET @IsFromStartDate = ISNULL((SELECT TOP 1 CAST(Value AS BIT) FROM #Options WHERE Name = 'MRG_IsFromStartDate'), 1) 
	SET @EndDate = GETDATE()
	IF @IsFromStartDate = 1
	BEGIN
		SET @FromDate = ISNULL((SELECT TOP 1 CAST(Value AS DATETIME) FROM op000 WHERE Name = 'AmnCfg_FPDate'), GETDATE())
	END ELSE BEGIN 
		DECLARE @SchedualType INT 
		SET @SchedualType = dbo.fn_SJ_GetScheduleType(@TaskID)
		IF (@SchedualType = -1)
		BEGIN 
			RAISERROR (N'No step attatched the task.', 16, 1) 
			RETURN 
		END 
		SET @FromDate = (
			CASE @SchedualType 
				WHEN 8 /*W*/ THEN DATEADD (WEEK, -1, GETDATE()) 
				WHEN 16 /*M*/ THEN DATEADD (MONTH, -1, GETDATE()) 
				ELSE DATEADD (DAY, -1, GETDATE()) 
			END)
	END 

	EXEC  prcManufac_reGenBills @FromDate,@EndDate,@PriceType
##############################################################################################
CREATE PROC prc_SJ_ShrinkDB
	@TaskID UNIQUEIDENTIFIER 
AS 
	SET NOCOUNT ON 
	
	IF ISNULL(@TaskID, 0x0) = 0x0
	BEGIN 
		RAISERROR (N'No task is passed.', 16, 1) 
		RETURN 
	END  
	DECLARE @Return INT 
	EXEC @Return = prc_SJ_Init
	IF @Return <> 0
		RETURN 
	
	CREATE TABLE #Options([Name] NVARCHAR(250), [Value] NVARCHAR(250)) 
	EXEC prc_SJ_FillOptions @TaskID

	DECLARE 
		@IsChangeCompressionType BIT,
		@CompressionType INT

	SET @IsChangeCompressionType = ISNULL((SELECT TOP 1 CAST(Value AS BIT) FROM #Options WHERE Name = 'SHRINK_IsChangeCompressionType'), 0) 
	
	BEGIN TRAN 
	IF ISNULL(@IsChangeCompressionType, 0) = 1 
	BEGIN
		SET @CompressionType = ISNULL((SELECT TOP 1 CAST(Value AS INT) FROM #Options WHERE Name = 'SHRINK_CompressionType'), 0) 
		EXEC @Return = prcDB_CompressData @CompressionType
	END 

	IF @Return != 0
		GOTO exitMe	
	COMMIT TRAN 

	EXEC prcDB_Shrink 

	exitMe:
		IF @@TRANCOUNT != 0
			ROLLBACK TRAN
		EXEC prc_SJ_Finalize		
#################################################################################################
CREATE PROC prc_SJ_Emptying_Temporary_Tables
	@TaskID UNIQUEIDENTIFIER 
AS 
	SET NOCOUNT ON 
	
	IF ISNULL(@TaskID, 0x0) = 0x0
	BEGIN 
		RAISERROR (N'No task is passed.', 16, 1) 
		RETURN 
	END  
	DECLARE @Return INT 
	EXEC @Return = prc_SJ_Init
	IF @Return <> 0
		RETURN 
	
	DECLARE 
		@valueTempTemporaryTables NVARCHAR(MAX)
		SET @valueTempTemporaryTables = ISNULL((SELECT TOP 1 Value FROM ScheduledJobOptions000 WHERE Name = 'EMPTYTEMPORARYTABLES_VectorTempTables'), ';0;') 	
		EXEC prcEmptingTemporaryTables @valueTempTemporaryTables
#################################################################################################
CREATE PROC prc_SJ_RegenerateCostEntries
	@TaskID UNIQUEIDENTIFIER 
AS 
	SET NOCOUNT ON 

	IF ISNULL(@TaskID, 0x0) = 0x0
	BEGIN 
		RAISERROR (N'No task is passed.', 16, 1) 
		RETURN 
	END  
	
	DECLARE @Return INT 
	EXEC @Return = prc_SJ_Init
	IF @Return <> 0
		RETURN 
	
	CREATE TABLE #Options([Name] NVARCHAR(250), [Value] NVARCHAR(250)) 
	EXEC prc_SJ_FillOptions @TaskID
	IF NOT EXISTS (SELECT * FROM #Options)
	BEGIN
		RAISERROR (N'No options found.', 16, 1) 
		RETURN 
	END 
	IF NOT EXISTS (SELECT * FROM #Options WHERE Name LIKE 'REGCOSTE_BillType_%')
	BEGIN
		RAISERROR (N'No bill types found.', 16, 1) 
		RETURN 
	END 
	
	DECLARE 
		@SrcGUID				UNIQUEIDENTIFIER,  
		@FromDate				DATE,  
		@EndDate				DATE,  
		@IsFromStartDate		BIT,
		@UseOutBalanceAVGPrice	BIT 

	SET @SrcGUID = NEWID()
	INSERT INTO RepSrcs(IdTbl, IdType, IdSubType)
	SELECT @SrcGUID, CAST(Value AS UNIQUEIDENTIFIER), 2 /*BILLS*/
	FROM #Options 
	WHERE Name LIKE 'REGCOSTE_BillType_%' 

	DECLARE @FirstPeriodDate DATE 
	SET @FirstPeriodDate = ISNULL((SELECT TOP 1 CAST(Value AS DATETIME) FROM op000 WHERE Name = 'AmnCfg_FPDate' AND Type = 0), GETDATE())

	SET @IsFromStartDate = ISNULL((SELECT TOP 1 CAST(Value AS BIT) FROM #Options WHERE Name = 'REGCOSTE_IsFromStartDate'), 1) 
	IF @IsFromStartDate = 1
	BEGIN
		SET @FromDate = @FirstPeriodDate
		SET @EndDate = GETDATE()
	END ELSE BEGIN 
		DECLARE @SchedualType INT 
		SET @SchedualType = dbo.fn_SJ_GetScheduleType(@TaskID)
		IF (@SchedualType = -1)
		BEGIN 
			RAISERROR (N'No step attatched the task.', 16, 1) 
			RETURN 
		END 
		SET @EndDate = (
			CASE @SchedualType 
				WHEN 8 /*W*/ THEN DATEADD (DAY, -1, GETDATE()) 
				WHEN 16 /*M*/ THEN DATEADD(DAY, -DAY(GETDATE()), GETDATE())
				ELSE DATEADD (DAY, -1, GETDATE()) 
			END)

		SET @FromDate = (
			CASE @SchedualType 
				WHEN 8 /*W*/ THEN DATEADD (WEEK, -1, GETDATE()) 
				WHEN 16 /*M*/ THEN DATEADD(DAY, -DAY(@EndDate) + 1, @EndDate)
				ELSE @EndDate
			END)
	END 
	IF @EndDate < @FromDate
		SET @EndDate = @FromDate
	IF @EndDate < @FirstPeriodDate
		RETURN 
	IF @FromDate < @FirstPeriodDate
		SET @FromDate = @FirstPeriodDate
	
	SET @UseOutBalanceAVGPrice = ISNULL((SELECT TOP 1 CAST(Value AS BIT) FROM #Options WHERE Name = 'REGCOSTE_UseOutBalanceAVGPrice'), 0) 
	DECLARE @GCCTAXENABLED BIT = ISNULL((SELECT CAST(value AS BIT) FROM op000 WHERE Name = 'AmnCfg_GCCTaxSystemCountry'), 0) 

	BEGIN TRAN 

		CREATE TABLE #Bills	(
		BuGuid UNIQUEIDENTIFIER,
		BtGuid UNIQUEIDENTIFIER,
		[btName] [NVARCHAR](256) COLLATE ARABIC_CI_AI,
		ceGuid UNIQUEIDENTIFIER,
		buNumber INT)

	INSERT INTO #Bills EXEC prcReGenCostEntriesPrepare @SrcGUID, @FromDate, @EndDate, 0

	EXEC @Return = prcBill_rePost

	IF @Return != 0
		GOTO exitMe	

	DECLARE 
		@b_cursor CURSOR,
		@BuGuid UNIQUEIDENTIFIER,
		@ceGuid UNIQUEIDENTIFIER

	SET @b_cursor = CURSOR FAST_FORWARD FOR SELECT BuGuid, ceGuid FROM #Bills 
	OPEN @b_cursor FETCH NEXT FROM @b_cursor INTO @BuGuid, @ceGuid
	WHILE @@FETCH_STATUS = 0
	BEGIN 
		IF ((ISNULL(@ceGuid, 0x0) != 0x0))
		BEGIN 
			EXEC prcMReGenCostEntries @ceGuid , @BuGuid, @UseOutBalanceAVGPrice, @GCCTAXENABLED
		END 
		FETCH NEXT FROM @b_cursor INTO @BuGuid, @ceGuid
	END CLOSE @b_cursor DEALLOCATE @b_cursor

	COMMIT TRAN 

	exitMe:
		IF @@TRANCOUNT != 0
			ROLLBACK TRAN
		EXEC prc_SJ_Finalize
#################################################################################################
CREATE PROC prc_SJ_CheckFiles
	@TaskID UNIQUEIDENTIFIER 
AS 
	SET NOCOUNT ON 

	IF ISNULL(@TaskID, 0x0) = 0x0
	BEGIN 
		RAISERROR (N'No task is passed.', 16, 1) 
		RETURN 
	END  
	
	DECLARE @Return INT 
	EXEC @Return = prc_SJ_Init
	IF @Return <> 0
		RETURN 
	
	CREATE TABLE #Options([Name] NVARCHAR(250), [Value] NVARCHAR(250)) 
	EXEC prc_SJ_FillOptions @TaskID
	IF NOT EXISTS (SELECT * FROM #Options)
	BEGIN
		RAISERROR (N'No options found.', 16, 1) 
		RETURN 
	END 
	
	BEGIN TRAN 

	DECLARE @CheckFiles INT = (SELECT Value FROM #Options WHERE NAME = 'CHECKTYPE_CHECKFRILES')
	DELETE FROM #Options WHERE Name = 'CHECKTYPE_CHECKFRILES'

	DECLARE 
		@b_cursor CURSOR,
		@SpName Nvarchar(250)

	SET @b_cursor = CURSOR FAST_FORWARD FOR SELECT Name FROM #Options WHERE [Value] = '1'
	OPEN @b_cursor FETCH NEXT FROM @b_cursor INTO @SpName
	WHILE @@FETCH_STATUS = 0
	BEGIN 
		EXEC sp_executesql @SpName , N'@Correct INT', @Correct = @CheckFiles 
		FETCH NEXT FROM @b_cursor INTO @SpName
	END 
	CLOSE @b_cursor DEALLOCATE @b_cursor

	COMMIT TRAN 

	EXEC prc_SJ_Finalize
#################################################################################################
#END
