###########################################################################################
CREATE PROCEDURE prcCheckDB_en_NoCe
	@Correct [INT] = 0
AS
/*
This method checks, corrects and reports the following:
	- 0x601 unknown ce.CurrencyPtr (corrected to 1)
	- 0x602 unknown en.CurrencyPtr (corrected to ce.CurrencyPtr)
	- 0x603 en.CurrencyVal = 0 (corrected to 1)
	- 0x604 unknown en.Account
	- 0x605  en.Account has sons
	- 0x606 en.Account type is not normal
*/
	-- en without ce:
	IF @Correct <> 1
		INSERT INTO [ErrorLog] ([Type], [g1])
			SELECT 0x601, [en].[ParentGUID] FROM [en000] AS [en] LEFT JOIN [ce000] AS [ce] ON [ce].[GUID] = [en].[ParentGUID] WHERE [ce].[GUID] IS NULL

	-- correct by deleting, if necessary:
	IF @Correct <> 0
	BEGIN
		EXEC prcDisableTriggers  'en000'
		DELETE [en000] FROM [en000] AS [en] LEFT JOIN [ce000] AS [ce] ON [ce].[GUID] = [en].[ParentGUID] WHERE [ce].[GUID] IS NULL
		ALTER TABLE [en000] ENABLE TRIGGER ALL
	END

###########################################################################################
#END