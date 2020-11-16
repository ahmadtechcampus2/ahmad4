##########################################################################
CREATE  TRIGGER TrgInvReconcileHeader
	ON InvReconcileHeader000 FOR DELETE 
AS 

	IF @@ROWCOUNT = 0 RETURN  
	SET NOCOUNT ON  
	  
	-- deleting related data:  
	DELETE [InvReconcileItem000] FROM [InvReconcileItem000] AS [InvI] INNER JOIN [deleted] ON [InvI].[ParentGUID] = [deleted].[GUID] 

###############################################################################
#END