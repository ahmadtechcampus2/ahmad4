################################################################################
CREATE PROCEDURE prcPOSSD_GetDeliveryTripsCounts
	@stationGuid UNIQUEIDENTIFIER,
	@ticketState INT,
	@isRTL		 BIT
AS
BEGIN

	DECLARE @StationDebitAccGUID UNIQUEIDENTIFIER = (SELECT DebitAccGUID FROM POSSDStation000 WHERE [GUID] = @stationGuid)
	DECLARE @StationCustomers TABLE(CustomerGUID UNIQUEIDENTIFIER)
	INSERT INTO @StationCustomers SELECT * FROM [dbo].fnGetCustsOfAcc(@StationDebitAccGUID)

	DECLARE @RelatedStations TABLE(StationGUID UNIQUEIDENTIFIER)
	INSERT INTO @RelatedStations VALUES(@stationGuid ) 
	INSERT INTO @RelatedStations SELECT AssociatedStationGUID FROM POSSDStationOrderAssociatedStations000 WHERE StationGUID = @stationGuid

	SELECT 
		OI.DriverGUID, 
		CASE WHEN @isRTL = 1 THEN d.Name ELSE (CASE WHEN D.LatinName = '' THEN D.Name ELSE D.LatinName END) END AS DriverName, 
		OT.[GUID] AS TripGuid, 
		OT.Number AS TripNumber, 
		COUNT(OI.[GUID]) AS OrdersCount 
	FROM
		POSSDTicket000 T
		INNER JOIN POSSDTicketOrderInfo000 OI ON T.[GUID]          = OI.TicketGUID 
		INNER JOIN POSSDDriver000 D			  ON D.[GUID]          = OI.DriverGUID 
		INNER JOIN POSSDOrderTrip000 OT		  ON OT.[GUID]         = OI.TripGUID 
		INNER JOIN POSSDShift000 SH			  ON SH.[GUID]         = T.ShiftGUID
		INNER JOIN @RelatedStations S		  ON S.StationGUID     = SH.StationGUID
		INNER JOIN @StationCustomers CUST     ON CUST.CustomerGUID = T.CustomerGUID
		LEFT  JOIN POSSDStationDrivers000 SD  ON SD.DriverGUID = OI.DriverGUID AND SD.StationGUID = @stationGuid
	WHERE 
		SD.DriverGUID IS NOT NULL
		AND T.[State] = @ticketState
	GROUP BY 
		OI.DriverGUID, 
		CASE WHEN @isRTL = 1 THEN D.Name ELSE (CASE WHEN D.LatinName = '' THEN D.Name ELSE D.LatinName END) END, 
		OT.[GUID], 
		OT.Number,
		OT.StartDate
	ORDER BY
		OT.StartDate DESC
END
#################################################################
CREATE PROCEDURE prcPOSSDGetTripClosingOutOrders
	@tripGuid UNIQUEIDENTIFIER
AS
BEGIN
	SELECT t.*  FROM POSSDTicket000 t
	INNER JOIN POSSDTicketOrderInfo000 toi ON toi.TicketGUID = t.[GUID]
	WHERE toi.TripGUID = @tripGuid AND t.[State] = 7
END
#################################################################
#END