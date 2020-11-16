########################################################
CREATE PROCEDURE prcPayment_delete
	@guid [UNIQUEIDENTIFIER]
AS
	delete [py000] where [guid] = @guid

########################################################
#END   