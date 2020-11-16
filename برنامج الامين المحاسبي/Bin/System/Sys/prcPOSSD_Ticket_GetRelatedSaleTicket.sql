################################################################################
CREATE PROCEDURE prcPOSSD_Ticket_GetRelatedSaleTicket
-- Params -------------------------------------------   
	@TicketGuid             UNIQUEIDENTIFIER
-----------------------------------------------------   
AS
    SET NOCOUNT ON
-----------------------------------------------------

	DECLARE @TicketType INT = ( SELECT [Type] FROM POSSDTicket000 WHERE [GUID] = @TicketGuid )
	DECLARE @RelatedTicket TABLE(RelatedTicketGuid UNIQUEIDENTIFIER, RelatedTicketCode NVARCHAR(250))


	IF(@TicketType = 0) -- Sale Ticket
	BEGIN
		
		INSERT INTO @RelatedTicket
		SELECT 
			RelatedTicket.[GUID], 
			RelatedTicket.Code 
		FROM 
			POSSDTicket000 Ticket INNER JOIN 
			POSSDTicket000 RelatedTicket ON Ticket.RelatedFrom = RelatedTicket.[GUID]
		WHERE 
			Ticket.RelatedTo = @TicketGuid

	END


	IF(@TicketType = 2) -- Return sale ticket
	BEGIN
		
		INSERT INTO @RelatedTicket
		SELECT 
			Ticket.[GUID], 
			Ticket.[Code] 
		FROM 
			POSSDTicket000 Ticket INNER JOIN 
			POSSDTicket000 RelatedTicket ON Ticket.[GUID] = RelatedTicket.[RelatedFrom]
		WHERE 
			RelatedTicket.[GUID] = @TicketGuid

	END

	IF NOT EXISTS(SELECT * FROM @RelatedTicket)
	BEGIN
		
		INSERT INTO @RelatedTicket
		SELECT 
			0x0,
			ISNULL(RelatedFromInfo, '')
		FROM 
			POSSDTicket000
		WHERE 
			[GUID] = @TicketGuid
	END

	--------------- Result --------------- 

	SELECT * FROM  @RelatedTicket
#################################################################
#END
