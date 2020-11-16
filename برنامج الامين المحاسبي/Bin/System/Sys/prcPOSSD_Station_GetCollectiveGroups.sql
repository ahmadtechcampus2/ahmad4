#################################################################
CREATE PROCEDURE prcPOSSD_Station_GetCollectiveGroups
(
	@POSCardGuid UNIQUEIDENTIFIER
)
AS
BEGIN
	/*******************************************************************************************************
	Company : Syriansoft
	SP : prcPOSSD_Station_GetCollectiveGroups
	Purpose: get collective for a specific pos station 
	How to Call: EXEC prcPOSSD_Station_GetCollectiveGroups '3C2561FE-406C-446D-AFE3-6212319487F8'
	Create By: 											Created On: 
	Updated On:	Hanadi Salka							Updated By: 12-Nov-2019
	Change Note:
	********************************************************************************************************/
	DECLARE @RelatedGroups TABLE
	(
		GroupGuid	UNIQUEIDENTIFIER,
		RelatedGuid UNIQUEIDENTIFIER,
		GroupKind	INT
	)

	DECLARE @Groups TABLE
	(
		Number		INT,
		GroupGUID	UNIQUEIDENTIFIER,  
		Name		NVARCHAR(MAX),
		Code		NVARCHAR(MAX),
		ParentGUID	UNIQUEIDENTIFIER,  
		LatinName	NVARCHAR(MAX),
		PictureGUID UNIQUEIDENTIFIER,
		GroupIndex	INT,
		Groupkind	TINYINT 
	) 

	INSERT INTO @Groups (Number,GroupGUID, Name,Code, ParentGUID, LatinName, PictureGUID, GroupIndex, Groupkind)
		EXEC prcPOSSD_Station_GetGroups @POSCardGuid

	DECLARE @GroupCursor AS CURSOR;
	DECLARE @CurrentGroupGUID UNIQUEIDENTIFIER

	SET @GroupCursor = CURSOR FOR
		SELECT GroupGUID from @Groups

	OPEN @GroupCursor;
	FETCH NEXT FROM @GroupCursor INTO @CurrentGroupGUID;

	WHILE @@FETCH_STATUS = 0
	BEGIN
	
		INSERT INTO @RelatedGroups (GroupGuid, RelatedGuid, GroupKind)
			SELECT DISTINCT @CurrentGroupGUID, Collective.[GUID], Collective.[GroupKind]
			FROM fnGetCollectiveGroupsList(@CurrentGroupGUID) AS Collective 
	
		INSERT INTO @RelatedGroups (GroupGuid, RelatedGuid, GroupKind)
			SELECT DISTINCT @CurrentGroupGUID, Mats.[mtGUID], 2 FROM fnGetMatsOfCollectiveGrps(@CurrentGroupGUID) Mats

		FETCH NEXT FROM @GroupCursor INTO @CurrentGroupGUID

	END
 
	CLOSE @GroupCursor;
	DEALLOCATE @GroupCursor;

	SELECT DISTINCT GroupGuid, RelatedGuid, GroupKind FROM @RelatedGroups WHERE GroupGuid <> RelatedGuid 
END
#################################################################
CREATE PROCEDURE prcPOSSD_Station_GetCollectiveGroupItem
@POSStationGuid UNIQUEIDENTIFIER
AS
BEGIN
	/*******************************************************************************************************
	Company : Syriansoft
	SP : prcPOSSD_Station_GetCollectiveGroupItem
	Purpose: get all items of the collective group related to specific pos station
	How to Call: EXEC prcPOSSD_Station_GetCollectiveGroupItem '3C2561FE-406C-446D-AFE3-6212319487F8'
	Create By: Hanadi Salka													Created On: 28 Oct 2019
	Updated On:																Updated By:
	Change Note:
	********************************************************************************************************/

	SELECT 
		GR.GUID,
		GR.GroupGuid,	
		GR.MatGuid,
		GR.ItemType		  
	  FROM gri000 AS GR INNER JOIN POSSDStationGroup000 AS PSGR ON (PSGR.GroupGUID = GR.GroupGuid)
	  WHERE PSGR.StationGUID = @POSStationGuid;
END

#################################################################
#END 