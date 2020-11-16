###########################################################################
CREATE FUNCTION fnGetFormatedName(@Code [VARCHAR](128), @Name [NVARCHAR](128))
	RETURNS [NVARCHAR](512)
AS BEGIN
	RETURN (@Code + ': ' + @Name)
END
 
###########################################################################
#END