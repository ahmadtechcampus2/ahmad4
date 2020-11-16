################################################################################
CREATE FUNCTION fnMatreialSegmentRecode ( @CompositionGuid UNIQUEIDENTIFIER )
		RETURNS NVARCHAR(MAX)
	AS 
	BEGIN
		DECLARE @Code Varchar(MAX);
		SELECT @Code = COALESCE(@Code + '-' + SE.Code, SE.Code) 
		FROM 
			MaterialElements000 ME
			INNER JOIN mt000  MT ON MT.GUID = ME.MaterialId
			INNER JOIN SegmentElements000 SE  ON SE.Id = ME.ElementId
		WHERE
			MT.GUID = @CompositionGuid
		ORDER BY
			[Order]
		RETURN @Code
	END 	
################################################################################
CREATE FUNCTION fnRepeatZero ( @i INT )
		RETURNS NVARCHAR(100)
	AS 
	BEGIN
		IF (@i <= 0)
			RETURN ''
		DECLARE @ii INT, @str NVARCHAR(100)
		SET @ii = 0
		SET @str = ''
		WHILE (@ii < @i)
		BEGIN
			SET @STR = @STR + '0'
			SET @ii = @ii + 1
		END
		RETURN @STR
	END
################################################################################
CREATE PROCEDURE repMatTree
	@Lang		INT = 0					-- Language	(0=Arabic; 1=English)

