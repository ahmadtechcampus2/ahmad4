#########################################################
CREATE TRIGGER trg_BLMain000_delete 
	ON [BLMain000] FOR delete 
	NOT FOR REPLICATION

AS 
	IF @@ROWCOUNT = 0 RETURN
	SET NOCOUNT ON 

	DELETE [BLHeader000]
	FROM 
		[BLHeader000] [h] 
		INNER JOIN [deleted] [d] ON [d].[GUID] = [h].[ParentGUID]

	DELETE [BLItemsHeader000]
	FROM 
		[BLItemsHeader000] [ih] 
		INNER JOIN [deleted] [d] ON [d].[GUID] = [ih].[ParentGUID]

	DELETE [BPOptions000]
	FROM 
		[BPOptions000] [o]
		INNER JOIN [deleted] [d] ON [d].[GUID] = [o].[BillLayoutGUID]

	DELETE [BPOptionsDetails000]
	FROM 
		[BPOptionsDetails000] [od]
		INNER JOIN [deleted] [d] ON [d].[GUID] = [od].[BillLayoutGUID]

#########################################################
CREATE TRIGGER trg_BLItemsHeader000_delete 
	ON [BLItemsHeader000] FOR delete
	NOT FOR REPLICATION
	 
AS 
	IF @@ROWCOUNT = 0 RETURN
	SET NOCOUNT ON 

	DELETE [BLItems000]
	FROM 
		[BLItems000] [i] 
		INNER JOIN [deleted] [d] ON [d].[GUID] = [i].[ParentGUID]

#########################################################
#END
