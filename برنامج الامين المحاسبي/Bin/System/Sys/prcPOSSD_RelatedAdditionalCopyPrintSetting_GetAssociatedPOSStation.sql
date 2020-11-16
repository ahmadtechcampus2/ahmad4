################################################################################
CREATE PROCEDURE prcPOSSDRelatedAdditionalCopyPrintSetting_GetAssociatedPOSStation
	@ExcludeStationGUID UNIQUEIDENTIFIER
AS
BEGIN
	/*******************************************************************************************************
	Company : Syriansoft
	SP : prcPOSSDAdditionalCopyPrintSetting_GetAssociatedPOSStation
	Purpose: get list of POS stations that has additional copy settings associated with
	How to Call: EXEC prcPOSSDRelatedAdditionalCopyPrintSetting_GetAssociatedPOSStation 'C0133D4F-0404-4A0E-8EAF-1623DC765538'

	Create By: Hanadi Salka													Created On: 15 March 2018
	Updated On:																Updated By:
	Change Note:
	********************************************************************************************************/

	SELECT 
		   distinct
		   POS.[GUID],
		   POS.Code,
		   POS.Name,
		   POS.Number,
		   POS.LatinName	  
		 
	  FROM POSSDRelatedAdditionalCopyPrintSetting000 AS RPS INNER JOIN POSSDStation000 AS POS ON (POS.GUID = RPS.StationGUID)
	  INNER JOIN POSSDStationGroup000 AS RGR ON (RGR.StationGUID = @ExcludeStationGUID)
	  INNER JOIN POSSDAdditionalCopyPrintSettingDetail000 AS D ON (D.GroupGUID = RGR.GroupGUID)
	  WHERE POS.GUID != @ExcludeStationGUID;
 END
#################################################################
#END
