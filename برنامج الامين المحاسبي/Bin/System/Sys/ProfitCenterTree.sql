#################################################################
CREATE PROCEDURE GetProfitCenterTypesTree
@Guid uniqueidentifier 
AS
BEGIN
SET NOCOUNT ON  
CREATE TABLE [#SecViol] ([Type] [INT], [Cnt] [INT]) 
	CREATE TABLE [#Result]
     ( 
	   [Guid]		[UNIQUEIDENTIFIER], 
        [Name]		[NVARCHAR](250) COLLATE ARABIC_CI_AI, 
        [LatinName]		[NVARCHAR](250) COLLATE ARABIC_CI_AI, 
	   [Type] [INT],
	   [SortNum] [INT]
      )

    INSERT INTO [#Result]  
    SELECT et.Guid,et.Name,et.LatinName ,PFCType.Type, et.SortNum FROM SubProfitCenterBill_EN_Type000 PFCType
    inner join et000 et on et.GUID =  PFCType.TypeGuid
    where PFCType.ParentGuid = @Guid
    union all
    SELECT et.Guid,et.Name,et.LatinName ,PFCType.Type, et.SortNum FROM SubProfitCenterBill_EN_Type000 PFCType
    inner join bt000 et on et.GUID =  PFCType.TypeGuid
    where PFCType.ParentGuid = @Guid
    EXEC [prcCheckSecurity] 
    SELECT * FROM [#Result]  ORDER BY Type, SortNum
    SELECT * FROM [#SecViol]   
END
#################################################################
CREATE PROCEDURE GetProfitCenterTree
@MainProfitCenterBrowseSec int,
@SubProfitCenterBrowseSec int
AS
BEGIN
SET NOCOUNT ON 
CREATE TABLE [#SecViol] ([Type] [INT], [Cnt] [INT]) 
	CREATE TABLE [#Result]
     ( 
		[Guid]		[UNIQUEIDENTIFIER], 
        [Name]		[NVARCHAR](250) COLLATE ARABIC_CI_AI, 
        [LatinName]		[NVARCHAR](250) COLLATE ARABIC_CI_AI, 
		[Code]		[NVARCHAR](250) COLLATE ARABIC_CI_AI, 
        [Parent] 	[UNIQUEIDENTIFIER], 
		[Level] [INT], 
		[Security] [INT],
        [userSecurity] [INT]
      )

    INSERT INTO [#Result]  
    SELECT Guid,Name,LatinName,Code,0x0 Parent,0 Level,Security,@MainProfitCenterBrowseSec FROM vtMainProfitCenter
    INSERT INTO [#Result]  
    SELECT sub.Guid,sub.Name,sub.LatinName,sub.Code,sub.ParentGuid parent,1 Level,sub.Security, @SubProfitCenterBrowseSec FROM vtSubProfitCenter sub
    INNER JOIN  [#Result] Rst on Rst.Guid = ParentGuid
    EXEC [prcCheckSecurity] 
    SELECT * FROM [#Result]  
    SELECT * FROM [#SecViol]   
END
#################################################################
CREATE FUNCTION fnGetPFCsTree() 
		RETURNS @Result TABLE (
					   [GUID] [UNIQUEIDENTIFIER], 
					   [ParentGUID] [UNIQUEIDENTIFIER],
					   [Code] [NVARCHAR](255),
					   [Name] [NVARCHAR](255),
					   [LatinName] [NVARCHAR](255),
					   [tableName] [NVARCHAR](255),
					   [branchMask] INT, 
					   [SortNum] INT, 
					   [IconID] INT, 
					   [Level] [INT] DEFAULT 0, 
					   [Path] [NVARCHAR](max) COLLATE ARABIC_CI_AI)  
AS BEGIN 
			DECLARE @FatherBuf TABLE( 
							   [GUID] [UNIQUEIDENTIFIER], 
							   [ParentGUID] [UNIQUEIDENTIFIER],
							   [Code] [NVARCHAR](255),
							   [Name] [NVARCHAR](255),
							   [LatinName] [NVARCHAR](255),
							   [tableName] [NVARCHAR](255),
							   [branchMask] INT, 
							   [SortNum] INT, 
							   [IconID] INT, 
							   [Level] [INT] DEFAULT 0, 
							   [Path] [NVARCHAR](max) COLLATE ARABIC_CI_AI,
							   [ID] [INT] IDENTITY( 1, 1))  
					   
			DECLARE @Continue [INT], @Level [INT]   
			SET @Level = 0    
			 
			INSERT INTO @FatherBuf ( [GUID], [ParentGUID], [Code] , [Name] ,[LatinName] , [tableName] , [branchMask] , [SortNum] , [IconID] ,[Level], [Path]) 
				SELECT Guid, 0x0 , MainPFC.[Code] , MainPFC.[Name] , MainPFC.[LatinName] , 'MainProfitCenter000', 0, 3, 11 , @Level, '' 
				FROM MainProfitCenter000 MainPFC
				ORDER BY [Name] 
				
			UPDATE @FatherBuf SET [Path] = CAST( ( 0.0000001 * [ID]) AS [NVARCHAR](40))  
			SET @Continue = 1  
 
			WHILE @Continue <> 0    
			BEGIN  
				SET @Level = @Level + 1    
				INSERT INTO @FatherBuf ( [GUID],		  [ParentGUID], [Code] ,		  [Name] ,			[LatinName] ,			[tableName] ,		[branchMask] , [SortNum] , [IconID] ,[Level], [Path]) 
								SELECT   [SubPFC].[GUID], [fb].[GUID] , [SubPFC].[Code] , [SubPFC].[Name] , [SubPFC].[LatinName] , 'SubProfitCenter000', 0, 3, 12 , @Level, [fb].[Path]  
								FROM SubProfitCenter000 AS [SubPFC] INNER JOIN 
								@FatherBuf AS [fb] ON [SubPFC].[ParentGuid] = [fb].[GUID] 
								WHERE [fb].[Level] = @Level - 1
								ORDER BY [SubPFC].[Name]  
					SET @Continue = @@ROWCOUNT    
					UPDATE @FatherBuf  SET [Path] = [Path] + CAST( ( 0.0000001 * [ID]) AS NVARCHAR(40))  WHERE [Level] = @Level    
			END 
			
			DECLARE @ProfitCentersFatherGuid UNIQUEIDENTIFIER
			SET @ProfitCentersFatherGuid  = 'A3B54C31-EC74-4C49-96B6-AEC526BC1E15'

			
			IF (dbo.fnOption_GetInt('PFC_IsBelongToProfitCenter', '0') = 0)
			BEGIN 
				INSERT INTO @Result
				VALUES (@ProfitCentersFatherGuid , 0x0, '', N'مراكز الربحية' , N'Profit Centers', 'SubProfitCenter000', 0, 3 , 11 , 0, N'0.')
			END
		
			UPDATE @FatherBuf
			SET 
			Level = Level + 1 
			
			UPDATE @FatherBuf
			SET ParentGuid = @ProfitCentersFatherGuid
			WHERE ParentGUID = 0x0
			
			INSERT INTO @Result 
			SELECT [fb].[GUID], [fb].[ParentGUID], [fb].[Code] , [fb].[Name] ,[fb].[LatinName] , [fb].[tableName] , [fb].[branchMask] , [fb].[SortNum] , [fb].[IconID] ,[fb].[Level], [fb].[Path] 
			FROM @FatherBuf [fb]
			ORDER BY [Path]
			RETURN 
END
--SELECT * FROM  dbo.[fnGetPFCsTree]()
#################################################################
#END