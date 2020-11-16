#################################################################
CREATE FUNCTION fnPOSSD_SerialNumbers_CheckReturned
-- Param ------------------------------------------------
		(	
			@MaterialGuid UNIQUEIDENTIFIER, 
			@SN			    NVARCHAR(500)	  
		)
-- Return -----------------------------------------------
RETURNS BIT
---------------------------------------------------------
AS
BEGIN
	DECLARE @Result		  BIT = 0

	IF EXISTS( SELECT 
					SN.SN
			   FROM 
					POSSDTicketItem000 TI  
					INNER JOIN POSSDTicketItemSerialNumbers000 SN ON TI.[GUID] = SN.TicketItemGUID
					INNER JOIN POSSDTicket000 T ON TI.TicketGUID = T.[GUID]
			   WHERE	TI.MatGUID = @MaterialGuid
					AND T.[Type] = 2 AND T.[State] <> 1 AND T.[State] <> 2
					AND SN.SN = @SN )
	BEGIN
		DECLARE @SalesCount INT = 0
		DECLARE @ReturnedSalesCount INT = 0

		SELECT @SalesCount =COUNT(*) 
		FROM POSSDTicketItem000 TI  
		INNER JOIN POSSDTicketItemSerialNumbers000 SN ON TI.[GUID] = SN.TicketItemGUID
		INNER JOIN POSSDTicket000 T ON TI.TicketGUID = T.[GUID]
		WHERE	TI.MatGUID = @MaterialGuid AND T.[Type] = 0 AND SN.SN = @SN

		SELECT @ReturnedSalesCount = COUNT(*) 
		FROM POSSDTicketItem000 TI  
		INNER JOIN POSSDTicketItemSerialNumbers000 SN ON TI.[GUID] = SN.TicketItemGUID
		INNER JOIN POSSDTicket000 T ON TI.TicketGUID = T.[GUID]
		WHERE	TI.MatGUID = @MaterialGuid AND T.[Type] = 2 AND SN.SN = @SN

		IF(ABS(@SalesCount - @ReturnedSalesCount) = 0 )
			SET @Result = 1

	END

	RETURN @Result
END
#################################################################
#END
