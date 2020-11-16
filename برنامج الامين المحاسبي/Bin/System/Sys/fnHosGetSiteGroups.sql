######################################################
CREATE  FUNCTION fnHosGetAllSiteGroups( @Group [UNIQUEIDENTIFIER] , @Sorted [INT] = 0)  
	RETURNS @Result TABLE
	([GUID] [UNIQUEIDENTIFIER], [Level] [INT] DEFAULT 0, [Path] [NVARCHAR](max) COLLATE ARABIC_CI_AI, [Type] [INT] DEFAULT 0)  
AS   
BEGIN   
	DECLARE @FatherBuf TABLE
	([GUID] [UNIQUEIDENTIFIER], [Level] [INT], [Path] [NVARCHAR](max) COLLATE ARABIC_CI_AI, [TYPE] [INT] DEFAULT 0, [ID] [INT] IDENTITY( 1, 1)) 
	DECLARE @Continue [INT], @Level [INT]  
	SET @Level = 0   
	 
	SET @Group = ISNULL(@Group, 0x0)   
	IF @Group = 0x0 
	BEGIN
		INSERT INTO @FatherBuf ([GUID], [Level], [Path])  
			SELECT GUID, @Level, ''  FROM [HosGroupSite000] AS
			[gr] WHERE [ParentGuid] = 0x0 ORDER BY CASE @Sorted WHEN 1 THEN [Code] WHEN 2 THEN [Name] ELSE [LatinName] END 
	
		DECLARE @NonGroupdeSites TABLE ([GUID] [UNIQUEIDENTIFIER])

		INSERT INTO @NonGroupdeSites
		SELECT 
			S.GUID 
		FROM
			vwHosSite AS S
			LEFT JOIN HosGroupSite000 AS Gr ON S.ParentGuid = Gr.Guid
			WHERE Gr.GUID IS NULL
		
		IF exists (SELECT * FROM @NonGroupdeSites)
			INSERT INTO @FatherBuf ([GUID], [Level], [Path], [TYPE])  
			VALUES(0X0, 0, '',-1) -- NON GroupedSites NODE
		--select count(*) from vwhossite
		UPDATE @FatherBuf  SET [Path] = CAST( ( 0.0000001 * [ID]) AS [NVARCHAR](40))   		

		IF exists (SELECT * FROM @NonGroupdeSites)
		BEGIN
			DECLARE @ParentPath [NVARCHAR](max) 
			SELECT @ParentPath = PATH FROM @FatherBuf  WHERE [TYPE] = -1

			INSERT INTO @FatherBuf ([GUID], [Level], [Path], [TYPE])  
				SELECT [n].[GUID], 1, @ParentPath,1
				FROM @NonGroupdeSites AS n
				INNER JOIN VwHosSite AS s ON s.GUID = n.GUID				
				ORDER BY CASE @Sorted WHEN 1 THEN s.[Code] WHEN 2 THEN s.[Name] ELSE s.[LatinName] END 
		END
	END
	ELSE   
	BEGIN
		INSERT INTO @FatherBuf  ([GUID], [Level], [Path])  
			SELECT [GUID], @Level, '' FROM [HosGroupSite000] AS [gr] WHERE [GUID] = @Group
			 ORDER BY CASE @Sorted WHEN 1 THEN [Code] WHEN 2 THEN [Name] ELSE [LatinName] END 
		UPDATE @FatherBuf  SET [Path] = CAST( ( 0.0000001 * [ID]) AS [NVARCHAR](40))   		
	END

	SET @Continue = 1
	---///////////////////////////////////////////////////////////// 
	WHILE @Continue <> 0   
	BEGIN 
		SET @Level = @Level + 1   
		INSERT INTO @FatherBuf([GUID], [Level], [Path]) 
			SELECT [gr].[GUID], @Level, [fb].[Path] 
			FROM [HosGroupSite000] AS [gr] INNER JOIN @FatherBuf AS [fb] 
				ON [gr].[ParentGuid] = [fb].[GUID] AND [fb].[TYPE] <> -1
			WHERE [fb].[Level] = @Level - 1
			ORDER BY CASE @Sorted WHEN 1 THEN [Code] WHEN 2 THEN [Name] ELSE [LatinName] END 

		SET @Continue = @@ROWCOUNT   
		UPDATE @FatherBuf  SET [Path] = [Path] + CAST( ( 0.0000001 * [ID]) AS [NVARCHAR](40))  
			WHERE [Level] = @Level   AND [TYPE] = 0
	END   

	---/////////////////////////////////////////////////////////////	 
	INSERT INTO @FatherBuf ([GUID], [Level], [Path], [TYPE])  
	SELECT 
		[Site].[GUID], 
		[fb].[Level] + 1, 
		[fb].[Path],
		1
	FROM 	 
		vwHosSite AS Site 
		INNER JOIN [HosGroupSite000] AS Gr ON Site.ParentGuid = Gr.Guid
		INNER JOIN @FatherBuf AS [fb] ON [gr].[Guid] = [fb].[GUID]

	UPDATE 	@FatherBuf  
		SET [Path] =  [PATH] + CAST( ( 0.0000001 * [ID]) AS [NVARCHAR](40))
	WHERE [TYPE] = 1
	
	INSERT INTO @Result 
	SELECT [GUID], [Level], [Path], [TYPE] 
	FROM @FatherBuf GROUP BY [GUID], [Level], [Path],[TYPE] ORDER BY [Path]
	--DECLARE @LAST_PARENTID INT
	--SELECT @LAST_PARENTID = MAX([ID]) FROM @FatherBuf
