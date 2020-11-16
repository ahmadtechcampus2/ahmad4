#########################################################
CREATE TRIGGER trg_dp000_CheckConstraints
	ON [dp000] FOR INSERT
	NOT FOR REPLICATION

AS
/*
This trigger checks:
	- not to use main CostJobs.									(AmnE0210)
*/
	IF @@ROWCOUNT = 0 RETURN
	SET NOCOUNT ON

	-- study a case when using main CostJobs (NSons <> 0):
	IF EXISTS(SELECT * FROM [inserted] AS [i] INNER JOIN [co000] AS [c] ON [i].[CostGuid] = [c].[Guid] INNER JOIN [co000] AS [c2] ON [c].[Guid] = [c2].[ParentGuid])
	BEGIN
		-- RAISERROR('AmnE0210: Can''t use main CostJobs', 16, 1)
		-- ROLLBACK TRANSACTION
		RETURN
	END

##########################################################
CREATE TRIGGER trg_dp000_delete ON [dp000] FOR DELETE
AS
	IF @@ROWCOUNT = 0 RETURN
	SET NOCOUNT ON

	-- delete related dd000 records:
	DELETE [dd000] FROM [dd000] AS [d] INNER JOIN [deleted] AS [l] ON [d].[parentGUID] = [l].[GUID]

	-- delete related entries:
	DECLARE
		@c CURSOR,
		@g [UNIQUEIDENTIFIER]

	SET @c = CURSOR FAST_FORWARD FOR SELECT [GUID] FROM [deleted]

	OPEN @c FETCH FROM @c INTO @g
	WHILE @@FETCH_STATUS = 0
	BEGIN
		EXEC [prcDP_DeleteEntry] @g
		FETCH FROM @c INTO @g
	END

	CLOSE @c DEALLOCATE @c

#########################################################
CREATE TRIGGER trg_Dp000_useFlag
	ON [Dp000] FOR INSERT, UPDATE, DELETE 
	NOT FOR REPLICATION

AS 

/* 
This trigger: 
  - updates UseFlag of ad000. 
*/ 
	IF @@ROWCOUNT = 0 RETURN 
	SET NOCOUNT ON 
	 
	IF EXISTS(SELECT * FROM [deleted]) 
	BEGIN 
			UPDATE [ad000] SET [UseFlag] = [UseFlag] - 1 FROM [ad000] AS [a] INNER JOIN [deleted] AS [d] ON [a].[GUID] = [d].[Ad_Guid]
	END 
	 
	IF EXISTS(SELECT * FROM [inserted]) 
	BEGIN 
			UPDATE [ad000] SET [UseFlag] = [UseFlag] + 1 FROM [ad000] AS [a] INNER JOIN [inserted] AS [i] ON [a].[GUID] = [i].[Ad_Guid] 
	END 
#########################################################
#END