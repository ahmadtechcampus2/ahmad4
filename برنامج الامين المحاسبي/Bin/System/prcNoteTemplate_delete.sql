########################################################
CREATE PROCEDURE prcNoteTemplate_delete
	@guid [UNIQUEIDENTIFIER]
AS
	delete [nt000] where [guid] = @guid

########################################################
#END    