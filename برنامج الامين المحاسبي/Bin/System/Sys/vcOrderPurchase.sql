#########################################
CREATE VIEW vcOrderPurchase
AS 
	SELECT * FROM [vbBt] WHERE [Type] = 6
#########################################
CREATE VIEW vwOrderInformation 
AS 
	SELECT 
		info.*,
		bu.TextFld1,
		bu.TextFld2,
		bu.TextFld3,
		bu.TextFld4
	FROM 
		OrAddInfo000 info
		INNER JOIN bu000 bu ON bu.guid = info.ParentGuid 
#########################################
CREATE VIEW vwBuOrders
AS 
	SELECT bu.*,
		   oi.* ,
		   CASE WHEN (oi.Finished = 0 AND oi.Add1 = 0) THEN 0 
				WHEN (oi.Finished = 1) THEN 1 
				WHEN (oi.Finished = 0 AND oi.Add1 = 1) THEN 2 END AS OrderState 
	FROM 
		vwBu bu 
		INNER JOIN vwOrderInformation oi ON bu.buGUID = oi.ParentGuid
	WHERE bu.btType IN(5, 6)
#########################################
CREATE VIEW vwBiMtOrders
AS
	SELECT bi.* FROM vwBiMt bi
	INNER JOIN vwBuOrders bu ON bu.buGUID = bi.biParent
#########################################

#END
