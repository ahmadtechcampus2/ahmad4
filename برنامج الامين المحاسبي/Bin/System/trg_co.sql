#########################################################
CREATE TRIGGER trg_co000_CheckConstraints
	ON [co000] FOR INSERT, UPDATE, DELETE
	NOT FOR REPLICATION

AS
/*
This trigger checks:
	- not to delete used cost centers
	- that new Parent(s) are already present (Orphants).
	- that new hosting parents are never descendants of the moving branches (Short-Circuit).
	- that no Account should be descending from used accounts
*/
	IF @@ROWCOUNT = 0
		RETURN
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
				SET @Parent = (SELECT [ParentGUID] FROM [co000] WHERE [GUID] = @Parent)
				IF @Parent IS NULL
					insert into [ErrorLog] ([level], [type], [c1], [g1]) select 1, 0, 'AmnE0091: Parent(s) not found (Orphants)', @guid

				--Short-Circuit check:
				IF @Parent = @GUID
					insert into [ErrorLog] ([level], [type], [c1], [g1]) select 1, 0, 'AmnE0092: Parent(s) found descending from own sons (Short Circuit)', @guid

			END

			FETCH FROM @c INTO @GUID, @OldParent, @NewParent
		END
		CLOSE @c DEALLOCATE @c

	END

	IF NOT EXISTS(SELECT * FROM [inserted])
	BEGIN
		insert into [ErrorLog] ([level], [type], [c1], [g1])
			select 1, 0, 'AmnE0093: No. of sons is not zero can''t delete card', d.[guid]
			from [co000] [c] inner join [deleted] [d] on [c].[parentGuid] = [d].[guid]
		insert into [ErrorLog] ([level], [type], [c1], [g1])
			select 1, 0, 'AmnE0095: card already used in bill', [d].[guid]
			from [bu000] [b] inner join [deleted] [d] on [b].[CostGuid] = [d].[guid]
		insert into [ErrorLog] ([level], [type], [c1], [g1])
			select 1, 0, 'AmnE0096: card already used in bill item', [d].[guid]
			from [bi000] [b] inner join [deleted] [d] on [b].[CostGuid] = [d].[guid]
		insert into [ErrorLog] ([level], [type], [c1], [g1])
			select 1, 0, 'AmnE0097: card already used in bill types', [d].[guid]
			from [bt000] [b] inner join [deleted] [d] on [b].[DefCostGuid] = [d].[guid]
		insert into [ErrorLog] ([level], [type], [c1], [g1])
			select 1, 0, 'AmnE0094: card already used in entry', [d].[guid]
			from [en000] [e] inner join [deleted] [d] on [e].[CostGuid] = [d].[guid]
		insert into [ErrorLog] ([level], [type], [c1], [g1])
			select 1, 0, 'AmnE0098: card already used in budjet', [d].[guid]
			from [abd000] [e] inner join [deleted] [d] on [e].[CostGuid] = [d].[guid]
		insert into [ErrorLog] ([level], [type], [c1], [g1]) 
			select 1, 0, 'AmnE0099: card already used in job order', [d].[guid] 
			from [JobOrder000] [JobOrder] inner join [deleted] [d] on [JobOrder].[CostCenter] = [d].[guid]
		insert into [ErrorLog] ([level], [type], [c1], [g1]) 
			select 1, 0, 'AmnE0100: card already used in Note Template', [d].[guid] 
			from [NT000] [NoteTemplate] inner join [deleted] [d] on [NoteTemplate].[DefaultCostcenter] = [d].[guid]
		insert into [ErrorLog] ([level], [type], [c1], [g1])
			select 1, 0, 'AmnE0101: card already used in another CostCenterCard .can''t delete card', d.[guid]
			from [CostItem000] [Cost] inner join [deleted] [d] ON [Cost].[SonGUID] = [d].[guid]
		insert into [ErrorLog] ([level], [type], [c1], [g1])
			select 1, 0, 'AmnE0102: card already used in Checks operation .can''t delete card', d.[guid]
			from [ch000] [check] inner join [deleted] [d] ON [d].[guid] IN ([check].[Cost1GUID] ,[check].[Cost2GUID])
		insert into [ErrorLog] ([level], [type], [c1], [g1])
			select 1, 0, 'AmnE0103: card already used in NewRatio of another distributive CostCenter .can''t delete card', d.[guid]
			from [AccCostNewRatio000] [NewRatioTbl] inner join [deleted] [d] ON [d].[guid] = [NewRatioTbl].[SonGUID]
		insert into [ErrorLog] ([level], [type], [c1], [g1])
			select 1, 0, 'AmnE0104: card already used in Notification system .can''t delete card', d.[guid]
			from  NSGetCostCenterUse() fn  inner join [deleted] [d] ON [d].[guid] = [fn].[GUID]

	END	
#########################################################
#END
