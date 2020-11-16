###############################################################################
CREATE PROC prcPOS_Theme_Get
	@Prefix NVARCHAR(250),
	@ThemeName NVARCHAR(250)
AS 
	SET NOCOUNT ON 

	DECLARE @Num NVARCHAR(10)
	SELECT TOP 1 @Num = Value FROM op000 WHERE Name = @Prefix + @ThemeName AND [Type] = 0
	IF ISNULL(@Num, '') = ''
		RETURN

	DECLARE @PrefixName NVARCHAR(100) 
	SET @PrefixName = @Prefix + @Num + '_'

	SELECT REPLACE([Name], @PrefixName, '') AS [Name], [Value] FROM op000 WHERE [Name] LIKE @PrefixName + '%' AND [Type] = 0
###############################################################################
CREATE PROC prcPOS_Theme_GetCurrent
	@Prefix NVARCHAR(250)
AS 
	SET NOCOUNT ON 

	DECLARE @ThemeName NVARCHAR(250)
	SELECT TOP 1 @ThemeName = Value FROM PcOP000 WHERE Name = @Prefix + 'ThemeName' AND CompName = HOST_NAME()
	IF ISNULL(@ThemeName, '') = ''
		RETURN

	EXEC prcPOS_Theme_Get @Prefix, @ThemeName
###############################################################################
CREATE PROC prcPOS_Theme_Delete
	@Prefix NVARCHAR(250),
	@ThemeName NVARCHAR(250),
	@IsModify BIT = 0
AS 
	SET NOCOUNT ON 

	DECLARE @Num NVARCHAR(10)
	SELECT TOP 1 @Num = Value FROM op000 WHERE Name = @Prefix + @ThemeName AND [Type] = 0
	IF ISNULL(@Num, '') != ''
	BEGIN 
		DELETE op000 WHERE Name = @Prefix + @ThemeName AND [Type] = 0
		DELETE op000 WHERE [Name] LIKE @Prefix + @Num + '_' + '%' AND [Type] = 0
	END 

	IF @IsModify = 0
		DELETE PcOP000 WHERE Value = @ThemeName AND Name = @Prefix + 'ThemeName'
###############################################################################
CREATE PROC prcPOS_Theme_SetCurrent
	@Prefix NVARCHAR(250),
	@ThemeName NVARCHAR(250) = ''
AS 
	SET NOCOUNT ON 

	DECLARE @OpName NVARCHAR(250)
	SET @OpName = @Prefix + 'ThemeName'

	DELETE PcOP000 WHERE Value = @ThemeName AND Name = @OpName
	IF EXISTS (SELECT * FROM op000 WHERE Name = @Prefix + @ThemeName AND [Type] = 0)
	BEGIN
		INSERT INTO PcOP000(GUID, CompName, Name, Value)
		SELECT NEWID(), HOST_NAME(), @OpName, @ThemeName
	END 
###############################################################################
CREATE PROC prcPOS_Theme_GetNames
	@Prefix NVARCHAR(250)
AS 
	SET NOCOUNT ON 

	SELECT CAST(REPLACE(REPLACE(Name, '_ThemeName', '') , @Prefix, '') AS INT) AS Num, Value INTO #op FROM op000 WHERE Name LIKE @Prefix + '%_ThemeName' AND [Type] = 0
	SELECT Value FROM #op ORDER BY Num
###############################################################################
CREATE FUNCTION fnPOS_Theme_GetMaxNumber(@Prefix NVARCHAR(250))
	RETURNS INT
AS BEGIN  
	RETURN ISNULL(
		(SELECT 
			MAX(ISNULL(CAST(Value AS INT), 0))
		FROM op000 
		WHERE Name LIKE @Prefix + '%_Number' AND [Type] = 0), 0) + 1
END 
###############################################################################
CREATE FUNCTION fnPOS_Theme_IsExists(@Prefix NVARCHAR(250), @ThemeName NVARCHAR(250), @ThemeNumber INT)
	RETURNS INT
AS BEGIN  
	DECLARE @Num NVARCHAR(10)
	-- not found 
	SELECT TOP 1 @Num = Value FROM op000 WHERE Name = @Prefix + @ThemeName AND [Type] = 0
	IF ISNULL(CAST(@Num AS INT), 0) = 0 
		RETURN 0
	-- found same 
	IF CAST(@Num AS INT) = @ThemeNumber
		RETURN 1
	RETURN 2
END 
###########################################################################
#END