AS
	SET NOCOUNT ON

	CREATE TABLE [#SecViol] ([Type] [INT], [Cnt] [INT])
	CREATE TABLE [#Result](
			[Guid]			[UNIQUEIDENTIFIER],
			[ParentGuid] 	[UNIQUEIDENTIFIER],
			[Code]			[NVARCHAR](250) COLLATE ARABIC_CI_AI,
			[Name]			[NVARCHAR](500) COLLATE ARABIC_CI_AI,
			[Number]		[FLOAT],
			[GroupSecurity] [INT],
			[Level]			[INT],
			[Path] 			[NVARCHAR](max) COLLATE ARABIC_CI_AI,
			Type			INT,  -- 0 Group , 1 MatHasSegment 
			[MatSecurity]	INT,
			Kind			INT)
	CREATE TABLE #Gr( Guid UNIQUEIDENTIFIER, Path NVARCHAR(max), [Level] INT)
	INSERT INTO #Gr SELECT Guid, Path, Level FROM dbo.fnGetGroupsOfGroupSorted( 0x0, 1) AS fn

	INSERT INTO [#Result] 
	SELECT 
			[gr].[grGuid], 
			CASE WHEN [gr].[grParent] IS Null then 0x0 ELSE [gr].[grParent] END AS [Parent],
			[gr].[grCode], 
			CASE WHEN (@Lang = 1)AND([gr].[grLatinName] <> '') THEN  [gr].[grLatinName] ELSE [gr].[grName] END AS [grName],
			[gr].[grNumber],
			[gr].[grSecurity],
			[fn].[Level],
			[fn].[Path],
			0, -- Group
			0,
			[gr].[grKind]
		FROM
			[vwgr] as [gr] INNER JOIN #Gr AS [fn]
			ON [gr].[grGuid] = [fn].[Guid]
	
	INSERT INTO #Result 
		SELECT  
			[mtGUID], 
			[mtGroup],
			[mtCode], 
			CASE WHEN (@Lang = 1)AND([mt].[mtLatinName] <> '') THEN  [mt].[mtLatinName] ELSE [mt].[mtName] END AS mtName,
			[mtNumber],
			0,
			[gr].[Level] + 1,
			[gr].[Path],
			1, -- Mat has segment
			[mt].[mtSecurity],
			0
		FROM 
			[vwmt] as [mt]
			INNER JOIN #Gr AS gr ON [mt].[mtGroup] = [gr].[Guid]
			WHERE [mt].[mtHasSegments] = 1

	EXEC [prcCheckSecurity]
	SELECT * FROM [#Result] ORDER BY [Path], [Type]
	SELECT * FROM [#SecViol]
###################################################################################
CREATE PROC PrcReorderMatsCodes 
	@grpGuid UNIQUEIDENTIFIER,  
	@grpCode NVARCHAR(100),  
	@chNum int = 0,             -----------ÚÏÏ ãÍÇÑÝ ÇáÊÑãíÒ  
	@prefix NVARCHAR(100) = '',  -----------ÇáÈÇÏÆÉ  
	@Indexing_Choice int =0,
	@SortSubGroups bit = 1  
AS   
	SET NOCOUNT ON  
	DECLARE @Count INT  
	SELECT @Count = COUNT(*) FROM mt000 WHERE GroupGuid = @grpGuid  AND Parent = 0X0
	SET @Count = LEN(LTRIM(@Count))  
	CREATE TABLE #t(id INT IDENTITY(1,1), guid UNIQUEIDENTIFIER, Code NVARCHAR(250) COLLATE ARABIC_CI_AI, gROUPgUID UNIQUEIDENTIFIER, [lEVEL] INT default 2, TYPE BIT)   
	INSERT INTO #t(guid,TYPE) 
	SELECT Guid,CASE WHEN parent = 0x0 THEN 0 ELSE 3 END-- 3-> IS MatSegment 
	FROM mt000 
	WHERE
		 GroupGuid = @grpGuid 
	ORDER BY 
		Case 
			WHEN @Indexing_Choice =0 THEN number   	
		END
		,
		Case 
			WHEN @Indexing_Choice =1 THEN name   	
		END
	CREATE TABLE #MAXMIN([COUNT] INT ,Minmum INT,GUID UNIQUEIDENTIFIER,CODE NVARCHAR(100),type tinyint)   
	DECLARE @Minmum int,@Groupcount int   
	  
	IF (@SortSubGroups = 1)  
	BEGIN  
		INSERT INTO #t(guid,TYPE)   
		SELECT Guid,1 
		FROM GR000 
		WHERE
			PARENTGuid = @grpGuid 
		ORDER BY 
			Case 
				WHEN @Indexing_Choice =0 THEN number   	
			END
			,
			Case 
				WHEN @Indexing_Choice =1 THEN name   	
			END
		  
		SELECT @Groupcount = count(*)  FROM #t WHERE TYPE = 0  
		SELECT @Minmum =  MIN(id) - 1  FROM #t WHERE TYPE = 1  
	END  
	SELECT @Count = COUNT(*) FROM mt000 WHERE GroupGuid = @grpGuid AND Parent = 0X0
	  
	IF (@SortSubGroups = 1)  
		SET @COUNT = @COUNT + (SELECT COUNT(*) FROM GR000 WHERE PARENTGuid = @grpGuid)  
	 
	SET @COUNT = len(cast(@COUNT AS NVARCHAR(100)))  
	 
	SET @Groupcount = len(cast(@Groupcount AS NVARCHAR(100)))  
	IF ( @Groupcount < @chNum)    --ÅÐÇ ßÇä ÚÏÏ ÇáÑãæÒ ÇáãÏÎá ãä ÇáãÓÊÎÏã ÃßÈÑ ãä ÇáÅÝÊÑÇÖí   
	   SET @Groupcount = @chNum  
	
	UPDATE #T  SET    
	Code = CASE @prefix WHEN '' THEN @grpCode ELSE @prefix  END  +   
	 --DBO.fnRepeatZero((case #T.type when 0 then @Groupcount else @COUNTend)- len(cast((id - case type when 0 then 0 else @Minmum end))))  
	DBO.fnRepeatZero((CASE TYPE WHEN 0 THEN @Groupcount ELSE @COUNT END) - len(id))+ 
	cast(id  AS NVARCHAR(100))   
	--code = @grpCode + DBO.fnRepeatZero((@Groupcount -  case type when 0 then 0 else @Groupcount end ) - len(cast((id - case type when 0 then 0 else @Minmum end)   as NVARCHAR(100))))   
	--+ cast((id - case type when 0 then 0 else @Minmum end) as NVARCHAR(100))   
	  	 	
	DECLARE @LEVEL INT, @MAXLEVEL INT	 
	IF (@SortSubGroups = 1)  
	BEGIN  
		SET @LEVEL = 2  
		SELECT A.GUID, A.[LEVEL], 1 AS TYPE, Parentguid GroupGuid  
		INTO #GRP   
		FROM dbo.fnGetGroupsListByLevel(@GrpGuid, 0) A  
		INNER JOIN GR000 G ON G.GUID = A.GUID   
		  
		SELECT @MAXLEVEL = MAX([LEVEL]) FROM #GRP	  
		INSERT INTO #GRP   
		SELECT M.GUID, [LEVEL] + 1 , 0, A.GUID   
		FROM MT000 M   
		INNER JOIN #GRP A ON M.GROUPGUID = A.GUID  
		WHILE @LEVEL <= @MAXLEVEL  
		BEGIN  
			INSERT INTO #t(guid, GROUPGUID, LEVEL, TYPE)   
			SELECT M.GUID, A.GUID, a.[LEVEL] + 1 , M.TYPE   
			FROM #GRP M INNER JOIN #GRP A ON M.GROUPGUID = A.GUID   
			WHERE A.LEVEL = @LEVEL  AND A.TYPE = 1  
			ORDER BY A.GUID  
 		  
			INSERT INTO #MAXMIN   
			SELECT COUNT(*), MIN(T.ID), Tp.GUID, TP.CODE,t.type    
			FROM #t T INNER JOIN #t TP ON T.GROUPGUID = TP.GUID   
			WHERE TP.LEVEL = @LEVEL   
			GROUP BY Tp.GUID, TP.CODE,t.type     
			UPDATE t SET   
			--CODE = M.cODE + DBO.fnRepeatZero(len(cast (M.COUNT as NVARCHAR(100))) - len(cast((T.id + 1 - M.Minmum) as NVARCHAR(100)))) + cast((T.id +1 - M.Minmum) as NVARCHAR(100))   
			CODE = M.cODE +  
			--DBO.fnRepeatZero(case t.type when 0 then @Groupcount-1 else @COUNT-1 end) 
			DBO.fnRepeatZero(CASE  T.type WHEN 0 THEN CASE WHEN @Groupcount >= len(cast (M.COUNT AS NVARCHAR(100))) THEN  @Groupcount else len(cast (M.COUNT as NVARCHAR(100))) end  else len(cast (M.COUNT as NVARCHAR(100)))end - len(cast((T.id + 1 - M.Minmum) as NVARCHAR(100)))) 
			 + cast((T.id +1 - M.Minmum) AS NVARCHAR(100))   
			FROM  #t T   
			INNER JOIN #MAXMIN M ON T.GroupGUID = M.GUID and t.type  = m.type  
			WHERE T.LEVEL = @LEVEL + 1  
			DELETE #MAXMIN  
			SET @LEVEL = @LEVEL + 1  
		END  
	END  
	DECLARE @STR NVARCHAR(10)   
	SET @STR = ''  
	-- English  
	IF ([dbo].[fnConnections_GetLanguage]() = 1)   
		SET @STR = ' Duplicated'  
	-- French  
	ELSE IF ([dbo].[fnConnections_GetLanguage]() = 2)   
		SET @STR = ' Répété'  
	-- Portuges  
	ELSE IF ([dbo].[fnConnections_GetLanguage]() = 7)   
		SET @STR = ' Repetido'  
	ELSE  
		SET @STR = 'ãßÑÑ '  
				  
	UPDATE A SET 	  
	a.CODE = a.CODE + @STR  
	FROM #T A   
	INNER JOIN MT000 M ON A.CODE = M.CODE   
	WHERE A.TYPE = 0   
	AND A.GUID <> M.GUID AND M.GroupGUID <> A.GroupGUID  
	BEGIN TRAN  
	-- if log file is used must be recorded in logfile  
	UPDATE MT SET   
	MT.CODE = CASE MT.parent WHEN 0x0 THEN T.CODE ELSE (SELECT T.Code FROM #T T WHERE T.GUID =  mt.Parent) + '-' +  (SELECT dbo.fnMatreialSegmentRecode(MT.Guid)) END 
	FROM MT000 MT   
	INNER JOIN #T T ON T.GUID = MT.GUID  

	UPDATE GR SET   
	GR.CODE = T.CODE   
	FROM GR000 GR   
	INNER JOIN #T T ON T.GUID = GR.GUID  
	COMMIT 
###################################################################################
#END
