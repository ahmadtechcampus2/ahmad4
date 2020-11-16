###############################################################################
CREATE PROC prcEntry_delete
	@EntryGUID [UNIQUEIDENTIFIER] = NULL
AS
/*
this procedure deletes an entry given its GUID
*/
	SET NOCOUNT ON 

	-- unpost the entry:
	IF @EntryGUID IS NOT NULL
		UPDATE [ce000] SET [IsPosted] = 0 FROM [ce000] WHERE [GUID] = @EntryGUID

	-- delete the entry:
	IF @@ROWCOUNT <> 0  
		DELETE [ce000] WHERE [GUID] = @EntryGUID 
		
###############################################################################
#END