#########################################################
CREATE PROCEDURE prcCheckDB_ce_typeGuid
	@Correct [INT] = 0 
AS 
	-- ce.typeGuid = 0x0 while found in er
	IF @Correct <> 1 
		INSERT INTO [ErrorLog] ([Type], [g1]) 
			SELECT 0x508, [c].[GUID] FROM [ce000] [c] INNER JOIN [er000] [e] ON [c].[GUID] = [e].[EntryGUID] INNER JOIN [bu000] [x] ON [e].[parentGuid] = [x].[GUID] WHERE [c].[typeGuid] = 0x0

	-- correct typeGuid
	IF @Correct <> 0
	BEGIN 
		
		EXEC prcDisableTriggers 'ce000'
		UPDATE [ce000] SET [typeGuid] = [x].[typeGuid] FROM [ce000] [c] INNER JOIN [er000] [e] ON [c].[GUID] = [e].[EntryGUID] INNER JOIN [bu000] [x] ON [e].[parentGuid] = [x].[GUID] WHERE [c].[typeGuid] = 0x0
		ALTER TABLE [ce000] ENABLE TRIGGER ALL 
	END 

	IF @Correct <> 1 
		INSERT INTO [ErrorLog] ([Type], [g1]) 
			SELECT 0x509, [c].[GUID] FROM [ce000] [c] INNER JOIN [er000] [e] ON [c].[GUID] = [e].[EntryGUID] INNER JOIN [ch000] [x] ON [e].[parentGuid] = [x].[GUID] WHERE [c].[typeGuid] = 0x0

	-- correct typeGuid
	IF @Correct <> 0
	BEGIN 
		
		EXEC prcDisableTriggers 'ce000'
		UPDATE [ce000] SET [typeGuid] = [x].[typeGuid] FROM [ce000] [c] INNER JOIN [er000] [e] ON [c].[GUID] = [e].[EntryGUID] INNER JOIN [ch000] [x] ON [e].[parentGuid] = [x].[GUID] WHERE [c].[typeGuid] = 0x0
		ALTER TABLE [ce000] ENABLE TRIGGER ALL 
	END

	IF @Correct <> 1 
		INSERT INTO [ErrorLog] ([Type], [g1]) 
			SELECT 0x50A, [c].[GUID] FROM [ce000] [c] INNER JOIN [er000] [e] ON [c].[GUID] = [e].[EntryGUID] INNER JOIN [py000] [x] ON [e].[parentGuid] = [x].[GUID] WHERE [c].[typeGuid] = 0x0

	-- correct typeGuid
	IF @Correct <> 0
	BEGIN 
	EXEC prcDisableTriggers 'ce000' 
		UPDATE [ce000] SET [typeGuid] = [x].[typeGuid] FROM [ce000] [c] INNER JOIN [er000] [e] ON [c].[GUID] = [e].[EntryGUID] INNER JOIN [py000] [x] ON [e].[parentGuid] = [x].[GUID] WHERE [c].[typeGuid] = 0x0
		ALTER TABLE [ce000] ENABLE TRIGGER ALL 
	END 

#########################################################