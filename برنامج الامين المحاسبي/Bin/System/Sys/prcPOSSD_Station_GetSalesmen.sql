################################################################################
CREATE PROCEDURE prcPOSSD_Station_GetSalesmen
	@stationGUID UNIQUEIDENTIFIER
AS
BEGIN
	SELECT  
		Salesman.*, ISNULL(co.Name,'') as CostCenterName, IsNull(co.LatinName, '')CostCenterLatinName
	FROM POSSDSalesman000 Salesman  
	INNER JOIN POSSDStationSalesman000 StationSales ON StationSales.[SalesmanGUID] = Salesman.[GUID]
	LEFT JOIN co000 co ON co.GUID = Salesman.CostCenterGUID 
	WHERE StationSales.[StationGUID] = @StationGUID
	AND Salesman.[IsWorking] = 1		
END
#################################################################
#END
