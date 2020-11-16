######################################################### 
CREATE FUNCTION fnGetCurrentUserPassword() 
	RETURNS [NVARCHAR](255)
AS BEGIN 
/* 
This function: 
- returns the current user name
*/ 
	DECLARE @result [NVARCHAR](255)

	SET @result = (SELECT [Password] FROM [us000] WHERE [guid] = [dbo].[fnGetCurrentUserGUID]())
	RETURN ISNULL(@result , '')
END

#########################################################
#END