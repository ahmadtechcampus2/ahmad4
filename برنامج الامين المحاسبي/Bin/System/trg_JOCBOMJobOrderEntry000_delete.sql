########################################################
CREATE TRIGGER trg_JOCBOMJobOrderEntry000_delete ON [JOCBOMJobOrderEntry000] FOR DELETE
NOT FOR REPLICATION
AS
	SET NOCOUNT ON 
	
	DELETE [JOCBOMDirectExpenseItems000] FROM [JOCBOMDirectExpenseItems000] [a] INNER JOIN [deleted] [d] ON 
		[a].[ParentGuid] = [d].[guid]

#########################################################
#END