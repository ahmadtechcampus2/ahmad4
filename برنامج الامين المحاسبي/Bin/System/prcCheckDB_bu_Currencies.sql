############################################################################################
CREATE PROCEDURE prcCheckDB_bu_Currencies
	@Correct [INT] = 0
AS
	DECLARE @TmpGUID [UNIQUEIDENTIFIER]

	-- CurrencyGUID existance:
	IF @Correct <> 1
		INSERT INTO [ErrorLog]([Type], [g1])
			SELECT 0x305, [bu].[GUID] FROM [bu000] AS [bu] LEFT JOIN [my000] AS [my] ON [my].[GUID] = [bu].[CurrencyGUID] WHERE [my].[GUID] IS NULL

	-- correct CurrencyGUID by setting to 1, if necessary:
	IF @Correct <> 0
	BEGIN
		EXEC prcDisableTriggers 'bu000'
		SET @TmpGUID = ISNULL((SELECT TOP 1 [GUID] FROM [my000]), 0x0)
		UPDATE [bu000] SET [CurrencyGUID] = @TmpGUID FROM [bu000] AS [bu] LEFT JOIN [my000] AS [my] ON [my].[GUID] = [bu].[CurrencyGUID] WHERE [my].[GUID] IS NULL
		ALTER TABLE [bu000] ENABLE TRIGGER ALL
	END

	-- CurrencyVal <> 0
	IF @Correct <> 1
		INSERT INTO [ErrorLog] ([Type], [g1])
			SELECT 0x306, [bu].[GUID] FROM [bu000] AS [bu] WHERE [bu].[CurrencyVal] = 0

	-- correct CurrencyValr by setting to 1, if necessary
	IF @Correct <> 0
	BEGIN
		EXEC prcDisableTriggers 'bu000'
		UPDATE [bu000] SET [CurrencyVal] = 1 FROM [bu000] AS [bu] WHERE [bu].[CurrencyVal] = 0
		ALTER TABLE [bu000] ENABLE TRIGGER ALL
	END

############################################################################################
#END