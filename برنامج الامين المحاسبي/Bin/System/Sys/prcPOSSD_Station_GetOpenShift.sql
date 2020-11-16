#################################################################
CREATE PROCEDURE prcPOSSD_Station_GetOpenShift
-- Params -----------------------------------------
	@StationGUID	 UNIQUEIDENTIFIER

AS
    SET NOCOUNT ON
---------------------------------------------------


	SELECT 
		TOP 1 SH.*,
		E.Name      AS EmployeeName,
        E.LatinName AS EmployeeLatinName
	FROM 
		POSSDShift000 SH 
		INNER JOIN POSSDEmployee000 E ON SH.EmployeeGUID = E.[GUID]
	WHERE 
		SH.StationGUID = @StationGUID
		AND SH.CloseDate IS NULL
#################################################################
#END 