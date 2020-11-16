########################################################
CREATE FUNCTION fnFlag_IsSet (@flagID [INT])
	RETURNS [INT]
AS BEGIN

	DECLARE @result [INT]
	
	IF EXISTS (SELECT * FROM [mc000] WHERE [type] = 24 AND [number] = @flagID)
		SET @result = 1
	ELSE
		SET @result = 0

	RETURN @result

END

######################################################## 
#END