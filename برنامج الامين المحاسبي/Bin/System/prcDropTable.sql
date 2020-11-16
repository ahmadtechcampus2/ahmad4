##############################################################################
CREATE PROCEDURE prcDropTable
	@TableName [NVARCHAR](128)
AS
	DECLARE @SQL NVARCHAR(250)
	SET @SQL = 'prcDropTable ' + @TableName
	EXEC [prcLog] @SQL
	
		IF [dbo].[fnObjectExists](@TableName) = 1
		BEGIN
		EXEC [prcExecuteSQL] 'DROP TABLE %0', @TableName	
		EXEC [prcLog] '-Table dropped'
	END
	ELSE
		EXEC [prcLog] '-Table not found'
	
##############################################################################
CREATE PROCEDURE prcDropTableIfEmpty
	@TableName [NVARCHAR](128)
AS
	DECLARE @SQL NVARCHAR(250)
	SET @SQL = 'prcDropTableIfEmpty ' + @TableName
	EXEC [prcLog] @SQL

	IF  OBJECT_ID( @TableName, N'U')  IS NOT NULL
		EXECUTE [prcExecuteSQL] 'IF NOT EXISTS(SELECT * FROM [%0])	DROP TABLE [%0]', @TableName
	
##############################################################################