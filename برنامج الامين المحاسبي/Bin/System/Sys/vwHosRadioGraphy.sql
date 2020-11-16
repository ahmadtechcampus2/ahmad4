###########################
CREATE VIEW vwHosRadioGraphy
AS
SELECT  
	Number,  
	GUID,  
	Code,  
	Name,  
	LatinName,  
	ParentGUID,
	TypeGUID,
	type,  
	Price, 
	Unit ,  
	Notes,  
	Security 
FROM hosRadioGraphy000 WHERE Type <> 2
#######################
CREATE   VIEW vwHosRadioGraphyAll
AS
SELECT  
	Number,  
	GUID,  
	Code,  
	Name, 
	LatinName,   
	0x0 as ParentGUID,
	Notes,  
	Security, 
	2 type
FROM hosRadioGraphyType000
UNION ALL
SELECT  
	Number,  
	GUID,  
	Code,  
	Name,  
	LatinName,  
	TypeGUID ParentGUID,
	Notes,  
	Security, 
	type
FROM hosRadioGraphy000 WHERE Type <> 2
#######################
#END