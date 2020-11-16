#########################################################
CREATE PROC prcBranch_InstallSingleBranchTable
	@TableName [NVARCHAR](128), 
	@FldName [NVARCHAR](128) 
AS
	SET NOCOUNT ON 

	DECLARE @SQL [NVARCHAR](max) 
	 
	EXEC [prcBranch_UnInstallTable] @TableName
	SET @SQL = ' 
	CREATE TRIGGER [dbo].[trg_%0_br]
		ON [%0] FOR INSERT, UPDATE 
		NOT FOR REPLICATION
	AS 
		IF @@ROWCOUNT = 0 RETURN 
		-- this trigger is auto generated for a SingleBranch related table 
		SET NOCOUNT ON
		
		DECLARE @defBranch [UNIQUEIDENTIFIER] 
		IF EXISTS(SELECT * FROM [inserted] WHERE ISNULL([%1], 0x0) = 0x0) 
		BEGIN 
			SET @defBranch = [dbo].[fnBranch_GetDefaultGuid]()
			IF @defBranch IS NOT NULL 
				UPDATE [%0] SET [%1] = @defBranch
					FROM [%0] AS [x] INNER JOIN [inserted] AS [i] ON [x].[GUID] = [i].[GUID] WHERE ISNULL([i].[%1], 0x0) = 0x0 
	END'
	EXEC [prcExecuteSQL] @SQL, @TableName, @FldName 

	-- reset faulty branch values: 
	EXEC prcDisableTriggers @TableName
	SET @SQL = '
			UPDATE [%0] SET [%1] = [dbo].[fnBranch_GetDefaultGuid]()
				FROM [%0] AS [x] LEFT JOIN [br000] AS [b] ON [x].[%1] = [b].[GUID] 
				WHERE [b].[GUID] IS NULL
			ALTER TABLE [%0] ENABLE TRIGGER ALL'

	EXEC [prcExecuteSQL] @SQL, @TableName, @FldName

#########################################################
#END