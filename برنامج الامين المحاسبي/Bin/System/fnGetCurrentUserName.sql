######################################################### 
CREATE FUNCTION fnGetCurrentUserName()
	RETURNS [NVARCHAR](128)
AS BEGIN
/*
This function:
- returns the current user name
*/
	DECLARE @result [NVARCHAR](128)

	SET @result = (SELECT [loginName] FROM [us000] WHERE [guid] = [dbo].[fnGetCurrentUserGUID]())
	RETURN ISNULL(@result , '')
END

#########################################################
#END