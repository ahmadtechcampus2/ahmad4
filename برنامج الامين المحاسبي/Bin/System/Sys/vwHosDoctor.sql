#########################################################
CREATE VIEW vwHosDoctor 
AS
 SELECT 
  GUID,
  [Name],
  LatinName,
  Code,
  Security
FROM vwHosEmployee 
WHERE WorkNature = 0
#########################################################
#END