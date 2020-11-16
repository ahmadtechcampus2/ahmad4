################################################################################
CREATE PROCEDURE prcPOSSD_Station_GetAddressArea
-- Params -------------------------------   
	@StationGuid		UNIQUEIDENTIFIER
-----------------------------------------   
AS
    SET NOCOUNT ON
------------------------------------------------------------------------

	DECLARE @language INT = [dbo].[fnConnections_getLanguage]()
	
	DECLARE @AddressArea TABLE
	(
		AddressAreaGUID		UNIQUEIDENTIFIER,
		StationGUID			UNIQUEIDENTIFIER,
		AreaGUID			UNIQUEIDENTIFIER,
		CityGUID			UNIQUEIDENTIFIER,
		CountryGUID			UNIQUEIDENTIFIER,
        Number				INT,
		AreaName			NVARCHAR(250),
		CityName			NVARCHAR(250),
		CountryName			NVARCHAR(250)
	)
	
	INSERT INTO @AddressArea
	SELECT
		SD.Guid																				AS AddressAreaGUID,
		SD.StationGuid																		AS StationGUID,
		SD.AreaGUID																			AS AreaGUID,
		Ads.CityGUID																		AS CityGUID,
		Ads.CountryGUID																		AS CountryGUID,
		SD.Number																			AS Number,
		CASE @language WHEN 0 THEN Ads.Name
                       ELSE CASE Ads.LatinName WHEN '' THEN Ads.Name
                                               ELSE Ads.LatinName END END					AS AreaName,
		CASE @language WHEN 0 THEN Ads.CityName
                       ELSE CASE Ads.CityLatinName WHEN '' THEN Ads.CityName
												   ELSE Ads.CityLatinName END END			AS CityName,
		CASE @language WHEN 0 THEN Ads.CountryName
                       ELSE CASE Ads.CountryLatinName WHEN '' THEN Ads.CountryName
													  ELSE Ads.CountryLatinName END END		AS CountryName
	FROM 
		POSSDStationAddressArea000 SD
		INNER JOIN vdAddressArea Ads ON Ads.[GUID] = SD.AreaGUID
	WHERE 
		SD.StationGuid = @StationGuid

	SELECT * FROM @AddressArea	
	ORDER BY Number

#################################################################
#END