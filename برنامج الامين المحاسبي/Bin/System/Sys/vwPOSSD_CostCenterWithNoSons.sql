################################################################################
CREATE VIEW vwPOSSD_CostCenterWithNoSons
AS
	SELECT
		CO.* 
	FROM
		co000 CO 
		LEFT JOIN co000 COParent ON CO.[GUID] = COParent.ParentGUID 
	WHERE
		COParent.ParentGUID IS NULL
		AND CO.[Type] = 0
################################################################################
#END
