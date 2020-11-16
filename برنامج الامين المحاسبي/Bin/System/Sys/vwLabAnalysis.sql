##################################################################################
## -- 0- Single 1- Composed 2- Categorized 3- Item
CREATE  VIEW vwHosAnalysisAll
As 
SELECT   
	Number,   
	GUID,   
	ParentGUID, 
	Code,   
	Name,   
	LatinName, 
	Type, 
	Security 
FROM HosAnalysis000
UNION 
SELECT   
	Number,   
	GUID,   
	ParentGUID, 
	Code,   
	Name,   
	LatinName, 
	2 Type, 
	Security 
FROM HosAnaCat000 
UNION 
SELECT   
	Number,   
	GUID,   
	ParentGUID, 
	Code,   
	Name,   
	LatinName, 
	3 Type,
	Security 
FROM HosAnalysisItems000 
##################################################################################
CREATE   VIEW vwHosAnalysis
AS 
SELECT * 
FROM   vwHosAnalysisAll 
WHERE  Type = 0 OR  TYPE = 1 OR Type = 2
##################################################################################
#END

