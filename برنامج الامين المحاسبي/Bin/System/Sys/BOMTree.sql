#########################################################
CREATE VIEW vwMatGroupsWithBOM
AS 
	SELECT 
		[GUID] AS [grGUID], 
		[Number] AS [grNumber], 
		[ParentGUID] AS [grParent], 
		[Code] AS [grCode], 
		[Name] AS [grName], 
		[LatinName] AS [grLatinName],
		[Security] AS [grSecurity],
		0 As [Type]
	FROM 
		[vbGr]

    Union 

	SELECT 
		bom.[GUID] AS [grGUID], 
		bom.[Number] AS [grNumber], 
		mt.GroupGUID AS [grParent], 
		bom.[Code] AS [grCode], 
		bom.[Name] AS [grName], 
		bom.[LatinName] AS [grLatinName],
		bom.[Security] AS [grSecurity],
		1 As [Type]
	FROM 
		JOCBOM000 bom 
		LEFT JOIN  JOCBOMFinishedGoods000 fg ON fg.BOMGuid = bom.GUID
		INNER JOIN mt000 mt ON fg.MatPtr = mt.[GUID] 

#########################################################
CREATE FUNCTION GetGroupsHaveBOM()
	RETURNS @Result TABLE 
	(
		[grGUID]	  UNIQUEIDENTIFIER, 
		[grNumber]    INT, 
		[grParent]    UNIQUEIDENTIFIER, 
		[grCode]	  NVARCHAR(100), 
		[grName]	  NVARCHAR(250), 
		[grLatinName] NVARCHAR(250),
		[grSecurity]  INT,
		[Type]		  INT,
		[TreeLevel]	  INT 
	)  
		
BEGIN
DECLARE @Continue INT = 1
DECLARE @LEVEL    INT = 1
------------------- FILL RESULTS WITH BOM DATA	----------------------
INSERT INTO @Result
	SELECT *,0 FROM vwMatGroupsWithBOM WHERE [Type]=1
-----------------------------------------------------------------------
WHILE @Continue <> 0   
	BEGIN 
		INSERT INTO @Result 
			SELECT *,@LEVEL FROM vwMatGroupsWithBOM 
			WHERE 
			[grGUID] IN (SELECT [grParent] FROM @Result WHERE TreeLevel=(@LEVEL-1))
			 AND 
			[grGUID] NOT IN (SELECT [grGUID] FROM @Result )
			
		SET @Continue = @@ROWCOUNT
		
		SET @LEVEL = @LEVEL +1 
	END   
	RETURN 
END

#########################################################
CREATE FUNCTION fnGetProductionLinesNameForBOM()
	RETURNS @Result TABLE 
	(
	 BOMGuid UNIQUEIDENTIFIER,
	 ProductionLinesNames NVARCHAR (max)COLLATE ARABIC_CI_AI
	)  
		
BEGIN
DECLARE @CodeNameString varchar(MAX)
INSERT INTO @Result(BOMGuid)
	SELECT  [GUID]  FROM JOCBOM000
UPDATE @Result SET ProductionLinesNames= 
					(SELECT  Line.Name +' - '
                             FROM ProductionLine000 AS Line
                             INNER JOIN JOCBOMProductionLines000 AS BOMLine
                             ON BOMLine.ProductionLineGuid=Line.Guid
                             WHERE BOMLine.JOCBOMGuid=BOMGuid
                             ORDER BY Line.Number
                             FOR XML PATH(''))
UPDATE @Result SET ProductionLinesNames=  CASE WHEN ISNULL (ProductionLinesNames ,'')='' THEN '' ELSE LEFT(ProductionLinesNames, LEN(ProductionLinesNames) - 1)  END  
	
	RETURN 
END
#########################################################
CREATE PROCEDURE repBOMTree
	@Lang		INT = 0					-- Language	(0=Arabic; 1=English)
