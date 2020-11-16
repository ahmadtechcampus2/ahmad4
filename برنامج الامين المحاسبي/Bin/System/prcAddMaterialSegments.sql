###########################################################################
CREATE PROC prcAddMaterialSegments
@MaterialId		UNIQUEIDENTIFIER,
@GroupId		UNIQUEIDENTIFIER
AS

INSERT INTO MaterialSegments000 (Id, MaterialId, SegmentId, Number)
(
	SELECT NEWID(), @MaterialId, SegmentId, gs.Number
	FROM GroupSegments000 gs WHERE GroupId = @GroupId 
)


INSERT INTO MaterialSegmentElements000 (MaterialSegmentId, ElementId, Number)
(
	SELECT ms.Id, gse.ElementId , gse.Number
	FROM  GroupSegmentElements000 gse 
	JOIN  GroupSegments000 gs ON gs.Id = gse.GroupSegmentId AND gs.GroupId = @GroupId
	JOIN mt000 mt ON mt.GroupGUID = @GroupId AND mt.GUID = @MaterialId
	JOIN MaterialSegments000  ms ON ms.MaterialId = @materialId AND ms.SegmentId = gs.SegmentId
)

###########################################################################
#END