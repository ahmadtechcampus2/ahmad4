################################################################################
CREATE PROCEDURE prcPOSSD_GetSegmentElements
	@POSStationGUID UNIQUEIDENTIFIER
	
AS
BEGIN
		/*******************************************************************************************************
	Company : Syriansoft
	SP : prcPOSSD_GetSegments
	Purpose: get all the segment elements that are related to a specific POS Station
	How to Call: EXEC prcPOSSD_GetSegmentElements 'FE3EA047-9BFE-42C8-9F89-5F3E62BB90D4'
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
		[se].[SegElementGuid]				AS Id,		
		CONVERT(VARCHAR(MAX),[se].[SegElementCode])	AS Code,
		[se].[SegElementName]				AS Name,
		[se].[SegElementLatinName]			AS LatinName,
		[se].[SegGuid]						AS SegmentId,
		[se].[SegElementDisplayOrder]		AS Number
	FROM vwPOSSDMaterialSegmentsElements	AS se	INNER JOIN 	@Groups AS gr ON (GR.GroupGUID = SE.MTParentGroupGuid)
	GROUP BY [se].[SegElementGuid], [se].[SegElementCode], [se].[SegElementName], [se].[SegElementLatinName], [se].[SegGuid], [se].[SegElementDisplayOrder]
	UNION 
	SELECT 		
		[se].[SegElementGuid]				AS Id,		
		CONVERT(VARCHAR(MAX),[se].[SegElementCode])	AS Code,
		[se].[SegElementName]				AS Name,
		[se].[SegElementLatinName]			AS LatinName,
		[se].[SegGuid]						AS SegmentId,
		[se].[SegElementDisplayOrder]		AS Number
	FROM vwPOSSDMaterialSegmentsElements	AS se
	INNER JOIN gri000 AS GRI ON (GRI.ItemType = 1 AND GRI.MatGuid = se.MatGuid)
	INNER JOIN 	@Groups AS gr ON (GR.GroupGUID = GRI.GroupGuid AND Groupkind = 1)
	GROUP BY [se].[SegElementGuid], [se].[SegElementCode], [se].[SegElementName], [se].[SegElementLatinName], [se].[SegGuid], [se].[SegElementDisplayOrder]
END
#################################################################
#END
