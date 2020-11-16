############################################################################################
CREATE PROCEDURE prcCheckDB_st_Links
	@Correct [INT] = 0
AS
/*
This method checks, corrects and reports the following:
	- 0x201 ParentGUID closed links.
	- 0x202 ParentGUID broken links.
*/
	DECLARE
		@c CURSOR,
		@GUID [UNIQUEIDENTIFIER],
		@Code [NVARCHAR](50),
		@Name [NVARCHAR](50),
		@ParentGUID [UNIQUEIDENTIFIER]

	EXEC prcDisableTriggers 'st000'
	SET @c = CURSOR DYNAMIC FOR SELECT [GUID], [Code], [Name], [ParentGUID] FROM [st000] ORDER BY [Code]

	OPEN @c FETCH FROM @c INTO @GUID, @Code, @Name, @ParentGUID
	WHILE @@FETCH_STATUS = 0
	BEGIN
		-- check closed links:
		IF EXISTS(SELECT * FROM [fnGetStoreParents](@GUID) WHERE [GUID] = @GUID)
		BEGIN
			IF @Correct <> 1
				INSERT INTO [ErrorLog]([Type], [g1], [c1], [c2]) VALUES(0x201, @GUID, @Code, @Name)
			IF @Correct <> 0
			BEGIN
				EXEC prcDisableTriggers 'st000'
				UPDATE [st000] SET [ParentGUID] = 0x0 WHERE CURRENT OF @c
				ALTER TABLE [st000] ENABLE TRIGGER ALL
			END
		END

		-- check broken links:
		IF ISNULL(@ParentGUID, 0x0) <> 0x0
			IF NOT EXISTS(SELECT * FROM [st000] WHERE [GUID] = @ParentGUID)
			BEGIN
				IF @Correct <> 1
					INSERT INTO [ErrorLog] ([Type], [g1], [c1], [c2]) VALUES ( 0x202, @GUID, @Code, @Name)
				IF @Correct <> 0
				BEGIN
					UPDATE [st000] SET [ParentGUID] = 0x0 WHERE CURRENT OF @c
				END
			END

		FETCH FROM @c INTO @GUID, @Code, @Name, @ParentGUID
	END
	
	close @c deallocate @c
	
	ALTER TABLE [st000] ENABLE TRIGGER ALL
	
############################################################################################
#END