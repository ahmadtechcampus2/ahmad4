#################################################################
CREATE PROCEDURE prcPOSSD_Station_GetReturnedSalesOptions
	@StationGUID UNIQUEIDENTIFIER
AS
    SET NOCOUNT ON

	SELECT 
		*
	FROM 
		POSSDStationResale000 ReturnedSales
	WHERE 
		ReturnedSales.[StationGUID] = @StationGUID
#################################################################
#END 