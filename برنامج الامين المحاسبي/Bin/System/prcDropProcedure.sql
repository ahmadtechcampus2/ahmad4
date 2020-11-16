#########################################################
CREATE PROCEDURE prcDropProcedure
	@ProcedureName [NVARCHAR](128)
AS
	DECLARE @SQL NVARCHAR(250)
	SET @SQL = 'prcDropProcedure: ' + @ProcedureName
	EXEC [prcLog] @SQL
	IF OBJECT_ID( @ProcedureName, N'P') IS NOT NULL	
	BEGIN
		EXEC [prcExecuteSQL] 'DROP PROCEDURE %0', @ProcedureName
	END

#########################################################
#END   