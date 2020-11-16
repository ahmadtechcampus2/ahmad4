########################################################
CREATE PROCEDURE prcStatementTypes_delete
	@guid [UNIQUEIDENTIFIER]
AS
	delete [TrnStatementTypes000] where [guid] = @guid

########################################################
#END    
 