#########################################################
CREATE VIEW vtTrnStatementTypes
AS
	SELECT * FROM TrnStatementTypes000

#########################################################
CREATE VIEW vbTrnStatementTypes
AS
	SELECT v.*
	FROM vtTrnStatementTypes AS v INNER JOIN fnBranch_GetCurrentUserReadMask(DEFAULT) AS f ON v.branchMask & f.Mask <> 0

#########################################################
CREATE VIEW vcTrnStatementTypes
AS
	SELECT * FROM vbTrnStatementTypes
#########################################################
CREATE VIEW vdTrnStatementTypes
AS
	SELECT * FROM vbTrnStatementTypes

#########################################################
CREATE  VIEW vwTrnStatementTypes
AS  
	SELECT  
		GUID					AS ttGuid, 
		SortNum					AS ttSortNum, 
		Name					AS ttName, 
		LatinName				AS ttLatinName, 
		Abbrev					AS ttAbbrev, 
		LatinAbbrev				AS ttLatinAbbrev, 
		Type					AS ttType, 
		SourceAcc				AS ttSourceAcc,
		DestAcc					AS ttDestAcc,
		branchMask				AS ttbranchMask,
		IsOut					AS IsOut
	FROM  
		vbTrnStatementTypes		
#########################################################
CREATE VIEW vwTrnInStatementTypes
AS  
	SELECT	* FROM  vcTrnStatementTypes 
	where IsOut = 0
#########################################################
CREATE VIEW vwTrnOutStatementTypes
AS  
	SELECT	* FROM  vcTrnStatementTypes 
	where IsOut = 1
#########################################################	
#END