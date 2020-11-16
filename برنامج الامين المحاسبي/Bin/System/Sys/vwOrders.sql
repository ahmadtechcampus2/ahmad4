######################################################
CREATE FUNCTION fnOrderAlternativeUser_IsUsed(@Guid UNIQUEIDENTIFIER) 
	RETURNS BIT 
AS 
BEGIN 
	IF EXISTS(SELECT * FROM OrderApprovalStates000 WHERE AlternativeUserGUID = @Guid)
		RETURN 1
	RETURN 0
END 
######################################################
CREATE VIEW vwOrderAlternativeUsers
AS
	SELECT	
		*, 
		dbo.fnOrderAlternativeUser_IsUsed(GUID) AS IsUsed 
	FROM 
		OrderAlternativeUsers000
######################################################
#END