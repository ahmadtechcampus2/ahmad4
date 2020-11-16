#########################################################
CREATE FUNCTION fnAssets_GetNewNumber()
	RETURNS [INT]
AS BEGIN
	RETURN (ISNULL((SELECT MAX([number]) FROM [as000]), 0) + 1)
END

#########################################################
#END