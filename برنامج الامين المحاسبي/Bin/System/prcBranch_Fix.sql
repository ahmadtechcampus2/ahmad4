###############################################################################
CREATE PROC prcBranch_Fix
AS
	SET NOCOUNT ON
	
	DECLARE
		@c CURSOR,
		@TableName [NVARCHAR](128),
		@SingleBranchFldName [NVARCHAR](128),
		@DefBranch [NVARCHAR](128),
		@SQL [NVARCHAR](2000)
	
	SET @DefBranch = [dbo].[fnBranch_getDefaultGuid]()

	-- insert references in bl for unreferenced entities:
	SET @c = CURSOR FAST_FORWARD FOR SELECT [TableName],[SingleBranchFldName] FROM [brt] WHERE [singleBranch] = 1
	OPEN @c FETCH FROM @c INTO @TableName, @SingleBranchFldName

	WHILE @@FETCH_STATUS = 0
	BEGIN
		SET @SQL = '
			ALTER TABLE [%0] DISABLE TRIGGER ALL
			UPDATE [%0] SET [%1] = ''%2'' WHERE [%1] NOT IN (SELECT [GUID] FROM [br000])
			ALTER TABLE [%0] ENABLE TRIGGER ALL'
		EXEC [prcExecuteSql] @SQL, @tableName, @SingleBranchFldName, @DefBranch
		FETCH FROM @c INTO @TableName, @SingleBranchFldName
	END

	CLOSE @c DEALLOCATE @c

###############################################################################
#END