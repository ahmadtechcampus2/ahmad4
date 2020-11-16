######################################################### 
CREATE FUNCTION fnGetCurrentUserNumber()
	RETURNS [INT]
AS BEGIN
	/*
	This function:
	- returns the current user number
	*/
	DECLARE @result [INT]
	
	SET @result = (SELECT [Number] FROM [us000] WHERE [guid] = [dbo].[fnGetCurrentUserGUID]())
	
	RETURN ISNULL(@result , 0)
END

#########################################################
#END