#################################################################
create PROCEDURE prcPOSSD_Shift_InsertShiftDetails
 @ShiftGuid UNIQUEIDENTIFIER,
@DeviceID NVARCHAR(Max),
@CurrentUserGuid UNIQUEIDENTIFIER
AS
BEGIN
INSERT INTO POSSDShiftdetail000 Values(NEWID(), @ShiftGuid,  @CurrentUserGuid ,@DeviceID, GETDATE())
END
#################################################################
#END 