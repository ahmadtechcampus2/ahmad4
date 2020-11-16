###########################################################################################
CREATE PROCEDURE prcCheckDB_et_Defaults
	@Correct [INT] = 0
AS
/*
This method checks, corrects and reports the following:
	- 0x801 unknown DefAccGUID.
*/

	-- check payment account:
	IF @Correct <> 1
		INSERT INTO [ErrorLog]([Type], [g1])
			SELECT 0x801, [et].[GUID] FROM [et000] AS [et] LEFT JOIN [ac000] AS [ac] ON [et].[DefAccGUID] = [ac].[GUID] WHERE [ac].[GUID] IS NULL
			AND (FldDebit = 0 OR FldCredit = 0)

###########################################################################################
#END