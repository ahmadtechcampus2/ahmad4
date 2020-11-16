################################################################################
CREATE VIEW vwPOSSDMaterialElementsBOM
AS 
	/*******************************************************************************************************
	Company : Syriansoft
	View : vwPOSSDMaterialElementsBOM
	Purpose: list all items that belong to compund item and to POS Station Group
	How to Call: SELECT * FROM vwPOSSDMaterialElementsBOM
	Create By: Hanadi Salka													Created On: 06 Sep 2018
	Updated On:																Updated By:
	Change Note:
	********************************************************************************************************/
	SELECT 
	[mtp].[mtGroup]				AS MTParentGroupGuid,	
	[ms].[MaterialId]				AS MtBOMGuid,
	[ms].[Id]						AS MtBOMSEGuid,		
	[ms].[Order]					AS MtBOMDisplayOrder,
	[mt].[mtCode]					AS MtBOMCode,
	[mt].[mtName]					AS [MtBOMName], 
	[mt].[mtLatinName]				AS [MtBOMLatinName],	
	[mt].[mtCompositionName]		AS [MtBOMCompositionName],
	[mt].[mtCompositionLatinName]	AS [MtBOMCompositionLatinName],
	[mt].[mtParent]					AS [MtBOMParent],
	[mtp].[mtCode]					AS MtCode,
	[mtp].[mtName]					AS [MtName], 
	[mtp].[mtLatinName]				AS [MtLatinName],
	[se].[SGuid]					AS [SGuid],
	[se].[SEGuid]					AS [SEGuid]

	FROM MaterialElements000 AS ms INNER JOIN [vwMT] AS [mt] ON [ms].[MaterialId] = [mt].mtGUID		
	INNER JOIN [vwMT] AS [mtp] ON [mt].[mtParent] = [mtp].mtGUID	
	INNER JOIN vwPOSSDSegmentsElemnts se ON (se.SEGuid = ms.ElementId)	
################################################################################
#END
