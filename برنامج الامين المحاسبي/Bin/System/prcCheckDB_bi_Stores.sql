############################################################################################
CREATE PROCEDURE prcCheckDB_bi_Stores
	@Correct [INT] = 0
AS
	-- bi without StorePtr:
	IF @Correct <> 1
		INSERT INTO [ErrorLog] ([Type], [g1])
			SELECT 0x403, [bi].[ParentGUID] FROM [bi000] AS [bi] LEFT JOIN [st000] AS [st] ON [bi].[StoreGUID] = [st].[GUID] WHERE [st].[GUID] IS NULL

	-- correct StoreGUID by setting to bu.StoreGUID, if necessary:
	IF @Correct <> 0
	BEGIN
		EXEC prcDisableTriggers 'bi000'
		UPDATE [bi000] SET [StoreGUID] = [bu].[StoreGUID] FROM [bu000] AS [bu] LEFT JOIN [bi000] AS [bi] ON [bu].[GUID] = [bi].[ParentGUID] LEFT JOIN [st000] AS [st] ON [bi].[StoreGUID] = [st].[GUID] WHERE [st].[GUID] IS NULL
		ALTER TABLE [bi000] ENABLE TRIGGER ALL
	END

############################################################################################
#END