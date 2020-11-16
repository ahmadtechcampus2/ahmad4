#################################################################
CREATE PROCEDURE GetProductioLineJobOrdersTree
@ProductionLineGuid UNIQUEIDENTIFIER 
AS
BEGIN
SET NOCOUNT ON 
	CREATE TABLE [#Result]
	( 
		[JOBOrderGuid]		[UNIQUEIDENTIFIER], 
		[AccountGuid]		[UNIQUEIDENTIFIER],
		[JOBOrderNumber]	[INT],
		[AccountName]		[NVARCHAR](250) COLLATE ARABIC_CI_AI, 
		[AccountLatinName]	[NVARCHAR](250) COLLATE ARABIC_CI_AI, 
		[AccountCode]		[NVARCHAR](100)
	)

    INSERT INTO [#Result]  
    SELECT JobOrder000.Guid,JobOrder000.Account,JobOrder000.Number,ac000.Name,ac000.LatinName,ac000.Code FROM  JobOrder000 
    INNER JOIN ac000 
    ON 
    ac000.GUID=JobOrder000.Account
    WHERE ProductionLine=@ProductionLineGuid
    SELECT * FROM [#Result]  ORDER BY JOBOrderNumber 
END
#################################################################
CREATE PROCEDURE GetManufactoryTree
AS
BEGIN
SET NOCOUNT ON 
	CREATE TABLE [#Result]
     ( 
		[Guid]		[UNIQUEIDENTIFIER], 
        [Name]		[NVARCHAR](250) COLLATE ARABIC_CI_AI, 
        [LatinName]		[NVARCHAR](250) COLLATE ARABIC_CI_AI, 
		[Code]		[NVARCHAR](250) COLLATE ARABIC_CI_AI, 
        [Parent] 	[UNIQUEIDENTIFIER], 
		[Level] [INT],
		[Path] [NVARCHAR](max) 
      )

    INSERT INTO [#Result]  ([Guid],[Name],[LatinName],[Code],[Parent],[Level] )
    SELECT Guid,Name,LatineName,Code,0x0 ,0  FROM Manufactory000
    INSERT INTO [#Result]  ([Guid],[Name],[LatinName],[Code],[Parent],[Level] )
    SELECT PRD.Guid,PRD.Name,PRD.LatinName,PRD.Code,PRD.ManufactoryGUID parent,1 Level FROM ProductionLine000 PRD
    INNER JOIN  [#Result] Rst on Rst.Guid = ManufactoryGUID
    UPDATE #Result SET Path =(SELECT Path FROM  fnGetManufactoryTree(0) AS FN WHERE #Result.Guid=FN.GUID)
    SELECT * FROM [#Result] ORDER BY Path   
END
#################################################################
CREATE FUNCTION fnGetManufactoryTree(@Sorted [INT]) 
	RETURNS @Result TABLE ([GUID] [UNIQUEIDENTIFIER], [Level] [INT] DEFAULT 0, [Path] [NVARCHAR](max) )  
BEGIN
	DECLARE @FatherBuf_S	TABLE([GUID] [UNIQUEIDENTIFIER], [Level] [INT], [Path] [NVARCHAR](max) , [ID] [INT] IDENTITY( 1, 1))  
	DECLARE @SonsBuf_S	TABLE([GUID] [UNIQUEIDENTIFIER], [Path] [NVARCHAR](max), [ID] [INT] IDENTITY( 1, 1))   
		 
	--FILL THE FIRST LEVEL FROM TREE WHICH CONTAINS MANUFACTORIES
	--------------------------------------------------------------------------------------------------------------------   
		INSERT INTO @FatherBuf_S ([GUID]  , [Level], [Path] ) SELECT [GUID],  0 , ''  FROM [Manufactory000]   ORDER BY CASE @Sorted  WHEN 0 THEN [Code] ELSE [Name] END 
			 
		UPDATE @FatherBuf_S  SET [Path] = CAST( ( 0.0000001 * [ID]) AS [NVARCHAR](40))  
	--------------------------------------------------------------------------------------------------------------------
		 --FILL SECOND LEVEL WHICH CONTAINS PRODUCTION LINE   
			INSERT INTO @SonsBuf_S([GUID],[Path]) SELECT [PRD].[GUID], [fb].[Path] 
						FROM [ProductionLine000] AS [PRD] INNER JOIN @FatherBuf_S AS [fb] ON [PRD].[ManufactoryGUID] = [fb].[GUID]  
						ORDER BY CASE @Sorted  WHEN 0 THEN [Code] ELSE [Name] END 
			INSERT INTO @FatherBuf_S SELECT [GUID], 1 , [Path] FROM @SonsBuf_S  
			UPDATE @FatherBuf_S  SET [Path] = [Path] + CAST( ( 0.0000001 * [ID]) AS [NVARCHAR](40))  WHERE [Level] = 1  
 
			INSERT INTO @Result SELECT [GUID], [Level] , [Path] FROM @FatherBuf_S GROUP BY [GUID], [Level], [Path] ORDER BY [Path] 
	
	RETURN 
END
#################################################################
#END