#################################################################
CREATE FUNCTION PosIsAuthorized
(
       @shiftGuid uniqueidentifier,
       @posEmployeeGuid uniqueidentifier,
       @deviceId nvarchar(50)
)
RETURNS BIT
AS
BEGIN
       
       DECLARE @isAuthorized BIT
       SET @isAuthorized = 0;

       IF (EXISTS(
                           SELECT TOP 1 *
                           FROM POSShiftDetails000

                           WHERE ShiftGuid =  @shiftGuid AND POSUSer = @posEmployeeGuid AND DeviceID = @deviceId

                           AND (EntryDate = (SELECT MAX(EntryDate) FROM POSShiftDetails000 WHERE ShiftGuid =  @shiftGuid AND POSUser = @posEmployeeGuid))
                           ORDER BY EntryDate DESC)
              )
       BEGIN
              SET @isAuthorized = 1;
       END
       
       RETURN @isAuthorized
END
#################################################################
#END
