#################################################################
CREATE FUNCTION fnPOSSD_GetStations
	(@POSGuid AS [UNIQUEIDENTIFIER])
	RETURNS TABLE
AS
	RETURN SELECT * 
		   FROM
				[POSSDStation000]
		   WHERE
				[GUID] <> @POSGuid 
#################################################################
#END 