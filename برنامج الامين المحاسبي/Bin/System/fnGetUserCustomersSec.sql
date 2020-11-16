###########################################################################
CREATE FUNCTION fnGetUserCustomersSec(@UserGUID [UNIQUEIDENTIFIER])
	RETURNS TABLE
AS
	RETURN (SELECT [cuGUID] AS [GUID], [cuSecurity] AS [SECURITY] from [vwCu])

###########################################################################
#END