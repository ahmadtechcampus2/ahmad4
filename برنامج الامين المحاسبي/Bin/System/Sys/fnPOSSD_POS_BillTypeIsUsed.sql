################################################################################
CREATE FUNCTION fnBillTypeIsUsedInPOSSmartDevices (@BillType UNIQUEIDENTIFIER)
RETURNS TABLE
AS
RETURN	(
			SELECT S.POSGuid
			FROM POSCard000 C
			INNER JOIN POSShift000 S ON C.[Guid] = S.POSGuid
			WHERE SaleBillType = @BillType
		)
#################################################################
#END
