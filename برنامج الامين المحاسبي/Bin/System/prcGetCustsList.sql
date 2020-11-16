#########################################################
CREATE PROCEDURE prcGetCustsList
	@CustGUID [UNIQUEIDENTIFIER] = 0x0, 
	@AccGUID [UNIQUEIDENTIFIER] = 0x0, 
	@CondGuid [UNIQUEIDENTIFIER] = 0x00
AS 
/* 
This procedure: 
	- returns Custs numbers according 
	  to a given @CustPtr, AccPtr and CondId found in mc000 
	- depends on fnGetCustConditionStr 
*/ 
	SET NOCOUNT ON 
	 
	DECLARE 
		@HasCond [INT], 
		@Criteria [NVARCHAR](max), 
		@SQL [NVARCHAR](max), 
		@HaveCFldCondition	BIT -- to check existing Custom Fields , it must = 1 
	SET @CustGUID = ISNULL(@CustGUID, 0x0) 
	SET @AccGUID = ISNULL(@AccGUID, 0x0) 
	SET @SQL = ' SELECT [cuGuid] AS [Guid], [cuSecurity] AS [Security] '
	SET @SQL = @SQL + ' FROM [vwCu] ' 
			
	IF @AccGUID <> 0x0 
		SET @SQL = @SQL + ' INNER JOIN [dbo].[fnGetCustsOfAcc]( ''' + CONVERT( [NVARCHAR](255), @AccGUID) + ''') AS [f] ON [vwCu].[cuGuid] = [f].[Guid]' 
	
	IF ISNULL(@CondGUID,0X00) <> 0X00 
	BEGIN 
		SET @Criteria = [dbo].[fnGetCustConditionStr](@CondGUID) 
		IF @Criteria <> '' 
		BEGIN 
			IF (RIGHT(@Criteria,4) = '<<>>')-- <<>> to Aknowledge Existing Custom Fields 
			BEGIN 
				SET @HaveCFldCondition = 1 
				SET @Criteria = REPLACE(@Criteria,'<<>>','')  
			END 
			SET @Criteria = '(' + @Criteria + ')' 
		END 
	END 
	ELSE 
		SET @Criteria = '' 
-------------------------------------------------------------------------------------------------------
-- Inserting Condition Of Custom Fields 
-------------------------------------------------------------------------------------------------------- 
	IF @HaveCFldCondition > 0 
		Begin 
			Declare @CF_Table NVARCHAR(255) 
			SET @CF_Table = (SELECT CFGroup_Table FROM CFMapping000 WHERE Orginal_Table = 'cu000') 	
			SET @SQL = @SQL + ' INNER JOIN ' + @CF_Table + ' ON [vwCu].[cuGuid] = ' + @CF_Table + '.Orginal_Guid ' 
		End 
-------------------------------------------------------------------------------------------------------
	SET @SQL = @SQL + ' 
		WHERE 1 = 1 ' 
	IF @Criteria <> '' 
		SET @SQL = @SQL + ' AND (' + @Criteria + ')' 
	IF @CustGUID <> 0x0 
		SET @SQL = @SQL + ' AND [cuGUID] = ''' + CONVERT( [NVARCHAR](255), @CustGUID) + '''' 
	EXEC(@SQL) 

#########################################################
CREATE PROCEDURE prcGetAcountEnCustsList
	@CustGUID [UNIQUEIDENTIFIER] = 0x0, 
	@AccGUID [UNIQUEIDENTIFIER] = 0x0, 
	@CondGuid [UNIQUEIDENTIFIER] = 0x00
AS 
/* 
This procedure: 
	- returns Custs numbers according 
	  to a given @CustPtr, AccPtr and CondId found in mc000 
	- depends on fnGetCustConditionStr 
*/ 
	--SET NOCOUNT ON 
	DECLARE  
		@HasCond [INT],   
		@Criteria [NVARCHAR](max), 
		@SQL [NVARCHAR](max), 
		@HaveCFldCondition	BIT -- to check existing Custom Fields , it must = 1 
	SET @CustGUID = ISNULL(@CustGUID, 0x0) 
	SET @AccGUID = ISNULL(@AccGUID, 0x0) 
	SET @SQL = ' SELECT DISTINCT [cuGuid] AS [Guid], [cuSecurity] AS [Security] '
	SET @SQL = @SQL + ' FROM [vwCu] ' 
	SET @SQL = @SQL + ' INNER JOIN en000 en on en.CustomerGUID = vwCu.cuGuid '
				
	IF ISNULL(@CondGUID,0X00) <> 0X00 
	BEGIN 
		SET @Criteria = [dbo].[fnGetCustConditionStr](@CondGUID) 
		IF @Criteria <> '' 
		BEGIN 
			IF (RIGHT(@Criteria,4) = '<<>>')-- <<>> to Aknowledge Existing Custom Fields 
			BEGIN 
				SET @HaveCFldCondition = 1 
				SET @Criteria = REPLACE(@Criteria,'<<>>','')  
			END 
			SET @Criteria = '(' + @Criteria + ')' 
		END 
	END 
	ELSE 
		SET @Criteria = '' 
-------------------------------------------------------------------------------------------------------
-- Inserting Condition Of Custom Fields 
-------------------------------------------------------------------------------------------------------- 
	IF @HaveCFldCondition > 0 
		Begin 
			Declare @CF_Table NVARCHAR(255) 
			SET @CF_Table = (SELECT CFGroup_Table FROM CFMapping000 WHERE Orginal_Table = 'cu000') 	
			SET @SQL = @SQL + ' INNER JOIN ' + @CF_Table + ' ON [vwCu].[cuGuid] = ' + @CF_Table + '.Orginal_Guid ' 
		End 
-------------------------------------------------------------------------------------------------------
	SET @SQL = @SQL + ' 
		WHERE 1 = 1 ' 
	--IF @AccGUID <> 0x0 
		SET @SQL = @SQL + ' AND AccountGUID = ''' + CONVERT( [NVARCHAR](255), @AccGUID) + '''' 
	IF @Criteria <> '' 
		SET @SQL = @SQL + ' AND (' + @Criteria + ')' 
	IF @CustGUID <> 0x0 
		SET @SQL = @SQL + ' AND [cuGUID] = ''' + CONVERT( [NVARCHAR](255), @CustGUID) + '''' 
	EXEC(@SQL) 
#########################################################
CREATE PROC prcGetCustomerExportData
	@CustomerGUID UNIQUEIDENTIFIER
AS
	SET NOCOUNT ON

	SELECT 
		CU.*,
		AC.Code + '-' + AC.Name AS AccountName,
		CO.Code + '-' + CO.Name AS CostName
	FROM
		vexCu CU
		INNER JOIN ac000 AC ON AC.GUID = Cu.AccountGUID
		LEFT JOIN co000 CO ON CO.GUID = Cu.CostGUID
	WHERE
		CU.GUID = @CustomerGUID
#########################################################
CREATE PROCEDURE prcGetAccountEntryExportData
	@AccountGUID UNIQUEIDENTIFIER
AS
	SET NOCOUNT ON

	SELECT
		AC.acLatinName,
		AC.acWarn,
		AC.acMaxDebit,
		MY.Code AS CurrencyCode,
		FinalAC.Code + ' - ' + FinalAC.Name AS FinalAccount,
		MainAC.Code + ' - ' + MainAC.Name AS MainAccount
	FROM
		vwAc AS AC
		JOIN My000 AS MY ON AC.acCurrencyPtr = MY.GUID
		JOIN ac000 AS FinalAC ON FinalAC.GUID = AC.acFinal
		JOIN ac000 AS MainAC ON MainAC.GUID = AC.acParent
	WHERE 
		AC.acGUID = @AccountGUID
#########################################################
#END