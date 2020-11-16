###########################################################################
CREATE FUNCTION fnOption_GetInt(@Option [NVARCHAR](250), @Default [NVARCHAR](2000) = '')
	RETURNS [INT]
AS BEGIN
	RETURN CAST([dbo].[fnOption_Get](@Option, @Default) AS [INT])
END

###########################################################################
#END