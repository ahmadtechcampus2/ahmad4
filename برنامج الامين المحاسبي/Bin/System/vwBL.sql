#########################################################
CREATE VIEW vtBl
AS 
	SELECT * FROM bl000
	
#########################################################
CREATE VIEW vbBl
AS 
	SELECT bl.* FROM vtBl AS bl INNER JOIN vwUIX_OfCurrentUser AS ui ON bl.BranchGUID = ui.uiSubID
	WHERE ui.uiReportID = CAST( 0x1001F000 AS INT)

#########################################################
CREATE VIEW vwBl
AS 
	SELECT 
		GUID			AS blGUID,
		BranchGUID		AS blBranchGUID,
		RefGUID			AS blRefGUID,
		RefType			AS blRefType	
	FROM 
		vbBl

#########################################################
#END