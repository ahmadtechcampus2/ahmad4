############################################################################################
CREATE PROCEDURE prcCheckDB_bu_Custs
	@Correct [INT] = 0
AS
	-- CustGUID existance:
	IF @Correct <> 1
		INSERT INTO [ErrorLog]([Type], [g1])
			SELECT 0x302, [bu].[GUID] FROM [bu000] AS [bu] LEFT JOIN [cu000] AS [cu] ON [bu].[CustGUID] = [cu].[GUID] WHERE [cu].[GUID] IS NULL AND ISNULL([bu].[CustGUID], 0x0) <> 0x0
	-- correct CustGUID by setting to 0x0, if necessary:
	IF (@@ROWCOUNT * @Correct <> 0)
	BEGIN
		EXEC prcDisableTriggers 'bu000'
		UPDATE [bu000] SET [CustGUID] = 0x0 FROM [bu000] AS [bu] LEFT JOIN [cu000] AS [cu] ON [bu].[CustGUID] = [cu].[GUID] WHERE [cu].[GUID] IS NULL AND ISNULL([bu].[CustGUID], 0x0) <> 0x0
		EXEC prcDisableTriggers 'bu000'
	END

	-- CustAccGUID existance:
	IF @Correct <> 1
		INSERT INTO [ErrorLog]([Type], [g1])
			SELECT 0x303, [bu].[GUID] FROM [bu000] AS [bu] LEFT JOIN [ac000] AS [ac] ON [ac].[GUID] = [bu].[CustAccGUID] WHERE [ac].[GUID] IS NULL AND ISNULL([bu].[CustAccGUID], 0x0) <> 0x0

	-- correct CustAccGUID by setting to GUIDZero, if necessary
	IF @Correct <> 0
	BEGIN
		
		EXEC prcDisableTriggers 'bu000'
		UPDATE [bu000] SET [CustAccGUID] = 0x0 FROM [bu000] AS [bu] LEFT JOIN [ac000] AS [ac] ON [ac].[GUID] = [bu].[CustAccGUID] WHERE [ac].[GUID] IS NULL AND ISNULL([bu].[CustAccGUID], 0x0) <> 0x0
		ALTER TABLE [bu000] ENABLE TRIGGER ALL
	END

############################################################################################
#END