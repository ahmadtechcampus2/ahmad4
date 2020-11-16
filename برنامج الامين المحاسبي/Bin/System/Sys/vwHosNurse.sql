#########################################################
CREATE VIEW vwHosNurse
AS
 SELECT 
  GUID,
  [Name],
  LatinName,
  Code,
  Security
FROM vwHosEmployee 
WHERE WorkNature = 1
#########################################################
#END