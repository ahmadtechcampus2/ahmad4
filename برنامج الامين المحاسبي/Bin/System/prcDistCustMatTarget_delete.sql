########################################################
CREATE PROCEDURE prcDistCustMatTarget_delete
	@guid [UNIQUEIDENTIFIER]
AS
	DELETE [DistCustMatTarget000] WHERE [guid] = @guid
########################################################
#END 
