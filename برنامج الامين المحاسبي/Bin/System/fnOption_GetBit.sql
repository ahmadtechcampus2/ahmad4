###########################################################################
CREATE FUNCTION fnOption_GetBit(@Option [NVARCHAR](250), @Default [BIT] = 0)
	RETURNS [BIT]
AS BEGIN
	RETURN CAST([dbo].[fnOption_Get](@Option, @Default) AS [BIT])
END

###########################################################################
#END