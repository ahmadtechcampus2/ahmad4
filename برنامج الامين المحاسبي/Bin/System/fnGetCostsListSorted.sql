#######################################################
CREATE FUNCTION fnGetCostsListSorted(  
			@CostGUID [UNIQUEIDENTIFIER], 
			@Sorted [INT] = 0 /* 0: without sort, 1:Sort By Cod, 2:Sort By Name*/) 
		RETURNS @Result TABLE ([GUID] [UNIQUEIDENTIFIER], [Level] [INT] DEFAULT 0, [Path] [NVARCHAR](max) COLLATE ARABIC_CI_AI)  
AS BEGIN 
	DECLARE @FatherBuf TABLE( [GUID] [UNIQUEIDENTIFIER], [Level] [INT], [Path] [NVARCHAR](max) COLLATE ARABIC_CI_AI , [ID] [INT] IDENTITY( 1, 1))  
	DECLARE @Continue [INT], @Level [INT]   
	SET @Level = 0    
	 
	
	IF ISNULL( @CostGUID, 0x0) = 0x0  
		INSERT INTO @FatherBuf ( [GUID], [Level], [Path]) 
			SELECT [coGUID], @Level, '' 
			FROM [vwCo] 
			WHERE ISNULL( [coParent], 0x0) = 0x0 AND [coType] = 0
			ORDER BY CASE @Sorted WHEN 1 THEN [coCode] ELSE [coName] END
	ELSE  
	BEGIN
	
		DECLARE @Type [INT]
		SET @Type = 0
		SELECT @Type = [Type] FROM [Co000] WHERE [Guid] = @CostGUID
		IF (@Type = 0)
			SELECT @Type = [Type] FROM [Co000] WHERE [Guid] = @CostGUID
		ELSE
		IF( @Type = 1 )
			INSERT INTO @FatherBuf ( [GUID], [Level], [Path])  
				SELECT [SonGUID], @Level, '' FROM [CostItem000] WHERE [ParentGUID] = @CostGUID 
	END	
	 
	UPDATE @FatherBuf SET [Path] = CAST( ( 0.0000001 * [ID]) AS [NVARCHAR](40))  
	SET @Continue = 1  
	---/////////////////////////////////////////////////////////////  
	WHILE @Continue <> 0    
	BEGIN  
		SET @Level = @Level + 1    
		INSERT INTO @FatherBuf( [GUID], [Level], [Path])  
			SELECT [Co].[coGUID], @Level, [fb].[Path] 
				FROM [vwCo] AS [co] INNER JOIN @FatherBuf AS [fb] ON [Co].[coParent] = [fb].[GUID] 
				WHERE [fb].[Level] = @Level - 1
				ORDER BY CASE @Sorted WHEN 1 THEN [coCode] ELSE [coName] END 
			SET @Continue = @@ROWCOUNT    

			UPDATE @FatherBuf  SET [Path] = [Path] + CAST( ( 0.0000001 * [ID]) AS [NVARCHAR](40))  WHERE [Level] = @Level    
	END 
	INSERT INTO @Result SELECT [GUID], [Level], [Path] FROM @FatherBuf GROUP BY [GUID], [Level], [Path] ORDER BY [Path]
	RETURN 
END
#######################################################
#END