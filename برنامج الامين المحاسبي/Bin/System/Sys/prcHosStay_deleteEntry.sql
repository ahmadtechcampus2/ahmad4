#########################
CREATE PROC prcHosStay_deleteEntry
	@FileGUID [UNIQUEIDENTIFIER]
AS
SET NOCOUNT ON 
/* 
this procedure: 
	- deletes a given notes' entries
	- entries are deleted from er
*/ 

	exec [prcER_delete] @FileGUID, 303

#########################
#END