##################################################################################
CREATE PROC prcImportBalanceSheetAccounts
(
	@CycleGuid UNIQUEIDENTIFIER
)
AS
BEGIN
	SET NOCOUNT ON

	DECLARE @database NVARCHAR(100)
	DECLARE @openingDate DATETIME
	SELECT @database = DatabaseName, @openingDate = FirstPeriod FROM FinancialCycleInfo000 WHERE [Guid] = @CycleGuid
	
	DECLARE @OpeningEntryType UNIQUEIDENTIFIER   
	SET @OpeningEntryType = (SELECT [Value] FROM op000 WHERE [Name] ='FSCfg_OpeningEntryType')

	Declare @sql NVARCHAR(MAX) = '

	INSERT INTO FABalanceSheetAccount000 
	SELECT ''' + CAST(@CycleGuid AS NVARCHAR(100)) + ''', AC.[GUID], AC.Code, AC.Name, AC.LatinName, AC.ParentGUID, FA.IncomeType, AC.IncomeType, AC.CashFlowType, AC.BalsheetGuid, 0, FA.IncomeType, AC.IncomeType, AC.BalsheetGuid
	FROM [' + @database + '].dbo.ac000 AC INNER JOIN [' + @database + '].dbo.ac000 FA ON AC.FinalGUID = FA.[Guid]
	WHERE AC.Type = 1
	-------------------------------------------
	INSERT INTO FACorrectiveAccount000
	SELECT ''' + CAST(@CycleGuid AS NVARCHAR(100)) + ''', CAC.AccountGuid, CAC.Destination, CAC.OperationalAffect
	FROM [' + @database + '].dbo.CorrectiveAccount000 CAC
	-------------------------------------------
	INSERT INTO FABalanceSheetAccountBalance000 
	SELECT ''' + CAST(@CycleGuid AS NVARCHAR(100)) + ''', AccountGuid, ''' + CAST(@openingDate AS NVARCHAR(100)) + ''', ISNULL(BAL.Balance, -1) 
	FROM
		(SELECT AccountGUID, SUM(EN.Debit - EN.Credit) Balance
		FROM [' + @database + '].dbo.en000 EN INNER JOIN [' + @database + '].dbo.ce000 CE ON EN.ParentGUID = CE.[GUID]
		WHERE CE.TypeGUID = ''' + CAST(@OpeningEntryType AS NVARCHAR(100)) + '''
		GROUP BY AccountGUID) BAL
	--------------------------------------------
			
	INSERT INTO FABalanceSheetAccountBalance000 
	SELECT ''' + CAST(@CycleGuid AS NVARCHAR(100)) + ''', AccountGuid, EOMONTH(DATEFROMPARTS(BAL.Year, BAL.Month, 1)), ISNULL(BAL.Balance, -1) 
	FROM
		(SELECT AccountGUID, DATEPART(Year, EN.[Date]) Year, DATEPART(Month, EN.[Date]) Month, SUM(EN.Debit - EN.Credit) Balance
		FROM [' + @database + '].dbo.en000 EN INNER JOIN [' + @database + '].dbo.ce000 CE ON EN.ParentGUID = CE.[GUID]
		WHERE CE.TypeGUID <> ''' + CAST(@OpeningEntryType AS NVARCHAR(100)) + '''
		GROUP BY AccountGUID, DATEPART(Year, EN.[Date]), DATEPART(Month, EN.[Date])) BAL'

	EXEC(@sql)
	-----------------------------------------------------------------------------
	UPDATE FABalanceSheetAccount000 
	SET FSType = FA.IncomeType, IncomeType = AC.IncomeType, CashFlowType = AC.CashFlowType, ClassificationGuid = AC.BalsheetGuid, Known = 1
	FROM ac000 AC INNER JOIN ac000 FA ON FA.[GUID] = AC.FinalGUID
	WHERE AccountGUID = AC.[GUID] AND FABalanceSheetAccount000.IncomeType <> 11

	UPDATE FABalanceSheetAccount000 SET ClassificationGuid = 0X0
	WHERE ClassificationGuid NOT IN (SELECT [GUID] FROM BalSheet000)

END
##################################################################################
CREATE PROC prcDeleteBalanceSheetAccounts
(
	@CycleGuid UNIQUEIDENTIFIER
)
AS
BEGIN
	SET NOCOUNT ON

	DELETE FinancialCycleInfo000 WHERE [Guid] = @CycleGuid
	DELETE FABalanceSheetAccount000 WHERE CycleGuid = @CycleGuid
	DELETE FABalanceSheetAccountBalance000 WHERE CycleGuid = @CycleGuid
	DELETE FACorrectiveAccount000 WHERE CycleGuid = @CycleGuid
END
##################################################################################
CREATE FUNCTION fnGetImportedCycleAccounts
(
	@CycleGuid UNIQUEIDENTIFIER
)
RETURNS @result Table
(
	[Guid]	UNIQUEIDENTIFIER,
	[Code]	NVARCHAR(255),
	[Name]	NVARCHAR(255),
	[LatinName]	NVARCHAR(255)
) 
AS
BEGIN
	INSERT INTO @result
	SELECT AccountGUID, Code, Name, LatinName
	FROM FABalanceSheetAccount000
	WHERE ISNULL(@CycleGuid, 0X0) = 0X0 OR CycleGuid = @CycleGuid

	RETURN
END
##################################################################################
CREATE PROCEDURE prcDeleteCurrentBalanceSheetAccounts
AS
BEGIN

	DECLARE @CycleGuid UNIQUEIDENTIFIER = (SELECT [Guid] FROM FinancialCycleInfo000 WHERE DatabaseName = DB_NAME())

	EXEC prcDeleteBalanceSheetAccounts @CycleGuid
END
##################################################################################
#END