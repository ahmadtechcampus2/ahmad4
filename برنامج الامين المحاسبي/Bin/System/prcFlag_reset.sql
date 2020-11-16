#########################################################
CREATE PROC prcFlag_reset
	@flagID [INT]
AS
/*
this procedure removes a given flag.
*/
	DELETE FROM [mc000] WHERE [type] = 24 AND [number] = @flagID 

#########################################################
#END