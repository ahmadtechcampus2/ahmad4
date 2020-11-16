#########################################################
CREATE TRIGGER trg_ng000_delete 
	ON [ng000] FOR DELETE 
	NOT FOR REPLICATION
AS 
/* 
This trigger: 
	- deletes related records: ni
*/ 
	IF @@ROWCOUNT = 0 
		RETURN 
	-- deleting related data: 
	DELETE [ni000] FROM [ni000] INNER JOIN [deleted] ON [ni000].[ParentGUID] = [deleted].[GUID]

#########################################################
#END