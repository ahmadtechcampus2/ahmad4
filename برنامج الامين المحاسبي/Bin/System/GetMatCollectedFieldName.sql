###########################################################################
CREATE FUNCTION fnGetMatCollectedFieldName(@Colect INT,@Prefix NVARCHAR(10) = '')
	RETURNS NVARCHAR(100)
AS
BEGIN
	DECLARE @fld NVARCHAR(100) 
	IF @Colect = 1
		SET @fld = '['+ @Prefix+ 'Dim]' 
	ELSE IF @Colect = 2
		SET @fld = '['+ @Prefix + 'Pos] ' 
	ELSE IF @Colect = 3
		SET @fld = '['+ @Prefix + 'Origin] ' 
	ELSE IF @Colect = 4
		SET @fld = '['+ @Prefix + 'Company] ' 
	ELSE IF @Colect = 5
		SET @fld = '['+ @Prefix + 'Color] ' 
	ELSE IF @Colect = 6
		SET @fld = '['+ @Prefix + 'Model] '
	ELSE IF @Colect = 7
		SET @fld = '['+ @Prefix + 'Quality]' 
	ELSE IF @Colect = 8
		SET @fld = '['+ @Prefix + 'Provenance]'
	ELSE IF @Colect = 9
		SET @fld = '['+ @Prefix + 'Name]'
	ELSE IF @Colect = 10
		SET @fld = '['+ @Prefix + 'LatinName]'
	ELSE IF @Colect = 11
	BEGIN
		IF (@Prefix = '')
			SET @fld = '[grName]'
		ELSE
			SET @fld = '['+ @Prefix + 'Name]'
	END
	ELSE
		SET @fld = '' 
	RETURN @fld
END
###########################################################################
CREATE FUNCTION fnGetInnerJoinGroup(@ColectGr INT,@mtGuidName NVARCHAR(100))
	RETURNS NVARCHAR(100)
AS
BEGIN
	DECLARE @INNER NVARCHAR(100) 
	IF @ColectGr = 0
		SET @INNER = ''
	ELSE
		SET @INNER = ' INNER JOIN  vwGr gr ON gr.grGuid = ' +  @mtGuidName + + ' ' + CHAR(13)
	RETURN @INNER
END
###########################################################################
#END 