RETURN  
END 
######################################################
Create FUNCTION fnHosGetSiteGroupsOfGroupSorted( @Group [UNIQUEIDENTIFIER] , @Sorted [INT] = 0)  
	RETURNS @Result TABLE
	([GUID] [UNIQUEIDENTIFIER], [Level] [INT] DEFAULT 0, [Path] [NVARCHAR](max) COLLATE ARABIC_CI_AI, [Type] [INT] DEFAULT 0)  
AS   
BEGIN   
	DECLARE @FatherBuf TABLE
	([GUID] [UNIQUEIDENTIFIER], [Level] [INT], [Path] [NVARCHAR](max) COLLATE ARABIC_CI_AI, [ID] [INT] IDENTITY( 1, 1)) 
	DECLARE @Continue [INT], @Level [INT]  
	SET @Level = 0   
	 
	SET @Group = ISNULL(@Group, 0x0)   
	IF @Group = 0x0 
		INSERT INTO @FatherBuf ([GUID], [Level], [Path])  
			SELECT GUID, @Level, ''  FROM [HosGroupSite000] AS
			[gr] WHERE [ParentGuid] = 0x0 ORDER BY CASE @Sorted WHEN 1 THEN [Code] WHEN 2 THEN [Name] ELSE [LatinName] END 
	ELSE   
		INSERT INTO @FatherBuf  ([GUID], [Level], [Path])  
			SELECT [GUID], @Level, '' FROM [HosGroupSite000] AS [gr] WHERE [GUID] = @Group
			 ORDER BY CASE @Sorted WHEN 1 THEN [Code] WHEN 2 THEN [Name] ELSE [LatinName] END 
	 
	UPDATE @FatherBuf  SET [Path] = CAST( ( 0.0000001 * [ID]) AS [NVARCHAR](40))   
	SET @Continue = 1 
	---///////////////////////////////////////////////////////////// 
	WHILE @Continue <> 0   
	BEGIN 
		SET @Level = @Level + 1   
		INSERT INTO @FatherBuf( [GUID], [Level], [Path]) 
			SELECT [gr].[GUID], @Level, [fb].[Path] 
			FROM [HosGroupSite000] AS [gr] INNER JOIN @FatherBuf AS [fb] ON [gr].[ParentGuid] = [fb].[GUID]
			WHERE [fb].[Level] = @Level - 1
			ORDER BY CASE @Sorted WHEN 1 THEN [Code] WHEN 2 THEN [Name] ELSE [LatinName] END 

		SET @Continue = @@ROWCOUNT   
		UPDATE @FatherBuf  SET [Path] = [Path] + CAST( ( 0.0000001 * [ID]) AS [NVARCHAR](40))  WHERE [Level] = @Level   
	END   
	INSERT INTO @Result SELECT [GUID], [Level], [Path], 0 FROM @FatherBuf GROUP BY [GUID], [Level], [Path] ORDER BY [Path]
	---/////////////////////////////////////////////////////////////	 
RETURN  
END 
######################################################
CREATE FUNCTION fnHosGetSiteGroups( @Group [UNIQUEIDENTIFIER])  
	RETURNS @Result TABLE
	([GUID] [UNIQUEIDENTIFIER], [Level] [INT])
AS   
BEGIN   
	DECLARE @Continue [INT], @Level [INT]  
	SET @Level = 0   
	 
	SET @Group = ISNULL(@Group, 0x0)   
	IF @Group = 0x0 
		INSERT INTO @Result ([GUID], [Level])  
			SELECT GUID, @Level  FROM [HosGroupSite000] AS
			[gr] WHERE [ParentGuid] = 0x0 
	ELSE   
		INSERT INTO @Result  ([GUID], [Level])  
			SELECT [GUID], @Level FROM [HosGroupSite000] AS [gr] WHERE [GUID] = @Group
	 
	SET @Continue = 1 
	---///////////////////////////////////////////////////////////// 
	WHILE @Continue <> 0   
	BEGIN 
		SET @Level = @Level + 1   
		INSERT INTO @Result( [GUID], [Level]) 
			SELECT [gr].[GUID], @Level 
			FROM [HosGroupSite000] AS [gr] 
			INNER JOIN @Result AS [fb] ON [gr].[ParentGuid] = [fb].[GUID]
			WHERE [fb].[Level] = @Level - 1

		SET @Continue = @@ROWCOUNT   
	END   
	---/////////////////////////////////////////////////////////////	 
RETURN  
END 
######################################################
CREATE FUNCTION fnHosGetSitesOfSiteGroups( @GroupSite [UNIQUEIDENTIFIER])  
	RETURNS @Result TABLE
	([GUID] [UNIQUEIDENTIFIER])
AS   
BEGIN   
	IF Exists (SELECT * FROM HosSite000 WHERE guid =  @GroupSite)
	BEGIN
		INSERT INTO @Result VALUES (@GroupSite)
		RETURN 
	END	
	ELSE
	BEGIN		
		DECLARE @Groups TABLE ([GUID] [UNIQUEIDENTIFIER])
		INSERT INTO @Groups
			SELECT GUID FROM fnHosGetSiteGroups(@GroupSite)

		INSERT INTO @Result
		SELECT 
			S.Guid
		FROM 
			HosSite000 AS S
			INNER JOIN @Groups as G ON G.Guid = S.ParentGuid
	END	
RETURN  
END
###################################################### 
#END