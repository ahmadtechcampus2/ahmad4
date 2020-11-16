########################################################################################
CREATE proc RepHosSiteActivityProfits
	@Site UNIQUEIDENTIFIER,
	@FROM	DATETIME,
	@To	DATETIME,
	@PatientGuid UNIQUEIDENTIFIER = 0x0,
	@SiteType UNIQUEIDENTIFIER = 0x0,
	@Sort INT = 0 --  0 sitename, 1 sitecode, 2 profit , 3 filecode , 4 guestname, 5 date
	--@Hourly	INT = -1 -- check if hourly or not BY yourself
AS
SET NOCOUNT ON 
CREATE TABLE #result
	(
		Guid		UNIQUEIDENTIFIER,
		[Name]		NVARCHAR(250) COLLATE ARABIC_CI_AI,
		Code		NVARCHAR(250) COLLATE ARABIC_CI_AI,
		FromDate 	DATETIME,	
		ToDate		DATETIME,
		Profits		FLOAT,
		[level]		INT   -- 0 sitetype , 1 site, 2 stay	
	)

CREATE TABLE #Finalresult
	(
		Guid		UNIQUEIDENTIFIER,
		[Name]		NVARCHAR(250) COLLATE ARABIC_CI_AI,
		Code		NVARCHAR(250) COLLATE ARABIC_CI_AI,
		FromDate 	DATETIME,	
		ToDate		DATETIME,
		Profits		FLOAT,
		[level]		INT   -- 0 sitetype , 1 site, 2 stay	
	)
	
	CREATE TABLE #tree
	(GUID UNIQUEIDENTIFIER, [Level] INT, [Path] NVARCHAR(max), ID INT IDENTITY( 1, 1)) 
	
	DECLARE @RootGuid UNIQUEIDENTIFIER
	SET @RootGuid = newid()
	
	INSERT INTO #tree(Guid, [Level])	
	VALUES(@RootGuid, -1)
	
	INSERT INTO #tree(Guid, [Level])	
	SELECT 	
		type.Guid,
		0
			
	FROM	VwhosSiteType  AS type	
	WHERE (@SiteType = 0x0 OR Guid = @SiteType)
	ORDER BY
		CASE @Sort 
		WHEN 0 THEN type.[name]
		ELSE type.Code
		END 	


	UPDATE #tree SET [Path] = CAST( ( 0.0000001 * ID) AS NVARCHAR(40))

	INSERT INTO #tree(Guid, [Level], path)	
	SELECT 	
		site.Guid,
		1,
		type.path

	FROM	VwhosSite  AS site	
	INNER JOIN #tree AS type ON type.guid = site.typeguid	
	WHERE (@Site = 0x0 OR @Site = site.Guid)
	ORDER BY
		CASE @Sort 
		WHEN 1 THEN site.Code 
		ELSE site.[Name] 
		END 	
	
	UPDATE #tree  SET [Path] = [Path] + CAST( ( 0.0000001 * ID) AS NVARCHAR(40))  WHERE [Level] = 1      
	

	DECLARE @stayGuid	UNIQUEIDENTIFIER,
		@siteGuid		UNIQUEIDENTIFIER,
		@IntersectFrom 	DATETIME,
		@IntersectTo 	DATETIME,
		@stayFrom 		DATETIME,
		@stayTo			DATETIME,
		@AllCost		FLOAT,	
		@Code			NVARCHAR(200),
		@Name			NVARCHAR(200),
		@SiteName 		NVARCHAR(200),
		@SiteCode		NVARCHAR(200),
		@Total			FLOAT


	DECLARE C CURSOR FOR  
	SELECT  
		site.guid,
		s.guid,
		s.startdate,
		s.enddate,
		ce.credit,
		f.[name],		
		f.code
		FROM vwHosFile AS f
		INNER JOIN hosstay000 AS s ON s.FileGuid = f.Guid
		INNER JOIN HosSite000 AS site ON site.guid = s.siteguid
		INNER JOIN ce000 AS ce ON ce.guid = s.entryguid
	WHERE 
		--site.guid = @site
		--AND
		(
			s.StartDate BETWEEN @FROM AND @To
			OR
			s.EndDate BETWEEN @FROM	AND @To	 	
			OR
			@FROM BETWEEN  s.StartDate AND s.EndDate
		)
		AND
		(@SiteType = 0x0 OR site.TypeGuid = @SiteType)
		AND
		(@Site = 0x0 OR @Site = site.Guid)
		AND(@PatientGuid = 0x0 OR @PatientGuid = f.PatientGuid)

	ORDER BY site.name, Site.Code, s.startdate	

	OPEN	C
	FETCH NEXT FROM C
	INTO  
		@siteGuid,
		@stayGuid,
		--@SiteName,
		--@SiteCode,
		@stayFrom,
		@stayTo,
		@AllCost,
		@Name,
		@Code
		 
	WHILE (@@FETCH_STATUS = 0) 
	BEGIN 
									
		if (@FROM < @stayFrom)
			SET @IntersectFrom = @stayfrom
		ELSE
			SET @IntersectFrom = @FROM
	
		if (@to < @stayto)
			SET @IntersectTo = @to
		ELSE
			SET @IntersectTo = @stayto
			
		DECLARE @num FLOAT, @minutes FLOAT, @Intersect_Minutes FLOAT
		SET @minutes = DATEDIFF(mi, @stayFrom, @stayTo) + 1 -- add one minutes
		SET @Intersect_Minutes = DATEDIFF(mi, @IntersectFrom, @IntersectTo) + 1 -- add one minutes
		
		SELECT @Total = (@Intersect_Minutes / @minutes) * @AllCost
		
		INSERT INTO #result(Guid, [Name], Code, FromDate, ToDate, Profits, [level])
		VALUES(@StayGuid, @Name, @Code, @stayFrom, @stayto, @Total, 2) 
		
		INSERT INTO #tree(Guid, [Level], path)	
		SELECT 	
			@stayGuid,
			2,
			site.path
		FROM #tree AS site 
		INNER JOIN vwhosstay AS stay ON stay.siteguid = site.guid
		WHERE	stay.StayGuid = @stayGuid 

		FETCH NEXT FROM C	 
		INTO  
			@siteGuid,
			@stayGuid,
			@stayFrom,
			@stayTo,
			@AllCost,
			@Name,
			@Code

	End 
	CLOSE C
	DEALLOCATE C   
	UPDATE #tree  SET [Path] = [Path] + CAST( ( 0.0000001 * ID) AS NVARCHAR(40))  WHERE [Level] = 2      

	SELECT
		site.guid,site.[name], site.code,Sum(r.profits) AS SiteProfits
	INTO #siteTemp
	FROM #result AS r
	INNER JOIN vwhosstay AS stay ON stay.stayguid =  r.guid	
	INNER JOIN vwhossite AS site ON site.guid = stay.siteguid
	GROUP BY site.guid, site.[name], site.code

	SELECT
		type.guid, type.[name], type.code, Sum(SiteProfits) AS TypeProfits
	INTO #typeTemp
	FROM #siteTemp AS t
	INNER JOIN vwHossite AS site  ON	site.guid = t.guid
	INNER JOIN vwHosSiteType AS type ON type.guid = site.TypeGuid    	
	GROUP BY Type.Guid, type.[name], type.code

	INSERT #result(Guid, [Name], Code, FromDate, Profits, [level])	
	SELECT 
		Guid, [Name], Code, '', SiteProfits, 1  
	FROM 
	#siteTemp

	INSERT #result(Guid, [Name], Code, FromDate, Profits, [level])	
	SELECT 
		Guid, [Name], Code, '', TypeProfits, 0 
	FROM 
	#typeTemp
	
	--SELECT * FROM #result
	--SELECT * FROM #tree ORDER BY path
	DECLARE @sumProfits FLOAT
	SELECT 
		@sumProfits = Sum(TypeProfits)
	FROM 
		#typeTemp
	INSERT #result(Guid, Profits, [level])	
	SELECT 
		@RootGuid, @sumProfits, -1
	FROM 
	#typeTemp
	
	INSERT INTO #FinalResult 
	SELECT  r.* 
	FROM #result AS r
	INNER JOIN #tree AS t ON t.guid = r.guid 
	ORDER BY t.path

	if (@Sort = 0 OR @Sort = 1)
		SELECT * FROM  #Finalresult 
	/*
	ELSE
	if (@Sort = 2)
		SELECT * FROM  #Finalresult	
		ORDER BY  [level], FromDate
	ELSE
	if (@Sort = 2)
		SELECT * FROM  #result	
		ORDER BY FromDate

	if (@Sort = 3)
		SELECT * FROM  #result	
		ORDER BY FromDate

	if (@Sort = 4)
		SELECT * FROM  #result	
		ORDER BY FromDate

	if (@Sort = 5)
		SELECT * FROM  #result	
		ORDER BY FromDate

	*/

########################################################################################
#END
