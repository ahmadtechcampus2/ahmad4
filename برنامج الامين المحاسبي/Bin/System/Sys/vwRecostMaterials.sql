################################################################################
CREATE VIEW vwRecostMaterials
AS
	SELECT DISTINCT R.* 
	FROM
		RecostMaterials000 R
		JOIN vwbubi bu ON R.InBillGuid = bu.buGuid OR R.OutBillGuid = bu.buGuid 

###################################################################################
#END


