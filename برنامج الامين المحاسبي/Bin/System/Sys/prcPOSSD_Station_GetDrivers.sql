#################################################################
CREATE PROCEDURE prcPOSSD_Station_GetDrivers
	@StationGUID UNIQUEIDENTIFIER
AS
	SELECT 
		PD.* 
	FROM 
		POSSDDriver000 PD 
		INNER JOIN POSSDStationDrivers000 PR ON PD.Guid = PR.DriverGUID
	WHERE 
		PR.StationGUID = @StationGUID
		AND 
		PD.IsWorking = 1
#################################################################
#END 