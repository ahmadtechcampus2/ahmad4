##################################################################################
CREATE FUNCTION fnGetImportedCycleAccountsList
(
	@CycleGuid UNIQUEIDENTIFIER,
	@ParentAccount UNIQUEIDENTIFIER
)
RETURNS @result Table
(
	[Guid]	UNIQUEIDENTIFIER
) 
AS
BEGIN

	IF ISNULL(@ParentAccount, 0X0) = 0X0
	BEGIN
		INSERT INTO @result
		SELECT AccountGUID FROM FABalanceSheetAccount000
		WHERE CycleGuid = @CycleGuid

		RETURN
	END;

	WITH ParentAccounts ([Guid])
	AS
	(
	-- Anchor member definition
		SELECT [AccountGUID] 
		FROM FABalanceSheetAccount000
		WHERE CycleGuid = @CycleGuid AND AccountGUID = @ParentAccount
		UNION ALL
	-- Recursive member definition
		SELECT AccountGUID
		FROM FABalanceSheetAccount000 AC 
		INNER JOIN ParentAccounts ON AC.ParentGuid = ParentAccounts.[Guid]
		WHERE CycleGuid = @CycleGuid 
	)
	-- Statement that executes the CTE
	INSERT INTO @result
	SELECT [Guid]
	FROM ParentAccounts

	RETURN
END
################################################################################
CREATE PROCEDURE prcPreviousYearsWorkSheet
	@CycleGuid			UNIQUEIDENTIFIER = 0x0,
	@ParentAccount		UNIQUEIDENTIFIER = 0x0,
	@FromPeriod			DATETIME = '1-1-1980',
	@ToPeroid			DATETIME = '1-1-1980',
	@ShowParents		    BIT = 0
	
