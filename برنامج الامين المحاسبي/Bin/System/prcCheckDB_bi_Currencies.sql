############################################################################################
CREATE PROCEDURE prcCheckDB_bi_Currencies
	@Correct [INT] = 0
AS
	-- CurrencyGUID existance:
	IF @Correct <> 1
		INSERT INTO [ErrorLog] ([Type], [g1])
			SELECT 0x404, [bi].[ParentGUID] FROM [bi000] AS [bi] LEFT JOIN [my000] AS [my] ON [my].[GUID] = [bi].[CurrencyGUID] WHERE [my].[GUID] IS NULL

	-- correct CurrencyPtr by setting to 1, if necessary:
	IF @Correct <> 0
	BEGIN
		EXEC prcDisableTriggers 'bi000'
		
		UPDATE [bi000] SET [CurrencyGUID] = (SELECT [GUID] FROM [my000] WHERE [Number] = 1) FROM [bi000] AS [bi] LEFT JOIN [my000] AS [my] ON [my].[GUID] = [bi].[CurrencyGUID] WHERE [my].[GUID] IS NULL
		ALTER TABLE [bi000] ENABLE TRIGGER ALL
	END

	-- CurrencyVal <> 0:
	IF @Correct <> 1
		INSERT INTO [ErrorLog] ([Type], [g1])
			SELECT 0x405, [ParentGUID] FROM [bi000] WHERE [CurrencyVal] = 0

	-- correct CurrencyValr by setting to 1, if necessary:
	IF @Correct <> 0
	BEGIN
		EXEC prcDisableTriggers 'bi000'
		UPDATE [bi000] SET [CurrencyVal] = 1 FROM [bi000] WHERE [CurrencyVal] = 0
		ALTER TABLE [bi000] ENABLE TRIGGER ALL
	END

############################################################################################
#END