#########################################################
CREATE PROCEDURE prcRenameFld
	@Table [NVARCHAR](128),
	@OldFldName [NVARCHAR](128),
	@NewFldName [NVARCHAR](128)
AS
	DECLARE @Sql AS NVARCHAR(200)
	SET @Sql = 'prcRenameFld: ' + @Table + '.' + @OldFldName + ' To ' + @NewFldName
	EXECUTE [prcLog] @Sql
	
	SET @OldFldName = @Table + '.' + @OldFldName
	IF [dbo].[fnObjectExists](@OldFldName) <> 0
		EXEC [sp_rename] @OldFldName, @NewFldName, 'COLUMN'

#########################################################
#END