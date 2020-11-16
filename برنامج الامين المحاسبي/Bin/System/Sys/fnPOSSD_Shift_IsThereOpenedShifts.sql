#################################################################
CREATE FUNCTION fnPOSSD_Shift_IsThereOpenedShifts(@employeeId AS uniqueidentifier, @deviceId AS nvarchar(255))
       RETURNS INT
AS BEGIN
       DECLARE       @Result							[INT]
       DECLARE       @anyShiftWithSameUserSameDevice	[INT]
       DECLARE       @anyShiftWithSameUserAnotherDevice [INT]
       DECLARE       @anyShiftWithSameDeviceAnotherUser [INT]
	   DECLARE		 @UserIsWorking						[INT]

	   SELECT @UserIsWorking = IsWorking
	   FROM POSSDEmployee000
	   WHERE [Guid] = @employeeId

	   IF(@UserIsWorking = 0)
	   BEGIN
		  SET    @Result = 6;
		  RETURN @Result;
	   END
      
       SELECT @anyShiftWithSameUserSameDevice = COUNT(*)
       FROM POSSDShift000 POSShift
       INNER JOIN  POSSDShiftDetail000 POSShiftDetails
       ON POSShift.[GUID] = POSShiftDetails.ShiftGUID
       WHERE
              POSShift.CloseDate is NULL
              AND POSShiftDetails.DeviceID = @deviceId
              AND POSShiftDetails.EmployeeGUID = @employeeId
              AND POSShiftDetails.EntryDate >= (SELECT MAX(EntryDate) FROM POSSDShiftDetail000 POSDetails WHERE POSDetails.EmployeeGUID = @employeeId)
      
       SELECT @anyShiftWithSameUserAnotherDevice=COUNT(*)
       FROM POSSDShift000 POSShift
       INNER JOIN  POSSDShiftDetail000 POSShiftDetails
       ON POSShift.[GUID] = POSShiftDetails.ShiftGUID
       WHERE
              POSShift.CloseDate is NULL
              AND POSShiftDetails.DeviceID != @deviceId
              AND POSShiftDetails.EmployeeGUID = @employeeId
              AND POSShiftDetails.EntryDate >= (SELECT MAX(EntryDate) FROM POSSDShiftDetail000 POSDetails WHERE POSDetails.EmployeeGUID = @employeeId)
 
       SET @Result = 0;
 
       IF @anyShiftWithSameUserSameDevice > 0
              SET @Result = 1
      
       ELSE IF @anyShiftWithSameUserAnotherDevice > 0
              SET @Result = 2
      
       RETURN @Result
END
#################################################################
#END 