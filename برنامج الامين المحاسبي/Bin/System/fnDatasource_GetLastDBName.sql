########################################################
CREATE FUNCTION fnObject_GetQualifiedName (@ObjectName NVARCHAR(250))
	RETURNS NVARCHAR(250)
AS 
BEGIN 
	IF @ObjectName = ''
		RETURN  @ObjectName

	SET @ObjectName = ISNULL((CASE SUBSTRING(@ObjectName, 1, 1) WHEN '[' THEN @ObjectName ELSE '[' + @ObjectName + ']' END), '')
	RETURN  @ObjectName
END 
########################################################
CREATE FUNCTION fnDatasource_GetLastDBName()
	RETURNS NVARCHAR(250)
AS 
BEGIN 
	DECLARE @DbName NVARCHAR(500)

	DECLARE @FPDate DATE = (SELECT [dbo].[fnOption_get]('AmnCfg_FPDate', DEFAULT))

	SELECT TOP 1 @DbName = DatabaseName
	FROM 
		ReportDataSources000
	WHERE 
		(DatabaseName != DB_NAME()) AND YEAR(EndPeriod) <= YEAR(@FPDate)
	ORDER BY FirstPeriod DESC 
	
	IF ISNULL(@DbName, '') = ''
		RETURN ''

	SET @DbName = dbo.fnObject_GetQualifiedName(@DbName)
	IF NOT EXISTS (SELECT * FROM SYS.DATABASES WHERE dbo.fnObject_GetQualifiedName([Name]) = @DbName)
		RETURN ''

	RETURN ISNULL(@DbName, '')
END 
########################################################
#END
