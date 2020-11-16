#################################################################################################33
CREATE FUNCTION fnGetTypesGroupSorted( @Group [UNIQUEIDENTIFIER])  
	RETURNS @Result TABLE ([GUID] [UNIQUEIDENTIFIER], [Level] [INT] DEFAULT 0, [Path] [NVARCHAR](max) COLLATE ARABIC_CI_AI, [Type] [INT] DEFAULT 0)  
AS   
BEGIN   
	DECLARE @FatherBuf TABLE([GUID] [UNIQUEIDENTIFIER], [Level] [INT], [Path] [NVARCHAR](max) COLLATE ARABIC_CI_AI, [ID] [INT] IDENTITY( 1, 1)) 
	DECLARE @Continue [INT], @Level [INT]  
	SET @Level = 0   
	 
	SET @Group = ISNULL(@Group, 0x0)   
	IF @Group = 0x0 
		INSERT INTO @FatherBuf ([GUID], [Level], [Path])  
			SELECT GUID, @Level, ''  FROM [TypesGroup000] AS [gr] WHERE [ParentGUID] = 0x0 ORDER BY [Code] 
	ELSE   
		INSERT INTO @FatherBuf  ([GUID], [Level], [Path])  
			SELECT [GUID], @Level, '' FROM [TypesGroup000] AS [gr] WHERE [GUID] = @Group ORDER BY [Code]
	 
	UPDATE @FatherBuf  SET [Path] = CAST( ( 0.0000001 * [ID]) AS [NVARCHAR](40))   
	SET @Continue = 1 
	---///////////////////////////////////////////////////////////// 
	WHILE @Continue <> 0   
	BEGIN 
		SET @Level = @Level + 1   
		INSERT INTO @FatherBuf( [GUID], [Level], [Path]) 
			SELECT [gr].[GUID], @Level, [fb].[Path] 
			FROM [TypesGroup000] AS [gr] INNER JOIN @FatherBuf AS [fb] ON [gr].[ParentGUID] = [fb].[GUID]
			WHERE [fb].[Level] = @Level - 1
			ORDER BY [Code] 

		SET @Continue = @@ROWCOUNT   
		UPDATE @FatherBuf  SET [Path] = [Path] + CAST( ( 0.0000001 * [ID]) AS [NVARCHAR](40))  WHERE [Level] = @Level   
	END   
	INSERT INTO @Result SELECT [GUID], [Level], [Path], 0 FROM @FatherBuf GROUP BY [GUID], [Level], [Path] ORDER BY [Path]
	---/////////////////////////////////////////////////////////////	 
RETURN  
END 
#################################################################################################
CREATE PROCEDURE repTypesTree
AS
	SET NOCOUNT ON 
	 
	CREATE TABLE [#SecViol](Type [INT], Cnt [INT]) 
	CREATE TABLE [#Result](  
			[GUID] [UNIQUEIDENTIFIER],  
			[ParentGUID] [UNIQUEIDENTIFIER],  
			[Code] [NVARCHAR](256) COLLATE ARABIC_CI_AI, 
			[Name] [NVARCHAR](256) COLLATE ARABIC_CI_AI, 
			[LatinName] [NVARCHAR](256) COLLATE ARABIC_CI_AI, 
			[Level] [INT], 
			[Path] [NVARCHAR](max) COLLATE ARABIC_CI_AI, 
			[CardType] [INT],
			[ScrType] [INT]) 
	 
	INSERT INTO [#Result]  
		SELECT  
			[Grp].[GUID],  
			[Grp].[ParentGUID], 
			[Grp].[Code],  
			[Grp].[Name],   
			[Grp].[LatinName], 
			[Gr].[Level], 
			[Gr].[Path], 
			[Grp].[Type],
			0
			 
	FROM  
		[dbo].[fnGetTypesGroupSorted](0x0) AS [Gr]  
		INNER JOIN [TypesGroup000] AS [Grp] ON [Gr].[GUID] = [Grp].[GUID] 
	 
	INSERT INTO [#Result]  
	SELECT 
		[TY].[TypeGuid], 
		[TY].[Guid], 
		'',
		[BT].[btName], 
		[BT].[btLatinName], 
		[gr].[level] + 1, 
		[gr].[Path], 
		-1,
		TY.Type
	 
	FROM  
		[#Result] AS [Gr] INNER JOIN [TypesGroupRepSrcs000] AS [ty] ON [Gr].[GUID] = [ty].[Guid]
		INNER JOIN vwBt BT ON BT.btGUID = TY.TypeGuid
	
	INSERT INTO [#Result]  
	SELECT 
		[TY].[TypeGuid], 
		[TY].[Guid], 
		'',
		[ET].[etName], 
		[ET].[etLatinName], 
		[gr].[level] + 1, 
		[gr].[Path],
		-1, 
		TY.Type
	 
	FROM  
		[#Result] AS [Gr] INNER JOIN [TypesGroupRepSrcs000] AS [ty] ON [Gr].[GUID] = [ty].[Guid]
		INNER JOIN vwEt ET ON ET.etGUID = TY.TypeGuid 

	INSERT INTO [#Result]  
	SELECT 
		[TY].[TypeGuid], 
		[TY].[Guid], 
		'',
		[NT].[ntName], 
		[NT].[ntLatinName], 
		[gr].[level] + 1, 
		[gr].[Path],
		-1, 
		TY.Type
	 
	FROM  
		[#Result] AS [Gr] INNER JOIN [TypesGroupRepSrcs000] AS [ty] ON [Gr].[GUID] = [ty].[Guid]
		INNER JOIN vwNt NT ON NT.ntGUID = TY.TypeGuid 

	SELECT  
		[GUID], 
		ISNULL( [ParentGUID], 0x0) AS [ParentGUID], 
		[Code], 
		[Name], 
		[LatinName], 
		ISNULL( [Level], 0) AS [Level], 
		[Path], 
		[CardType],
		[ScrType]
	FROM  
		[#Result]  
	ORDER BY  
		[Path], [ScrType]
##########################################################################
#END