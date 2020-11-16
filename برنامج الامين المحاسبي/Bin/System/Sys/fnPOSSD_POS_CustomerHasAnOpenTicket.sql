################################################################################
CREATE FUNCTION fnCustomerHasAnOpenTicketInPOSSmartDevices (@CustomerGuid UNIQUEIDENTIFIER)
RETURNS TABLE
AS 
RETURN	(
			SELECT TOP 1 C.Name AS POSName
			FROM POSTicket000 T
			INNER JOIN POSShift000 S ON T.ShiftGuid  = S.[Guid]
			INNER JOIN POSCard000  C ON S.POSGuid	= C.[Guid]
			WHERE T.CustomerGuid = @CustomerGuid
			AND   S.CloseDate IS NULL
		)
#################################################################
#END
