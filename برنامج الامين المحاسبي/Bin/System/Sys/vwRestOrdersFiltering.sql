###############################################################################
CREATE VIEW vwRestOrdersFiltering
AS 
	SELECT 
		rf.*,
		ISNULL(us.LoginName, '') AS UserName,
		ISNULL(v.Name, '') AS VendorName,
		ISNULL(v.LatinName, '') AS VendorLatinName,
		ISNULL(dr.Name, '') AS DriverName,
		ISNULL(dr.LatinName, '') AS DriverLatinName,
		ISNULL(cu.CustomerName, '') AS CustomerName,
		ISNULL(cu.LatinName, '') AS CustomerLatinName,
		ISNULL(tbl.Code, '') AS TableCode
	FROM 
		RestOrdersFiltering000 AS rf 
		LEFT JOIN us000 us ON rf.UserGUID = us.GUID
		LEFT JOIN RestVendor000 v ON rf.VendorGUID = v.GUID
		LEFT JOIN RestVendor000 dr ON rf.DriverGUID = dr.GUID
		LEFT JOIN cu000 cu ON rf.CustomerGUID = cu.GUID
		LEFT JOIN RestTable000 tbl ON rf.TableGUID = tbl.GUID
###############################################################################
#END