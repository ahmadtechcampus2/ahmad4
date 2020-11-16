########################################################
CREATE PROCEDURE prcDistribution_delete
	@guid [UNIQUEIDENTIFIER]
AS
	DELETE [Distributor000] WHERE [guid] = @guid
########################################################
#END 
