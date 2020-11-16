#########################################################
CREATE VIEW vwPOSLoyaltyCardTypeItem
AS 
	SELECT 
		lcti.*,
		CASE ISNULL(mt.mtGUID, 0x0) 
			WHEN 0x0 THEN ISNULL(gr.grCode, '') 
			ELSE mt.mtCode
		END AS ItemCode,
		CASE ISNULL(mt.mtGUID, 0x0) 
			WHEN 0x0 THEN ISNULL(gr.grName, '') 
			ELSE mt.mtName
		END AS ItemName,
		CASE ISNULL(mt.mtGUID, 0x0) 
			WHEN 0x0 THEN ISNULL(gr.grLatinName, '') 
			ELSE mt.mtLatinName
		END AS ItemLatinName,
		CASE ISNULL(mt.mtGUID, 0x0) 
			WHEN 0x0 THEN ''
			ELSE 
				CASE lcti.Unit 
					WHEN 1 THEN mt.mtUnity
					WHEN 2 THEN mt.mtUnit2
					WHEN 3 THEN mt.mtUnit3
					ELSE mt.mtDefUnitName
				END 
		END AS UnitName
	FROM 
		POSLoyaltyCardTypeItem000 lcti
		LEFT JOIN vwmt mt ON mt.mtGUID = lcti.ItemGUID
		LEFT JOIN vwgr gr ON gr.grGUID = lcti.ItemGUID	
#########################################################
#END
