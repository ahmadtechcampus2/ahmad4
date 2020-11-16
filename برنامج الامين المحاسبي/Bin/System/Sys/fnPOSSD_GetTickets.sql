#################################################################
CREATE FUNCTION fnPOSSD_GetTickets
	( @ShiftGuid UNIQUEIDENTIFIER = 0x0 )
	RETURNS TABLE
AS
	RETURN SELECT T.*, SH.Code AS ShiftCode, S.Name AS StationName
		   FROM
				POSSDTicket000 T
				INNER JOIN POSSDShift000 SH ON T.ShiftGUID = SH.[GUID]
				INNER JOIN POSSDStation000 S ON SH.StationGUID = S.[GUID]
		   WHERE
				ShiftGUID = @ShiftGuid
			 OR @ShiftGuid    = 0x0
#################################################################
#END 