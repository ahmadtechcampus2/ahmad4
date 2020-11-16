############################################################################################
CREATE PROCEDURE prcCheckDB_ce_NoEn
	@Correct [INT] = 0
AS
/*
This method checks, corrects and reports the following:
	- 0x501 ce without en.
	- 0x502 unknown ce.CurrencyPtr (corrected to 1)
	- 0x503 ce.CurrencyVal = 0 (corrected to 1)
	- 0x504 Sums (Debit, Credit) (correct by recalculating)
*/
	DECLARE @TmpGUID [UNIQUEIDENTIFIER]

	-- ce without en:
	IF @Correct <> 1
		INSERT INTO [ErrorLog] ([Type], [g1])
			SELECT 0x501, [ce].[GUID] FROM [ce000] AS [ce] LEFT JOIN [en000] AS [en] ON [ce].[GUID] = [en].[ParentGUID] WHERE [en].[GUID] IS NULL

	-- correct by deleting, if necessary:
	IF @Correct <> 0
	BEGIN
		
		EXEC prcDisableTriggers 'ce000'
		DELETE [ce000] FROM [ce000] AS [ce] LEFT JOIN [en000] AS [en] ON [ce].[GUID] = [en].[ParentGUID] WHERE [en].[GUID] IS NULL
		ALTER TABLE [ce000] ENABLE TRIGGER ALL
	END

############################################################################################
#END