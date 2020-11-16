########################################################
CREATE PROCEDURE prcManufac_delete
	@guid [UNIQUEIDENTIFIER]
AS
	SET NOCOUNT ON
	delete [mn000] where [guid] = @guid

########################################################
#END    