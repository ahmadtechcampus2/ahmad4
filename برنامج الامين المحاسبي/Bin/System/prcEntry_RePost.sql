################################################################################
CREATE PROC prcEntry_rePost
@LgGuid UNIQUEIDENTIFIER=0x0
AS 
/*  
This method:  
	- is responsible for updating all ac balances an NSons depending on posted entries.  
	- is called usually during maintenance stages.  
	- resets balances to 0 after disabling ac triggers. thus, resetting parents. 
	- updates debit, credit and NSons from en, wich will recurslively go to all parents.  
*/  
	SET NOCOUNT ON  
	BEGIN TRAN
	SELECT Guid,Debit,Credit INTO #ac FROM ac000  
	
	EXEC prcDisableTriggers 'ac000' 
	EXEC prcDisableTriggers 'cu000' 

	UPDATE [ac000] SET  
		[Debit] = 0,  
		[Credit] = 0 
	UPDATE [cu000] SET  
		[Debit] = 0,  
		[Credit] = 0 
	UPDATE [co000] SET  
		[Debit] = 0,  
		[Credit] = 0 
	EXEC [prcEntry_post] 
	DECLARE @Parms NVARCHAR(2000)
	SET @Parms = ''
	--EXEC prcCreateMaintenanceLog 7,@LgGuid OUTPUT,@Parms 
	CREATE TABLE [#AccTmp]( [GUID] [UNIQUEIDENTIFIER], [Debit] [FLOAT], [Credit] [FLOAT], [LEVEL] [INT])
	INSERT INTO [#AccTmp] SELECT [ac].[ParentGuid], SUM( [ac].[Debit]), SUM( [ac].[Credit]), 0 FROM [ac000][ac] WHERE [ac].[Debit] <> 0 or [ac].[Credit] <> 0 GROUP BY [ac].[ParentGuid]
	DECLARE @Continue [INT], @Lv [INT]
	SET @Lv = 0    
	SET @Continue = 1    
	WHILE @Continue <> 0  
	BEGIN    
		SET @Lv = @Lv + 1
		INSERT INTO [#AccTmp] SELECT [ac].[ParentGuid], SUM( [ac].[Debit]), SUM( [ac].[Credit]), @Lv FROM [#AccTmp][acTmp] INNER JOIN [ac000][ac] on [acTmp].[Guid] = [ac].[Guid] WHERE [acTmp].[Level] = @Lv - 1 GROUP BY [ac].[ParentGuid] 
		SET @Continue = @@ROWCOUNT     
	END
	UPDATE [ac] SET [Debit] = [tmp].[Debit], [Credit]= [tmp].[Credit]
	FROM [ac000][ac] inner join [#AccTmp][tmp] on [tmp].[Guid] = [ac].[Guid]

	ALTER TABLE [ac000] ENABLE TRIGGER ALL
	ALTER TABLE [cu000] ENABLE TRIGGER ALL

	SELECT NEWID() Gu,@LgGuid LgGuid,2 tp,GETDATE() dt,ac.Guid g2,CAST(0x10017000 AS INT) flag,CAST(0x00 AS [UNIQUEIDENTIFIER]) GGG,0 TTT
		,ac.Code + '-' + ac.Name
		+CASE WHEN ABS(ac.Debit - a.Debit) > dbo.fnGetZeroValuePrice() THEN 'debit ' + CAST(ac.Debit AS  NVARCHAR(100)) + ':' +  CAST(a.Debit AS  NVARCHAR(100)) ELSE '' END
		+ CASE WHEN ABS(ac.Credit - a.Credit) > dbo.fnGetZeroValuePrice() THEN 'avgPrice ' + CAST(ac.Credit AS  NVARCHAR(100)) + ':' +  CAST(a.Credit AS  NVARCHAR(100)) ELSE '' END FDSE
	INTO #QQQ
	FROM ac000 ac INNER JOIN #ac a ON a.Guid = ac.Guid
	WHERE ABS(ac.Debit - a.Debit) > dbo.fnGetZeroValuePrice() OR  ABS(ac.Credit - a.Credit) > dbo.fnGetZeroValuePrice()
	
	INSERT INTO MaintenanceLogItem000 ( GUID, ParentGUID, Severity, LogTime, ErrorSourceGUID1, ErrorSourceType1, ErrorSourceGUID2, ErrorSourceType2, Notes)
		SELECT * FROM #QQQ
		EXEC prcCloseMaintenanceLog @LgGuid  
	COMMIT TRAN  
################################################################################
#END
