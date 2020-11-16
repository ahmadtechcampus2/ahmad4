#########################################################
CREATE TRIGGER trg_gr000_CheckConstraints
	ON [gr000] FOR INSERT, UPDATE, DELETE
	NOT FOR REPLICATION

AS
/*
This trigger checks:
	- not to delete used accounts
	- that new Parent(s) are already present (Orphants).
	- that new hosting parents are never descendants of the moving branches (Short-Circuit).
	- that no Account should be descending from used accounts
*/
	IF @@ROWCOUNT = 0 RETURN
	SET NOCOUNT ON	

	DECLARE
		@c			CURSOR,
		@GUID		[NVARCHAR](128),
		@Parent		[UNIQUEIDENTIFIER],
		@OldParent	[UNIQUEIDENTIFIER],
		@NewParent	[UNIQUEIDENTIFIER]

	-- when updating Parents:
	IF UPDATE([ParentGUID])
	BEGIN
		SET @c = CURSOR FAST_FORWARD FOR
						SELECT
							CAST(ISNULL([i].[GUID], [d].[GUID]) AS [NVARCHAR](128)),
							ISNULL([d].[ParentGUID], 0x0),
							ISNULL([i].[ParentGUID], 0x0)
						FROM [inserted] AS [i] FULL JOIN [deleted] AS [d] ON [i].[GUID] = [d].[GUID]

		OPEN @c FETCH FROM @c INTO @GUID, @OldParent, @NewParent

		WHILE @@FETCH_STATUS = 0
		BEGIN
			SET @Parent = @NewParent
			WHILE @Parent <> 0x0
			BEGIN
				-- orphants
				SET @Parent = (SELECT [ParentGUID] FROM [gr000] WHERE [GUID] = @Parent)
				IF @Parent IS NULL
					insert into [ErrorLog] ([level], [type], [c1], [g1]) select 1, 0, 'AmnE0110: Parent(s) not found (Orphants)', @guid

				--Short-Circuit check:
				IF @Parent = @GUID
					insert into [ErrorLog] ([level], [type], [c1], [g1]) select 1, 0, 'AmnE0281: Parent(s) found descending from own sons (Short Circuit)...', @guid

			END

			FETCH FROM @c INTO @GUID, @OldParent, @NewParent
		END
		CLOSE @c DEALLOCATE @c
	END
	IF [dbo].[fnObjectExists]('bg000') <> 0 
	BEGIN
		IF EXISTS ( 
			SELECT * 
			FROM 
				deleted d 
				INNER JOIN bg000 bg ON d.GUID = bg.GroupGUID 
				LEFT JOIN inserted i ON d.guid = i.guid  
			WHERE i.GUID IS NULL)
		BEGIN 
			INSERT INTO [ErrorLog] ([level], [type], [c1], [g1]) 
			SELECT 1, 0, 'AmnE0282: Can''t delete Group(s), it''s being used in POS', @guid
		END 
	END


#########################################################
CREATE TRIGGER trg_gr000_delete
	ON [gr000] FOR DELETE
	NOT FOR REPLICATION
AS
	-- delete related ma
	IF @@ROWCOUNT = 0 RETURN
	SET NOCOUNT ON	

	DELETE [ma000] FROM [ma000] AS [m] INNER JOIN [deleted] AS [d] ON [m].[ObjGUID] = [d].[GUID]

#########################################################
#END