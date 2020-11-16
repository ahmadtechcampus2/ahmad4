########################################################
CREATE PROCEDURE prcTransferTypes_delete
	@guid [UNIQUEIDENTIFIER]
AS
	delete [TrnTransferTypes000] where [guid] = @guid

########################################################
#END    
 