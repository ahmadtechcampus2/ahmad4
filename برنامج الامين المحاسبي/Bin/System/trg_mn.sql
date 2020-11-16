#########################################################
CREATE TRIGGER trg_mn000_useFlag
	ON [mn000] FOR INSERT, UPDATE, DELETE
	NOT FOR REPLICATION
AS
/*
This trigger:
  - updates UseFlag of concerned accounts.
*/
	IF @@ROWCOUNT = 0 RETURN
	SET NOCOUNT ON
	
	IF UPDATE([InAccountGUID]) OR UPDATE([OutAccountGUID]) OR UPDATE([InTempAccGUID]) OR UPDATE([OutTempAccGUID])
	BEGIN
		IF EXISTS(SELECT * FROM [deleted])
		BEGIN
			UPDATE [ac000] SET [UseFlag] = [UseFlag] - 1 FROM [ac000] AS [a] INNER JOIN [deleted] AS [d] ON [a].[GUID] = [d].[InAccountGUID]
			UPDATE [ac000] SET [UseFlag] = [UseFlag] - 1 FROM [ac000] AS [a] INNER JOIN [deleted] AS [d] ON [a].[GUID] = [d].[OutAccountGUID]
			UPDATE [ac000] SET [UseFlag] = [UseFlag] - 1 FROM [ac000] AS [a] INNER JOIN [deleted] AS [d] ON [a].[GUID] = [d].[InTempAccGUID]
			UPDATE [ac000] SET [UseFlag] = [UseFlag] - 1 FROM [ac000] AS [a] INNER JOIN [deleted] AS [d] ON [a].[GUID] = [d].[OutTempAccGUID]
		END

		IF EXISTS(SELECT * FROM [inserted])
		BEGIN
			UPDATE [ac000] SET [UseFlag] = [UseFlag] + 1 FROM [ac000] AS [a] INNER JOIN [inserted] AS [i] ON [a].[GUID] = [i].[InAccountGUID]
			UPDATE [ac000] SET [UseFlag] = [UseFlag] + 1 FROM [ac000] AS [a] INNER JOIN [inserted] AS [i] ON [a].[GUID] = [i].[OutAccountGUID]
			UPDATE [ac000] SET [UseFlag] = [UseFlag] + 1 FROM [ac000] AS [a] INNER JOIN [inserted] AS [i] ON [a].[GUID] = [i].[InTempAccGUID]
			UPDATE [ac000] SET [UseFlag] = [UseFlag] + 1 FROM [ac000] AS [a] INNER JOIN [inserted] AS [i] ON [a].[GUID] = [i].[OutTempAccGUID]
		END
	END

#########################################################
CREATE TRIGGER trg_mn000_delete
	ON [mn000] FOR DELETE
	NOT FOR REPLICATION
AS
/*
This trigger:
	- deletes related records: mi
*/
	IF @@ROWCOUNT = 0 RETURN 
	SET NOCOUNT ON 
	-- delete related bills: 
	DECLARE @ManGuid uniqueidentifier
	SELECT @ManGuid = [GUID] FROM [deleted]
	EXEC [prcManufac_deleteBills] @ManGuid
	-- deleting related data: 
	DELETE [mb000] FROM [mb000] INNER JOIN [deleted] AS MN ON Mn.Guid = [mb000].[ManGUID]
	DELETE [mi000] FROM [mi000] INNER JOIN [deleted] AS MN ON Mn.Guid = [mi000].[ParentGUID]
	DELETE [mx000] FROM [mx000] INNER JOIN [deleted] AS MN ON Mn.Guid = [mx000].[ParentGUID]
	DELETE [ManWorker000] FROM [ManWorker000] INNER JOIN [deleted] AS MN ON Mn.Guid = [ManWorker000].[ParentGUID]
	DELETE [ManMachines000] FROM [ManMachines000] INNER JOIN [deleted] AS MN ON Mn.Guid = [ManMachines000].[ParentGUID]

#########################################################
#END