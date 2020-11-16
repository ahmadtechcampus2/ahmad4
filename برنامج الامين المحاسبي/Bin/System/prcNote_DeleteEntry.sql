######################################################### 
CREATE PROC prcNote_deleteEntry
	@noteGUID [UNIQUEIDENTIFIER]
AS
/* 
this procedure: 
	- deletes a given notes' entries
	- entries are deleted from er
*/ 

	exec [prcER_delete] @noteGuid, 5

#########################################################
#END