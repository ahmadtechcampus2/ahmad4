#########################################################
CREATE FUNCTION fnStrings_get(@code [NVARCHAR](128), @language [INT] = -1)
	RETURNS [NVARCHAR](256)

AS BEGIN
	DECLARE @result [NVARCHAR](256)

	IF @language = -1
		SET @language = [dbo].[fnConnections_GetLanguage]()
		
	IF @language = 0 -- arabic
		SET @result = (SELECT [arabic] FROM [strings] WHERE [code] = @code)

	ELSE IF @language = 1 --english
		SET @result = (SELECT [english] FROM [strings] WHERE [code] = @code)
		
	ELSE IF @language = 2 --french
		SET @result = (SELECT [french] FROM [strings] WHERE [code] = @code)
		
	ELSE -- For any other language use english strings
		SET @result = (SELECT [english] FROM [strings] WHERE [code] = @code)
		
	IF @result IS NULL -- if string not found
		SET @result = 'RESOURCE ERROR: Code: ' + @code

	RETURN @result

END

#########################################################
#END