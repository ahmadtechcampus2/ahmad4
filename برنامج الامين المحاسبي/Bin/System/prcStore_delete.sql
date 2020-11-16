########################################################
CREATE PROCEDURE prcStore_delete
	@guid [UNIQUEIDENTIFIER]
AS
	delete [st000] where [guid] = @guid

########################################################
#END   