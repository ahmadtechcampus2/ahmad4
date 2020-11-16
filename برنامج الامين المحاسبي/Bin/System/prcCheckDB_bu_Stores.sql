############################################################################################
CREATE PROCEDURE prcCheckDB_bu_Stores
	@Correct [INT] = 0
AS
	DECLARE @TmpGUID [UNIQUEIDENTIFIER]

	-- StoreGUID existance:
	IF @Correct <> 1
		INSERT INTO [ErrorLog]([Type], [g1])
			SELECT 0x304, [bu].[GUID] FROM [bu000] AS [bu] LEFT JOIN [st000] AS [st] ON [st].[GUID] = [bu].[StoreGUID] WHERE [st].[GUID] IS NULL AND ISNULL([bu].[StoreGUID], 0x0) <> 0x0

	-- correct StoreGUID by setting to GUIDZero, if necessary:
	IF @Correct <> 0
	BEGIN
			EXEC prcDisableTriggers 'bu000'
		SET @TmpGUID = ISNULL((SELECT TOP 1 [GUID] FROM [st000]), 0x0)
		UPDATE [bu000] SET [StoreGUID] = @TmpGUID FROM [bu000] AS [bu] LEFT JOIN [st000] AS [st] ON [st].[GUID] = [bu].[StoreGUID] WHERE [st].[GUID] IS NULL
		ALTER TABLE [bu000] ENABLE TRIGGER ALL
	END

############################################################################################
#END