AS
	SET NOCOUNT ON

	SET @ToPeroid = EOMONTH(@ToPeroid)

	DECLARE @openingDate DATETIME
	SELECT @openingDate = FirstPeriod FROM FinancialCycleInfo000 CI
	WHERE CI.Guid = @CycleGuid

	CREATE TABLE [#RESULT]
	(
		CycleGuid					UNIQUEIDENTIFIER,
		[AccountGuid]				UNIQUEIDENTIFIER,
		[ParentGuid]				UNIQUEIDENTIFIER,
		[Code]				NVARCHAR(225) COLLATE ARABIC_CI_AI,
		[Name]				NVARCHAR(225) COLLATE ARABIC_CI_AI,
		[FSType]			        INT,
		[FSClassification]			INT,
		[CashFlow]					INT,
		[ClassificationDetailsGuid] UNIQUEIDENTIFIER,
		[ClassificationDetails]		NVARCHAR(225) COLLATE ARABIC_CI_AI,
		[Known]						BIT,
		[Balance]					FLOAT,
		[Period]					INT,
		[Level]						INT,
		[Nsons]						INT
	)
	-------------------------------------------------------------------------------------
	DECLARE @accountGuid UNIQUEIDENTIFIER = (SELECT TOP 1 Guid FROM fnGetImportedCycleAccountsList(@CycleGuid, @ParentAccount)); 

	With CTE as
	(
		Select EOMONTH(@FromPeriod) [DATE]
		UNION ALL
		Select DATEADD(MONTH, 1, [DATE]) from CTE
		Where [DATE] < @ToPeroid
	)
	INSERT INTO #RESULT
	SELECT AC.CycleGuid, AC.AccountGUID, AC.ParentGuid, AC.Code, AC.Name, AC.FSType, AC.IncomeType, 
		AC.CashFlowType, CD.[GUID], CD.Name , AC.Known, 0 Balance,
		CASE WHEN C.[Date] IS NULL OR C.[Date] = EOMONTH(@FromPeriod) THEN 0 ELSE datediff(MONTH, @FromPeriod, ISNULL(C.[Date], @FromPeriod))  + 1 END, 0, 0 
	FROM
	CTE C INNER JOIN FABalanceSheetAccount000 AC
	ON AC.AccountGUID = @accountGuid
	LEFT JOIN BalSheet000 CD ON AC.ClassificationGuid = CD.[GUID]
	-----------------------------------------------------------------
	INSERT INTO #RESULT
	SELECT AC.CycleGuid, AC.AccountGUID, AC.ParentGuid, AC.Code, AC.Name, AC.FSType, AC.IncomeType, 
		AC.CashFlowType, CD.[GUID], CD.Name , AC.Known, ISNULL(FAB.Balance, 0) Balance,
		CASE WHEN FAB.[Date] IS NULL OR [Date] = @openingDate THEN 0 ELSE datediff(MONTH, @FromPeriod, ISNULL(FAB.[Date], @FromPeriod))  + 1 END, 0, 0 
	FROM
	FABalanceSheetAccount000 AC INNER JOIN fnGetImportedCycleAccountsList(@CycleGuid, @ParentAccount) F
	ON AC.AccountGUID = F.[Guid]
	LEFT JOIN FABalanceSheetAccountBalance000 FAB ON FAB.AccountGuid = AC.AccountGUID
	LEFT JOIN BalSheet000 CD ON AC.ClassificationGuid = CD.[GUID]
	WHERE AC.CycleGuid = @CycleGuid
	AND ([Date] IS NULL OR ([DATE] >= @FromPeriod AND [DATE] <= @ToPeroid))
	-----------------------------------------------------------------
	UPDATE #Result SET [nsons] = [count]
	FROM  (   
			SELECT  
				[parentguid],  
				count(*) [count]
			FROM  
				[#result]       
			WHERE   
				CycleGuid = @CycleGuid
			GROUP BY  
				[parentguid]  
			) [sons] -- sum sons  
	WHERE 	#result.accountguid = sons.parentguid
	-----------------------------------------------------------------------------
	SELECT * FROM #RESULT
	WHERE (@ShowParents = 1 OR [Nsons] = 0) 
###################################################################################
CREATE PROCEDURE prcAccountReclassification
	@CycleGuid			UNIQUEIDENTIFIER = 0x0,
	@AccountGuid		UNIQUEIDENTIFIER = 0x0,
	@FSType				INT = 0,
	@FClassification	INT = 0,
	@CashFlow			INT = 0,
	@ClassDetails		UNIQUEIDENTIFIER = 0x0,
	@UpdateChild		BIT = 0
AS
	SET NOCOUNT ON

	IF(@UpdateChild = 0)
	BEGIN
		UPDATE FABalanceSheetAccount000 
		SET FSType = @FSType, IncomeType = @FClassification, CashFlowType = @CashFlow, ClassificationGuid = @ClassDetails
		WHERE CycleGuid = @CycleGuid AND AccountGUID = @AccountGuid AND Known = 0
	END
	ELSE
	BEGIN
		UPDATE FABalanceSheetAccount000 
		SET FSType = @FSType, IncomeType = @FClassification, CashFlowType = @CashFlow, ClassificationGuid = @ClassDetails
		FROM fnGetImportedCycleAccountsList(@CycleGuid, @AccountGuid) F
		WHERE CycleGuid = @CycleGuid AND AccountGUID = F.[Guid] AND Known = 0
	END
###################################################################################
CREATE PROCEDURE prcFinancialStatementsReclassificationAffect
	@CycleGuid			UNIQUEIDENTIFIER = 0x0
AS
BEGIN
	SET NOCOUNT ON
	
	DECLARE @affectedAccounts Table
	(
		[AccountGuid]				UNIQUEIDENTIFIER,
		[PrevFSType]			    INT,
		[PrevFSClassification]		INT,
		[FSType]			        INT,
		[FSClassification]			INT,
		ClassDetails				NVARCHAR(225) COLLATE ARABIC_CI_AI,
		PrevClassDetails			NVARCHAR(225) COLLATE ARABIC_CI_AI,
		[Balance]					FLOAT
	)

	INSERT INTO @affectedAccounts
	SELECT Account.AccountGUID, PrevFSType, CASE PrevIncomeType WHEN 0 THEN -1 * PrevFSType ELSE PrevIncomeType END,
		FSType, CASE IncomeType WHEN 0 THEN -1 * FSType ELSE IncomeType END,
		ISNULL(BS.Name, ''), ISNULL(PrevBS.Name, ''), SUM(ISNULL(Balance, 0)) 
	FROM FABalanceSheetAccount000 Account
		LEFT JOIN FABalanceSheetAccountBalance000 Balance ON Account.AccountGUID = Balance.AccountGuid 
		AND Balance.CycleGuid = Account.CycleGuid
		LEFT JOIN BalSheet000 BS ON BS.GUID = Account.ClassificationGuid
		LEFT JOIN BalSheet000 PrevBS ON PrevBS.GUID = Account.PrevClassificationGuid
	WHERE Account.CycleGuid = @CycleGuid AND 
		(PrevFSType <> FSType or PrevIncomeType <> IncomeType)
	GROUP BY Account.AccountGUID, PrevFSType, PrevIncomeType, FSType, IncomeType, BS.Name, PrevBS.Name
	---------------------------------------------------------------------------------------------
	DECLARE @CLASSIFICATIONS INT = 1
	DECLARE @CLASSIFICATION_DETAILS INT = 2
	DECLARE @ACCOUNT INT = 3
	---------------------------------------------------------------------------------------------
	DECLARE @classification Table
	(
		ClassificationGuid			UNIQUEIDENTIFIER DEFAULT NEWID(),
		Classification				INT
	)

	INSERT INTO @classification (Classification)
	SELECT DISTINCT PrevFSType
	FROM @affectedAccounts

	INSERT INTO @classification (Classification)
	SELECT DISTINCT FSType FROM @affectedAccounts
	WHERE FSType NOT IN (SELECT Classification FROM @classification)
	---------------------------------------------------------------------------------------------
	DECLARE @classificationDetails Table
	(
		[ClassificationGuid]		UNIQUEIDENTIFIER,
		ClassificationDetailsGuid	UNIQUEIDENTIFIER DEFAULT NEWID(),
		Classification				INT,
		ClassificationDetails		INT
	)

	INSERT INTO @classificationDetails (ClassificationGuid, Classification, ClassificationDetails)
	SELECT DISTINCT C.ClassificationGuid, Account.PrevFSType, Account.PrevFSClassification
	FROM @affectedAccounts Account INNER JOIN @classification C ON Account.PrevFSType = C.Classification 

	INSERT INTO @classificationDetails (ClassificationGuid, Classification, ClassificationDetails)
	SELECT DISTINCT C.ClassificationGuid, Account.FSType, Account.FSClassification
	FROM @affectedAccounts Account INNER JOIN @classification C ON Account.FSType = C.Classification 
	WHERE Account.FSClassification NOT IN (SELECT ClassificationDetails FROM @classificationDetails)
	---------------------------------------------------------------------------------------------
	CREATE TABLE [#RESULT]
	(
		[ClassificationGuid]		UNIQUEIDENTIFIER,
		[ParentClassificationGuid]	UNIQUEIDENTIFIER,
		[Code]				NVARCHAR(225) COLLATE ARABIC_CI_AI,
		[Name]				NVARCHAR(225) COLLATE ARABIC_CI_AI,
		[FromFSType]			        INT,
		[FromFSClassification]			INT,
		FromClassDetails				NVARCHAR(225) COLLATE ARABIC_CI_AI,
		[ToFSType]						INT,
		[ToFSClassification]			INT,
		ToClassDetails					NVARCHAR(225) COLLATE ARABIC_CI_AI,
		[Known]							BIT,
		[FromBalance]					FLOAT,
		[ToBalance]						FLOAT,
		[Type]							INT
	)

	INSERT INTO #RESULT 
	SELECT ClassificationGuid, 0x0, '', '', Classification, 0, '', 0, 0, '', 0, 0, 0 , @CLASSIFICATIONS 
	FROM @classification
	--------------------------------------------------------------------------------------
	INSERT INTO #RESULT
	SELECT ClassificationDetailsGuid, ClassificationGuid, '', '', Classification, ClassificationDetails, '', 0, 0, '', 0, 0, 0 , @CLASSIFICATION_DETAILS 
	FROM @classificationDetails
	----------------------------------------------------------------------------------------
	INSERT INTO #RESULT
	SELECT NEWID(), CD.ClassificationDetailsGuid, CODE, ACCOUNT.NAME, BALANCE.PrevFSType, BALANCE.PrevFSClassification, Balance.PrevClassDetails,
	BALANCE.FSType, BALANCE.FSClassification, BALANCE.ClassDetails, Known, -1 * ABS(Balance), 0, @ACCOUNT
	FROM @affectedAccounts BALANCE INNER JOIN FABalanceSheetAccount000 ACCOUNT ON ACCOUNT.AccountGUID = Balance.AccountGuid
	INNER JOIN @classificationDetails CD ON Balance.PrevFSClassification = CD.ClassificationDetails
	WHERE ACCOUNT.CycleGuid = @CycleGuid
	------------------------------------------------------------------------------------------
	INSERT INTO #RESULT
	SELECT NEWID(), CD.ClassificationDetailsGuid, CODE, ACCOUNT.NAME, BALANCE.FSType, BALANCE.FSClassification, BALANCE.ClassDetails,
	BALANCE.PrevFSType, BALANCE.PrevFSClassification, BALANCE.PrevClassDetails, Known, 0, ABS(Balance), @ACCOUNT
	FROM @affectedAccounts BALANCE INNER JOIN FABalanceSheetAccount000 ACCOUNT ON ACCOUNT.AccountGUID = Balance.AccountGuid
	INNER JOIN @classificationDetails CD ON Balance.FSClassification = CD.ClassificationDetails
	WHERE ACCOUNT.CycleGuid = @CycleGuid
	------------------------------------------------------------------------------------------
	SELECT * FROM #RESULT
END
###################################################################################
#END