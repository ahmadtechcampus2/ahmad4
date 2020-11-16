#################################################################
CREATE PROCEDURE prcPOSSD_Shift_GetShiftInfo
@shiftGuid uniqueidentifier
AS
BEGIN
        DECLARE @maxSalesTicketNumber int = (SELECT MAX(Number) FROM POSSDTicket000 WHERE ShiftGUID = @shiftGuid AND Type = 0 AND (OrderType =  0  OR State = 0) ),
				@maxPurchasesTicketNumber int = (SELECT MAX(Number) FROM POSSDTicket000 WHERE ShiftGUID = @shiftGuid AND Type = 1),
				@maxReturnedSalesTicketNumber int = (SELECT MAX(Number) FROM POSSDTicket000 WHERE ShiftGUID = @shiftGuid AND Type = 2),
				@maxReturnedPurchasesTicketNumber int = (SELECT MAX(Number) FROM POSSDTicket000 WHERE ShiftGUID = @shiftGuid AND Type = 3),
				@maxOrderNumber int = (SELECT MAX(Number) FROM POSSDTicketOrderInfo000 ),
				@maxExternalOperationNumber int = (SELECT MAX(number) FROM POSSDExternalOperation000 WHERE ShiftGuid = @shiftGuid),
				@currentShiftCash FLOAT = (SELECT [dbo].fnPOSSD_Shift_GetShiftCash(@shiftGuid, default, default))
		
		SELECT	@shiftGuid AS ShiftGuid, 
				ISNULL(@maxSalesTicketNumber, 0) MaxSalesTicketNumber, 
				ISNULL(@maxPurchasesTicketNumber, 0) MaxPurchasesTicketNumber,
				ISNULL(@maxReturnedSalesTicketNumber, 0) MaxReturnedSalesTicketNumber,
				ISNULL(@maxReturnedPurchasesTicketNumber, 0) MaxReturnedPurchasesTicketNumber,
				ISNULL(@maxExternalOperationNumber, 0) MaxExternalOperationNumber, 
				ISNULL(@maxOrderNumber, 0) MaxOrderNumber,
				@currentShiftCash CurrentShiftCash
END
#################################################################
#END 