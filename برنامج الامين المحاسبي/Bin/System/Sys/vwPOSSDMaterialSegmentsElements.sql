################################################################################
CREATE VIEW vwPOSSDMaterialSegmentsElements
AS 
	/*******************************************************************************************************
	Company : Syriansoft
	View : vwPOSSDMaterialSegmentsElements
	Purpose: list all the compound items along with segment element info that are asscoiated with POS Group
	How to Call: SELECT * FROM vwPOSSDMaterialSegmentsElements
	Create By: Hanadi Salka													Created On: 06 Sep 2018
	Updated On:																Updated By:
	Change Note:
	********************************************************************************************************/
	SELECT 
	ms.*,
	mse.ElementId AS SegElementGuid,
	mse.Number AS MatSegElementDisplayOrder,
	se.Id,
	se.Code AS SegElementCode,
	se.Name AS SegElementName,
	se.LatinName AS SegElementLatinName,
	se.Number AS SegElementDisplayOrder
	FROM vwPOSSDMaterialSegments AS ms INNER JOIN MaterialSegmentElements000 AS mse ON (ms.MatSegGuid = mse.MaterialSegmentId)
	INNER JOIN SegmentElements000 AS se ON (mse.ElementId = se.Id)
################################################################################
#END
