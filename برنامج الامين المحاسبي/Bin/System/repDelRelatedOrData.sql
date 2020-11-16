################################################################################
CREATE PROCEDURE repPOSDelRelatedOrData
	@OrderGUID	[UNIQUEIDENTIFIER]
AS
	-- Deleting related data:  
	DELETE [och000] FROM [och000] WHERE [ParentGUID] = @OrderGUID  
	-- Deleting related data:  
	DELETE [ocur000] FROM [ocur000] WHERE [ParentGUID] = @OrderGUID    
	-- Delete bills generated of or and del relation Between or and bu	 	 
	EXEC [prcBillRel_delete] @OrderGUID  
	-- Delete Entries generated of or 
	EXEC [PrcEr_delete] @OrderGUID 

################################################################################
#END
