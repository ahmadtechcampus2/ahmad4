################################################################################
CREATE PROCEDURE prcPOSSD_Order_GetOrders
-- Params -------------------------------
	@stationGuid    UNIQUEIDENTIFIER,
	@customerGuid   UNIQUEIDENTIFIER,
	@orderType      INT		 = 0,
	@edd			DATETIME = NULL,
	@orderNumber    INT      = 0
AS
    SET NOCOUNT ON
	------------------------------------------------------------
	DECLARE @StationDebitAccGUID UNIQUEIDENTIFIER = (SELECT DebitAccGUID FROM POSSDStation000 WHERE [GUID] = @stationGuid)
	DECLARE @StationCustomers TABLE(CustomerGUID UNIQUEIDENTIFIER)

	INSERT INTO @StationCustomers 
	SELECT 
		CUSTOMERS.[GUID]
	FROM 
		dbo.fnGetAccountsList(@StationDebitAccGUID, 0) AccountList
		INNER JOIN vexCu CUSTOMERS ON CUSTOMERS.AccountGUID = AccountList.[GUID]
		INNER JOIN CustAddress000 CustAd ON CustAd.CustomerGUID = CUSTOMERS.[GUID]
		INNER JOIN POSSDStationAddressArea000 AddressArea ON AddressArea.AreaGUID = CustAd.AreaGUID AND StationGUID = @stationGuid
	GROUP BY 
		CUSTOMERS.[GUID]

	DECLARE @RelatedStations TABLE(StationGUID UNIQUEIDENTIFIER)
	INSERT INTO @RelatedStations VALUES(@stationGuid) 
	INSERT INTO @RelatedStations SELECT AssociatedStationGUID FROM POSSDStationOrderAssociatedStations000 WHERE StationGUID = @stationGuid

	SELECT 
		T.* 
	FROM 
		POSSDTicket000 T
		INNER JOIN POSSDTicketOrderInfo000 OI ON T.[GUID] = OI.TicketGUID
		INNER JOIN @RelatedStations S ON S.[StationGUID] = OI.StationGUID
		INNER JOIN @StationCustomers CUST ON CUST.CustomerGUID = T.CustomerGUID
		LEFT  JOIN POSSDStationDrivers000 D ON D.DriverGUID = OI.DriverGUID AND D.StationGUID = @stationGuid
	WHERE 
		((D.DriverGUID IS NULL AND T.OrderType = 1) OR (D.DriverGUID IS NOT NULL) OR (D.DriverGUID IS NULL AND T.[State] = 5))
		AND (@OrderType = 0 OR T.OrderType = @OrderType)
		AND (T.[State] IN (5, 6, 7))
		AND (@CustomerGUID = 0x0 OR T.CustomerGuid = @CustomerGUID)
		AND (@edd IS NULL OR CAST(OI.EDD AS DATE) = CAST(@edd AS DATE))
		AND (@orderNumber = 0 OR OI.Number = @orderNumber)
	ORDER BY 
		OI.Number
#################################################################
#END
