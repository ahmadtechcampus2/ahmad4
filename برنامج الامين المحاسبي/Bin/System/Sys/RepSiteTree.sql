##################################################################################
CREATE PROCEDURE RepSiteTree
	@Lang		INT = 0
AS
SET NOCOUNT ON 
	CREATE TABLE #SecViol (Type INT, Cnt INT) 
	CREATE TABLE #Result( 
			Guid		UNIQUEIDENTIFIER, 
			ParentGuid 	UNIQUEIDENTIFIER, 
			Code		NVARCHAR(250) COLLATE ARABIC_CI_AI, 
			[Name]		NVARCHAR(250) COLLATE ARABIC_CI_AI, 
			[LatinName]	NVARCHAR(250) COLLATE ARABIC_CI_AI, 
			Number		FLOAT, 
			Security	INT, 
			Type 		INT,
			[Level] 	INT, 
			[Path] 		NVARCHAR(max) COLLATE ARABIC_CI_AI 
		   	) 
	 
	INSERT INTO #Result  
	SELECT  
			ana.Guid,  
			ISNull(ana.ParentGUID , 0x0) AS Parent, 
			ana.Code,  
			Ana.Name,
			Ana.LatinName,
			ana.Number, 
			ana.Security, 
			0,--ana.Type,
			fn.[Level],
			fn.Path 
		FROM 	
			vwHosSite as ana INNER JOIN dbo.fnGetSitesListSorted( 0x0, 1) AS fn 
			ON ana.Guid = fn.Guid
	EXEC prcCheckSecurity 
	SELECT * FROM #Result ORDER BY Path 
	SELECT * FROM #SecViol

/*
RepSiteTree
RepanalysisTree
*/
##################################################################################
CREATE PROC prcHosSiteOccupationRatioRep
			@SiteGuid uniqueidentifier = 0x0,
			@SiteTypeGuid uniqueidentifier = 0x0, 
			@GroupSiteGuid uniqueidentifier = 0x0, 
			@FROM DateTime = '',  
			@To DateTime = '2100' 
AS  
	SET NOCOUNT ON  
	
	DECLARE @tempDate DATETIME
	
	SET @tempDate = CAST (DATEPART(mm, GETDATE())AS NVARCHAR) + '-1-'+ 
		        CAST (DATEPART(yy, GETDATE())AS NVARCHAR)

	SET @FROM = [dbo].[IsDate1900](@From, @tempDate)
	SET @To = [dbo].[IsDate2100](@To, GETDATE())


	----------------------------
	CREATE TABLE #result
	(
		SiteGuid uniqueidentifier,
		SiteCode NVARCHAR(200) COLLATE Arabic_CI_AI,
		SiteName NVARCHAR(200) COLLATE Arabic_CI_AI,
		TypeName NVARCHAR(200) COLLATE Arabic_CI_AI,
		GroupName NVARCHAR(200) COLLATE Arabic_CI_AI,
		ResidentCount	INT DEFAULT 0,
		OccupiedCount float DEFAULT 0,
		EmptyCount INT DEFAULT 0,
		OccupationRatio Decimal(5,5) DEFAULT 0
	)		


	INSERT INTO #result(SiteGuid, SiteCode, SiteName, TypeName, GroupName)
	SELECT
		s.GUID,
		s.code,
		s.name, 
		t.name, 
		g.name
	FROM hosSite000 AS s
		INNER JOIN hosGroupSite000 AS g ON s.parentguid = g.guid
		INNER JOIN hosSiteType000 AS t ON s.typeguid = t.guid
	WHERE  
		(@SiteGuid = 0x0 OR s.Guid = @SiteGuid) 
		AND 
		(@SiteTypeGuid = 0x0 OR s.typeGuid = @SiteTypeGuid) 
		AND(@GroupSiteGuid = 0x0 OR s.parentGuid = @GroupSiteGuid) 
	----------------------------

	
	CREATE TABLE #tempTbl
	(
		SiteGuid uniqueidentifier,
		OccupiedCount float DEFAULT 0,
		ResidentCount INT DEFAULT 0
	)

	INSERT INTO #tempTbl
	select 
		SiteGuid,
		CASE 
			WHEN ([dbo].[IsDate1900](StartDate, @tempDate) <= @From) 
			     AND 
			     ([dbo].[IsDate2100](EndDate, GETDATE())BETWEEN @From AND @To)
			THEN DATEDIFF(Day, @From, [dbo].[IsDate2100](EndDate, GETDATE()))+1
			
			
			WHEN ([dbo].[IsDate2100](EndDate, GETDATE()) >= @To) 
			     AND 
			     ([dbo].[IsDate1900](StartDate, @tempDate) BETWEEN @From AND @To)
			THEN DATEDIFF(Day, [dbo].[IsDate2100](StartDate, GETDATE()),@To)+1

			
			WHEN ([dbo].[IsDate1900](StartDate, @tempDate) < @From)
 			     AND 
			     ([dbo].[IsDate2100](EndDate, GETDATE()) > @To)
			THEN DATEDIFF(Day, @From ,@To)+1				

			
			ELSE DATEDIFF(Day, [dbo].[IsDate1900](StartDate, @tempDate), 
					   [dbo].[IsDate2100](EndDate, GETDATE()))+1
		END ,
		PersonCount
	FROM hosStay000
	WHERE
		[dbo].[IsDate1900](StartDate, @tempDate) BETWEEN @From AND @To
		OR 
		[dbo].[IsDate2100](EndDate, GETDATE()) BETWEEN @From AND @To
		OR 
		@From BETWEEN  [dbo].[IsDate1900](StartDate, @tempDate) 
			   AND [dbo].[IsDate2100](EndDate, GETDATE()) 
	----------------------------	

	CREATE TABLE #tempSums
	(
		SiteGuid uniqueidentifier,
		OccupiedCounts FLOAT DEFAULT 0,
		FreeDaysCounts INT DEFAULT 0,
		ResidentCounts INT DEFAULT 0
	)
	
	INSERT INTO #tempSums (SiteGuid , OccupiedCounts , ResidentCounts)
	SELECT 
		SiteGuid,
		SUM(OccupiedCount),
		SUM(ResidentCount)
	FROM #tempTbl
	GROUP BY SiteGuid
	
	DECLARE @DesiredPeriod Float
	SET @DesiredPeriod = DATEDIFF(Day , @From, @To) + 1

	UPDATE #tempSums
		SET FreeDaysCounts = @DesiredPeriod - OccupiedCounts
	
	----------------------------
	
	UPDATE #result 
		SET OccupiedCount = OccupiedCounts 	     
		FROM #result AS r
		INNER JOIN #tempSums AS t
		ON r.SiteGuid = t.SiteGuid
	
	UPDATE #result
		SET EmptyCount = FreeDaysCounts
		FROM #result AS r
		INNER JOIN #tempSums AS t
		ON r.SiteGuid = t.SiteGuid

	UPDATE #result
		SET OccupationRatio = (CASE WHEN @DesiredPeriod= 0 THEN 0
					    ELSE  OccupiedCount /@DesiredPeriod 
				       END)

	UPDATE #result
		SET ResidentCount = ResidentCounts
		FROM #result AS r
		INNER JOIN #tempSums AS t
		ON r.SiteGuid = t.SiteGuid
		
	SELECT * FROM #result
	--SELECT * FROM HosStay000
##################################################################################
#END