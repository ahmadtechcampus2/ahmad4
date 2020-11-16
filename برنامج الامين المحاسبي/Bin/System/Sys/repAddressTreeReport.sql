#########################################################################
CREATE PROC repAddressTreeReport
AS
	SET NOCOUNT ON 

	DECLARE @lang INT 	
	SET @lang = [dbo].[fnConnections_getLanguage]()
	
	CREATE TABLE #SecViol (Type INT, Cnt INT)  
	CREATE TABLE #Result(  
			[GUID]			UNIQUEIDENTIFIER,
			[ParentGUID] 	UNIQUEIDENTIFIER,
			[Code]			NVARCHAR(250) COLLATE ARABIC_CI_AI,  
			[Name]			NVARCHAR(500) COLLATE ARABIC_CI_AI,  
			[Number]		INT,
			[Type]			INT,  -- 1: Country, 2: City, 3: Area, 4: Street
			[Level]			INT,
			[Path]			NVARCHAR(100) COLLATE ARABIC_CI_AI)

	INSERT INTO #Result
	SELECT 
		GUID,
		0X0,
		Code,
		CASE WHEN (@Lang != 0) AND (LatinName <> '') THEN LatinName ELSE [Name] END,
		Number,
		1,
		0,
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
		r.Path + CAST((ROW_NUMBER() OVER (ORDER BY aar.Number) * 0.000001) AS VARCHAR(40))
	FROM 
		AddressArea000 aar
		INNER JOIN #Result r ON r.GUID = aar.ParentGUID 

	SELECT 
		[GUID],
		[ParentGUID],
		[Code],
		[Name],
		[Type]
	FROM 
		#Result 
	ORDER BY 
		[Path],
		[Type],
		[Number]

	SELECT * FROM #SecViol 
##########################################################################
#END