##################################
CREATE TRIGGER trg_hosAnaCat000_Hos_CheckConstraints
	ON hosAnaCat000 FOR INSERT, UPDATE, DELETE 
	NOT FOR REPLICATION
AS 
/* 
This trigger checks: 
	- not to delete used analysis category used in analysis card
*/ 
SET NOCOUNT ON 
	IF @@ROWCOUNT = 0 
		RETURN 
	DECLARE 
		@c			CURSOR, 
		@GUID		[NVARCHAR](128), 
		@Parent		[UNIQUEIDENTIFIER], 
		@OldParent	[UNIQUEIDENTIFIER], 
		@NewParent	[UNIQUEIDENTIFIER]

	declare @t table([g] [uniqueidentifier]) 

	IF NOT EXISTS(SELECT * FROM inserted) 
	BEGIN 
		insert into ErrorLog (level, type, c1, g1) 
			select 1, 0, 'AmnE0508: card already used in Analysis Category card...', d.guid 
			from vwHosAnalysis AS T inner join deleted d on T.ParentGUID = d.guid 
	END

	IF UPDATE([ParentGUID])
	BEGIN
		SET @c = CURSOR FAST_FORWARD FOR 
						SELECT 
							CAST( ISNULL([i].[GUID], [d].[GUID]) AS [NVARCHAR](128)), 
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
				SET @Parent = (SELECT [ParentGUID] FROM [hosAnaCat000] WHERE [GUID] = @Parent) 
				IF @Parent IS NULL 
					insert into [ErrorLog] ([level], [type], [c1], [g1]) select 1, 0, 'AmnE0515: Parent not found (Orphants)', @guid 
				-- short-circuit check: 
				IF @Parent = @GUID 
					insert into [ErrorLog] ([level], [type], [c1], [g1]) select 1, 0, 'AmnE0516: Parent found descending from own sons (Short Circuit)', @guid 
			END 
			-- descending from a used analysis category: 
			IF [dbo].[fnAnaCat_IsUsed](@NewParent) BETWEEN 0x1 AND 0xFFFF 
				insert into [ErrorLog] ([level], [type], [c1], [g1]) select 1, 0, 'AmnE0517: Analysis vategory (s) found descend from used analysis category(s)...', @guid 
	
			FETCH FROM @c INTO @GUID, @OldParent, @NewParent
		END 
		CLOSE @c DEALLOCATE @c 
	END 


/*

select * from hosAnaCat000
select * from vwHosAnalysis

*/
#################################
#END