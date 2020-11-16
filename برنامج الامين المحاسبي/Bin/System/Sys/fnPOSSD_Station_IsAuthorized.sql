#################################################################
CREATE FUNCTION fnPOSSD_Station_IsAuthorized
(
       @shiftGuid uniqueidentifier,
       @posEmployeeGuid uniqueidentifier,
       @deviceId nvarchar(50)
)
RETURNS BIT
AS
BEGIN
       
     IF(EXISTS (SELECT *
                FROM POSSDShiftDetail000
                WHERE ShiftGUID = @shiftGuid AND EmployeeGUID = @posEmployeeGuid))
     BEGIN
          RETURN 1;
     END
      
     RETURN 0;
     
END
#################################################################
#END
