################################################################################
CREATE PROCEDURE prcPOSSDStationPrintDesign_GetList
	@StationGUID UNIQUEIDENTIFIER
AS
BEGIN
	/*******************************************************************************************************
	Company : Syriansoft
	SP : prcPOSSDStationPrintDesign_GetList
	Purpose: get list of print designs that are asscoiated with a specific POS station
	How to Call: EXEC prcPOSSDStationPrintDesign_GetList '7b71319c-3a71-4dea-a222-39cc8d68967f'
	Created By: Hanadi Salka												Created On: 12 Dec 2018
	Updated On:																Updated By:
	Change Note:
	********************************************************************************************************/
	SELECT 
		PD.GUID
		,PD.Number
		,PD.StationGUID
		,PD.PrintDesignGUID
		,PD.BillTypeGUID
		,PD.AskBeforePrinting
	FROM POSSDStationPrintDesign000 AS PD 
	WHERE PD.StationGUID = @StationGUID
	UNION
	SELECT
		 NEWID() AS GUID
		,PD.Number
		,RCPS.StationGUID
		,PD.GUID AS PrintDesignGUID		
		,0x0 AS BillTypeGUID		
		,CAST(0 AS BIT) AS AskBeforePrinting
	FROM POSSDRelatedAdditionalCopyPrintSetting000 AS RCPS INNER JOIN POSSDAdditionalCopyPrintSettingHeader000 AS CPSH ON (RCPS.AdditionalCopyPSGUID = CPSH.GUID)
	INNER JOIN POSSDPrintDesign000 AS PD ON (PD.GUID = CPSH.PrintDesignGUID)
	INNER JOIN POSSDStation000 AS POS ON (POS.GUID = RCPS.StationGUID)
	WHERE RCPS.StationGUID =  @StationGUID
	GROUP BY PD.Number,RCPS.StationGUID,PD.GUID
	UNION
	SELECT 
		 NEWID() AS GUID
		,PD.Number
		,RCS.StationGUID
		,PD.GUID AS PrintDesignGUID		
		,0x0 AS BillTypeGUID		
		,CAST(0 AS BIT) AS AskBeforePrinting
	FROM POSSDStationReturnCouponSettings000 AS RCS INNER JOIN POSSDPrintDesign000 AS PD ON (PD.GUID = RCS.PrintDesignTypeGUID)
	WHERE RCS.StationGUID =  @StationGUID;
END
#################################################################
#END
