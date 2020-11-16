#########################################################
CREATE VIEW vwUIX_OfCurrentUser
AS
	SELECT * FROM [vwUIX]
	WHERE [uiUserGUID] = [dbo].[fnGetCurrentUserGUID]()

#########################################################
#END