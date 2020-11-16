################################################################################
CREATE PROCEDURE prcPOSSD_StationSyncModifiedData
@POSCardGuid UNIQUEIDENTIFIER,
@DeviceId NVARCHAR(250),
@RelatedToObject NVARCHAR(100),
@DataAction NVARCHAR(5),
@IsDataSync BIT
AS
BEGIN 
	/*******************************************************************************************************
	Company : Syriansoft
	SP : prcPOSSD_Station_GetNewMaterials
	Purpose: get all new items that are related to a specific POS Station
	How to Call: EXEC prcPOSSD_StationSyncModifiedData '3C2561FE-406C-446D-AFE3-6212319487F8','bcT5wzaMH7IkPgGQBlQClXtinXcSnh0uJ4Pu1OSgccA=','GR000','CU',0
	Create By: Hanadi Salka													Created On: 28 Oct 2019
	Updated On:																Updated By:
	Change Note:
	********************************************************************************************************/
	
	DECLARE @UpdatedOn		DATETIME = SYSUTCDATETIME();	
	IF @DataAction = 'C'
		UPDATE POSSDStationSyncModifiedData000
		SET IsNewDataSync = @IsDataSync,
			UpdatedOn = @UpdatedOn		
		WHERE StationGuid = @POSCardGuid
			AND DeviceID = @DeviceId
			AND RelatedToObject = @RelatedToObject
			AND IsNewDataSync = ~ @IsDataSync;			
	ELSE IF @DataAction = 'U'
		UPDATE POSSDStationSyncModifiedData000
		SET IsModifiedDataSync = @IsDataSync,
			UpdatedOn = @UpdatedOn		
		WHERE StationGuid = @POSCardGuid
			 AND DeviceID = @DeviceId
			 AND RelatedToObject = @RelatedToObject
			 AND IsModifiedDataSync = ~ @IsDataSync;
	ELSE IF @DataAction = 'CU'
		BEGIN
			UPDATE POSSDStationSyncModifiedData000
			SET IsNewDataSync = @IsDataSync,
				UpdatedOn = @UpdatedOn		
			WHERE StationGuid = @POSCardGuid
				AND DeviceID = @DeviceId
				AND RelatedToObject = @RelatedToObject
				AND IsNewDataSync = ~ @IsDataSync;	

			UPDATE POSSDStationSyncModifiedData000
			SET IsModifiedDataSync = @IsDataSync,
				UpdatedOn = @UpdatedOn		
			WHERE StationGuid = @POSCardGuid
				 AND DeviceID = @DeviceId
				 AND RelatedToObject = @RelatedToObject
				 AND IsModifiedDataSync = ~ @IsDataSync;	
		END;	
END
#################################################################
CREATE PROCEDURE prcPOSSD_StationSyncModifiedMaterialData
@POSCardGuid UNIQUEIDENTIFIER,
@DeviceId NVARCHAR(250),
@DataAction NVARCHAR(5),
@IsDataSync BIT
AS
BEGIN
	/*******************************************************************************************************
	Company : Syriansoft
	SP : prcPOSSD_Station_GetNewMaterials
	Purpose: get all new items that are related to a specific POS Station
	How to Call: EXEC prcPOSSD_StationSyncModifiedMaterialData '5DE598E0-A959-4365-B6BF-069E1D5FF919','bcT5wzaMH7IkPgGQBlQClXtinXcSnh0uJ4Pu1OSgccA=','C', 1
	Create By: Hanadi Salka													Created On: 28 Oct 2019
	Updated On:																Updated By:
	Change Note:
	********************************************************************************************************/	
	DECLARE @RelatedToObject NVARCHAR(100) = 'MT000';
	
	EXEC prcPOSSD_StationSyncModifiedData @POSCardGuid, @DeviceId, @RelatedToObject, @DataAction, @IsDataSync
END
#################################################################
CREATE PROCEDURE prcPOSSD_StationSyncModifiedGroupData
@POSCardGuid UNIQUEIDENTIFIER,
@DeviceId NVARCHAR(250),
@DataAction NVARCHAR(5),
@IsDataSync BIT
AS
BEGIN
	/*******************************************************************************************************
	Company : Syriansoft
	SP : prcPOSSD_StationSyncModifiedGroupData
	Purpose: update the sync status of new / modified group
	How to Call: EXEC prcPOSSD_StationSyncModifiedGroupData '3C2561FE-406C-446D-AFE3-6212319487F8','bcT5wzaMH7IkPgGQBlQClXtinXcSnh0uJ4Pu1OSgccA=','C', 0
	Create By: Hanadi Salka													Created On: 18 Nov 2019
	Updated On:																Updated By:
	Change Note:
	********************************************************************************************************/	
	DECLARE @RelatedToObject NVARCHAR(100) = 'GR000';	
	EXEC prcPOSSD_StationSyncModifiedData @POSCardGuid, @DeviceId, @RelatedToObject, @DataAction, @IsDataSync
