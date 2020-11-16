################################################################################
CREATE FUNCTION fnPOSSD_Material_IsMaterialExtendedExists 
				(@matGUID UNIQUEIDENTIFIER)
	RETURNS INT
AS BEGIN  
	
--=========== Check used in cross sale qusation materials
	IF EXISTS(SELECT * FROM POSSDMaterialExtended000 WHERE MaterialGUID = @matGUID AND [Type] = 1)
		RETURN 1

--=========== Check used in up sale qusation materials
	IF EXISTS(SELECT * FROM POSSDMaterialExtended000 WHERE MaterialGUID = @matGUID AND [Type] = 2)
		RETURN 2

--=========== Check used in cross sale materials
	IF EXISTS(SELECT *
			  FROM POSSDRelatedSaleMaterial000 RSM 
			  INNER JOIN POSSDMaterialExtended000 ME ON RSM.ParentGUID = ME.GUID 
			  WHERE RSM.MaterialGUID = @matGUID AND ME.[Type] = 1)
		RETURN 1

--=========== Check used in up sale materials
	IF EXISTS(SELECT *
			  FROM POSSDRelatedSaleMaterial000 RSM 
			  INNER JOIN POSSDMaterialExtended000 ME ON RSM.ParentGUID = ME.GUID 
			  WHERE RSM.MaterialGUID = @matGUID AND ME.[Type] = 2)
		RETURN 2

	RETURN 0

END 
#################################################################
#END
