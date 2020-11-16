################################################################################
CREATE VIEW vwPOSSDMaterialExtended
AS
	SELECT 
		me.*,
		mt.Parent
	FROM POSSDMaterialExtended000 me
	INNER JOIN mt000 mt on mt.GUID = me.MaterialGUID 
################################################################################
#END
