######################################################### 
CREATE PROC prcTransfer_deleteEntry
	@TransferGUID UNIQUEIDENTIFIER,
	@TransferProcessType INT -- ERT_TRANSFER_CASH = 500, ERT_TRANSFER_PAY = 501, ERT_TRANSFER_RETURN = 502
AS
/* 
this procedure: 
	- deletes a given notes' entries
	- entries are deleted from er
*/ 
	SET NOCOUNT ON
	exec [prcER_delete] @TransferGUID, @TransferProcessType

#########################################################
#END