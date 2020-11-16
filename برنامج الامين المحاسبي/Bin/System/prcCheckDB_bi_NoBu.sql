############################################################################################
CREATE PROCEDURE prcCheckDB_bi_NoBu
	@Correct [INT] = 0
AS
/*
This method checks, corrects and reports the following:
	- 0x401 unknown bu
	- 0x402 unknown MatGUID
	- 0x403 unknown StoreGUID (corrected to bu.StoreGUID)
	- 0x404 unknown CurrencyPtr (corrected to 1)
	- 0x405 CurrencyVal = 0 (corrected to 1)
	- 0x406 Qty2 or Qty3 <> 0 for a relative units
	- 0x407 Qty2 or Qty3 = 0 for a non-relative units
	- 0x408 Check nulls.
*/

	-- bi without bu:
	IF @Correct <> 1
		INSERT INTO [ErrorLog] ([Type], [g1])
			SELECT 0x401, [bi].[ParentGUID] FROM [bi000] AS [bi] LEFT JOIN [bu000] AS [bu] ON [bu].[GUID] = [bi].[ParentGUID] WHERE [bu].[GUID] IS NULL

	-- correct by deleting, if necessary:
	IF @Correct <> 0
		DELETE [bi000] FROM [bi000] AS [bi] LEFT JOIN [bu000] AS [bu] ON [bu].[GUID] = [bi].[ParentGUID] WHERE [bu].[GUID] IS NULL

############################################################################################
#END