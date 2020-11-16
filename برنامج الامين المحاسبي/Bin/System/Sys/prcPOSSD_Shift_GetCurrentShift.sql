#################################################################
CREATE PROCEDURE prcPOSSD_Shift_GetCurrentShift
@posGuid UNIQUEIDENTIFIER,
@currentUserGuid UNIQUEIDENTIFIER
AS
BEGIN
 SELECT ps.*,
        e.Name AS EmployeeName,
        e.LatinName AS EmployeeLatinName
 FROM POSSDShift000 ps 
 INNER JOIN POSSDEmployee000 e ON ps.EmployeeGUID = e.Guid
 WHERE ps.StationGUID = @posGuid AND ps.EmployeeGUID = @currentUserGuid 
 AND (ps.CloseDate is NULL
 OR (ps.CloseDate is NOT NULL 
 AND ps.CloseDate = (SELECT MAX(CloseDate) 
								FROM POSSDShift000 ps1
								WHERE ps1.StationGUID = @posGuid 
								AND ps1.EmployeeGUID = @currentUserGuid
								AND not exists (SELECT 1 FROM POSSDShift000 ps2 WHERE  ps2.StationGUID = @posGuid 
								AND ps2.EmployeeGUID = @currentUserGuid AND Ps2.CloseDate is null)))) 
END
#################################################################
#END 