###########################################################################
CREATE FUNCTION fnOption_GetVarChar(@Option [NVARCHAR](250), @Default [NVARCHAR](2000) = '')
	RETURNS [VARCHAR]
AS BEGIN
	RETURN [dbo].[fnOption_Get](@Option, @Default)
END

###########################################################################
#END