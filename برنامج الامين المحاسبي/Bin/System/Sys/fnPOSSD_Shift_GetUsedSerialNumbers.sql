#################################################################
CREATE FUNCTION fnPOSSD_Shift_GetUsedSerialNumbers
	( @ShiftGUID UNIQUEIDENTIFIER )
	RETURNS TABLE
AS
	RETURN SELECT 
				SN.SN		 AS SN, 
				T.[Type]	 AS TicketType, 
				TI.MatGUID   AS MatGuid
		   FROM 
				POSSDTicketItemSerialNumbers000 SN 
				INNER JOIN POSSDTicketItem000   TI ON TI.[GUID] = SN.TicketItemGUID 
				INNER JOIN POSSDTicket000       T  ON  T.[GUID] = TI.TicketGUID
				INNER JOIN POSSDShift000        SH ON SH.[GUID] = T.ShiftGUID
		   WHERE 
				SH.[GUID] = @ShiftGUID 
				AND CloseDate IS NULL
				AND T.[State] <> 2 --without Cancel ticket
#################################################################
#END 