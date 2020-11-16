#########################################################
CREATE PROCEDURE prcRenameTable
	@OldTableName [NVARCHAR](128),
	@NewTableName [NVARCHAR](128)
AS
	DECLARE @Sql As NVARCHAR(200)
	SET @Sql = 'prcRenameTable ' + @OldTableName + ' To ' + @NewTableName
	EXECUTE [prcLog] @Sql
	
	IF [dbo].[fnObjectExists](@OldTableName) <> 0
		EXEC [sp_rename] @OldTableName, @NewTableName

#########################################################
#END