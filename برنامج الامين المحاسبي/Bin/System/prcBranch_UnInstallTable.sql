#########################################################
CREATE PROC prcBranch_UnInstallTable
	@TableName [NVARCHAR](128)
AS 
	SET NOCOUNT ON
	
	DECLARE @SQL [NVARCHAR](128) 

	SET @SQL = 'trg_' + @TableName + '_bl'
	EXEC [prcDropTrigger] @SQL
	
	SET @SQL = 'trg_' + @TableName + '_br'
	EXEC [prcDropTrigger] @SQL

#########################################################
#END