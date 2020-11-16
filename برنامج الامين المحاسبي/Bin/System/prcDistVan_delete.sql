########################################################
CREATE PROCEDURE prcDistVan_delete
	@guid [UNIQUEIDENTIFIER]
AS
	DELETE [DistVan000] WHERE [guid] = @guid
########################################################
#END 
