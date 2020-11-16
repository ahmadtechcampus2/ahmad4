########################################################
CREATE TRIGGER trg_ab000_delete ON [ab000] FOR DELETE
NOT FOR REPLICATION
AS
	SET NOCOUNT ON 
	
	DELETE [abd000] FROM [abd000] [a] INNER JOIN [deleted] [d] ON 
		[a].[parentGuid] = [d].[guid]

#########################################################
#END