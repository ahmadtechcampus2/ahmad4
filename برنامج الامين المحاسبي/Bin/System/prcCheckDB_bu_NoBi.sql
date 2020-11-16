############################################################################################
CREATE PROCEDURE prcCheckDB_bu_NoBi
	@Correct [INT] = 0
AS
/*
This method checks, corrects and reports the following:
	- 0x301 bu without bi, corrected by deletion
	- 0x302 unknown CustPtr
	- 0x303 unknown CustAccount
	- 0x304 unknown StorePtr (corrected to 1)
	- 0x305 unknown CurrPtr (corrected to 1)
	- 0x306 CurrVal found 0 (corrected  to 1)
	- 0x307 sums Total errror (corrected by recalculating)
	- 0x308 sums TotalDisc errror (corrected by recalculating)
	- 0x309 sums TotalExtra errror (corrected by recalculating)
	- 0x30A sums ItemsDisc errror (corrected by recalculating)
	- 0x30B sums BonusDisc errror (corrected by recalculating)
	- 0x30C NULLs in bu.
	- 0x30D sums VAT errror (corrected by recalculating)
	- 0x30E Posted without entries while bill type auto-generates entry
*/
	DECLARE @TmpGUID [UNIQUEIDENTIFIER]

	-- bu without bi
	IF @Correct <> 1
		INSERT INTO [ErrorLog]([Type], [g1])
			SELECT 0x301, [bu].[GUID] FROM [bu000] AS [bu] LEFT JOIN [bi000] AS [bi] ON [bu].[GUID] = [bi].[ParentGUID] WHERE [bi].[ParentGUID] IS NULL

	-- correct by deleting, if necessary:
	IF @Correct <> 0
	BEGIN -- unpost before deletion
		UPDATE [bu000] SET [IsPosted] = 0 FROM [bu000] AS [bu] LEFT JOIN [bi000] AS [bi] ON [bu].[GUID] = [bi].[ParentGUID] WHERE [bi].[ParentGUID] IS NULL
		--DELETE [bu000] FROM [bu000] AS [bu] LEFT JOIN [bi000] AS [bi] ON [bu].[GUID] = [bi].[ParentGUID] WHERE [bi].[ParentGUID] IS NULL
	END

############################################################################################
#END