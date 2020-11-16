###########################################################################
CREATE PROCEDURE prcCheckDB_ac_Links
	@Correct [INT] = 0
AS
	-- check ParentGUIDhood topics:
	DECLARE
		@c CURSOR,
		@GUID [UNIQUEIDENTIFIER],
		@Code [NVARCHAR](50),
		@Name [NVARCHAR](50),
		@ParentGUID [UNIQUEIDENTIFIER]

	SET @c = CURSOR FAST_FORWARD FOR SELECT [GUID], [Code], [Name], [ParentGUID] FROM [ac000] ORDER BY [Code]

	OPEN @c FETCH FROM @c INTO @GUID, @Code, @Name, @ParentGUID
	WHILE @@FETCH_STATUS = 0
	BEGIN
		-- check closed links:
		IF EXISTS ( SELECT * FROM [fnGetAccountParents](@GUID) WHERE [GUID] = @GUID)
			INSERT INTO [ErrorLog] ([Type], [g1], [c1], [c2])
				VALUES (0x1, @GUID, @Code, @Name)

		-- check broken links:
		IF ISNULL(@ParentGUID, 0x0) <> 0x0 AND NOT EXISTS (SELECT * FROM [ac000] WHERE [GUID] = @ParentGUID)
			INSERT INTO [ErrorLog] ([Type], [g1], [c1], [c2])
				VALUES (0x2, @GUID, @Code, @Name)

		FETCH FROM @c INTO @GUID, @Code, @Name, @ParentGUID
	END
	CLOSE @c
	DEALLOCATE @c

	-- check final accounts having final accounts as ParentGUIDs, and normal accounts having normal accounts as ParentGUIDs
	IF @Correct <> 1
		INSERT INTO [ErrorLog]([Type], [g1], [c1], [c2])
			SELECT 0x4, [ac1].[GUID], [ac1].[Code], [ac1].[Name] FROM [ac000] AS [ac1] INNER JOIN [ac000] AS [ac2] ON [ac1].[ParentGUID] = [ac2].[GUID] WHERE [ac1].[Type] = 1 AND [ac2].[Type] = 2
			UNION ALL
			SELECT 0x5, [ac1].[GUID], [ac1].[Code], [ac1].[Name] FROM [ac000] AS [ac1] INNER JOIN [ac000] AS [ac2] ON [ac1].[ParentGUID] = [ac2].[GUID] WHERE [ac1].[Type] = 2 AND [ac2].[Type] = 1

	-- check for missing parents:
	IF @Correct <> 1
		INSERT INTO [ErrorLog]([Type], [g1])
			SELECT 0x4, [guid] FROM [ac000] WHERE [parentGuid] NOT IN (SELECT [GUID] FROM [ac000]) AND [parentGuid] != 0x0

	IF @Correct <> 0
	BEGIN
		EXEC prcDisableTriggers 'ac000'
		UPDATE [ac000] SET [parentGuid] = 0x0 WHERE [parentGuid] != 0x0 AND [parentGuid] NOT IN (SELECT [guid] FROM [ac000])
		ALTER TABLE [ac000] ENABLE TRIGGER ALL
	END

	-- check for missing finals:
	IF @Correct <> 1
		INSERT INTO [ErrorLog]([Type], [g1])
			SELECT 0x5, [guid] FROM [ac000] WHERE [finalGuid] NOT IN (SELECT [guid] FROM [ac000]) AND [finalGuid] != 0x0

	IF @Correct <> 0
	BEGIN
		EXEC prcDisableTriggers 'ac000'
		UPDATE [ac000] SET [finalGuid] = 0x0 WHERE [finalGuid] != 0x0 AND [finalGuid] NOT IN (SELECT [guid] FROM [ac000])
		ALTER TABLE [ac000] ENABLE TRIGGER ALL
	END


###########################################################################
#END