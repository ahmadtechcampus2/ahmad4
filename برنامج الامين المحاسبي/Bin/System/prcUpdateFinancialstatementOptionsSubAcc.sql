#########################################################
CREATE PROCEDURE prcUpdateFinancialstatementOptionsSubAcc
	@AccGuid UNIQUEIDENTIFIER,
	@SecUser INT
AS
	SET NOCOUNT ON
	DECLARE @IncomeType INT,@BalsheetGuid UNIQUEIDENTIFIER,@CashFlowType INT, @FinalAccGuid UNIQUEIDENTIFIER
	DECLARE @UserGuid UNIQUEIDENTIFIER,@HostName NVARCHAR(100)
	SELECT @IncomeType = IncomeType,@BalsheetGuid = BalsheetGuid,@CashFlowType = CashFlowType, @FinalAccGuid = FinalGUID
	FROM [ac000] WHERE [Guid] = @AccGuid
	SELECT [Guid] INTO #ac FROM dbo.fnGetAccountsList(@AccGuid,1) WHERE [Guid] <> @AccGuid
	UPDATE [ac] SET IncomeType = @IncomeType,BalsheetGuid = @BalsheetGuid,CashFlowType = @CashFlowType, FinalGUID = @FinalAccGuid
	FROM [ac000] ac INNER JOIN #ac a ON a.Guid = ac.Guid 
	WHERE [Security] <= @SecUser
	
	
	IF EXISTS(SELECT * from op000 where name = 'AmnCfg_UseLogging' AND [Value] = 1)
	BEGIN
		SET @UserGuid = [dbo].[fnGetCurrentUserGUID]()
		SET @HostName = HOST_NAME()

		INSERT INTO LoG000(guid, UserGUID, Computer, Operation, DrvRID, RecGuid, LogTime, Notes, OperationType, RecContent)
		SELECT newID(), @UserGuid, @HostName, 1024, 0, a.Guid, GetDate(), ac.Code + '-' + ac.Name, 3,
			dbo.SaveReportLog(a.GUID, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 1, 0x0, GETDATE(), GETDATE())
		FROM [ac000] ac INNER JOIN #ac a ON a.Guid = ac.Guid 
		WHERE [Security] <= @SecUser
	END
######################################################### 
#END
