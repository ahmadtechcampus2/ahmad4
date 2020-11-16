#################################################################
CREATE PROCEDURE prcPOSSD_Station_GetDeliveryAreas
	@StationGUID UNIQUEIDENTIFIER
AS
	SELECT 
		GUID, Number, DeliveryFee,AreaGUID
	FROM 
		POSSDStationDeliveryArea000 DA 
	WHERE 
		DA.StationGUID = @StationGUID
#################################################################
#END 