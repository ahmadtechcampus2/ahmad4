###########################
CREATE proc prcBillRel_delete 
	@parentGuid [uniqueidentifier]
as 
	-- BillRel delete Bills from its trigger. 
	delete [BillRel000] where [parentGuid] = @parentGuid 
	
	
###########################
#END

