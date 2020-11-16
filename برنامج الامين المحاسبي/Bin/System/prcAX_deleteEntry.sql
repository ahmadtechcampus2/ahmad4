#########################################################
CREATE PROC prcAX_deleteEntry
	@entryGUID [UNIQUEIDENTIFIER]  
AS  
/*  
this procedure:  
	- deletes a given AXs' entries 
	- entries are deleted from er 
*/  
	SET NOCOUNT ON 
	DELETE FROM py000 where Guid = @entryGUID
	exec [prcER_delete] @entryGUID

#########################################################
#END