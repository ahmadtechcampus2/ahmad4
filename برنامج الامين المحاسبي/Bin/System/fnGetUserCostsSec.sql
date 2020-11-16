###########################################################################
CREATE FUNCTION fnGetUserCostsSec(@UserGUID [UNIQUEIDENTIFIER])
	RETURNS TABLE
AS
	RETURN (SELECT [coGUID] AS [GUID], [coSecurity] AS [SECURITY] from [vwCo])

###########################################################################
#END