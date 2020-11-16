#########################################################
CREATE PROCEDURE prcLog_Clear

AS
	IF OBJECT_ID( N'DBLog', N'U') IS NOT NULL
		EXECUTE ('DELETE [DBLog]')

#########################################################
#END
