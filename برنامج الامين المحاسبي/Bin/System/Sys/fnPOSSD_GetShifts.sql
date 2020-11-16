#################################################################
CREATE FUNCTION fnPOSSD_GetShifts
	( @POSGuid UNIQUEIDENTIFIER = 0x0 )
	RETURNS TABLE
AS
	RETURN SELECT SH.*, S.Name AS StationName
		   FROM
				POSSDShift000 SH
				INNER JOIN POSSDStation000 S ON SH.StationGUID = S.[GUID]
		   WHERE
				StationGUID = @POSGuid
			 OR @POSGuid    = 0x0
#################################################################
#END 