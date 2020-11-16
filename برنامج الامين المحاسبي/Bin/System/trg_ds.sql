#########################################################
CREATE TRIGGER trg_ds000_Delete ON [ds000] FOR DELETE
	NOT FOR REPLICATION

AS
/*
This trigger:
	- deletes related records.
*/
	IF @@ROWCOUNT = 0 RETURN
	SET NOCOUNT ON

	-- deleting related data: 
	DELETE [df000] FROM [df000] INNER JOIN [deleted] ON [df000].[ParentGUID] = [deleted].[GUID]

#########################################################
#END