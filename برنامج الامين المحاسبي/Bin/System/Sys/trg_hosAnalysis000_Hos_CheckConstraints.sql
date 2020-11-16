##########################
CREATE TRIGGER trg_hosAnalysis000_Hos_CheckConstraints 
	ON hosAnalysis000 FOR INSERT, UPDATE, DELETE  
	NOT FOR REPLICATION
AS
/*  
This trigger checks:  
	- not to delete used Site used in Patient dossier 
*/
SET NOCOUNT ON 
	IF @@ROWCOUNT = 0  
		RETURN  
	DECLARE 
		@c			CURSOR, 
		@GUID		[VARCHAR](128), 
		@Parent		[UNIQUEIDENTIFIER], 
		@OldParent	[UNIQUEIDENTIFIER], 
		@NewParent	[UNIQUEIDENTIFIER]

	declare @t table([g] [uniqueidentifier]) 

	IF NOT EXISTS(SELECT * FROM inserted)  
	BEGIN  
		insert into ErrorLog (level, type, c1, g1)  
			select 1, 0, 'AmnE0506: card already used in Analysis Order', d.guid  
			from HosToDoAnalysis000 AS T inner join deleted d on T.AnalysisGUID = d.guid  
	END 
	-- when updating Parents: 
/*
select * from hosAnalysis000
*/


	IF UPDATE([ParentGUID])
	BEGIN 
		SET @c = CURSOR FAST_FORWARD FOR 
						SELECT 
							CAST( ISNULL([i].[GUID], [d].[GUID]) AS [VARCHAR](128)), 
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
				SET @Parent = (SELECT [ParentGUID] FROM [hosAnalysis000] WHERE [GUID] = @Parent) 
				/*
				IF @Parent IS NULL 
					insert into [ErrorLog] ([level], [type], [c1], [g1]) select 1, 0, 'AmnE0512: Parent not found (Orphants)', @guid 
				*/
				-- short-circuit check: 
				IF @Parent = @GUID 
					insert into [ErrorLog] ([level], [type], [c1], [g1]) select 1, 0, 'AmnE0513: Parent found descending from own sons (Short Circuit)', @guid 
			END 
			-- descending from a used analysis: 
			IF [dbo].[fnAnalysis_IsUsed](@NewParent) BETWEEN 0x1 AND 0xFFFF 
				insert into [ErrorLog] ([level], [type], [c1], [g1]) select 1, 0, 'AmnE0514: Analysis(s) found descend from used analysis(s)...', @guid 
	
			FETCH FROM @c INTO @GUID, @OldParent, @NewParent
		END 
		CLOSE @c DEALLOCATE @c 
	END 

/* 
select * from hosAnalysis000 
select * from hosAnalysisOrder000 
select * from HosToDoAnalysis000 
select * from hospFile000 
select * from hosAnalysisOrderDetail000 
dbo.HosAnalysisResults000 
-- hosAnalysisOrder000 
*/ 
#########################
#END