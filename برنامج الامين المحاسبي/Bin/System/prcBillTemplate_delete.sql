########################################################
CREATE PROCEDURE prcBillTemplate_delete
	@guid [UNIQUEIDENTIFIER]
AS
	delete [bt000] where [guid] = @guid

########################################################
#END   