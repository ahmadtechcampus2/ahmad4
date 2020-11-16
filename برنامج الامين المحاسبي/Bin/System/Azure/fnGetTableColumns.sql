#########################################################
CREATE FUNCTION fnGetTableColumns (@tableName [NVARCHAR](128))
	RETURNS @Result TABLE ([name] [NVARCHAR](128) COLLATE arabic_ci_ai)
AS BEGIN
		INSERT INTO @Result SELECT [name] FROM [syscolumns] WHERE [id] = OBJECT_ID(@tableName) ORDER BY [colorder]
	RETURN
END


#########################################################
#END