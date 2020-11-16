################################################################################
CREATE PROCEDURE prcPOSSD_TicketItem_GetSerialNumbers
-- Params ---------------------------------------
	@ShiftGuid				UNIQUEIDENTIFIER,
	@TicketGuid				UNIQUEIDENTIFIER,
	@TicketType             INT,
	@MaterialGuid			UNIQUEIDENTIFIER,
	@SalesmanGuid			UNIQUEIDENTIFIER
AS
    SET NOCOUNT ON
--------------------------------------------------

	IF(@TicketType = 1)
		SET  @TicketType = 0 -- Sales ticket
	
	IF(@TicketType = 3)
		SET @TicketType = 2-- Sales Return tickets

	IF(@TicketGuid <> 0x0)
		SET @TicketType = -1
	

	SELECT 
		SN.SN AS SN
	FROM 
		POSSDTicketItemSerialNumbers000 SN
		INNER JOIN POSSDTicketItem000 TI ON SN.TicketItemGUID = TI.[GUID]
	    INNER JOIN POSSDTicket000 T ON TI.TicketGUID = T.[GUID]
		INNER JOIN POSSDShift000 SH ON T.ShiftGUID = SH.[GUID]
	WHERE 
		(T.[GUID]  = @TicketGuid OR @TicketGuid = 0x0)
	AND (SH.[GUID] = @ShiftGuid  OR @ShiftGuid  = 0x0)
	AND (T.[Type] = @TicketType  OR @TicketType  = -1)
	AND T.SalesmanGUID = @SalesmanGuid
	AND TI.MatGUID = @MaterialGuid
    ORDER BY
		SN.SN
#################################################################
#END
