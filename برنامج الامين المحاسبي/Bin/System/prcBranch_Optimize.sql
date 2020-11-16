#########################################################
CREATE PROC prcBranch_Optimize
AS
	SET NOCOUNT ON
	
	DECLARE
		@c CURSOR,
		@tableName [NVARCHAR](128),
		@SingleBranch [NVARCHAR](128),
		@SingleBranchFldName [NVARCHAR](128),
		@SQL [NVARCHAR](2000),
		@brCount [INT],
		@brEnabled [BIT],
		@MultiFiles BIT

	SET @brCount = (SELECT COUNT(*) FROM [br000])
	SET @brEnabled = [dbo].[fnOption_get]('EnableBranches', '0')
	SELECT @MultiFiles = CAST(VALUE AS BIT) FROM OP000 WHERE [NAME] = 'AmncfgMultiFiles'
	IF @MultiFiles IS NULL
		SET @MultiFiles = 0
	SET @c = CURSOR FAST_FORWARD FOR SELECT [tableName],[SingleBranch],[SingleBranchFldName] FROM [brt]

	OPEN @c FETCH FROM @c INTO @tableName, @SingleBranch, @SingleBranchFldName
	WHILE @@FETCH_STATUS = 0
	BEGIN
		IF @brCount = 0
			EXEC [prcBranch_UnInstallTable] @tableName

		ELSE IF @singleBranch = 1 AND @MultiFiles = 0
			EXEC [prcBranch_InstallSingleBranchTable] @tableName, @SingleBranchFldName
		ELSE
		BEGIN
			IF  @MultiFiles = 0
				EXEC [prcBranch_InstallMultiBranchTable] @tableName
		END

		SET @tableName = REPLACE(@tableName, '0', '')

		-- if no branches were present, or branch system is disabled:
		IF @brCount <= 1 OR @brEnabled = 0
			EXEC [prcExecuteSQL] '
	ALTER VIEW [vb%0]
	AS 
		SELECT * FROM [vt%0]' , @tableName, @SingleBranchFldName

		ELSE
			IF @SingleBranch = 1
				EXEC [prcExecuteSQL]'
	ALTER VIEW [vb%0]
	AS
		SELECT [%0].*
		FROM [vt%0] AS [%0] INNER JOIN [vwBr] AS [br] ON [%0].[%1] = [br].[brGUID]', @tableName, @SingleBranchFldName

			ELSE
				EXEC [prcExecuteSQL] '
	ALTER VIEW [vb%0] 
	AS
		SELECT [%0].* 
		FROM [vt%0] AS [%0] WHERE [%0].[branchMask] & [dbo].[fnConnections_getBranchMask]() <> 0' , @tableName, @SingleBranchFldName

		FETCH FROM @c INTO @tableName, @SingleBranch, @SingleBranchFldName
	END

	CLOSE @c DEALLOCATE @c
#########################################################
CREATE PROCEDURE prcBranch_Optimize_LeftTables
AS
	DECLARE  @tableName NVARCHAR(255),@SingleBranchFldName   NVARCHAR(255),
	@c CURSOR,
	@brEnabled [BIT],@brCount INT
	SET @brCount = (SELECT COUNT(*) FROM [br000])
	CREATE TABLE #tblName([Name] NVARCHAR(255)COLLATE ARABIC_CI_AI,[FldName] NVARCHAR(255)COLLATE ARABIC_CI_AI)
	SET @brEnabled = [dbo].[fnOption_get]('EnableBranches', '1')
	--For Add Left Tables
	INSERT INTO #tblName VALUES('abd000','Branch')
	SET @c = CURSOR FAST_FORWARD FOR SELECT [Name],[FldName] FROM #tblName
	OPEN @c FETCH FROM @c INTO @tableName   , @SingleBranchFldName
	WHILE @@FETCH_STATUS = 0
	BEGIN
		
		SET @tableName = REPLACE(@tableName, '0', '')
		IF @brEnabled > 0 AND @brCount > 1
			EXEC [prcExecuteSQL]'
		ALTER VIEW [vb%0]
		AS
			SELECT [%0].*
			FROM [vt%0] AS [%0] LEFT JOIN [vwBr] AS [br] ON [%0].[%1] = [br].[brGUID] WHERE ISNULL([%0].[%1],0X00) = 0X00 OR [%0].[%1] = [br].[brGUID]', @tableName, @SingleBranchFldName
		ELSE 
				EXEC [prcExecuteSQL]'
		ALTER VIEW [vb%0]
		AS
			SELECT [%0].*
			FROM [vt%0] AS [%0]',@tableName, @SingleBranchFldName
		FETCH FROM @c INTO @tableName	, @SingleBranchFldName
	END
	CLOSE @c DEALLOCATE @c
#########################################################
#END