#################################################################
CREATE PROCEDURE prcPOSSD_Ticket_SetValue
	@TicketGUID UNIQUEIDENTIFIER,	
	@FieldName	VARCHAR(255),  	
	@FieldValue VARCHAR(MAX)
AS
BEGIN
	/*******************************************************************************************************
	Company : Syriansoft
	SP : prcPOSSD_Ticket_SetValue
	Purpose: Set the value of a specific column (print or state ) of the ticket
	How to Call: EXEC prcPOSSD_Ticket_SetValue '06431BBB-6FC2-493C-97D9-777A4735F605','PRINT', '1'
	Create By: Hanadi Salka													Created On: 03 Sep 2018
	Updated On:																Updated By:
	Change Note:
	********************************************************************************************************/
	IF UPPER(@FieldName) = 'PRINT' 
		UPDATE POSSDTicket000 
		SET [POSSDTicket000].[bIsPrinted] = CAST(@FieldValue AS int)
		WHERE [POSSDTicket000].[GUID] = @TicketGUID;
	ELSE IF UPPER(@FieldName) = 'STATE' 
		UPDATE POSSDTicket000 
		SET [POSSDTicket000].[State] = CAST(@FieldValue AS int)
		WHERE [POSSDTicket000].[GUID] = @TicketGUID;	
END
#################################################################
CREATE PROCEDURE prcPOSSD_Ticket_SetTicketState
	@TicketGUID UNIQUEIDENTIFIER,	
	@State		VARCHAR(255),  	
	@DeviceID   VARCHAR(MAX)
AS
BEGIN
		UPDATE POSSDTicket000 
		SET 
			[POSSDTicket000].State = CAST(@State AS int),
			DeviceID = @DeviceID
		WHERE [POSSDTicket000].[GUID] = @TicketGUID
END
#################################################################
#END 