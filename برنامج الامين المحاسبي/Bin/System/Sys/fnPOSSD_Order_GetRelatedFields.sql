################################################################################
CREATE FUNCTION fnPOSSD_Order_GetRelatedFields()
-- Return ----------------------------------------------------------
RETURNS @Result TABLE ( OrderGuid			  UNIQUEIDENTIFIER, 
						AddStation			  NVARCHAR(50), 
						AddEmployee			  NVARCHAR(50), 
						AddShiftCode		  NVARCHAR(50),  
						PaidStation			  NVARCHAR(50), 
						PaidEmployee		  NVARCHAR(50), 
						PaidShiftCode		  NVARCHAR(50), 
						DownPaymentAccGuid    UNIQUEIDENTIFIER,
						DriverName			  NVARCHAR(50), 
						DeliveryFee           FLOAT,
						DownPayment           FLOAT,
						DriverPayment		  FLOAT, 
						DriverReceiveAccGuid  UNIQUEIDENTIFIER,
						CancelReason		  NVARCHAR(1000),
						AddOrderDate          DATETIME,
						ExpectedDeliveryDate  DATETIME,
						CustomerAddressGuid   UNIQUEIDENTIFIER)
--------------------------------------------------------------------
AS BEGIN
--------------------------------------------------------------------
	DECLARE @EventResult TABLE ( OrderGuid            UNIQUEIDENTIFIER, 
								 AddStation           NVARCHAR(50), 
								 AddEmployee          NVARCHAR(50), 
								 AddShiftCode         NVARCHAR(50),
								 PaidStation          NVARCHAR(50), 
								 PaidEmployee         NVARCHAR(50), 
								 PaidShiftCode        NVARCHAR(50), 
								 DownPaymentAccGuid   UNIQUEIDENTIFIER)


	DECLARE @AddEventResult TABLE (OrderGuid UNIQUEIDENTIFIER, Station NVARCHAR(50), Employee NVARCHAR(50), ShiftCode NVARCHAR(50), DownPaymentAccGuid UNIQUEIDENTIFIER)
	INSERT INTO @AddEventResult SELECT OE.OrderGUID, S.Name, E.Name, SH.Code, SO.DownPaymentAccountGUID
										FROM  POSSDOrderEvent000 OE 
										INNER JOIN POSSDShift000 SH           ON OE.ShiftGUID    = SH.[Guid] 
										INNER JOIN POSSDStation000 S          ON SH.StationGUID  = S.[GUID]
										INNER JOIN POSSDEmployee000 E         ON SH.EmployeeGUID = E.[GUID]
										INNER JOIN POSSDStationOrder000 SO    ON SO.StationGUID  = S.[GUID]
										WHERE OE.[Event] = 1


	DECLARE @PaidEventResult TABLE (OrderGuid UNIQUEIDENTIFIER, Station NVARCHAR(50), Employee NVARCHAR(50), ShiftCode NVARCHAR(50))
	INSERT INTO @PaidEventResult SELECT OE.OrderGUID, S.Name, E.Name, SH.Code
										FROM  POSSDOrderEvent000 OE 
										INNER JOIN POSSDShift000 SH   ON oe.ShiftGUID = SH.[Guid] 
										INNER JOIN POSSDStation000 S  ON sh.StationGUID = S.[GUID]
										INNER JOIN POSSDEmployee000 E ON sh.EmployeeGUID = E.[GUID]
										WHERE OE.[Event] IN (10, 11)


	INSERT INTO @EventResult
	SELECT 
		A.OrderGuid, 
		A.Station, 
		A.Employee, 
		A.Shiftcode, 
		P.Station, 
		P.Employee, 
		P.ShiftCode, 
		A.DownPaymentAccGuid
	FROM 
		@AddEventResult A 
		LEFT JOIN @PaidEventResult P ON A.OrderGuid = P.OrderGuid


	INSERT INTO @Result
	SELECT 
		ER.*, 
		D.Name, 
		OI.DeliveryFee,
		OI.DownPayment,
		T.Total - OI.DownPayment AS DriverPayment,
		D.ReceiveAccountGUID,
		OE.Reason,
		T.OpenDate,
		OI.ETD,
		OI.CustomerAddressGUID
	FROM 
		@EventResult ER  
		LEFT JOIN POSSDTicketOrderInfo000 OI ON ER.OrderGuid = OI.[GUID]
		LEFT JOIN POSSDTicket000 T ON OI.TicketGUID = T.[GUID]
		LEFT JOIN POSSDDriver000 D ON OI.DriverGUID = D.[GUID]
		LEFT JOIN POSSDOrderEvent000 OE ON OE.OrderGUID = ER.OrderGuid AND OE.GUID IS NOT NULL AND OE.[Event] = 9


	RETURN

	END
#################################################################
#END
