##########################################################################################
CREATE PROC prcBranch_InstallMultiBranchTable
	@TableName [NVARCHAR](128)  
AS
	SET NOCOUNT ON
	
	DECLARE @defBranchMask [BIGINT]
	SET @defBranchMask = [dbo].[fnBranch_GetDefaultMask]()
	
	EXEC [prcBranch_UnInstallTable] @TableName
	-- add a trigger to insert and delete data in bl related to Table 
	
	EXEC prcDisableTriggers @TableName

	EXEC [prcExecuteSQL] '
		UPDATE [%0] SET [branchMask] = %1 WHERE [branchMask] = 0
		ALTER TABLE [%0] ENABLE TRIGGER ALL
		', @TableName, @defBranchMask

	EXEC [prcExecuteSQL] '
CREATE TRIGGER [dbo].[trg_%0_br] -- insert and delete related bl primary data 
	ON [%0] FOR INSERT, UPDATE
	NOT FOR REPLICATION
AS 
	-- this trigger is auto generated from prcBranch_InstallMultiBranchTable, which is usually called from trg_brt_insert 
	-- insert for default branch:


	IF @@ROWCOUNT = 0
		RETURN

	SET NOCOUNT ON 
	
	DECLARE @defBranchMask [BIGINT]

	SET @defBranchMask = [dbo].[fnBranch_GetDefaultMask]()
	
	UPDATE [%0] SET
			[branchMask] = @defBranchMask
		FROM [%0] AS [t] INNER JOIN [inserted] AS [i] ON [t].[GUID] = [i].[GUID]
		WHERE [t].[branchMask] = 0'
			, @TableName


##########################################################################################
#END