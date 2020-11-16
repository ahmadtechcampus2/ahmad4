#########################################################
CREATE TRIGGER trg_Site000_delete 
	ON [Site000] FOR DELETE ,UPDATE
	NOT FOR REPLICATION
AS
	IF @@ROWCOUNT = 0 RETURN
	SET NOCOUNT ON	

	DELETE  [hosSiteDetail000] FROM [hosSiteDetail000] [s] INNER JOIN [deleted] [d] ON
		[s].[parentGuid] = [d].[guid]

#########################################################
#END