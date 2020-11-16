#########################################################
create  proc prcGroup_delete
	@groupGuid [uniqueidentifier]
as
/*
This procedure:
	- deletes a given group with its related ma.
	- is not responsible for any constraint checking, this will be done by triggers
*/

	delete [gr000] where [guid] = @groupGuid
	delete [ma000] where [objGuid] = @groupGuid

#########################################################
#END