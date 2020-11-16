#########################################################
CREATE VIEW vwUSX_OfCurrentUser
AS
	SELECT * FROM [vwUSX]
	WHERE [usGUID] = [dbo].[fnGetCurrentUserGUID]()

#########################################################
#END