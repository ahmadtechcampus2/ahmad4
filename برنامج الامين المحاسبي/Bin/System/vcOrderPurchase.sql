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
#END
