#########################################################
CREATE FUNCTION fnGetAccountName( @guid UNIQUEIDENTIFIER)
	RETURNS NVARCHAR(250)
AS 
BEGIN 
	DECLARE @name NVARCHAR(250)
	SET @name = ( SELECT [Name] FROM [AC000] WHERE [GUID] = @guid)
	IF ISNULL( @name, '') = ''
		RETURN ''
	RETURN @name
END 	
		
#########################################################
#END
