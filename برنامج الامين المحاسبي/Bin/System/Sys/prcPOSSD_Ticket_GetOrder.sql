################################################################################
CREATE PROCEDURE prcPOSSD_Ticket_GetOrder
-- Params -----------------------------------------------------
	@TicketGuid		     UNIQUEIDENTIFIER

AS
    SET NOCOUNT ON
---------------------------------------------------------------
	DECLARE @language INT = [dbo].[fnConnections_getLanguage]()

	SELECT 
		O.[GUID]				  AS OrderGuid,
		O.Number				  AS Number,
		O.ETD					  AS ETD,
		CASE WHEN T.State = 0 THEN   T.Net
		     ELSE				     T.Net + O.DownPayment END AS Net,
		O.IsEDDDefined            AS IsEDDDefined,
		CASE @language			  WHEN 0 THEN area.Name
								  ELSE CASE area.LatinName WHEN '' THEN area.Name
														   ELSE area.LatinName END END	 AS Area,
		O.DriverGUID			  AS DriverGuid,
		O.DownPayment             AS DownPayment,
		O.DeliveryFee             AS DeliveryFee,
		SO.DownPaymentAccountGUID AS DownPaymentAccGuid,
		(CASE ISNULL(D.ReceiveAccountGUID, 0x0) WHEN 0x0 THEN 0 ELSE T.Net END)   AS DriverPayment,
		D.ReceiveAccountGUID      AS DriverPaymentAccGuid,
		ISNULL(CAST(OT.Number AS NVARCHAR(100)), '') AS TripNumber,

		DownPaymentAcc.Code + ' - '+ CASE @language WHEN 0 THEN DownPaymentAcc.Name
													ELSE CASE DownPaymentAcc.LatinName WHEN '' THEN DownPaymentAcc.Name 
																					   ELSE DownPaymentAcc.LatinName END END AS  DownPaymentAccount,

		DriverPaymentACC.Code + ' - '+	CASE @language WHEN 0 THEN DriverPaymentACC.Name
													   ELSE CASE DriverPaymentACC.LatinName WHEN '' THEN DriverPaymentACC.Name 
																							ELSE DriverPaymentACC.LatinName END END AS  DriverPaymentAccount,

	    CASE @language WHEN 0 THEN D.Name
					   ELSE CASE D.LatinName WHEN '' THEN D.Name 
											 ELSE D.LatinName END END AS  DriverName
	FROM 
		POSSDTicketOrderInfo000 O 
		INNER JOIN POSSDTicket000 T ON T.[GUID] = O.TicketGUID
		LEFT JOIN POSSDDriver000 D ON D.[GUID] = O.DriverGUID
		LEFT JOIN POSSDStationOrder000 So ON SO.StationGUID = O.StationGUID
		LEFT JOIN POSSDOrderTrip000 OT ON OT.[GUID] = O.TripGUID 
		LEFT JOIN ac000 DownPaymentAcc ON DownPaymentAcc.[GUID] = SO.DownPaymentAccountGUID
		LEFT JOIN ac000 DriverPaymentACC ON DriverPaymentACC.[GUID] = D.ReceiveAccountGUID
		LEFT JOIN AddressArea000 area ON area.[GUID] = O.AreaGUID
	WHERE 
		O.TicketGUID = @TicketGuid
#################################################################
#END
