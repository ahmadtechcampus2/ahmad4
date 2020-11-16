############################################################################################
CREATE PROCEDURE prcCheckDB_ce_Currencies
	@Correct [INT] = 0
AS
	DECLARE @TmpGUID [UNIQUEIDENTIFIER]
	-- ce.CurrencyGUID existance:
	IF @Correct <> 1
		INSERT INTO [ErrorLog] ([Type], [g1])
			SELECT 0x502, [ce].[GUID] FROM [ce000] AS [ce] LEFT JOIN [my000] AS [my] ON [my].[GUID] = [ce].[CurrencyGUID] WHERE [my].[GUID] IS NULL
	-- correct CurrencyPtr by setting to 1, if necessary:
	IF @Correct <> 0
	BEGIN
		
		EXEC prcDisableTriggers 'ce000'
		SET @TmpGUID = ISNULL((SELECT TOP 1 [GUID] FROM [my000] WHERE [currencyVal] = 1), 0x0)
		UPDATE [ce000] SET [CurrencyGUID] = @TmpGUID FROM [ce000] AS [ce] LEFT JOIN [my000] AS [my] ON [my].[GUID] = [ce].[CurrencyGUID] WHERE [my].[GUID] IS NULL
		ALTER TABLE [ce000] ENABLE TRIGGER ALL
	END

	-- CurrencyVal <> 0:
	IF @Correct <> 1
		INSERT INTO [ErrorLog] ([Type], [g1])
			SELECT 0x503, [GUID] FROM [ce000] WHERE [CurrencyVal] = 0
	-- correct CurrencyValr by setting to 1, if necessary:
	IF @Correct <> 0
	BEGIN
		
		EXEC prcDisableTriggers 'ce000'
		UPDATE [ce000] SET [CurrencyVal] = 1 FROM [ce000] WHERE [CurrencyVal] = 0
		ALTER TABLE [ce000] ENABLE TRIGGER ALL
	END

############################################################################################
#END