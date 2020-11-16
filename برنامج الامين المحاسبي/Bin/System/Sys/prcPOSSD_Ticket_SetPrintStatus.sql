################################################################################
CREATE PROCEDURE prcPOSSD_Ticket_SetPrintStatus
	@TicketGUID UNIQUEIDENTIFIER,	
	@Printed BIT
AS
BEGIN
	/*******************************************************************************************************
	Company : Syriansoft
	SP : prcPOSSD_Ticket_SetPrintStatus
	Purpose: Set the value of bIsPrinted column of the ticket
	How to Call: EXEC prcPOSSD_Ticket_SetPrintStatus 'CC008441-C78E-47DC-86B7-F8DDBD4D3330',1

	Create By: Hanadi Salka													Created On: 29 March 2018
	Updated On:																Updated By:
	Change Note:
	********************************************************************************************************/
	UPDATE POSSDTicket000 
	SET POSSDTicket000.bIsPrinted = @Printed
	WHERE POSSDTicket000.GUID = @TicketGUID;
END
#################################################################
#END