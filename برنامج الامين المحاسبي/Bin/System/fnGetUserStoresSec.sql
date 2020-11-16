###########################################################################
CREATE FUNCTION fnGetUserStoresSec(@UserGUID [UNIQUEIDENTIFIER])
	RETURNS TABLE
AS
	RETURN (SELECT [stGUID] AS [GUID], [stSecurity] AS [Security] FROM [vwSt])

###########################################################################
#END