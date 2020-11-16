################################################################################
CREATE PROCEDURE prcPOSSD_GetMaterialSegments
	@POSStationGUID UNIQUEIDENTIFIER
	
AS
BEGIN
	/*******************************************************************************************************
	Company : Syriansoft
	SP : prcPOSSD_GetMaterialSegments
	Purpose: get all the compound materials associated with segments that are related to a specific POS Station
	How to Call: EXEC prcPOSSD_GetMaterialSegments '3C2561FE-406C-446D-AFE3-6212319487F8'
	Create By: Hanadi Salka													Created On: 03 Sep 2018
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
		[ms].[MatSegGuid]				AS Id,
		[ms].[MatGuid]					AS MaterialId,
		[ms].[SegGuid]					AS SegmentId,
		[ms].[MatSegDisplayOrder]		AS Number
	
	FROM vwPOSSDMaterialSegments AS ms LEFT JOIN 	@Groups AS gr ON (GR.GroupGUID = ms.MTParentGroupGuid)	
	GROUP BY [ms].[MatSegGuid], [ms].[MatGuid], [ms].[SegGuid], [ms].[MatSegDisplayOrder];
END
#################################################################
#END
