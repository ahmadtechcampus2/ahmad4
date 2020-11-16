#########################################################
CREATE TRIGGER trg_BPOptions000_delete 
	ON [BPOptions000] FOR delete 
	NOT FOR REPLICATION

AS 
	IF @@ROWCOUNT = 0 RETURN
	SET NOCOUNT ON 

	DELETE [BPOptionsDetails000]
	FROM 
		[BPOptionsDetails000] [od] 
		INNER JOIN [deleted] [d] ON [d].[GUID] = [od].[ParentGUID]
#########################################################
#END
