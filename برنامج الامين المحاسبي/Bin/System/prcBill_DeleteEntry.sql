######################################################### 
CREATE PROC prcBill_deleteEntry
	@billGUID [UNIQUEIDENTIFIER]
AS
/* 
this procedure: 
	- deletes a given bills' entries
	- entries are deleted from er
*/ 
	SET NOCOUNT ON
	
	exec [prcER_delete] @billGuid

#########################################################
#END