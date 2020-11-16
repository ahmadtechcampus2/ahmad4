######################################################
CREATE PROCEDURE HosRepSiteTree
	@Lang		INT = 0					-- Language	(0=Arabic; 1=English)

AS
	SET NOCOUNT ON
	
	CREATE TABLE [#SecViol] ([Type] [INT], [Cnt] [INT])
	CREATE TABLE [#Result](
			[Guid]		[UNIQUEIDENTIFIER],
			[ParentGuid] 	[UNIQUEIDENTIFIER],
			[Code]		[NVARCHAR](250) COLLATE ARABIC_CI_AI,
			[Name]		[NVARCHAR](250) COLLATE ARABIC_CI_AI,
			[TypeName]	[NVARCHAR](250) COLLATE ARABIC_CI_AI,
			[Number]	[FLOAT],
			[Security] 	[INT],
			[TYPE] 		[INT],
			[Level] 	[INT],
			[Path] 		[NVARCHAR](max) COLLATE ARABIC_CI_AI)
	
	DECLARE  @HosGroups TABLE
	([GUID] [UNIQUEIDENTIFIER], [Level] [INT] DEFAULT 0, [Path] [NVARCHAR](max) COLLATE ARABIC_CI_AI, [Type] [INT] DEFAULT 0)  

	INSERT INTO @HosGroups
		SELECT * FROM [dbo].[fnHosGetAllSiteGroups]( 0x0, 1) 	
	
	INSERT INTO [#Result] 
	SELECT 
			[gr].[Guid], 
			ISNULL([gr].[ParentGuid], 0x0) ,
			[gr].[Code], 
			CASE WHEN (@Lang = 1)AND([gr].[LatinName] <> '') THEN  [gr].[LatinName] ELSE [gr].[Name] END AS [Name],
			'',
			[gr].[Number],
			[gr].[Security],
			[fn].[TYPE],
			[fn].[Level],
			[fn].[Path]
		FROM
			[HosGroupSite000] as [gr] INNER JOIN @HosGroups AS [fn]
			ON [gr].[Guid] = [fn].[Guid]

	IF EXISTS (SELECT * FROM @HosGroups WHERE TYPE = -1)

	INSERT INTO [#Result] 
	SELECT 
			0X0, 
			0X0,
			'Non Grouped Sites', 
			'Non Grouped Sites', 
			'',
			0,
			1,
			[fn].[TYPE],
			[fn].[LEVEL],
			[fn].[Path]
	FROM	@HosGroups AS fn WHERE TYPE = -1

		
	INSERT INTO [#Result] 
	SELECT 
			[s].[Guid], 
			ISNULL([s].[ParentGuid], 0x0),
			[s].[Code], 
			CASE WHEN (@Lang = 1)AND([s].[LatinName] <> '') THEN  [s].[LatinName] ELSE [s].[Name] END AS [Name],
			CASE WHEN (@Lang = 1)AND([t].[LatinName] <> '') THEN  [t].[LatinName] ELSE [t].[Name] END AS [Name],
			[s].[Number],
			[s].[Security],
			[fn].[TYPE],
			[fn].[Level],
			[fn].[Path]
		FROM
			[VwHosSite] as [s] 
			INNER JOIN @HosGroups AS [fn]	ON [s].[Guid] = [fn].[Guid]
			INNER JOIN VwHosSiteType AS [t] ON [t].GUID = [s].[TypeGuid]

	EXEC [prcCheckSecurity]
	SELECT * FROM [#Result] ORDER BY [Path]
	SELECT * FROM [#SecViol]
######################################################
CREATE  PROCEDURE HosrepGetSiteList
	@Lang		INT = 0,					-- Language	(0=Arabic; 1=English)
	@Group		[UNIQUEIDENTIFIER] = NULL
AS

	SET NOCOUNT ON
		
	CREATE TABLE [#SecViol] ([Type] [INT], [Cnt] [INT])
	CREATE TABLE [#Result]
			(
				[Guid]		[UNIQUEIDENTIFIER],
				[GroupGuid] 	[UNIQUEIDENTIFIER],
				[Code]		[NVARCHAR](250) COLLATE ARABIC_CI_AI,
				[Name]		[NVARCHAR](250) COLLATE ARABIC_CI_AI,
				[TypeName]	[NVARCHAR](250) COLLATE ARABIC_CI_AI,
				[Number]		[FLOAT],
				[Type]		[INT],
				[SiteSecurity] [INT],
			)

	DECLARE @FathersGroups TABLE
	([GUID] [UNIQUEIDENTIFIER], [Path] [NVARCHAR](max) COLLATE ARABIC_CI_AI)
	
	INSERT INTO @FathersGroups
	SELECT GUID,PATH FROM dbo.fnHosGetSiteGroupsOfGroupSorted(@Group, 1) 

	INSERT INTO [#Result] 
	SELECT 
			[Site].[Guid], 
			[Site].[ParentGuid],
			[Site].[Code], 
			CASE WHEN (@Lang = 1)AND([Site].[LatinName] <> '') THEN  [Site].[LatinName] ELSE [Site].[Name] END AS [Name],
			CASE WHEN (@Lang = 1)AND([Type].[LatinName] <> '') THEN  [Type].[LatinName] ELSE [Type].[Name] END AS [Name],
			[Site].[Number],
			1,
			[Site].[Security]
	FROM
			[vwHosSite] as [Site]
			INNER JOIN @FathersGroups AS gr ON gr.GUID = [Site].[ParentGuid]
			INNER JOIN vwHosSiteType AS type ON [type].GUID = [site].[TypeGuid]

	SELECT 
		Res.* 
	FROM 
		[#Result] AS Res 
		INNER JOIN @FathersGroups AS gr ON gr.GUID = [Res].[GroupGuid]
		ORDER BY gr.path,Res.code

	SELECT * FROM [#SecViol]
######################################################
CREATE PROC prcHosTreeGetPatientSiteList
	@GroupSiteGuid UNIQUEIDENTIFIER,
	@StartDate DATETIME = '',
	@EndDate DATETIME = '2100',
	@DuringMonth INT = 0
AS 
	SET NOCOUNT ON

	CREATE TABLE #Sites (Guid UNIQUEIDENTIFIER, Name NVARCHAR(250) COLLATE ARABIC_CI_AI)

	IF EXISTS (SELECT * FROM HosSite000 WHERE GUID = @GroupSiteGuid)
		INSERT INTO #Sites
		SELECT
			[Guid],
			''
		FROM HosSite000 WHERE GUID = @GroupSiteGuid
	ELSE
		INSERT INTO #Sites
		SELECT 
			fn.[Guid],
			s.[Name]
		FROM 
			fnHosGetAllSiteGroups(@GroupSiteGuid, 0) AS fn
			INNER JOIN HosSite000 AS S ON S.GUID =  fn.Guid
		WHERE TYPE = 1


	CREATE TABLE #Res
		(Guid UNIQUEIDENTIFIER, [Name] NVARCHAR(250) COLLATE ARABIC_CI_AI,
		[Code] NVARCHAR(250) COLLATE ARABIC_CI_AI, SiteName NVARCHAR(250) COLLATE ARABIC_CI_AI)

	INSERT INTO #Res (Guid, [Name], [Code], SiteName)
	SELECT 
		f.[GUID],
		f.[NAME],	
		f.[Code],
		Site.[Name]	
	FROM 
		VwHosFile AS f
		INNER JOIN vwhosstay AS stay ON stay.StayFileGuid = F.Guid
		INNER JOIN #SITES AS Site ON Site.Guid = Stay.StaySiteGuid
		
	WHERE 
		stayStartDate BETWEEN @StartDate AND @EndDate 
		OR
		stayEndDate BETWEEN @StartDate AND @EndDate 
		OR 
		(
			DATEPART (YEAR, stayEndDate) < 2050 
			AND @StartDate BETWEEN stayStartDate AND stayEndDate
		)
		OR
		(
			DATEPART (YEAR,DATEOUT) >= 2050 
			AND @StartDate > stayStartDate
			AND @EndDate < stayEndDate
			AND DATEDIFF(MONTH, stayStartDate, @StartDate) <= @DuringMonth
		)

	SELECT 
		GUID,
		[NAME],
		[Code],
		SiteName AS TypeName
	FROM #Res 
		
	CREATE TABLE [#SecViol] ([Type] [INT], [Cnt] [INT])
	SELECT * FROM [#SecViol]
###############################################
#END