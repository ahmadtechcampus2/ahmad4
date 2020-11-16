######################################################
CREATE TRIGGER trg_OrderApprovals000_delete
	ON [OrderApprovals000] FOR DELETE   
	NOT FOR REPLICATION
AS    
	IF @@ROWCOUNT = 0 
		RETURN      

	SET NOCOUNT ON    
	
	DELETE oas
	FROM 
		OrderApprovalStates000 oas 
		INNER JOIN [deleted] d ON d.[GUID] = oas.ParentGuid
######################################################
CREATE TRIGGER trg_MgrApp000_delete
	ON [MgrApp000] FOR DELETE   
	NOT FOR REPLICATION
AS    
	IF @@ROWCOUNT = 0 
		RETURN      

	SET NOCOUNT ON    
	
	DELETE oas
	FROM 
		OrderApprovalStates000 oas 
		INNER JOIN [deleted] d ON d.[GUID] = oas.ParentGuid
######################################################
#END