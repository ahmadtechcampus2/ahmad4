#########################################################
CREATE PROC prcPOSSD_AdditionalCopyPrintSetting_Get	@PSGUID UNIQUEIDENTIFIER
AS
	-- Read THE POSSDAdditionalCopyPrintSettingHeader that belong to the specific station
	SELECT 
		HEADER.* ,
		PD.Name AS PDName,
		PD.LatinName AS PDLatinName,
		PD.Number AS PDNumber
	FROM POSSDAdditionalCopyPrintSettingHeader000 AS HEADER INNER JOIN POSSDPrintDesign000 AS PD ON (HEADER.PrintDesignGUID = PD.GUID)
	WHERE HEADER.GUID = @PSGuid;
	-- ****************************************************************************************
	-- Read THE POSSDAdditionalCopyPrintSettingDetail that belong to the specific station
	SELECT 
		LINE.* ,
		GR.Code AS GRCode,
		GR.Name as GRName,
		GR.LatinName AS GRLatinName
	FROM POSSDAdditionalCopyPrintSettingDetail000 AS LINE INNER JOIN gr000 AS GR ON (LINE.GroupGUID = GR.GUID)
	WHERE  LINE.AdditionalCopyPSGUID = @PSGuid
	ORDER BY LINE.Number;
	-- ****************************************************************************************
	-- Read THE POSSDRelatedAdditionalCopyPrintSettin that belong to the specific station
	SELECT 
		STATION.* 
	FROM POSSDRelatedAdditionalCopyPrintSetting000 AS STATION
	WHERE  STATION.AdditionalCopyPSGUID = @PSGuid;
#########################################################
CREATE PROC prcPOSSD_AdditionalCopyPrintSetting_Delete	@additionalCopyPSGUID UNIQUEIDENTIFIER
AS
	/*******************************************************************************************************
	Company : Syriansoft
	SP : prcPOSSD_AdditionalCopyPrintSetting_DELETE
	Purpose: delete existing row from POSSDAdditionalCopyPrintSettingHeader if not used by any POS printer

	How to Call: 	
	EXEC prcPOSSD_AdditionalCopyPrintSetting_DELETE '62064F33-AA1C-4012-AD7F-699ACBC35C92'
	

	Create By: Hanadi Salka													Created On: 16 May 2018
	Updated On:																Updated By:
	Change Note:
	********************************************************************************************************/
	DECLARE	@TransactionName					      NVARCHAR(50) = 'AddtionalCopyPrintSettingDelete'
	DECLARE @IsUsed									  INT;
	BEGIN TRY  
		SELECT @IsUsed =  COUNT(*)
		FROM POSSDRelatedAdditionalCopyPrintSetting000	
		WHERE AdditionalCopyPSGUID = @additionalCopyPSGUID AND UsedByPOSPrinter = 1;
		IF @IsUsed = 0 
			BEGIN	
				
				BEGIN TRANSACTION @TransactionName
					DELETE FROM POSSDAdditionalCopyPrintSettingDetail000	WHERE AdditionalCopyPSGUID = @additionalCopyPSGUID;
					DELETE FROM POSSDRelatedAdditionalCopyPrintSetting000	WHERE AdditionalCopyPSGUID = @additionalCopyPSGUID;
					DELETE FROM POSSDAdditionalCopyPrintSettingHeader000  	WHERE POSSDAdditionalCopyPrintSettingHeader000.GUID = @additionalCopyPSGUID;
				COMMIT TRANSACTION @TransactionName;
			END;		
	END TRY  
	BEGIN CATCH  
		-- Execute error retrieval routine.  
		ROLLBACK TRANSACTION @TransactionName;  
	END CATCH;
#########################################################
#END