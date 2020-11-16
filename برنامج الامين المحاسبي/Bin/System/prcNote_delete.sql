#########################################################
CREATE  proc prcNote_delete
	@noteGuid [uniqueidentifier]
as
/*
This procedure:
	- deletes a given note with its related data.
*/

	delete [ch000] where [guid] = @noteGuid
	-- exec prcNote_deleteEntry @noteGuid done from triggers
 
#########################################################
#END