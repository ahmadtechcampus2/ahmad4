#################################################################
CREATE PROCEDURE prcPOSSD_Station_GetOrdersOptions
	@StationGUID UNIQUEIDENTIFIER
AS
    SET NOCOUNT ON
	SELECT 
		*
	FROM 
		POSSDStationOrder000 orderOption
	WHERE 
		orderOption.[StationGUID] = @StationGUID
#################################################################
#END 