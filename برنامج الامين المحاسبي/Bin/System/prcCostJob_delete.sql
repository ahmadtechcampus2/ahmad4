########################################################
CREATE PROCEDURE prcCostJob_delete
	@guid [UNIQUEIDENTIFIER]
AS
	delete [co000] where [guid] = @guid

########################################################
#END  