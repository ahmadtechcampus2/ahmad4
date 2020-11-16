#########################################################
CREATE TRIGGER trg_di000_CheckConstraints
	ON [di000] FOR INSERT
	NOT FOR REPLICATION

AS
/*
This trigger checks:
	- not to use main CostJobs.									(AmnE0200)

*/
	IF @@ROWCOUNT = 0 RETURN
	SET NOCOUNT ON

	-- study a case when using main CostJobs (NSons <> 0):
	IF EXISTS(SELECT * FROM [inserted] AS [i] INNER JOIN [co000] AS [c] ON [i].[CostGuid] = [c].[Guid] INNER JOIN [co000] AS [c2] ON [c].[Guid] = [c2].[ParentGuid])
	BEGIN
		-- RAISERROR('AmnE0200: Can''t use main CostJobs', 16, 1)
		-- ROLLBACK TRANSACTION
		RETURN
	END


#########################################################
CREATE TRIGGER trg_di000_useFlag
	ON [di000] FOR INSERT, UPDATE, DELETE
	NOT FOR REPLICATION

AS
/*
This trigger:
  - updates UseFlag of concerned accounts.
*/
	IF @@ROWCOUNT = 0 RETURN
	SET NOCOUNT ON

	IF UPDATE([AccountGUID])
	BEGIN
		IF EXISTS(SELECT * FROM [deleted])
			UPDATE [ac000] SET [UseFlag] = [UseFlag] - 1 FROM [ac000] AS [a] INNER JOIN [deleted] AS [d] ON [a].[GUID] = [d].[AccountGUID]

		IF EXISTS(SELECT * FROM [inserted])
			UPDATE [ac000] SET [UseFlag] = [UseFlag] + 1 FROM [ac000] AS [a] INNER JOIN [inserted] AS [i] ON [a].[GUID] = [i].[AccountGUID]
	END

#########################################################
#END