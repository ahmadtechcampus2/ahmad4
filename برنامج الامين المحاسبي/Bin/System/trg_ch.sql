#########################################################
CREATE TRIGGER trg_ch000_CheckConstraints
	ON [ch000] FOR INSERT, UPDATE, DELETE
	NOT FOR REPLICATION

AS
/*
This trigger checks:
	- not to use main CostJobs.						(AmnE0191)
*/
	IF @@ROWCOUNT = 0 RETURN
	SET NOCOUNT ON

	-- study a case when using main CostJobs (NSons <> 0):
	IF EXISTS(SELECT * FROM [inserted] AS i INNER JOIN [co000] AS [c] ON [i].[Cost1Guid] = [c].[Guid] OR [i].[Cost2Guid] = [c].[Guid] INNER JOIN [co000] AS [c2] ON [c].[Guid] = [c2].[ParentGuid])
	BEGIN
		-- RAISERROR('AmnE0191: Can''t use main CostJobs', 16, 1)
		-- ROLLBACK TRANSACTION
		RETURN
	END

#########################################################
CREATE TRIGGER trg_ch000_useFlag
	ON [ch000] FOR INSERT, UPDATE, DELETE
AS
/*
This trigger:
  - updates UseFlag of concerned accounts.
*/
	IF @@ROWCOUNT = 0 RETURN
	SET NOCOUNT ON

	IF UPDATE([AccountGUID]) OR UPDATE([Account2GUID])
	BEGIN
		IF EXISTS(SELECT * FROM [deleted])
		BEGIN
			UPDATE [ac000] SET [UseFlag] = [UseFlag] - 1 FROM [ac000] AS [a] INNER JOIN [deleted] AS [d] ON [a].[GUID] = [d].[AccountGUID]
			UPDATE [ac000] SET [UseFlag] = [UseFlag] - 1 FROM [ac000] AS [a] INNER JOIN [deleted] AS [d] ON [a].[GUID] = [d].[Account2GUID]
		END

		IF EXISTS(SELECT * FROM [inserted])
		BEGIN
			UPDATE [ac000] SET [UseFlag] = [UseFlag] + 1 FROM [ac000] AS [a] INNER JOIN [inserted] AS [i] ON [a].[GUID] = [i].[AccountGUID]
			UPDATE [ac000] SET [UseFlag] = [UseFlag] + 1 FROM [ac000] AS [a] INNER JOIN [inserted] AS [i] ON [a].[GUID] = [i].[Account2GUID]
		END
	END
	IF [dbo].[fnGetUserSec](dbo.fnGetCurrentUserGUID(), 0X1025, 0x00, 1, 0) <= 0
		insert into ErrorLog ([level], [type], [c1], [g1]) 
		select 1, 0, 'AmnE0166: there are checked Fields', d.Guid FROM [RCH000] A INNER JOIN [deleted] d ON   A.[ObjGUID]  = d.Guid 
#########################################################
CREATE TRIGGER trg_ch000_delete
	ON [ch000] FOR DELETE
	NOT FOR REPLICATION

AS
/*
This trigger:
	- deletes related records in er and ce
*/
	IF @@ROWCOUNT = 0 RETURN
	SET NOCOUNT ON

	BEGIN TRAN

	-- deleting related data:
	DELETE [ColCh000] FROM [ColCh000] [ColCh] INNER JOIN [deleted] [d] ON [d].[GUID] = [ColCh].[ChGUID]
	DELETE [ChequeHistory000] FROM [ChequeHistory000] [chHistory] INNER JOIN [deleted] [d] ON [d].[GUID] = [chHistory].[ChequeGUID]
	DELETE [AccCostnewRatio000] FROM [AccCostnewRatio000] [accnew]  INNER JOIN [deleted] [d] ON [d].[GUID] = [accnew].[ParentGUID]
	DELETE au FROM Audit000 au INNER JOIN [deleted] ON au.AuditRelGuid = deleted.GUID
	DECLARE
		@c CURSOR,
		@g [UNIQUEIDENTIFIER]
	SET @c = CURSOR FAST_FORWARD FOR SELECT [GUID] FROM [deleted]

	OPEN @c FETCH FROM @c INTO @g
	WHILE @@FETCH_STATUS = 0
	BEGIN
		EXEC [prcER_delete] @g
		FETCH FROM @c INTO @g
	END	CLOSE @c DEALLOCATE @c
	
	COMMIT TRAN
#########################################################
#END