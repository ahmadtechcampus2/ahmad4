##############################
CREATE VIEW vwHosGeneralOperation
AS
SELECT
	Number, 
	GUID, 
	Code, 
	Name, 
	LatinName, 
	Notes, 
	Type, 
	Cost, 
	Security
FROM 
	HosGeneralOperation000

##############################
#END