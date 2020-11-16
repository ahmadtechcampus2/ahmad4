################################################################################
CREATE PROCEDURE prcPOSSD_RelatedSale_GetRelatedSaleMaterials
-- Param --------------------------------   
	   @ParentGuid UNIQUEIDENTIFIER
-----------------------------------------   
AS
    SET NOCOUNT ON
---------------------------------------------------------------
	DECLARE @language INT = [dbo].[fnConnections_getLanguage]()

	SELECT 
		RSM.MaterialGUID																  AS MaterialGUID,
		MT.Code +' - '+ CASE @language WHEN 0 THEN MT.Name								  
									   ELSE CASE MT.LatinName WHEN '' THEN MT.Name		  
															  ELSE MT.LatinName END END   AS Material
	FROM 
		POSSDRelatedSaleMaterial000 RSM 
		INNER JOIN POSSDMaterialExtended000 ME ON RSM.ParentGUID = ME.[GUID]
		INNER JOIN mt000 MT ON RSM.MaterialGUID = MT.[GUID]
	WHERE 
		RSM.ParentGUID = @ParentGuid
	ORDER BY
		MT.Code
#################################################################
#END
