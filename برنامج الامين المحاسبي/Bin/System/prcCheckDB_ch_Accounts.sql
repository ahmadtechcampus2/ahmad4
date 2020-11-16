############################################################################################
CREATE PROCEDURE prcCheckDB_ch_Accounts
	@Correct [INT] = 0 
AS 
/*  
This method checks, corrects and reports the following:
	- 0x701 unknown Account.
*/  
	-- check payment account:
	IF @Correct <> 1
		INSERT INTO [ErrorLog] ([Type], [g1])
			SELECT 0x701, [ch].[GUID] FROM [ch000] AS [ch] LEFT JOIN [ac000] AS [ac] ON [ch].[AccountGUID] = [ac].[GUID] WHERE [ac].[GUID] IS NULL

############################################################################################
#END