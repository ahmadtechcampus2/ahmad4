########################################################
CREATE PROCEDURE prcDistSalesMan_delete
	@guid [UNIQUEIDENTIFIER]
AS
	DELETE [DistSalesMan000] WHERE [guid] = @guid
########################################################
#END 
