################################################################################
CREATE PROCEDURE prcPOSSD_GetMaterialSegmentElements
	@POSStationGUID UNIQUEIDENTIFIER
	
AS
BEGIN
	/*******************************************************************************************************
	Company : Syriansoft
	SP : prcPOSSD_GetSegments
	Purpose: get all the segment elements that are related to a specific POS Station
	How to Call: EXEC prcPOSSD_GetMaterialSegmentElements '3C2561FE-406C-446D-AFE3-6212319487F8'
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
		[mse].[MatSegGuid]				AS MaterialSegmentId,
		[mse].[SegElementGuid]			AS ElementId,
		[mse].[MatSegElementDisplayOrder]		AS Number
	
	FROM vwPOSSDMaterialSegmentsElements AS mse	LEFT JOIN @Groups AS gr ON (GR.GroupGUID = mse.MTParentGroupGuid)	
	GROUP BY [mse].[MatSegGuid], [mse].[SegElementGuid], [mse].[MatSegElementDisplayOrder];		
END
#################################################################
#END
