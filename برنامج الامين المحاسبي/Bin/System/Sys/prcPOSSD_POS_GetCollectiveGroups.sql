#################################################################
CREATE PROCEDURE prcPOSGetCollectiveGroups
(
	@POSCardGuid UNIQUEIDENTIFIER
)
AS
BEGIN
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
		GroupIndex	INT 
	) 

	INSERT INTO @Groups (Number,GroupGUID, Name,Code, ParentGUID, LatinName, PictureGUID, GroupIndex)
		EXEC prcPOSGetRelatedGroups @POSCardGuid

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
#END 