###########################################################################################
CREATE PROCEDURE prcCheckDB_en_Currencies
	@Correct [INT] = 0
AS

	-- get the primary currency
	declare @primCurGuid [uniqueidentifier]
	set @primCurGuid = (select top 1 [guid] from [my000] where [currencyVal] = 1)


	-- en.CurrencyPtr existance:
	IF @Correct <> 1
		INSERT INTO [ErrorLog] ([Type], [g1])
			SELECT distinct 0x602, [en].[ParentGUID] FROM [en000] AS [en] LEFT JOIN [my000] AS [my] ON [my].[GUID] = [en].[CurrencyGUID] WHERE [my].[GUID] IS NULL

	-- correct en.CurrencyPtr by setting to ce.CurrencyPtr, if necessary:
	IF @Correct <> 0
	BEGIN
		EXEC prcDisableTriggers 'en000'
		UPDATE [en000] SET [CurrencyGUID] = @primCurGuid FROM [en000] AS [en] LEFT JOIN [my000] [my] ON [en].[currencyGuid] = [my].[guid] WHERE [my].[guid] is null
		ALTER TABLE [en000] ENABLE TRIGGER ALL
	END

	-- en.CurrencyVal <> 0:
	IF @Correct <> 1
		INSERT INTO [ErrorLog] ([Type], [g1])
			SELECT distinct 0x603, [ParentGUID] FROM [en000] WHERE [CurrencyVal] = 0

	-- correct CurrencyVal by setting to 1, if necessary:
	IF @Correct <> 0
	BEGIN
		EXEC prcDisableTriggers 'en000'
		UPDATE [en000] SET [CurrencyVal] = 1 FROM [en000] WHERE [CurrencyVal] = 0
		ALTER TABLE [en000] ENABLE TRIGGER ALL
	END

	-- en.CurrencyVal <> 1 while currencyGuid is for the primary currency:
	if (select count(*) from [my000] where [currencyVal] = 1) = 1 -- this will make sure that there is only one currency with value of 1
	begin
		-- report en000 with currencyVal of 1 while currency is not the primary:
		IF @Correct <> 1
			INSERT INTO [ErrorLog] ([Type], [g1])
				SELECT distinct 0x60A, [ParentGUID] FROM [en000] [en] WHERE [CurrencyVal] = 1 AND [currencyGuid] != @primCurGuid

		-- report en000 with primary currency while currencyVal != 1
		IF @Correct <> 1
			INSERT INTO [ErrorLog] ([Type], [g1])
				SELECT distinct 0x60B, [ParentGUID] FROM [en000] [en] WHERE [CurrencyVal] != 1 AND [currencyGuid] = @primCurGuid

	
		-- correct CurrencyVal by setting to 1, if necessary:
		IF @Correct <> 0
		BEGIN
			EXEC prcDisableTriggers 'en000'
			UPDATE [en000] SET [CurrencyVal] = 1 FROM [en000] WHERE [CurrencyGuid] = @primCurGuid
			ALTER TABLE [en000] ENABLE TRIGGER ALL
		END
	
	end

###########################################################################################
#END