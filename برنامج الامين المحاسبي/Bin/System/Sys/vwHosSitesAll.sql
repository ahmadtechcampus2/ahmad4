##################################################################################
## -- 0- Single 1- Composed 2- Categorized 3- Item
CREATE  VIEW vwHosSitesAll
As 
SELECT   
	Number,   
	GUID,   
	0x0 AS ParentGUID, 
	Code,   
	Name,   
	LatinName, 
	0 Type, 
	Security 
FROM HosSiteType000
UNION 
SELECT   
	Number,   
	GUID,   
	ParentGUID, 
	Code,   
	Name,   
	LatinName, 
	2 as Type, 
	Security 
FROM HosSite000 

################################
#END