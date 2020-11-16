############################################################################################
CREATE PROCEDURE prcCheckDB_ce_IsPosted
	@Correct [INT] = 0
AS
	-- correct IsPosted values
	IF @Correct <> 1
		INSERT INTO [ErrorLog] ([Type], [g1])
			SELECT 0x507, [GUID] FROM [ce000] WHERE ([IsPosted] IS NULL) OR [IsPosted] NOT IN (0, 1)

	-- correct if necessary:
	IF @Correct <> 0
	BEGIN
		
		EXEC prcDisableTriggers 'ce000'
		UPDATE [ce000] SET [IsPosted] = 0 WHERE ([IsPosted] IS NULL) OR [IsPosted] NOT IN (0, 1)
		ALTER TABLE [ce000] ENABLE TRIGGER ALL
	END

############################################################################################
#END