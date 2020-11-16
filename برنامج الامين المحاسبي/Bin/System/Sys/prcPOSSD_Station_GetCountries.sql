################################################################################
CREATE PROCEDURE prcPOSSD_Station_GetCountries
-- Params -------------------------------   
	@StationGuid		UNIQUEIDENTIFIER
-----------------------------------------   
AS
    SET NOCOUNT ON
------------------------------------------------------------------------
	SELECT
		aco.Number,					
		aco.GUID as Guid,	
		aco.Code,
		aco.Name,
		aco.LatinName,
		ROW_NUMBER() OVER (PARTITION BY aco.GUID ORDER BY aco.GUID) AS CountryRank
	INTO #Result
	FROM 
		POSSDStationAddressArea000 pos
		INNER JOIN AddressArea000 a ON a.GUID = pos.AreaGUID
		INNER JOIN AddressCity000 aci ON aci.GUID = a.ParentGUID
		INNER JOIN AddressCountry000 aco ON aco.GUID = aci.ParentGUID
	WHERE 
		pos.StationGUID = @StationGuid

	SELECT
		Number,
		GUID,
		Code,
		Name,
		LatinName
	FROM #Result
	WHERE
		CountryRank = 1

#################################################################
#END