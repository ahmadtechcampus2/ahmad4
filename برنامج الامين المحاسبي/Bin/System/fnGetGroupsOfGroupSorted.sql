#################################################################################################33
CREATE FUNCTION fnGetGroupsOfGroupSorted( @Group [UNIQUEIDENTIFIER] , @Sorted [INT] = 0)  
	RETURNS @Result TABLE ([GUID] [UNIQUEIDENTIFIER], [Level] [INT] DEFAULT 0, [Path] [NVARCHAR](max) COLLATE ARABIC_CI_AI, [Type] [INT] DEFAULT 0)  
AS   
BEGIN   
	DECLARE @FatherBuf TABLE([GUID] [UNIQUEIDENTIFIER], [Level] [INT], [Path] [NVARCHAR](max) COLLATE ARABIC_CI_AI, [ID] [INT] IDENTITY( 1, 1)) 
	DECLARE @Continue [INT], @Level [INT]  
	SET @Level = 0   
	 
	SET @Group = ISNULL(@Group, 0x0)   
	IF @Group = 0x0 
		INSERT INTO @FatherBuf ([GUID], [Level], [Path])  
			SELECT grGUID, @Level, ''  FROM [vwGr] AS [gr]
			WHERE [grParent] = 0x0
			ORDER BY CASE @Sorted WHEN 1 THEN [grCode] WHEN 2 THEN [grName] ELSE [grLatinName] END 
	ELSE
	IF ((SELECT [KIND] FROM [gr000] WHERE [gr000].[GUID] = @Group) = 0)
		INSERT INTO @FatherBuf  ([GUID], [Level], [Path])  
			SELECT [grGUID], @Level, '' FROM [vwGr] AS [gr]
			WHERE [grGUID] = @Group
			ORDER BY CASE @Sorted WHEN 1 THEN [grCode] WHEN 2 THEN [grName] ELSE [grLatinName] END
	ELSE
		BEGIN
			INSERT INTO @FatherBuf ([GUID], [Level], [Path])
			SELECT [GUID], [Level], [Path]
			FROM (
				SELECT DISTINCT [mt].[GroupGUID] AS [GUID], @Level AS [Level], '' AS [Path]
				FROM
					[fnGetMatsOfCollectiveGrps] (@Group) AS [FN]
					INNER JOIN [mt000] AS [mt] ON [mt].[Guid] = [FN].[mtGuid]) AS [tbl] INNER JOIN [vwGr] AS [gr] ON [gr].[grGUID] = [tbl].[GUID]
			ORDER BY CASE @Sorted WHEN 1 THEN [grCode] WHEN 2 THEN [grName] ELSE [grLatinName] END
			
			UPDATE @FatherBuf  SET [Path] = CAST( ( 0.0000001 * [ID]) AS [NVARCHAR](40))
			
			INSERT INTO @Result SELECT [GUID], [Level], [Path], 0 FROM @FatherBuf GROUP BY [GUID], [Level], [Path] ORDER BY [Path]			
			
			RETURN
		END
	 
	UPDATE @FatherBuf  SET [Path] = CAST( ( 0.0000001 * [ID]) AS [NVARCHAR](40))   
	SET @Continue = 1 
	---///////////////////////////////////////////////////////////// 
	WHILE @Continue <> 0   
	BEGIN 
		SET @Level = @Level + 1   
		INSERT INTO @FatherBuf( [GUID], [Level], [Path]) 
			SELECT [gr].[grGUID], @Level, [fb].[Path] 
			FROM [vwGr] AS [gr] INNER JOIN @FatherBuf AS [fb] ON [gr].[grParent] = [fb].[GUID]
			WHERE [fb].[Level] = @Level - 1
			ORDER BY CASE @Sorted WHEN 1 THEN [grCode] WHEN 2 THEN [grName] ELSE [grLatinName] END 
		SET @Continue = @@ROWCOUNT   
		UPDATE @FatherBuf  SET [Path] = [Path] + CAST( ( 0.0000001 * [ID]) AS [NVARCHAR](40))  WHERE [Level] = @Level   
	END   
	INSERT INTO @Result SELECT [GUID], [Level], [Path], 0 FROM @FatherBuf GROUP BY [GUID], [Level], [Path] ORDER BY [Path]
	---/////////////////////////////////////////////////////////////	 
RETURN  
END 
#################################################################################################33
#END