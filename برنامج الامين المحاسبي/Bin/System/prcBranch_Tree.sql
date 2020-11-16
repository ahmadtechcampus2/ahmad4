#########################################################
CREATE PROC prcBranch_Tree
	@branchMask [BIGINT] = 0,
	@Filter [INT] = 0 -- 0 no filtering, 1 checked only, 2 unchecked only
AS
/*
	@Filter:
		0. no filtering, all #result columns are returned, usualy used to fill/refresh tree
		1. checked only,
		2. unchecked only

Result:
	icons ids:
		1. accounts root.
		2. normal account.
		3. normal account with customer
		4. final account.
		5 collective account.
		6. distributed account.
	
		11. costs root.
		12. cost.
	
		21. materials and groups root.
		22. group.
		23. material
	
		31. stores root
		32. store.
	
		41. Bills Typs root.
		42. non standard bills
		43. standard bills
	
		51. entries types root
		52. entry
	
		61. notes types listt
		62. note
		
		71. manufacturing form root
		72. manufacturing form.

*/

	SET NOCOUNT ON

	DECLARE
		@c CURSOR,
		@tableName [NVARCHAR](128),
		@func [NVARCHAR](128),
		@LangFldName [NVARCHAR](50),
		@SQL [NVARCHAR](max),
		@Crt [NVARCHAR](1000)

	CREATE TABLE [#Result] (
		[GUID] [UNIQUEIDENTIFIER],
		[ParentGUID] [UNIQUEIDENTIFIER],
		[Code] [NVARCHAR](250) COLLATE ARABIC_CI_AI,
		[Name] [NVARCHAR](250) COLLATE ARABIC_CI_AI,
		[tableName] [NVARCHAR](250) COLLATE ARABIC_CI_AI,
		[branchMask] [BIGINT],
		[SortNum] [INT],
		[IconID] [INT],
		[Path] [NVARCHAR](512) COLLATE ARABIC_CI_AI,
		[Level] [INT])
	DECLARE @id AS [INT], @idStr AS [NVARCHAR](10)
	SET @id = 0
	SET @idStr = '/' + CAST( @id AS [NVARCHAR](10)) + '/' 
	SET @LangFldName = CASE [dbo].[fnConnections_GetLanguage]() WHEN 1 THEN 'LatinName' ELSE 'Name' END
	SET @c = CURSOR FAST_FORWARD FOR SELECT [tableName],[ListingFunctionName] FROM [brt] WHERE [ListingFunctionName] <> ''

	OPEN @c FETCH FROM @c INTO @tableName, @func
	
	WHILE @@FETCH_STATUS = 0
	BEGIN
		SET @SQL = 'INSERT INTO [#Result] SELECT [GUID],[ParentGUID],[Code], ' + @LangFldName + ', [tableName],[branchMask],[SortNum],[IconID], (''' + @idStr + ''' + [Path]) AS [Path], [Level] FROM [dbo].' + @func + '()'
		EXEC (@SQL)
		SET @id = @id + 1		
		SET @idStr = '/' + CAST( @id AS [NVARCHAR](10)) + '/' 
		FETCH FROM @c INTO @tableName, @func
	END
	CLOSE @c DEALLOCATE @c

	IF @Filter = 0
		SET @Crt = ''

	ELSE IF @Filter = 1
		SET @Crt = ' WHERE [ParentGUID] = 0x0 OR ([branchMask] & CAST(' + CAST(@branchMask AS [NVARCHAR](50)) + ' AS BIGINT)) <> 0'

	ELSE
		SET @Crt = ' WHERE [ParentGUID] = 0x0 OR ([branchMask] & CAST(' + CAST(@branchMask AS [NVARCHAR](50)) + ' AS BIGINT)) = 0'

	SET @SQL = 'SELECT * FROM [#Result]' + @Crt +  ' ORDER BY [Path]'--ParentGUID'
	EXEC (@SQL)
	DROP TABLE [#Result]
#########################################################
CREATE FUNCTION fnGetBranchesListSorted(
			@BranchGUID [UNIQUEIDENTIFIER],
			@Sorted [INT] = 0 -- 0: without sort, 1:Sort By Cod, 2:Sort By Name
			) 
		RETURNS @Result TABLE (GUID [UNIQUEIDENTIFIER], [Level] [INT] DEFAULT 0, [Path] [NVARCHAR](max) COLLATE ARABIC_CI_AI)    
AS BEGIN   
	DECLARE @FatherBuf TABLE( [GUID] [UNIQUEIDENTIFIER], [Level] [INT], [Path] [NVARCHAR](max) COLLATE ARABIC_CI_AI, ID INT IDENTITY( 1, 1))    
	DECLARE @Continue [INT], @Level [INT]    
	DECLARE @SQL [NVARCHAR](500) 
	SET @Level = 0      
	IF ISNULL( @BranchGUID, 0x0) = 0x0 
	BEGIN
		INSERT INTO @FatherBuf ( [GUID], [Level], [Path])   
			SELECT [GUID], @Level, '' 
			FROM [veBr]
			WHERE ISNULL([ParentGUID], 0x0) = 0x0 
			ORDER BY CASE @Sorted WHEN 1 THEN [Code] ELSE [Name] END 
	END
	ELSE    
	BEGIN
		INSERT INTO @FatherBuf ( [GUID], [Level], [Path])   
			SELECT [GUID], @Level, '' FROM [veBr] WHERE [GUID] = @BranchGUID  
	END

	UPDATE @FatherBuf SET [Path] = CAST( ( 0.0000001 *[ID]) AS [NVARCHAR](40))    
	SET @Continue = 1    
	---/////////////////////////////////////////////////////////////    
	WHILE @Continue <> 0      
	BEGIN    
		SET @Level = @Level + 1      
		INSERT INTO @FatherBuf( [GUID], [Level], [Path])    
			SELECT [Br].[GUID], @Level, [fb].[Path]   
				FROM [veBr] AS [Br] INNER JOIN @FatherBuf AS [fb] ON [Br].[ParentGUID] = [fb].[GUID]   
				WHERE [fb].[Level] = @Level - 1
				ORDER BY CASE @Sorted WHEN 1 THEN [Code] ELSE [Name] END   
		SET @Continue = @@ROWCOUNT 
		UPDATE @FatherBuf  SET [Path] = [Path] + CAST( ( 0.0000001 * [ID]) AS [NVARCHAR](40))  WHERE [Level] = @Level 
	END   
	INSERT INTO @Result SELECT [GUID], [Level], [Path] FROM @FatherBuf GROUP BY [GUID], [Level], [Path] ORDER BY [Path]  

	RETURN   
END 
#########################################################
CREATE PROCEDURE repBranchTree
	@Lang		[INT] = 0					-- Language	(0=Arabic; 1=English)  
AS  
	SET NOCOUNT ON
	
	CREATE TABLE [#SecViol] ([Type] [INT], [Cnt] [INT])  
	CREATE TABLE [#Result](  
			[Guid]			[UNIQUEIDENTIFIER],  
			[ParentGuid] 	[UNIQUEIDENTIFIER],  
			[Code]			[NVARCHAR](250) COLLATE ARABIC_CI_AI,  
			[Name]			[NVARCHAR](250) COLLATE ARABIC_CI_AI,  
			[Number]		[FLOAT],  
			[Security]		[INT],  
			[Level] 		[INT],  
			[Path] 			[NVARCHAR](max) COLLATE ARABIC_CI_AI  
		   	)  
	  
	INSERT INTO [#Result]   
	SELECT   
			[Br].[Guid],   
			ISNULL([Br].[ParentGUID], 0x0),  
			[Br].[Code],   
			CASE WHEN (@Lang = 1)AND([Br].[LatinName] <> '') THEN  [Br].[LatinName] ELSE [Br].[Name] END AS [Name],  
			[Br].[Number],  
			[Br].[Security],  
			[fn].[Level] ,  
			[fn].[Path]  
		FROM  
			[vtBr] as [br] INNER JOIN [dbo].[fnGetBranchesListSorted]( 0x0, 1) AS [fn]  
			ON [Br].[Guid] = [fn].[Guid] 

	EXEC [prcCheckSecurity]
	SELECT * FROM [#Result] ORDER BY [Path]  
	SELECT * FROM [#SecViol]
#########################################################
#END