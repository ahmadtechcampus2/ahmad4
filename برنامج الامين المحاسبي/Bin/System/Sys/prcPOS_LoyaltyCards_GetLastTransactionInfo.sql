#######################################################################################
CREATE PROC prcPOS_LoyaltyCards_GetLastTransactionInfo
	@LoyaltyCardGUID	UNIQUEIDENTIFIER 
AS 
	SET NOCOUNT ON 

	CREATE TABLE #Result ( [LastUseDate] DATETIME, [BranchName] NVARCHAR(500), [BranchLatinName] NVARCHAR(500))

	DECLARE 
		@CentralizedDBName			NVARCHAR(250),
		@ErrorNumber				INT

	SELECT TOP 1
		@ErrorNumber =			ISNULL(ErrorNumber, 0),
		@CentralizedDBName =	ISNULL(CentralizedDBName, '')
	FROM 
		dbo.fnPOS_LoyaltyCards_CheckSystem (0x0)

	IF @ErrorNumber > 0 
		GOTO exitproc
			
    DECLARE @CmdText NVARCHAR(MAX)
	SET @CmdText = ' INSERT INTO #Result SELECT TOP 1 orderDate, BranchName, BranchLatinName FROM ' + @CentralizedDBName + 'POSLoyaltyCardTransaction000
		WHERE LoyaltyCardGUID = '''  + CAST(@LoyaltyCardGUID AS VARCHAR(100)) + '' + ' ORDER BY orderDate '''
	
	EXEC (@CmdText)


	exitProc:
		SELECT @ErrorNumber AS ErrorNumber
		SELECT * FROM #Result
#######################################################################################
#END