################################################################################
CREATE PROCEDURE prcPOSSD_Station_GetEmployees
	@StationGUID UNIQUEIDENTIFIER
AS
	SELECT 
		PE.* 
	FROM 
		POSSDEmployee000 PE 
		INNER JOIN POSSDStationEmployee000 PR ON PE.Guid = PR.EmployeeGuid
	WHERE 
		PE.IsSuperVisor = 0
		AND
		PR.StationGUID = @StationGUID
		AND 
		PE.IsWorking = 1
################################################################################
CREATE PROCEDURE prcPOSSD_Station_GetEmployeesPermissions
	@stationGUID UNIQUEIDENTIFIER
AS
BEGIN
	SELECT PE.* 
	FROM POSSDEmployeePermissions000 PE
	INNER JOIN  POSSDStationEmployee000 SE ON PE.EmployeeGUID = SE.EmployeeGUID
	INNER JOIN POSSDEmployee000 E ON E.GUID = PE.EmployeeGUID
	WHERE 
		E.IsSuperVisor = 0
		AND  
		SE.StationGUID = @StationGUID
		AND 
		PE.HasPermission = 1 
END
#################################################################
CREATE PROCEDURE prcPOSSD_Station_GetSuperVisors
	@StationGUID UNIQUEIDENTIFIER
AS
	SELECT 
		PE.* 
	FROM 
		POSSDEmployee000 PE 
		INNER JOIN POSSDStationEmployee000 PR ON PE.Guid = PR.EmployeeGuid
	WHERE 
		PE.IsSuperVisor = 1
		AND
		PR.StationGUID = @StationGUID
		AND 
		PE.IsWorking = 1
################################################################################
CREATE PROCEDURE prcPOSSD_Station_GetSuperVisorsPermissions
	@stationGUID UNIQUEIDENTIFIER
AS
BEGIN
	SELECT PEP.* 
	FROM POSSDEmployeePermissions000 PEP
	INNER JOIN  POSSDStationEmployee000 SE ON PEP.EmployeeGUID = SE.EmployeeGUID
	INNER JOIN POSSDEmployee000 PE ON PE.GUID = PEP.EmployeeGUID
	WHERE 
		PE.IsSuperVisor = 1 
		AND 
		SE.StationGUID = @StationGUID
		AND 
		PEP.HasPermission = 1 
END
#################################################################
#END 