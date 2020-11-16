#########################################################
CREATE VIEW vwLeafPeriods
AS 
SELECT 
 Number,
 Guid,
 Code,
 Name,
 LatinName,
 Notes,
 StartDate,
 EndDate,
 Security,
 ParentGuid

FROM BDP000 AS BDP
WHERE BDP.GUID NOT IN (SELECT parentGuid FROM bdp000)
#########################################################
#END