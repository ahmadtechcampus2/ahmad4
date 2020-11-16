################################################################################
CREATE FUNCTION fnPOSSD_Station_CustomerHasAnOpenTicket (@CustomerGuid UNIQUEIDENTIFIER)
RETURNS TABLE
AS 
RETURN	(
			SELECT TOP 1 C.Name AS POSName
			FROM POSSDTicket000 T
			INNER JOIN POSSDShift000 S ON T.ShiftGUID   = S.[GUID]
			INNER JOIN POSSDStation000 C ON S.StationGUID = C.[Guid]
			WHERE T.CustomerGUID = @CustomerGuid
			AND   S.CloseDate IS NULL
		)
#################################################################
#END
