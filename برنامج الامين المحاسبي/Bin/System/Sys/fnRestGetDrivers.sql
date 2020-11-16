########################################
CREATE FUNCTION fnRestGetDrivers( @AddressGUID UNIQUEIDENTIFIER ) 
	RETURNS TABLE
AS 
	RETURN 
		SELECT 
			rv.*
		FROM 
			RestVendor000 rv 
			LEFT JOIN RestDriverAddress000 rda ON rv.GUID = rda.DriverGUID 
		WHERE 
			(rv.IsAllAddress = 1 OR rda.AddressGUID = @AddressGUID)
			AND 
			rv.IsInactive = 0

#############################
#END