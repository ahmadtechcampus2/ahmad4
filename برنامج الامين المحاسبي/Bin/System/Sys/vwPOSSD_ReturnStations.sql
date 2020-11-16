################################################################################
CREATE VIEW vwPOSSDReturnStations
AS
	SELECT 
		st.[GUID],
		StationGUID,
		ReturnStationGUID,
		RetStation.[Name],
		RetStation.[LatinName],
		RetStation.[Code]
	FROM POSSDStationReturnStations000 st
	INNER JOIN POSSDStation000 RetStation On RetStation.[GUID] = st.[ReturnStationGUID]
################################################################################
#END
