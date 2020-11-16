###########################################################################
CREATE FUNCTION fnGetUserGroupsSec(@UserGUID [UNIQUEIDENTIFIER])
	RETURNS TABLE
AS
	RETURN (SELECT [grGUID] AS [GUID], [grSecurity] AS [SECURITY] from [vwGr])

###########################################################################
#END