#################################################################
CREATE FUNCTION fnGetChildLCsOfLCSorted(@LCMain [UNIQUEIDENTIFIER] , @Sorted [INT] = 0)  
	RETURNS @Result TABLE ([GUID] [UNIQUEIDENTIFIER], [Level] [INT] DEFAULT 0, [Path] [NVARCHAR](max) COLLATE ARABIC_CI_AI)  
AS   
BEGIN   
	DECLARE @FatherBuf TABLE([GUID] [UNIQUEIDENTIFIER], [Level] [INT], [Path] [NVARCHAR](max) COLLATE ARABIC_CI_AI , [ID] [INT] IDENTITY( 1, 1)) 
	DECLARE @Continue [INT], @Level [INT]  
	SET @Level = 0   
	 
	SET @LCMain = ISNULL(@LCMain, 0x0)   
	IF @LCMain = 0x0 
		INSERT INTO @FatherBuf ([GUID], [Level], [Path])  
			SELECT [GUID], @Level, '' FROM [LCMain000] WHERE [ParentGUID] = 0x0 ORDER BY CASE @Sorted WHEN 1 THEN [Code] WHEN 2 THEN [Name] ELSE [LatinName] END 
	ELSE   
		INSERT INTO @FatherBuf  ([GUID], [Level], [Path])  
			SELECT [GUID], @Level, '' FROM [LCMain000] WHERE [GUID] = @LCMain ORDER BY CASE @Sorted WHEN 1 THEN [Code] WHEN 2 THEN [Name] ELSE [LatinName] END 

	UPDATE @FatherBuf SET [Path] = CAST( ( 0.0000001 * [ID]) AS [NVARCHAR](40))  
	SET @Continue = 1 

	WHILE @Continue <> 0   
	BEGIN 
		SET @Level = @Level + 1   
		INSERT INTO @FatherBuf( [GUID], [Level], [Path]) 
			SELECT [lcm].[GUID], @Level, [fb].[Path]
			FROM [LCMain000] AS [lcm] INNER JOIN @FatherBuf AS [fb] ON [lcm].[ParentGUID] = [fb].[GUID]
			WHERE [fb].[Level] = @Level - 1
			ORDER BY CASE @Sorted WHEN 1 THEN [Code] WHEN 2 THEN [Name] ELSE [LatinName] END 
		
		SET @Continue = @@ROWCOUNT      
		UPDATE @FatherBuf  SET [Path] = [Path] + CAST( ( 0.0000001 * [ID]) AS [NVARCHAR](40))  WHERE [Level] = @Level    
	END   
	INSERT INTO @Result SELECT [GUID], [Level], [Path] FROM @FatherBuf GROUP BY [GUID], [Level], [Path] ORDER BY [Path] 
RETURN  
END 
#################################################################
CREATE PROCEDURE GetLCTreeList
@LCMainGuid uniqueidentifier,
@LCBrowseSec int 
AS
BEGIN
SET NOCOUNT ON 

	CREATE TABLE [#Result]
     ( 
	   [Guid]		[UNIQUEIDENTIFIER],  
	   [Code]		[NVARCHAR](250),
       [Name]		[NVARCHAR](250) COLLATE ARABIC_CI_AI, 
       [LatinName]	[NVARCHAR](250) COLLATE ARABIC_CI_AI
      )

    INSERT INTO [#Result]  
    SELECT [lc].[GUID],
		   [lc].[Code],
		   [lc].[Name],
		   [lc].[LatinName] 
	  FROM vwLC AS [lc]
     WHERE [lc].[ParentGUID] = @LCMainGuid AND [lc].[Security] <= @LCBrowseSec
	 ORDER BY [lc].[Code]

    SELECT * FROM [#Result]  ORDER BY [Code]
END
#################################################################
CREATE PROCEDURE GetLCMainTree
@LCMainBrowseSec int
AS
BEGIN
SET NOCOUNT ON 
	CREATE TABLE [#Result]
     ( 
		[Guid]		[UNIQUEIDENTIFIER], 
        [Name]		[NVARCHAR](250) COLLATE ARABIC_CI_AI, 
        [LatinName]	[NVARCHAR](250) COLLATE ARABIC_CI_AI, 
		[Code]		[NVARCHAR](250) COLLATE ARABIC_CI_AI, 
        [Parent] 	[UNIQUEIDENTIFIER], 
		[Level]		[INT],
		[Path]		[NVARCHAR](max) COLLATE ARABIC_CI_AI
      )

    INSERT INTO [#Result]  
    SELECT [lcm].[GUID],
		   [lcm].[Name],
		   [lcm].[LatinName],
		   [lcm].[Code],
		   [lcm].[ParentGUID],
		   [fn].[Level],
		   [fn].[Path] 
	  FROM vwLCMain AS [lcm] 
		   INNER JOIN [dbo].[fnGetChildLCsOfLCSorted]( 0x0, 1) AS [fn] ON [fn].[GUID] = [lcm].[GUID]
	 WHERE [lcm].[Security] <= @LCMainBrowseSec
	 ORDER BY [fn].[Path]

    SELECT * FROM [#Result] ORDER BY [Path]   
END
#################################################################
CREATE PROCEDURE repLCTreeReport
@LCMainBrowseSec int,
@LCBrowseSec int 
AS
BEGIN
	SET NOCOUNT ON 
	CREATE TABLE [#Result]
    ( 
		[Guid]		[UNIQUEIDENTIFIER], 
        [Name]		[NVARCHAR](250) COLLATE ARABIC_CI_AI, 
        [LatinName]	[NVARCHAR](250) COLLATE ARABIC_CI_AI, 
		[Code]		[NVARCHAR](250) COLLATE ARABIC_CI_AI, 
        [Parent] 	[UNIQUEIDENTIFIER], 
		[Level]		[INT],
		[Path]		[NVARCHAR](max) COLLATE ARABIC_CI_AI,
		[Type]		[INT]
    )

    INSERT INTO [#Result]  
    SELECT [lcm].[GUID],
		   [lcm].[Name],
		   [lcm].[LatinName],
		   [lcm].[Code],
		   [lcm].[ParentGUID],
		   [fn].[Level],
		   [fn].[Path],
		   0 
	  FROM vwLCMain AS [lcm] 
		   INNER JOIN [dbo].[fnGetChildLCsOfLCSorted](0x0, 1) AS [fn] ON [fn].[GUID] = [lcm].[GUID]
	 WHERE [lcm].[Security] <= @LCMainBrowseSec
	 ORDER BY [fn].[Path]

    INSERT INTO [#Result]  
    SELECT [lc].[GUID],
		   [lc].[Name],
		   [lc].[LatinName], 
		   [lc].[Code],
		   [lc].[ParentGUID],
		   [r].[Level] + 1,
		   [r].[Path],
		   1
	  FROM vwLC AS [lc]
		   INNER JOIN #Result AS [r] ON [r].[Guid] = [lc].[ParentGUID] 
     WHERE [lc].[Security] <= @LCBrowseSec
	ORDER BY [r].[Path], [r].[Code]
    
	SELECT * FROM [#Result] ORDER BY [Path], [Type], [Code] 

END
#################################################################
#END