#########################################################
CREATE PROC prcPOSSD_AdditionalCopyPrintSetting_GetAll	@StationGUID UNIQUEIDENTIFIER
AS
	-- ****************************************************************************************
	-- Read THE POSSDAdditionalCopyPrintSettingHeader that belong to the specific station
	SELECT 
		HEADER.* ,
		PD.Name AS PDName,
		PD.LatinName AS PDLatinName,
		PD.Number AS PDNumber, 
		PD.LanguageType AS PDLanguageType
	FROM POSSDAdditionalCopyPrintSettingHeader000 AS HEADER INNER JOIN POSSDRelatedAdditionalCopyPrintSetting000 AS STATION ON (HEADER.GUID = STATION.AdditionalCopyPSGUID)
	INNER JOIN POSSDPrintDesign000 AS PD ON (HEADER.PrintDesignGUID = PD.GUID)
	WHERE STATION.StationGUID = @StationGUID
	ORDER BY HEADER.Number;
	-- ****************************************************************************************
	-- Read THE POSSDAdditionalCopyPrintSettingDetail that belong to the specific station
	SELECT 
		LINE.* ,
		GR.Code AS GRCode,
		GR.Name as GRName,
		GR.LatinName AS GRLatinName
	FROM POSSDAdditionalCopyPrintSettingDetail000 AS LINE INNER JOIN POSSDAdditionalCopyPrintSettingHeader000 AS HEADER ON (LINE.AdditionalCopyPSGUID = HEADER.GUID)
	INNER JOIN POSSDRelatedAdditionalCopyPrintSetting000 AS STATION ON (HEADER.GUID = STATION.AdditionalCopyPSGUID)
	INNER JOIN gr000 AS GR ON (LINE.GroupGUID = GR.GUID)
	WHERE  STATION.StationGUID = @StationGUID
	ORDER BY HEADER.Number, LINE.Number;
	-- ****************************************************************************************
	-- Read THE POSSDRelatedAdditionalCopyPrintSettin that belong to the specific station
	SELECT 
		STATION.* 
	FROM POSSDRelatedAdditionalCopyPrintSetting000 AS STATION
	WHERE  STATION.StationGUID = @StationGUID;

#########################################################
#END