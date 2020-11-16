#########################################################
CREATE VIEW vwLeafStores
AS 
SELECT 
 Number,
 Code,
 Name,
 Notes,
 Address,
 Keeper,
 Security,
 LatinName,
 GUID,
 ParentGUID,
 AccountGUID,
 Type,
 branchMask

FROM vbSt

WHERE GUID NOT IN (SELECT parentGuid FROM VbSt)
#########################################################
#END