#########################################################
CREATE FUNCTION fnLC_IsUsed(@LCGuid UNIQUEIDENTIFIER)
	RETURNS BIT
AS BEGIN 
	IF	EXISTS(SELECT * FROM BU000 WHERE LCGUID = @LCGuid) OR 
		EXISTS(SELECT * FROM EN000 WHERE LCGUID = @LCGuid)
		RETURN 1
	RETURN 0
END	
#########################################################
CREATE VIEW vtLC
AS 
	SELECT * FROM LC000
###########################################################################
CREATE VIEW vbLC
AS
	SELECT [LC].*
	FROM [vtLC] AS [LC] INNER JOIN [vwBr] AS [br] ON [LC].[BranchGUID] = [br].[brGUID]
#########################################################
CREATE VIEW vwLC
AS
	SELECT 
		*,
		dbo.fnLC_IsUsed(GUID) AS IsUsed
	FROM vbLC 
#########################################################
CREATE VIEW vwLCSub 
AS
	SELECT * FROM vbLCMain
	WHERE GUID NOT IN (SELECT ParentGUID FROM vbLCMain)
###########################################################################
CREATE VIEW vwOpenedLC
AS
	SELECT * FROM vwLC WHERE State = 1
###########################################################################
#END