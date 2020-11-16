﻿#################################################################
CREATE PROCEDURE prcPOSSD_Station_GetAllMaterials
@POSCardGuid UNIQUEIDENTIFIER,
@DeviceId NVARCHAR(250)
AS
BEGIN
/*******************************************************************************************************
	Company : Syriansoft
	SP : prcPOSSD_Station_GetAllMaterials
	Purpose: get all products for a specific pos station and device
	How to Call: EXEC prcPOSSD_Station_GetAllMaterials '3C2561FE-406C-446D-AFE3-6212319487F8',null
	Create By: 											Created On: 
	Updated On:	Hanadi Salka							Updated By: 12-Nov-2019
	Change Note:
	********************************************************************************************************/
	DECLARE @Groups TABLE (
		Number	   INT,
		GroupGUID   UNIQUEIDENTIFIER,  
		Name		   NVARCHAR(MAX),
		Code		   NVARCHAR(MAX),
		ParentGUID  UNIQUEIDENTIFIER,  
		LatinName   NVARCHAR(MAX),
		PictureGUID UNIQUEIDENTIFIER,
		GroupIndex  INT,
		Groupkind	TINYINT );
	
	-- ******************************************************************************************
	-- Declare Temp tables 
	DECLARE @Materials TABLE (MatGuid	UNIQUEIDENTIFIER);
	-- ******************************************************************************************
	-- Declare local variables
	DECLARE @IsGCCTaxSystemEnable BIT = CONVERT(Bit,dbo.fnOption_Get('AmnCfg_EnableGCCTaxSystem','0'));
	
	INSERT INTO @Groups (Number,GroupGUID, Name,Code, ParentGUID, LatinName, PictureGUID, GroupIndex, Groupkind)
	EXEC prcPOSSD_Station_GetGroups @POSCardGuid	
	

	INSERT INTO @Materials(MatGuid)
	SELECT [mt].[GUID]
	FROM @Groups AS [grp]
	INNER JOIN [gri000] AS [gri] ON ([gri].[GroupGuid] = [grp].[GroupGUID] AND [gri].[ItemType] = 1)
	INNER JOIN [mt000] AS [mt] ON ([mt].[GUID] = [gri].[MatGuid]);
			
    -- ********************************************************************************
	INSERT INTO @Materials(MatGuid)	
	SELECT MT.GUID
	FROM @Groups AS  GrTree INNER JOIN mt000 AS MT ON (MT.GroupGUID = GrTree.GroupGUID)
	LEFT JOIN @Materials AS TMPMT ON (TMPMT.MatGuid = MT.GUID)
	WHERE TMPMT.MatGuid IS NULL;		
	----------------------------------------
	INSERT INTO [#Materials]
		SELECT      mt.Number,
					mt.Code,
					mt.[GUID],
					mt.GroupGUID,
					mt.LatinName,
					mt.Name,
					mt.Unity,
					mt.Unit2,
					mt.Unit3,
					mt.DefUnit,
					mt.Unit2Fact,
					mt.Unit3Fact,
					mt.Unit2FactFlag,
					mt.Unit3FactFlag,
					mt.Whole,
					mt.Whole2,
					mt.Whole3,
					mt.Half,
					mt.Half2,
					mt.Half3,
					mt.EndUser,
					mt.EndUser2,
					mt.EndUser3,
					mt.Vendor,
					mt.Vendor2,
					mt.Vendor3,
					mt.Export,
					mt.Export2,
					mt.Export3,
					mt.LastPrice,
					mt.LastPrice2,
					mt.LastPrice3,
					mt.AvgPrice,
					mt.BarCode,
					mt.BarCode2,
					mt.BarCode3,
					mt.PictureGUID,
					mt.Retail,
					mt.Retail2,
					mt.Retail3,
					mt.MaxPrice,
					mt.MaxPrice2,
					mt.MaxPrice3,
					LOWER(mt.Dim),
					LOWER(mt.Origin),
					LOWER(mt.Pos),
					LOWER(mt.Company),
					LOWER(mt.Color),
					LOWER(mt.Provenance),
					LOWER(mt.Quality),
					LOWER(mt.Model),
					mt.[type],
					CASE @IsGCCTaxSystemEnable WHEN 1 THEN ISNULL(GCCM.Ratio, 0) ELSE mt.VAT END AS TaxRatio,
					CAST((CASE ISNULL(ME.[GUID], 0x0) WHEN 0x0 THEN 0 ELSE (CASE ME.[Type] WHEN 1 THEN 1 ELSE 0 END) END) AS BIT) AS HasCrossSaleMaterials,
					CAST((CASE ISNULL(ME.[GUID], 0x0) WHEN 0x0 THEN 0 ELSE (CASE ME.[Type] WHEN 2 THEN 1 ELSE 0 END) END) AS BIT) AS HasUpSaleMaterials,
					ISNULL(ME.Question, '')      AS CrossSaleQuestion,
				    ISNULL(ME.LatinQuestion, '') AS CrossSaleLatinQuestion,
					mt.SNFlag,
					mt.ForceInSN,
					mt.ForceOutSN,
					mt.HasSegments,
					mt.Parent,
					mt.IsCompositionUpdated,
					mt.InheritsParentSpecs,
					mt.CompositionName,
					mt.CompositionLatinName,
					ISNULL(GCCM.TaxCode, 0) AS TaxCoding
		FROM @Materials mats
		INNER JOIN mt000 mt ON mt.[GUID] = mats.MatGuid
		-- EXCLUDE NEW ITEMS IN POSSDStationSyncModifiedData000 TABLE
		-- LEFT JOIN POSSDStationSyncModifiedData000 AS SSD ON (SSD.StationGuid = @POSCardGuid AND  SSD.DeviceID = @DeviceId AND SSD.RelatedToObject = 'MT000' AND (SSD.ReleatedToObjectGuid = mt.[GUID] OR SSD.ReleatedToObjectGuid = mt.Parent) AND (SSD.IsNewDataSync = 0 OR SSD.IsModifiedDataSync = 0 ) )
		LEFT  JOIN POSSDMaterialExtended000 ME ON mats.MatGuid = ME.MaterialGUID
		LEFT  JOIN GCCMaterialTax000 GCCM ON @IsGCCTaxSystemEnable = 1 AND GCCM.MatGUID = mats.MatGuid AND GCCM.TaxType = 1
		-- WHERE SSD.ReleatedToObjectGuid IS NULL		
END
#################################################################
#END 