######################################################### 
CREATE PROC prcDP_deleteEntry
	@dpGUID [UNIQUEIDENTIFIER]
AS
/* 
this procedure: 
	- deletes a given dps' entries
	- entries are deleted from er
*/ 

	exec [prcER_delete] @dpGuid

#########################################################
#END