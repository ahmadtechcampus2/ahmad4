###############################################################################
create procedure prcER_delete 
	@parentGuid [uniqueidentifier],
	@parentType [int] = 0
as 
	-- er delete entries from its trigger. 
	if isnull(@parentType, 0) = 0	
		delete [er000] where [parentGuid] = @parentGuid
	else
		delete [er000] where [parentGuid] = @parentGuid and [parentType] = @parentType

###############################################################################