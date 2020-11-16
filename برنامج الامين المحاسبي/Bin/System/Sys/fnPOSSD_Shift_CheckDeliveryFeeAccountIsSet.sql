#################################################################
CREATE FUNCTION fnPOSSD_Shift_CheckDeliveryFeeAccountIsSet
(
	 @ShiftGUID   UNIQUEIDENTIFIER
)
RETURNS BIT
AS
BEGIN

	DECLARE @OrderPaidCount	INT = 0
	DECLARE @StationGUID UNIQUEIDENTIFIER = (SELECT StationGUID FROM POSSDShift000 WHERE [GUID] = @ShiftGUID)
	DECLARE @DeliveryFeeAccount UNIQUEIDENTIFIER = (SELECT ISNULL(DeliveryFeeAccountGUID, 0x0) FROM POSSDStationOrder000 WHERE StationGUID = @StationGUID)

	SELECT 
		@OrderPaidCount = COUNT(*)
	FROM 
		POSSDOrderEvent000 OE 
		INNER JOIN POSSDTicketOrderInfo000 OI ON OE.OrderGUID = OI.[GUID]
	WHERE 
		OE.ShiftGUID = @ShiftGuid
		AND OE.[Event] = 10
		AND OI.DeliveryFee > 0

	IF(@OrderPaidCount > 0 AND @DeliveryFeeAccount = 0x0)
	BEGIN
		RETURN 0
	END

	RETURN 1
END
#################################################################
#END 