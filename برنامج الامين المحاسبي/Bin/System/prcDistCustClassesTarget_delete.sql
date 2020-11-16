########################################################
CREATE PROCEDURE prcDistCustClassesTarget_delete
	@guid [UNIQUEIDENTIFIER]
AS
	DELETE [DistCustClassesTarget000] WHERE [guid] = @guid
########################################################
#END 
