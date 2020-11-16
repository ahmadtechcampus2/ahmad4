###################################################
CREATE PROC prcPatient_deleteEntry
	@FileGuid UNIQUEIDENTIFIER
AS
SET NOCOUNT ON 
/* 
this procedure: 
	- deletes a given Patient' entries
	- entries are deleted from er
*/ 

	exec [prcER_delete] @FileGuid, 302
##################################################
#END