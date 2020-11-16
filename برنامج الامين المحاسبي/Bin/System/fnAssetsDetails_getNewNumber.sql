######################################################### 
CREATE FUNCTION fnAssetsDetails_getNewNumber(@matGUID [UNIQUEIDENTIFIER])
	RETURNS [INT]
AS BEGIN
	RETURN (ISNULL((SELECT MAX([number]) FROM [ad000] WHERE [parentGUID] = @matGUID), 0) + 1)
END

#########################################################
#END