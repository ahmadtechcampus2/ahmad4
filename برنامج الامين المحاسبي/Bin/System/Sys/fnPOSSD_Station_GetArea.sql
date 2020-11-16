#############################################
CREATE FUNCTION fnPOSSD_Station_GetArea
-- Param ----------------------------------------------------------
	  ( @stationGUID UNIQUEIDENTIFIER )
-- Return ----------------------------------------------------------
RETURNS @Result TABLE([GUID] UNIQUEIDENTIFIER, Area NVARCHAR(50))
--------------------------------------------------------------------
AS 
BEGIN
	
	INSERT INTO @Result
	SELECT
		ar.[GUID], 
		Name
	FROM 
		AddressArea000 ar
		INNER JOIN 	POSSDStationAddressArea000 pos ON ar.[GUID] = pos.AreaGUID
	WHERE pos.StationGuid = @StationGuid

	RETURN
END
##############################################
#END
