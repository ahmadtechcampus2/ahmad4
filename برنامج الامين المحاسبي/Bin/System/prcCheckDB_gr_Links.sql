############################################################################################
CREATE PROCEDURE prcCheckDB_gr_Links
	@Correct [INT] = 0
AS
/*
This method checks, corrects and reports the following:
	- 0x101 parent closed links.
	- 0x102 parent broken links.
*/
	DECLARE
		@c CURSOR,
		@GUID [UNIQUEIDENTIFIER],
		@Code [NVARCHAR](50),
		@Name [NVARCHAR](50),
		@ParentGUID [UNIQUEIDENTIFIER]

	EXEC prcDisableTriggers 'gr000'

	SET @c = CURSOR DYNAMIC FOR SELECT [GUID], [Code], [Name], [ParentGUID] FROM [gr000] ORDER BY [Code]
	
				
	OPEN @c FETCH FROM @c INTO @GUID, @Code, @Name, @ParentGUID
	WHILE @@FETCH_STATUS = 0
	BEGIN
		-- check closed links:
		IF EXISTS(SELECT * FROM [fnGetGroupParents](@GUID) WHERE [GUID] = @GUID)
		BEGIN
			IF @Correct <> 1
				INSERT INTO [ErrorLog] ([Type], [g1], [c1], [c2]) VALUES ( 0x101, @GUID, @Code, @Name)

			IF @Correct <> 0
				UPDATE [gr000] SET [ParentGUID] = 0x0 WHERE CURRENT OF @c
		END

		-- check broken links:
		IF ISNULL(@ParentGUID, 0x0) <> 0x0
			IF NOT EXISTS ( SELECT * FROM [gr000] WHERE [GUID] = @ParentGUID)
			BEGIN
				IF @Correct <> 1
					INSERT INTO [ErrorLog] ([Type], [g1], [c1], [c2]) VALUES ( 0x102, @GUID, @Code, @Name)
				IF @Correct <> 0
					UPDATE [gr000] SET [ParentGUID] = 0x0 WHERE CURRENT OF @c
			END

		FETCH FROM @c INTO @GUID, @Code, @Name, @ParentGUID
				
	END	
	
	close @c deallocate @c
	
	ALTER TABLE [gr000] ENABLE TRIGGER ALL

############################################################################################
#END