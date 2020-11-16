########################################################
CREATE PROCEDURE prcTransferVoucher_delete
	@guid [UNIQUEIDENTIFIER]
AS
	delete [TrnTransferVoucher000] where [guid] = @guid

########################################################
#END    
 