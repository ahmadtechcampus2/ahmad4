########################################################
CREATE PROCEDURE prcDistDistributorTarget_delete
	@guid [UNIQUEIDENTIFIER]
AS
	DELETE [DistDistributorTarget000] WHERE [guid] = @guid
########################################################
#END 
