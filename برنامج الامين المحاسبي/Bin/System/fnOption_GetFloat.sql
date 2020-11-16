###########################################################################
CREATE FUNCTION fnOption_GetFloat(@Option [NVARCHAR](250), @Default [NVARCHAR](2000) = '')
	RETURNS [FLOAT]
AS BEGIN
	RETURN CAST([dbo].[fnOption_Get](@Option, @Default) AS [FLOAT])
END

###########################################################################
#END