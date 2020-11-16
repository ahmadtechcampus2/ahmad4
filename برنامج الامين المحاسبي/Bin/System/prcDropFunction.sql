#########################################################
CREATE PROCEDURE prcDropFunction
	@FunctionName [NVARCHAR](128)
AS
	DECLARE @Sql AS NVARCHAR(200)
	SET @Sql = 'prcDropFunction ' + @FunctionName
	EXECUTE [prcLog] @Sql
	
	IF [dbo].[fnObjectExists](@FunctionName) <> 0	
		EXEC [prcExecuteSQL] 'DROP FUNCTION %0', @FunctionName	

#########################################################
#END  