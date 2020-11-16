#########################################################
CREATE TRIGGER trg_st000_CheckConstraints
	ON [st000] FOR INSERT, UPDATE, DELETE
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
	IF UPDATE(ParentGUID)
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
				SET @Parent = (SELECT [ParentGUID] FROM [st000] WHERE [GUID] = @Parent)
				IF @Parent IS NULL
					insert into [ErrorLog] ([level], [type], [c1], [g1])
						select 1, 0, 'AmnE0110: Parent(s) not found (Orphants)', @guid

				--Short-Circuit check:
				IF @Parent = @GUID
					insert into [ErrorLog] ([level], [type], [c1], [g1])
						select 1, 0, 'AmnE0111: Parent(s) found descending from own sons (Short Circuit)', @guid

			END

			FETCH FROM @c INTO @GUID, @OldParent, @NewParent
		END
		CLOSE @c DEALLOCATE @c
	END

	-- check store usage
	IF NOT EXISTS(SELECT * FROM inserted)
		BEGIN
			-- as a aprent store
			insert into [ErrorLog] ([level], [type], [c1], [g1])
				select 1, 0, 'AmnE0112: No. of sons is not zero can''t delete card', [d].[guid]
					from [st000] [s] inner join [deleted] [d] on [s].[ParentGUID] = [d].[GUID]
					
			-- in a bill
			insert into [ErrorLog] ([level], [type], [c1], [g1], [g2])
				SELECT 1, 0, 'AmnE00113: Store is used in bills', [d].[guid], [b].[GUID]
					FROM [deleted] AS [d] INNER JOIN [bu000] [b] ON [d].[guid] = [b].[StoreGUID]
			
			-- in bill items
			insert into [ErrorLog] ([level], [type], [c1], [g1], [g2])
				SELECT 1, 0, 'AmnE00114: Store is used in bill items', [d].[guid], [b].[ParentGUID]
					FROM [deleted] AS [d] INNER JOIN [bi000] [b] ON [d].[guid] = [b].[StoreGUID]

			-- in bill templates
			insert into [ErrorLog] ([level], [type], [c1], [g1], [g2])
				SELECT 1, 0, 'AmnE00115: Store is used in bill template', [d].[guid], [b].[GUID]
					FROM [deleted] AS [d] INNER JOIN [bt000] [b] ON [d].[guid] = [b].[DefStoreGUID]
					
			-- in Job Order
			insert into [ErrorLog] ([level], [type], [c1], [g1], [g2]) 
				SELECT 1, 0, 'AmnE00117: Store is used in job order', [d].[guid], [JobOrder].[GUID] 
					FROM [deleted] AS [d] INNER JOIN [JobOrder000] [JobOrder] ON [d].[guid] = [JobOrder].[Store] 

			-- in Notification system
			insert into [ErrorLog] ([level], [type], [c1], [g1]) 
				SELECT 1, 0, 'AmnE00118: Store is used in Notification system', [d].[guid] 
					FROM [deleted] AS [d] INNER JOIN NSGetStoreUse() fn ON [d].[guid] = [fn].Guid 
				
		END
		
	IF EXISTS (SELECT * FROM ReconcileInOutBill000 r INNER JOIN [deleted] d ON r.stGUID = d.guid LEFT JOIN INSERTED i ON i.Guid = d.Guid WHERE i.Guid IS NULL)
		BEGIN
			insert into [ErrorLog] ([level], [type], [c1], [g1], [g2]) 
					SELECT 1, 0, 'AmnE00116: Store is used in ReconcileInOutBill', 0x0, 0x0
		END

#########################################################
CREATE TRIGGER trg_st000_useFlag
	ON [st000] FOR INSERT, UPDATE, DELETE
	NOT FOR REPLICATION
AS
/*
This trigger:
  - updates UseFlag of concerned accounts.
*/
	IF @@ROWCOUNT = 0 RETURN
	SET NOCOUNT ON

	IF EXISTS(SELECT * FROM [deleted])
		UPDATE [ac000] SET [UseFlag] = [UseFlag] - 1 FROM [ac000] AS [a] INNER JOIN [deleted] AS [d] ON [a].[GUID] = [d].[AccountGUID]

	IF EXISTS(SELECT * FROM [inserted])
		UPDATE [ac000] SET [UseFlag] = [UseFlag] + 1 FROM [ac000] AS [a] INNER JOIN inserted AS [i] ON [a].[GUID] = [i].[AccountGUID]


###########################################################################
#END