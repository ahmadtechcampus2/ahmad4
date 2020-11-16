########################################################
CREATE PROCEDURE prcStatement_delete
	@guid [UNIQUEIDENTIFIER]
AS
	delete [TrnStatement000] where [guid] = @guid

########################################################
#END     