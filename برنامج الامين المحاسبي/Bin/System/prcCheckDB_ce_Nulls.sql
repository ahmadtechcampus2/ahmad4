############################################################################################
CREATE PROCEDURE prcCheckDB_ce_Nulls
	@Correct [INT] = 0
AS
	-- check NULLs:
	IF @Correct <> 1
		INSERT INTO [ErrorLog] ([Type], [g1])
			SELECT 0x506, [GUID] FROM [ce000]
			WHERE [IsPosted] IS NULL

	-- correct if necessary:
	IF @Correct <> 0
	BEGIN
		
		EXEC prcDisableTriggers 'ce000'
		UPDATE [ce000] SET [IsPosted] = ISNULL([IsPosted], 0)
		ALTER TABLE [ce000] ENABLE TRIGGER ALL
	END

############################################################################################
#END