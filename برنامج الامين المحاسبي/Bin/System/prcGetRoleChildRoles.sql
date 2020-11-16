#########################################################
CREATE PROC prcGetRoleChildRoles
	@roleGUID [UNIQUEIDENTIFIER]
AS 
	SELECT * FROM [fnGetRoleChildRoles](@roleGUID)
#########################################################
CREATE PROC prcGetUserGroups
	@UserGUID UNIQUEIDENTIFIER,
	@GroupGUID UNIQUEIDENTIFIER
AS 
	SET NOCOUNT ON 

	SELECT 
		r.LoginName AS GroupName,
		us.LoginName AS UserName
	FROM 
		us000 us 
		INNER JOIN rt000 rt ON us.GUID = rt.ChildGUID
		INNER JOIN us000 r ON r.GUID = rt.ParentGUID
	WHERE 
		us.GUID = @UserGUID
		AND 
		r.GUID != @GroupGUID
#########################################################
#END