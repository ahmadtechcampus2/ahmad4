#########################################################
CREATE VIEW vwGetLCLowerMat
	AS
		SELECT lc.Name, bu.Date, mt.mtName, bi.Qty, mt.mtQty, mt.StorePtr FROM bu000 bu
			INNER JOIN LC000 lc ON bu.LCGUID = lc.GUID
			INNER JOIN bi000 bi ON bi.ParentGUID = bu.GUID
			INNER JOIN vwMtGrMS mt ON mt.mtGUID = bi.MatGUID AND mt.StorePtr = bu.StoreGUID
		 WHERE bu.LCGUID <> 0x0 AND lc.State = 1 AND bu.LCType = 1 AND mt.mtQty - bi.Qty < 0
######################################################### 
CREATE VIEW vwLCEntries
	AS
		SELECT LCE.*, 
		PY.Date ,PY.Number , ET.Abbrev AS Name,ET.LatinAbbrev AS LatinName
		FROM 
		LCEntries000  LCE INNER JOIN Py000 Py ON LCE.EntryGUID = Py.GUID 
						  INNER JOIN Et000 ET ON Py.TypeGuid = ET.GUID
#########################################################
#end
