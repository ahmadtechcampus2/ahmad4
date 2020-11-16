################################################################################
CREATE PROCEDURE repAddressTree
AS 
	SET NOCOUNT ON

	CREATE TABLE #SecViol (Type INT, Cnt INT)  

	DECLARE @lang INT 	
	SET @lang = [dbo].[fnConnections_getLanguage]()
	
	CREATE TABLE #Result (
		GUID			UNIQUEIDENTIFIER,
		ParentGUID 		UNIQUEIDENTIFIER,
		Code			NVARCHAR(250) COLLATE ARABIC_CI_AI,  
		[Name]			NVARCHAR(500) COLLATE ARABIC_CI_AI,  
		Number			INT,
		[Type]			INT,  -- 1: Country, 2: City, 3: Area
		[Level]			INT,
		DetailsCount	INT,
		[Path]			NVARCHAR(1000) COLLATE ARABIC_CI_AI)  

	INSERT INTO #Result
	SELECT 
		GUID,
		0X0,
		Code,
		CASE WHEN (@Lang != 0) AND (LatinName <> '') THEN LatinName ELSE [Name] END,
		Number,
		1,
		0,
		(SELECT COUNT(*) FROM AddressCity000 WHERE ParentGUID = ac.GUID),
		CAST((ROW_NUMBER() OVER (ORDER BY Number) * 0.000001) AS VARCHAR(40))
	FROM AddressCountry000 ac

	INSERT INTO #Result
	SELECT 
		aci.GUID,
		aci.ParentGUID,
		aci.Code,
		CASE WHEN (@Lang != 0) AND (aci.LatinName <> '') THEN aci.LatinName ELSE [aci].[Name] END,
		aci.Number,
		2,
		1,
		(SELECT COUNT(*) FROM AddressArea000 WHERE ParentGUID = aci.GUID),
		r.Path + CAST((ROW_NUMBER() OVER (ORDER BY aci.Number) * 0.000001) AS VARCHAR(40))
	FROM 
		AddressCity000 aci
		INNER JOIN #Result r ON r.GUID = aci.ParentGUID 

	INSERT INTO #Result
	SELECT 
		aar.GUID,
		aar.ParentGUID,
		aar.Code,
		CASE WHEN (@Lang != 0) AND (aar.LatinName <> '') THEN aar.LatinName ELSE [aar].[Name] END,
		aar.Number,
		3,
		2,
		(SELECT COUNT(*) FROM CustAddress000 WHERE AreaGUID = aar.GUID),
		r.Path + CAST((ROW_NUMBER() OVER (ORDER BY aar.Number) * 0.000001) AS VARCHAR(40))
	FROM 
		AddressArea000 aar
		INNER JOIN #Result r ON r.GUID = aar.ParentGUID 

	SELECT *
	FROM 
		#Result 
	ORDER BY 
		[Path],
		[Type],
		[Number]

	SELECT * FROM #SecViol
################################################################################
CREATE PROCEDURE repDetailsAddressList
	@Type			[INT], -- 1: Country, 2: City, 3: Area
	@ParentGUID		[UNIQUEIDENTIFIER]
AS
	SET NOCOUNT ON
		
	CREATE TABLE [#SecViol] ([Type] [INT], [Cnt] [INT])
	
	CREATE TABLE [#Result] (
		[GUID]			[UNIQUEIDENTIFIER],
		[ParentGUID]	[UNIQUEIDENTIFIER],
		[Type]			[INT], -- 1: City, 2: Area, 3:Street
		[Code]			[NVARCHAR](250) COLLATE ARABIC_CI_AI,
		[Name]			[NVARCHAR](250) COLLATE ARABIC_CI_AI,
		[Number]		[FLOAT] )

	DECLARE @lang INT 	
	SET @lang = [dbo].[fnConnections_getLanguage]()

	IF @Type = 1
	BEGIN 
		INSERT INTO #Result
		SELECT 
			GUID,
			@ParentGUID,
			2,
			Code,
			CASE WHEN (@Lang != 0) AND (LatinName <> '') THEN LatinName ELSE [Name] END,
			Number
		FROM AddressCity000
		WHERE ParentGUID = @ParentGUID
	END ELSE 
	IF @Type = 2
	BEGIN 
		INSERT INTO #Result
		SELECT 
			GUID,
			@ParentGUID,
			3,
			Code,
			CASE WHEN (@Lang != 0) AND (LatinName <> '') THEN LatinName ELSE [Name] END,
			Number
		FROM AddressArea000
		WHERE ParentGUID = @ParentGUID
	END ELSE 
	IF @Type = 3
	BEGIN 
		WITH cte(Street)
		AS (
		SELECT DISTINCT 
			Street 
		FROM CustAddress000
		WHERE AreaGUID = @ParentGUID)

		INSERT INTO #Result
		SELECT 
			0x0,
			@ParentGUID,
			4,
			'',
			Street,
			ROW_NUMBER() OVER (ORDER BY Street)
		FROM cte
		WHERE ISNULL(Street, '') != ''

		UPDATE #Result SET Code = CAST(Number AS NVARCHAR(10))
	END

	SELECT * 
	FROM [#Result] 
	ORDER BY [Number]

	SELECT * FROM [#SecViol]
###################################################################################
#END
