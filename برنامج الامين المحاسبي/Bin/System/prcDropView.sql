#########################################################
CREATE PROCEDURE prcDropView
	@viewName [NVARCHAR](128)
AS
	DECLARE @Sql AS NVARCHAR(200)
	SET @Sql = 'prcDropView ' + @viewName
	EXECUTE [prcLog] @Sql
	
	IF OBJECT_ID( @viewName, N'V') IS NOT NULL
		EXEC [prcExecuteSQL] 'DROP VIEW %0', @viewName

#########################################################
#END