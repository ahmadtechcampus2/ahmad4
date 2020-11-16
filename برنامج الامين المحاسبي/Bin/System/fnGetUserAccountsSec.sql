###########################################################################
CREATE FUNCTION fnGetUserAccountsSec(@UserGUID [UNIQUEIDENTIfIER])
	RETURNS TABLE
AS
	RETURN (SELECT [acGUID] AS [GUID], [acSecurity] AS [SECURITY] from [vwAc])

###########################################################################
#END