END
#################################################################
CREATE PROCEDURE prcPOSSD_Station_GetNewMaterials
@POSCardGuid UNIQUEIDENTIFIER,
@DeviceId NVARCHAR(250),
@DataAction VARCHAR(5),
@PageSize	 INT = 200,
@PageIndex	 INT = 0
AS
BEGIN
	
	/*******************************************************************************************************
	Company : Syriansoft
	SP : prcPOSSD_Station_GetNewMaterials
	Purpose: get all new items that are related to a specific POS Station
	How to Call: EXEC prcPOSSD_Station_GetNewMaterials '5DE598E0-A959-4365-B6BF-069E1D5FF919','bcT5wzaMH7IkPgGQBlQClXtinXcSnh0uJ4Pu1OSgccA=','C',300,0
	Create By: Hanadi Salka													Created On: 28 Oct 2019
	Updated On:																Updated By:
	Change Note:
	********************************************************************************************************/
	-- ******************************************************************************************
	-- Declare local variables
	
	DECLARE @IsGCCTaxSystemEnable BIT = CONVERT(Bit,dbo.fnOption_Get('AmnCfg_EnableGCCTaxSystem','0'));
	DECLARE @Groups TABLE (Number	   INT,
						   GroupGUID   UNIQUEIDENTIFIER,  
						   Name		   NVARCHAR(MAX),
						   Code		   NVARCHAR(MAX),
						   ParentGUID  UNIQUEIDENTIFIER,  
						   LatinName   NVARCHAR(MAX),
						   PictureGUID UNIQUEIDENTIFIER,
						   GroupIndex  INT,
						   Groupkind   TINYINT);	
	DECLARE @Count	INT = 0;
	-- ******************************************************************************************
	-- Declare Temp tables 
	DECLARE @Materials TABLE (MatGuid	UNIQUEIDENTIFIER);
	INSERT INTO @Groups (Number,GroupGUID, Name,Code, ParentGUID, LatinName, PictureGUID, GroupIndex, Groupkind)
	EXEC prcPOSSD_Station_GetGroups @POSCardGuid		
	
	INSERT INTO @Groups (Number,GroupGUID, Name,Code, ParentGUID, LatinName, PictureGUID, Groupkind,  GroupIndex)
	SELECT GR.Number,GR.GUID,GR.Name,GR.Code,GR.ParentGUID,GR.LatinName,GR.PictureGUID,GR.Kind,MIN(0)
	FROM @Groups AS grp
	INNER JOIN gri000 AS gri ON (gri.GroupGuid = grp.GroupGUID AND gri.ItemType = 1)
	INNER JOIN mt000 AS mt ON (mt.GUID = gri.MatGuid)
	INNER JOIN GR000 AS GR ON (GR.GUID = MT.GroupGUID)
	GROUP BY GR.Number,GR.GUID,GR.Name,GR.Code,GR.ParentGUID,GR.LatinName,GR.PictureGUID,GR.Kind;
	-- **************************************************************
	-- GET NEW MATERIALS
	IF @DataAction = 'C'
		BEGIN
			SELECT	
				(mt.Number),
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
				LOWER(mt.Dim) as Dim,
				LOWER(mt.Origin) Origin,
				LOWER(mt.Pos) Pos,
				LOWER(mt.Company) Company,
				LOWER(mt.Color) Color,
				LOWER(mt.Provenance) Provenance,
				LOWER(mt.Quality) Quality,
				LOWER(mt.Model) Model,
				mt.[type] ,
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
			FROM POSSDStationSyncModifiedData000 AS NMT
			INNER JOIN mt000 mt ON ((NMT.RelatedToObject = 'Mt000') AND (mt.[GUID] = NMT.ReleatedToObjectGuid ))
			INNER JOIN POSSDStationDevice000 AS POSD ON (NMT.StationGuid = POSD.StationGUID  AND POSD.DeviceID = NMT.DeviceID)
			INNER JOIN @Groups AS gr ON (GR.GroupGUID = MT.GroupGUID)
			LEFT  JOIN POSSDMaterialExtended000 ME ON mt.GUID = ME.MaterialGUID
			LEFT  JOIN GCCMaterialTax000 GCCM ON @IsGCCTaxSystemEnable = 1 AND GCCM.MatGUID = mt.GUID AND GCCM.TaxType = 1
			WHERE NMT.StationGuid = @POSCardGuid
					AND NMT.DeviceID = @DeviceId
					AND NMT.IsNewDataSync = 0
					-- AND POSD.ActiveFlag = 1
			UNION ALL
			SELECT	
				(mt.Number),
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
				LOWER(mt.Dim) as Dim,
				LOWER(mt.Origin) Origin,
				LOWER(mt.Pos) Pos,
				LOWER(mt.Company) Company,
				LOWER(mt.Color) Color,
				LOWER(mt.Provenance) Provenance,
				LOWER(mt.Quality) Quality,
				LOWER(mt.Model) Model,
				mt.[type] ,
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
			FROM POSSDStationSyncModifiedData000 AS NMT
			INNER JOIN mt000 mt ON ((NMT.RelatedToObject = 'Mt000') AND (mt.Parent = NMT.ReleatedToObjectGuid ))
			INNER JOIN POSSDStationDevice000 AS POSD ON (NMT.StationGuid = POSD.StationGUID  AND POSD.DeviceID = NMT.DeviceID)
			INNER JOIN @Groups AS gr ON (GR.GroupGUID = MT.GroupGUID)
			LEFT  JOIN POSSDMaterialExtended000 ME ON mt.GUID = ME.MaterialGUID
			LEFT  JOIN GCCMaterialTax000 GCCM ON @IsGCCTaxSystemEnable = 1 AND GCCM.MatGUID = mt.GUID AND GCCM.TaxType = 1
			WHERE NMT.StationGuid = @POSCardGuid
					AND NMT.DeviceID = @DeviceId
					AND NMT.IsNewDataSync = 0
					-- AND POSD.ActiveFlag = 1
			ORDER BY Number OFFSET (@PageSize * @PageIndex)  ROWS FETCH NEXT @PageSize ROWS ONLY;	
				
		END
	-- GET UPDATED MATERIALS
	ELSE IF @DataAction = 'U'
		BEGIN
			SELECT	(mt.Number),
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
						LOWER(mt.Dim) as Dim,
						LOWER(mt.Origin) Origin,
						LOWER(mt.Pos) Pos,
						LOWER(mt.Company) Company,
						LOWER(mt.Color) Color,
						LOWER(mt.Provenance) Provenance,
						LOWER(mt.Quality) Quality,
						LOWER(mt.Model) Model,
						mt.[type] ,
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
			FROM POSSDStationSyncModifiedData000 AS NMT	INNER JOIN mt000 mt ON (NMT.RelatedToObject = 'Mt000' AND mt.[GUID] = NMT.ReleatedToObjectGuid)
			INNER JOIN POSSDStationDevice000 AS POSD ON (NMT.StationGuid = POSD.StationGUID  AND POSD.DeviceID = NMT.DeviceID)
			INNER JOIN @Groups AS gr ON (GR.GroupGUID = MT.GroupGUID)
			LEFT  JOIN POSSDMaterialExtended000 ME ON mt.GUID = ME.MaterialGUID
			LEFT  JOIN GCCMaterialTax000 GCCM ON @IsGCCTaxSystemEnable = 1 AND GCCM.MatGUID = mt.GUID AND GCCM.TaxType = 1
			WHERE NMT.StationGuid = @POSCardGuid
					AND NMT.DeviceID = @DeviceId
					AND NMT.IsModifiedDataSync = 0
					-- AND POSD.ActiveFlag = 1
			UNION ALL
			SELECT	(mt.Number),
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
						LOWER(mt.Dim) as Dim,
						LOWER(mt.Origin) Origin,
						LOWER(mt.Pos) Pos,
						LOWER(mt.Company) Company,
						LOWER(mt.Color) Color,
						LOWER(mt.Provenance) Provenance,
						LOWER(mt.Quality) Quality,
						LOWER(mt.Model) Model,
						mt.[type] ,
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
			FROM POSSDStationSyncModifiedData000 AS NMT	INNER JOIN mt000 mt ON ((NMT.RelatedToObject = 'Mt000') AND (mt.Parent = NMT.ReleatedToObjectGuid))
			INNER JOIN POSSDStationDevice000 AS POSD ON (NMT.StationGuid = POSD.StationGUID  AND POSD.DeviceID = NMT.DeviceID)
			INNER JOIN @Groups AS gr ON (GR.GroupGUID = MT.GroupGUID)
			LEFT  JOIN POSSDMaterialExtended000 ME ON mt.GUID = ME.MaterialGUID
			LEFT  JOIN GCCMaterialTax000 GCCM ON @IsGCCTaxSystemEnable = 1 AND GCCM.MatGUID = mt.GUID AND GCCM.TaxType = 1
			WHERE NMT.StationGuid = @POSCardGuid
					AND NMT.DeviceID = @DeviceId
					AND NMT.IsModifiedDataSync = 0
					-- AND POSD.ActiveFlag = 1
			ORDER BY Number OFFSET (@PageSize * @PageIndex)  ROWS FETCH NEXT @PageSize ROWS ONLY;
		END	
	ELSE IF @DataAction = 'CU'
		BEGIN
			SELECT	
				(mt.Number),
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
				LOWER(mt.Dim) as Dim,
				LOWER(mt.Origin) Origin,
				LOWER(mt.Pos) Pos,
				LOWER(mt.Company) Company,
				LOWER(mt.Color) Color,
				LOWER(mt.Provenance) Provenance,
				LOWER(mt.Quality) Quality,
				LOWER(mt.Model) Model,
				mt.[type] ,
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
			FROM POSSDStationSyncModifiedData000 AS NMT
			INNER JOIN mt000 mt ON ((NMT.RelatedToObject = 'Mt000') AND (mt.[GUID] = NMT.ReleatedToObjectGuid ))
			INNER JOIN POSSDStationDevice000 AS POSD ON (NMT.StationGuid = POSD.StationGUID  AND POSD.DeviceID = NMT.DeviceID)
			INNER JOIN @Groups AS gr ON (GR.GroupGUID = MT.GroupGUID)
			LEFT  JOIN POSSDMaterialExtended000 ME ON mt.GUID = ME.MaterialGUID
			LEFT  JOIN GCCMaterialTax000 GCCM ON @IsGCCTaxSystemEnable = 1 AND GCCM.MatGUID = mt.GUID AND GCCM.TaxType = 1
			WHERE NMT.StationGuid = @POSCardGuid
					AND NMT.DeviceID = @DeviceId
					AND (NMT.IsNewDataSync = 0 OR NMT.IsModifiedDataSync = 0)
					-- AND POSD.ActiveFlag = 1
			UNION ALL
			SELECT	
				(mt.Number),
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
				LOWER(mt.Dim) as Dim,
				LOWER(mt.Origin) Origin,
				LOWER(mt.Pos) Pos,
				LOWER(mt.Company) Company,
				LOWER(mt.Color) Color,
				LOWER(mt.Provenance) Provenance,
				LOWER(mt.Quality) Quality,
				LOWER(mt.Model) Model,
				mt.[type] ,
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
			FROM POSSDStationSyncModifiedData000 AS NMT
			INNER JOIN mt000 mt ON ((NMT.RelatedToObject = 'Mt000') AND (mt.Parent = NMT.ReleatedToObjectGuid ))
			INNER JOIN POSSDStationDevice000 AS POSD ON (NMT.StationGuid = POSD.StationGUID  AND POSD.DeviceID = NMT.DeviceID)
			INNER JOIN @Groups AS gr ON (GR.GroupGUID = MT.GroupGUID)
			LEFT  JOIN POSSDMaterialExtended000 ME ON mt.GUID = ME.MaterialGUID
			LEFT  JOIN GCCMaterialTax000 GCCM ON @IsGCCTaxSystemEnable = 1 AND GCCM.MatGUID = mt.GUID AND GCCM.TaxType = 1
			WHERE NMT.StationGuid = @POSCardGuid
					AND NMT.DeviceID = @DeviceId
					AND (NMT.IsNewDataSync = 0 OR NMT.IsModifiedDataSync = 0)
					-- AND POSD.ActiveFlag = 1
			ORDER BY Number OFFSET (@PageSize * @PageIndex)  ROWS FETCH NEXT @PageSize ROWS ONLY;	
				
		END
END
#################################################################
#END
