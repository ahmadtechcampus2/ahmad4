#########################################################
CREATE TRIGGER trg_df000_Delete ON [df000] FOR DELETE
	NOT FOR REPLICATION

AS
/*
This trigger:
	- deletes related records.
*/
	IF @@ROWCOUNT = 0 RETURN
	SET NOCOUNT ON

	-- deleting related data:
	DELETE [fa000] FROM [fa000] INNER JOIN [deleted] 
	ON [fa000].[ParentGUID] = [deleted].[GUID]

	DELETE [fn000] FROM [fn000] INNER JOIN [deleted] 
	ON [fn000].[GUID] = [deleted].[FontGUID]

#########################################################
#END