AS
	SET NOCOUNT ON
	
	CREATE TABLE [#SecViol] ([Type] [INT], [Cnt] [INT])
	CREATE TABLE [#Result](
			[Guid]		[UNIQUEIDENTIFIER],
			[ParentGuid] 	[UNIQUEIDENTIFIER],
			[Code]		[NVARCHAR](250) COLLATE ARABIC_CI_AI,
			[Name]		[NVARCHAR](250) COLLATE ARABIC_CI_AI,
			[Number]		[FLOAT],
			[GroupSecurity] [INT],
			[Level] [INT],
			[Path] 		[NVARCHAR](max) COLLATE ARABIC_CI_AI,
			[Type]    [INT] ,
			[ProductionLineName] [NVARCHAR](max) )
	
	INSERT INTO [#Result] 
	SELECT 
			[BOMgr].[grGuid], 
			CASE WHEN [BOMgr].[grParent] IS Null then 0x0 ELSE [BOMgr].[grParent] END AS [Parent],
			[BOMgr].[grCode], 
			CASE WHEN (@Lang = 1)AND([BOMgr].[grLatinName] <> '') THEN  [BOMgr].[grLatinName] ELSE [BOMgr].[grName] END AS [grName],
			[BOMgr].[grNumber],
			[BOMgr].[grSecurity],
			[fn].[Level],
			[fn].[Path],
			[BOMgr].[Type],
			[PrdLine].[ProductionLinesNames]
			
		FROM
			[vwMatGroupsWithBOM] as [BOMgr] INNER JOIN fnGetBOMMatSorted( 0x0, 1) AS [fn]
			ON [BOMgr].[grGuid] = [fn].[Guid]
			LEFT JOIN fnGetProductionLinesNameForBOM() AS PrdLine
			ON PrdLine.BOMGuid= [BOMgr].[grGuid]
	EXEC [prcCheckSecurity]
	SELECT * FROM [#Result] ORDER BY [Path]
	SELECT * FROM [#SecViol]
#########################################################
CREATE FUNCTION fnGetBOMMatSorted( @Group [UNIQUEIDENTIFIER] , @Sorted [INT] = 0)  
	RETURNS @Result TABLE ([GUID] [UNIQUEIDENTIFIER], [Level] [INT] DEFAULT 0, [Path] [NVARCHAR](max) COLLATE ARABIC_CI_AI, [Type] [INT] DEFAULT 0)  
AS   
BEGIN   
	DECLARE @FatherBuf TABLE([GUID] [UNIQUEIDENTIFIER], [Level] [INT], [Path] [NVARCHAR](max) COLLATE ARABIC_CI_AI, [ID] [INT] IDENTITY( 1, 1)) 
	DECLARE @Continue [INT], @Level [INT]  
	SET @Level = 0   
	 
	SET @Group = ISNULL(@Group, 0x0)   
	IF @Group = 0x0 
		INSERT INTO @FatherBuf ([GUID], [Level], [Path])  
			SELECT grGUID, @Level, ''  FROM GetGroupsHaveBOM() AS [gr] WHERE [grParent] = 0x0 AND [Type]=0 ORDER BY CASE @Sorted WHEN 1 THEN [grCode] WHEN 2 THEN [grName] ELSE [grLatinName] END 
	ELSE   
		INSERT INTO @FatherBuf  ([GUID], [Level], [Path])  
			SELECT [grGUID], @Level, '' FROM GetGroupsHaveBOM() AS [gr] WHERE [grGUID] = @Group AND [Type]=0 ORDER BY CASE @Sorted WHEN 1 THEN [grCode] WHEN 2 THEN [grName] ELSE [grLatinName] END 
	 
	UPDATE @FatherBuf  SET [Path] = CAST( ( 0.0000001 * [ID]) AS [NVARCHAR](40))   
	SET @Continue = 1 
	---///////////////////////////////////////////////////////////// 
	WHILE @Continue <> 0   
	BEGIN 
		SET @Level = @Level + 1   
		INSERT INTO @FatherBuf( [GUID], [Level], [Path]) 
			SELECT [BOMgr].[grGUID], @Level, [fb].[Path] 
			FROM GetGroupsHaveBOM() AS [BOMgr] INNER JOIN @FatherBuf AS [fb] ON [BOMgr].[grParent] = [fb].[GUID]
			WHERE [fb].[Level] = @Level - 1
			ORDER BY CASE @Sorted WHEN 1 THEN [grCode] WHEN 2 THEN [grName] ELSE [grLatinName] END 
		SET @Continue = @@ROWCOUNT   
		UPDATE @FatherBuf  SET [Path] = [Path] + CAST( ( 0.0000001 * [ID]) AS [NVARCHAR](40))  WHERE [Level] = @Level   
	END   
	INSERT INTO @Result SELECT [GUID], [Level], [Path], 0 FROM @FatherBuf GROUP BY [GUID], [Level], [Path] ORDER BY [Path]
	---/////////////////////////////////////////////////////////////	 
RETURN  
END
#########################################################
CREATE PROC prcTreeBOMDetails
	 @BOMGuid UNIQUEIDENTIFIER
AS
SET NOCOUNT ON
SELECT 
	MT.GUID   ,
	MT.NAME   ,
	MT.CODE			      ,
	MT.Number			  ,
	rawMat.JOCBOMGuid PARENTGUID,
	1 [Level],
	1 [Type],
	rawMat.GridIndex SortFld
INTO #RESULT
FROM JOCBOMRawMaterials000 rawMat
INNER JOIN MT000 MT ON MT.GUID = rawMat.MatPtr
WHERE    rawMat.JOCBOMGuid = @BOMGuid

INSERT INTO #RESULT
SELECT 
	GUID,
	NAME,
	CODE,
	NUMBER,
	newid() PARENTGUID,
	0 [Level],
	0 [Type],
	-1 SortFld
FROM JOCBOM000 
WHERE Guid = @BOMGuid


SELECT * FROM #RESULT
ORDER BY [Level],SortFld
#########################################################
#END