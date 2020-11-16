##############################
CREATE VIEW vwHosOperation
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
	HosOperation000

##############################
#END