################################################################################
CREATE PROCEDURE prcPOSSD_GetMaterialElements
	@POSStationGUID UNIQUEIDENTIFIER	
AS
BEGIN
	/*******************************************************************************************************
	Company : Syriansoft
	SP : prcPOSSD_GetMaterialElements
	Purpose: get all list all items that belong to compund item and to POS Station Group
	How to Call: EXEC prcPOSSD_GetMaterialElements '3C2561FE-406C-446D-AFE3-6212319487F8'
	Create By: Hanadi Salka													Created On: 06 Sep 2018
	Updated On:																Updated By:
	Change Note:
	********************************************************************************************************/
	DECLARE @Groups TABLE
	(
		Number int ,
		GroupGUID UNIQUEIDENTIFIER,  
		Name NVARCHAR(MAX),
		Code NVARCHAR(MAX),
		ParentGUID UNIQUEIDENTIFIER,  
		LatinName  NVARCHAR(MAX),
		PictureGUID UNIQUEIDENTIFIER,
		GroupIndex	INT,
		Groupkind	TINYINT
	) 
	-- *******************************************************************************************
	-- Get the group related to the pos station
	INSERT INTO @Groups (Number,GroupGUID, Name,Code, ParentGUID, LatinName, PictureGUID, GroupIndex, Groupkind)
	EXEC prcPOSSD_Station_GetGroups @POSStationGUID;	
	SELECT 		
		[mebom].[MtBOMSEGuid]				AS Id,
		[mebom].[MtBOMGuid]					AS MaterialId,
		[mebom].[SEGuid]					AS ElementId,
		[mebom].[MtBOMDisplayOrder]			AS [Order]
	FROM vwPOSSDMaterialElementsBOM	AS mebom LEFT JOIN @Groups AS gr ON (GR.GroupGUID = mebom.MTParentGroupGuid)
	
	GROUP BY [mebom].[MtBOMSEGuid], [mebom].[MtBOMGuid], [mebom].[SEGuid],[mebom].[MtBOMDisplayOrder];			
END
#################################################################
#END
