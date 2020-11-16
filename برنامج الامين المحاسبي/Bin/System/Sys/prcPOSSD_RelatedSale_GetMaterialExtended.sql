################################################################################
CREATE PROCEDURE prcPOSSD_RelatedSale_GetMaterialExtended
-- Param --------------------------------
	   @MaterialExtendedType         INT
----------------------------------------- 
AS
    SET NOCOUNT ON
------------------------------------------------------------------------

SELECT ME.[GUID]				 AS MatExtendedGuid,
	   ME.Number				 AS Number,
	   ME.MaterialGUID			 AS MatGuid,
	   MT.Code + ' - ' + MT.Name AS MaterialStr,
	   ME.Question				 AS Question,
	   ME.LatinQuestion			 AS LatinQuestion
FROM POSSDMaterialExtended000 ME
INNER JOIN mt000 MT ON ME.MaterialGUID = MT.[GUID]
WHERE ME.[Type] = @MaterialExtendedType
ORDER BY ME.Number
#################################################################
#END
