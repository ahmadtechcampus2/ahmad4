########################################################
CREATE PROCEDURE prcOrder_delete
	@guid [UNIQUEIDENTIFIER]
AS
	delete [or000] where [guid] = @guid

########################################################
#END    