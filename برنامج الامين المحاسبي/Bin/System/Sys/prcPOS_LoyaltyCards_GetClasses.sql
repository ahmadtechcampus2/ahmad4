##################################################################
CREATE PROC prcPOS_LoyaltyCards_GetClasses
AS 
	SET NOCOUNT ON 

	CREATE TABLE #Class (GUID UNIQUEIDENTIFIER, [Name] NVARCHAR(500), [LatinName] NVARCHAR(500))

	DECLARE 
		@CentralizedDBName			NVARCHAR(250),
		@ErrorNumber				INT

	SELECT TOP 1
		@ErrorNumber =			ISNULL(ErrorNumber, 0),
		@CentralizedDBName =	ISNULL(CentralizedDBName, '')
	FROM 
		dbo.fnPOS_LoyaltyCards_CheckSystem (0x0)

	IF @ErrorNumber > 0 
		GOTO exitproc

	EXEC ('
		INSERT INTO #Class
		SELECT 
			[GUID],
			[Name],
			[LatinName]
		FROM ' + @CentralizedDBName + 'POSLoyaltyCardClassification000 ORDER BY [Number] ')

	exitProc:
		SELECT @ErrorNumber AS ErrorNumber
		SELECT * FROM #Class
#######################################################################################
CREATE PROC prcPOS_LoyaltyCards_GetClassInfo
	@ClassificationGUID	UNIQUEIDENTIFIER 
AS 
	SET NOCOUNT ON 

	CREATE TABLE #Class (GUID UNIQUEIDENTIFIER, [Name] NVARCHAR(500), [LatinName] NVARCHAR(500))

	DECLARE 
		@CentralizedDBName			NVARCHAR(250),
		@ErrorNumber				INT

	SELECT TOP 1
		@ErrorNumber =			ISNULL(ErrorNumber, 0),
		@CentralizedDBName =	ISNULL(CentralizedDBName, '')
	FROM 
		dbo.fnPOS_LoyaltyCards_CheckSystem (0x0)

	IF @ErrorNumber > 0 
		GOTO exitproc
    DECLARE @CmdText NVARCHAR(MAX)
	SET @CmdText = ' INSERT INTO #Class SELECT [GUID],[Name],[LatinName] FROM ' + @CentralizedDBName + 'POSLoyaltyCardClassification000
		WHERE GUID = '''  + CAST(@ClassificationGUID AS VARCHAR(100)) + ''''
	
	EXEC (@CmdText)

	exitProc:
		SELECT @ErrorNumber AS ErrorNumber
		SELECT * FROM #Class
#######################################################################################
#END