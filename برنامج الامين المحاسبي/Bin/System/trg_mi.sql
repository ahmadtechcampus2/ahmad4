#########################################################
CREATE TRIGGER trg_mi000_CheckConstraints
	ON [mi000] FOR INSERT, UPDATE, DELETE
	NOT FOR REPLICATION
AS
/*
This trigger checks:
	- not to use main stores.											(AmnE0230)
	- not to use main CostJobs.										(AmnE0231)
*/
	IF @@ROWCOUNT = 0 RETURN
	SET NOCOUNT ON

	-- study a case when using main Stores (NSons <> 0):
	IF EXISTS(SELECT * FROM [inserted] AS [i] INNER JOIN [st000] AS [s] ON [i].[StoreGuid] = [s].[Guid] INNER JOIN [st000] AS [s2] ON s.[Guid] = [s2].[ParentGuid])
	BEGIN
		-- RAISERROR('AmnE0230: Can''t use main stores', 16, 1)
		-- ROLLBACK TRANSACTION
		RETURN
	END

	-- study a case when using main CostJobs (NSons <> 0):
	IF EXISTS(SELECT * FROM [inserted] AS [i] INNER JOIN [co000] AS [c] ON [i].[CostGuid] = [c].[Guid] INNER JOIN [co000] AS [c2] ON [c].[Guid] = [c2].[ParentGuid])
	BEGIN
		-- RAISERROR('AmnE0231: Can''t use main CostJobs', 16, 1)
		-- ROLLBACK TRANSACTION
		RETURN
	END

#########################################################
CREATE  TRIGGER trg_mi000_delete 
	ON [mi000] FOR DELETE 
AS 
/* 
This trigger: 
	- deletes related records: misn000
*/ 
	IF @@ROWCOUNT = 0 RETURN 
	SET NOCOUNT ON 
	-- deleting related data: 
	DELETE [misn000] FROM [misn000] INNER JOIN [deleted] ON [misn000].[miGUID] = [deleted].[GUID] 
	
#########################################################
#END