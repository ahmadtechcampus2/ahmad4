################################################################################
CREATE PROCEDURE prcWorkSheet
	@FatherAccount		UNIQUEIDENTIFIER = 0x0,
	@StartDate			datetime = '1-1-1980',
	@EndDate			datetime = '1-1-9999',
	@ShowFather		    BIT = 1
	
AS
	SET NOCOUNT ON

	CREATE TABLE [#RESULT]
	(
		[AccountGuid]				UNIQUEIDENTIFIER,
		[ParentGuid]				UNIQUEIDENTIFIER,
		[AccountCode]				NVARCHAR(225) COLLATE ARABIC_CI_AI,
		[AccountName]				NVARCHAR(225) COLLATE ARABIC_CI_AI,
		[Balance]					FLOAT,
		[FSType]			        INT,
		[FSClassification]			INT,
		[CashFlowClassification]	INT,
		[ClassificationDetails]		NVARCHAR(225) COLLATE ARABIC_CI_AI,
		[Level]						INT,
		[Path]						NVARCHAR(225) COLLATE ARABIC_CI_AI,
		[Nsons]						INT
	)
	-------------------------------------------------------------------------------------------
	INSERT INTO #RESULT (AccountGuid, Level, Path)
	SELECT F.GUID, F.Level, F.Path 
	FROM fnGetAccountsList(@FatherAccount,1) AS F
	INNER JOIN ac000 AC ON AC.GUID = F.GUID
	INNER JOIN ac000 FA ON FA.GUID = AC.FinalGUID
	LEFT JOIN BalSheet000 BS ON BS.GUID = AC.BalsheetGuid
	WHERE AC.Type <> 2
	-------------------------------------------------------------------------------------------
	UPDATE #RESULT SET Balance = 0,
			#RESULT.ParentGuid = AC.ParentGUID, 
			AccountName = AC.Name, FSType = FA.IncomeType, 
			AccountCode = AC.Code,
			FSClassification = AC.IncomeType,
			CashFlowClassification = AC.CashFlowType,
			ClassificationDetails = DT.Name,
			[Nsons] = AC.NSons
	FROM ac000 AC INNER JOIN ac000 AS FA ON FA.GUID = AC.FinalGUID
	LEFT JOIN BalSheet000 AS DT ON DT.GUID = AC.BalsheetGuid
	WHERE AC.GUID = #RESULT.AccountGuid 

	-------------------------------------------------------------------------------------------
	UPDATE #RESULT SET #RESULT.Balance = EN.Debit - EN.Credit
	FROM
		(SELECT enAccount GUID, SUM(EN.enDebit) Debit, SUM(EN.enCredit)Credit
		FROM 
			vwCeEn AS EN 
		where en.enDate BETWEEN @StartDate AND @EndDate
		GROUP BY enAccount) EN
	WHERE EN.GUID = #RESULT.AccountGuid	
	-------------------------------------------------------------------------------------------
	DECLARE @level INT
	SET @Level = (SELECT MAX([Level]) FROM #RESULT)  
		WHILE @Level >= 0   
		BEGIN   
			UPDATE #RESULT SET  [Balance] = [SumPrevBalace], [Nsons] = [COUNT]
				FROM  (   
						SELECT  
							[ParentGUID],  
							SUM([Balance]) AS [SumPrevBalace],
							COUNT(*) [COUNT]
						FROM  
							[#RESULT]       
						WHERE   
							[Level] = @Level
						GROUP BY  
							[ParentGUID]  
						) AS [Sons] -- sum sons  
				WHERE 	#RESULT.AccountGuid = SONS.ParentGuid
			SET @Level = @Level - 1  
		END 
  
	IF(@ShowFather = 0)
	BEGIN
		DELETE #RESULT WHERE [Nsons] > 0
	END

	SELECT * FROM #RESULT
	ORDER BY [Path] 
		
###################################################################################
CREATE FUNCTION FnCanDeleteBalSheet (@BalSheetGuid UNIQUEIDENTIFIER) RETURNS BIT
AS
BEGIN	
DECLARE @CanDelete BIT

IF(EXISTS(SELECT * FROM ac000 WHERE BalsheetGuid = @BalSheetGuid))
	SET @CanDelete = 0 			
ELSE
	SET @CanDelete = 1

RETURN(@CanDelete)
END
###################################################################################
#END


