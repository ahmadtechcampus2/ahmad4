########################################################
CREATE PROCEDURE prcEntryTemplate_delete
	@guid [UNIQUEIDENTIFIER]
AS
	delete [et000] where [guid] = @guid

########################################################
#END    