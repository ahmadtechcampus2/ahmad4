#################################################################
CREATE FUNCTION fnPOSSD_Station_GetShifts
	(@POSGuid AS [UNIQUEIDENTIFIER])
	RETURNS TABLE
AS
	RETURN SELECT * 
		   FROM
				[POSSDShift000]
		   WHERE
				[StationGUID] = @POSGuid 
#################################################################
#END 