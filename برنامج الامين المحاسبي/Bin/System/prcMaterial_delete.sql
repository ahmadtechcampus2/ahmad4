###############################################################################
CREATE proc prcMaterial_delete
	@guid [uniqueidentifier]
as
/*
This procedure:
	- deletes a given material with its related ma.
	- is not responsible for any constraint checking, this will be done by triggers
*/

	delete [mt000] where [guid] = @guid
	-- delete ma000 where objGuid = @guid this will be done from tirggers

###############################################################################
#END