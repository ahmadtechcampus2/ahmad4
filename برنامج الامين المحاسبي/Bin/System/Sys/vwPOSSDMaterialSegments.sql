################################################################################
CREATE VIEW vwPOSSDMaterialSegments
AS 
	
	/*******************************************************************************************************
	Company : Syriansoft
	View : vwPOSSDMaterialSegments
	Purpose: list all the compound items along with segment info that are asscoiated with POS Group
	How to Call: SELECT * FROM vwPOSSDMaterialSegments
	Create By: Hanadi Salka													Created On: 06 Sep 2018
	Updated On:																Updated By:
	Change Note:
	********************************************************************************************************/
	SELECT 
	mt.mtGroup				AS MTParentGroupGuid,	
	ms.MaterialId					AS MatGuid,
	ms.Id							AS MatSegGuid,	
	ms.SegmentId					AS SegGuid,
	ms.Number						AS MatSegDisplayOrder,
	seg.Name						AS SegName,
	seg.LatinName					AS SegLatinName,
	seg.Number						AS SegDisplayOrder,
	seg.CharactersCount				AS SegCharactersCount,
	mt.mtCode						AS MatCode,
	[mt].[mtName]					AS [MatName], 
	[mt].[mtLatinName]				AS [MatLatinName],
	[mt].[mtHasSegments]			AS [MatHasSegments],
	[mt].[mtParent]					AS [MatParent]
	
	FROM MaterialSegments000 AS ms INNER JOIN [vwMT] AS [mt] ON [ms].[MaterialId] = [mt].mtGUID		
	INNER JOIN Segments000 AS seg ON (seg.Id = MS.SegmentId)
################################################################################
#END
