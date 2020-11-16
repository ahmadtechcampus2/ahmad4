################################################################################
CREATE PROCEDURE prcPOSSD_Station_GetCities
-- Params -------------------------------   
	@StationGuid		UNIQUEIDENTIFIER
-----------------------------------------   
AS
    SET NOCOUNT ON
------------------------------------------------------------------------
	SELECT
		aci.Number,					
		aci.GUID as Guid,	
		aci.Code,
		aci.Name,
		aci.LatinName,
		aci.ParentGUID,
		ROW_NUMBER() OVER (PARTITION BY aci.GUID ORDER BY aci.GUID) AS CityRank 
	INTO #Result
	FROM 
		POSSDStationAddressArea000 pos
		INNER JOIN AddressArea000 a ON a.GUID = pos.AreaGUID
		INNER JOIN AddressCity000 aci ON aci.GUID = a.ParentGUID 
	WHERE 
		pos.StationGUID = @StationGuid
		
	SELECT 
		Number,					
		GUID,	
		Code,
		Name,
		LatinName,
		ParentGUID
	FROM #Result
	WHERE 
		CityRank = 1

#################################################################
#END

 

