################################################################################
CREATE PROCEDURE prcPOSSD_GetSegments
	@POSStationGUID UNIQUEIDENTIFIER
	
AS
BEGIN
	/*******************************************************************************************************
	Company : Syriansoft
	SP : prcPOSSD_GetSegments
	Purpose: get all the segments that are related to a specific POS Station
	How to Call: EXEC prcPOSSD_GetSegments '3C2561FE-406C-446D-AFE3-6212319487F8'
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
		-- S.MTParentGroupGuid,
		[s].[SegGuid]						AS Id,
		[s].[SegName]						AS Name,
		[s].[SegLatinName]					AS LatinName,
		[s].[SegDisplayOrder]				AS Number,
		[s].[SegCharactersCount]			AS CharactersCount
	FROM vwPOSSDMaterialSegments AS s LEFT JOIN @Groups AS gr ON (GR.GroupGUID = S.MTParentGroupGuid)	
	GROUP BY SegGuid, SegName, SegLatinName, SegDisplayOrder, SegCharactersCount;
END
#################################################################
#END
