########################################################
CREATE PROCEDURE prcDisGeneralTarget_delete
	@guid [UNIQUEIDENTIFIER]
AS
	DELETE [DisGeneralTarget000] WHERE [guid] = @guid
########################################################
#END 
