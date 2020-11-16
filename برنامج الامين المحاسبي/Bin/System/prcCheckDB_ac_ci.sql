###########################################################################
CREATE PROCEDURE prcCheckDB_ac_ci
	@Correct [INT] = 0
AS
	-- check ci, account not found
	IF @Correct <> 1
		INSERT INTO [ErrorLog]([Type], [g1])
			SELECT 0x6, [ci].[GUID] FROM [ci000] AS [ci] LEFT JOIN [ac000] AS [ac] ON [ac].[GUID] = [ci].[ParentGUID] WHERE [ac].[GUID] IS NULL
			UNION ALL
			SELECT 0x6, [ci].[GUID] FROM [ci000] AS [ci] LEFT JOIN [ac000] AS [ac] ON [ac].[GUID] = [ci].[SonGUID] WHERE [ac].[GUID] IS NULL

	-- correct by deleting
	IF @Correct <> 0
	BEGIN
		DELETE [ci000] FROM [ci000] [ci] LEFT JOIN [ac000] AS [ac] ON [ac].[GUID] = [ci].[ParentGUID] WHERE [ac].[GUID] IS NULL
		DELETE [ci000] FROM [ci000] [ci] LEFT JOIN [ac000] AS [ac] ON [ac].[GUID] = [ci].[SonGUID] WHERE [ac].[GUID] IS NULL
	END

###########################################################################
#END