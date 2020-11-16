###############################################################################
CREATE PROC prcOrder_deleteBills
	@orderGuid [UNIQUEIDENTIFIER]
AS 
/*
this procedure:
	- deletes bills related to a given @orderGuid

it does so by deleting billRel which in turn deletes the bills from its trigger.
*/
	-- a trigger in billRel will delete related bills: 
	-- delete from billRel000 where parentGuid = @orderGuid
	-------------------------------------------------------------------
	-- delete all related bills except the reseved bill 
	delete [b] from [billRel000] [b] left join [ts000] [t1] on [b].[billGuid] = [t1].[OutBillGuid]
				   left join [ts000] [t2] on [b].[billGuid] = [t2].[InBillGuid]
	where 
		[b].[parentGuid] = @orderGuid
		and [t1].[OutBillGuid] is null 
		and [t2].[OutBillGuid] is null 


###############################################################################
#END