#################################################################
CREATE FUNCTION fnGetPOSShifts
	(@POSGuid AS [UNIQUEIDENTIFIER])
	RETURNS TABLE
AS
	RETURN SELECT * 
		   FROM
				[POSShift000]
		   WHERE
				[POSGuid] = @POSGuid 
#################################################################
#END 