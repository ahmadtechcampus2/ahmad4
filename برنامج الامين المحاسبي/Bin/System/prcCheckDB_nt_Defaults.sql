###########################################################################################
CREATE PROCEDURE prcCheckDB_nt_Defaults
	@Correct [INT] = 0
AS
/*
This method checks, corrects and reports the following:
	- 0xA01 unknown DefPayAccGUID
	- 0xA02 unknown DefRecAccGUID.
	- 0xA03 unknown DefColAccGUID.
	- 0xA04 unknown CostGUID.
*/

	-- check DefPayAccGUID:
	IF @Correct <> 1
		INSERT INTO [ErrorLog]([Type], [g1])
			SELECT 0xA01, [nt].[GUID] FROM [nt000] AS [nt] LEFT JOIN [ac000] AS [ac] ON [nt].[DefPayAccGUID] = [ac].[GUID] WHERE [ac].[GUID] IS NULL

	-- correct by reseting to NULL:
	IF @Correct <> 0
		UPDATE [nt000] SET [DefPayAccGUID] = 0x0 FROM [nt000] AS [nt] LEFT JOIN [ac000] AS [ac] ON [nt].[DefPayAccGUID] = [ac].[GUID] WHERE [ac].[GUID] IS NULL

	-- check DefRecAccGUID:
	IF @Correct <> 1
		INSERT INTO [ErrorLog]([Type], [g1])
			SELECT 0xA02, [nt].[GUID] FROM [nt000] AS [nt] LEFT JOIN [ac000] AS [ac] ON [nt].[DefRecAccGUID] = [ac].[GUID] WHERE [ac].[GUID] IS NULL
	-- correct by reseting to NULL:
	IF @Correct <> 0
		UPDATE [nt000] SET [DefRecAccGUID] = 0x0 FROM [nt000] AS [nt] LEFT JOIN [ac000] AS [ac] ON [nt].[DefRecAccGUID] = [ac].[GUID] WHERE [ac].[GUID] IS NULL

	-- check DefColAccGUID:
	IF @Correct <> 1
		INSERT INTO [ErrorLog]([Type], [g1])
			SELECT 0xA03, [nt].[GUID] FROM [nt000] AS [nt] LEFT JOIN [ac000] AS [ac] ON [nt].[DefColAccGUID] = [ac].[GUID] WHERE [ac].[GUID] IS NULL

	-- correct by reseting to NULL:
	IF @Correct <> 0
		UPDATE [nt000] SET [DefColAccGUID] = 0x0 FROM [nt000] AS [nt] LEFT JOIN [ac000] AS [ac] ON [nt].[DefColAccGUID] = [ac].[GUID] WHERE [ac].[GUID] IS NULL

	-- check CostGUID:
	IF @Correct <> 1
		INSERT INTO [ErrorLog]([Type], [g1])
			SELECT 0xA04, [nt].[GUID] FROM [nt000] AS [nt] LEFT JOIN [ac000] AS [co] ON [nt].[CostGUID] = [co].[GUID] WHERE [co].[GUID] IS NULL

	-- correct by reseting to NULL:
	IF @Correct <> 0
		UPDATE [nt000] SET [CostGUID] = 0x0 FROM [nt000] AS [nt] LEFT JOIN [co000] AS [co] ON [nt].[CostGUID] = [co].[GUID] WHERE [co].[GUID] IS NULL

###########################################################################################
#END