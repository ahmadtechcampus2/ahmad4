########################################################
CREATE PROCEDURE prcDistCustTarget_delete
	@guid [UNIQUEIDENTIFIER]
AS
	DELETE [DistCustTarget000] WHERE [guid] = @guid
########################################################
#END 
