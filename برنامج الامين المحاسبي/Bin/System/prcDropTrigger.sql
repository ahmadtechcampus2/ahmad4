#########################################################
CREATE PROCEDURE prcDropTrigger
	@TriggerName [NVARCHAR](128)
AS
	DECLARE @Sql AS NVARCHAR(200)
	SET @Sql = 'prcDropTrigger ' + @TriggerName
	EXECUTE [prcLog] @Sql
	IF OBJECT_ID( @TriggerName, N'TR') IS NOT NULL
		EXEC [prcExecuteSQL] 'DROP TRIGGER %0', @TriggerName	

#########################################################
#END 