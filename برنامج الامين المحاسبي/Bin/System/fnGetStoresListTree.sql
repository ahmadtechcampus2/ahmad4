#########################################################
CREATE   FUNCTION fnGetStoresListTree ( @stGUID [UNIQUEIDENTIFIER],@Sorted [INT]) 
	RETURNS @Result TABLE ([GUID] [UNIQUEIDENTIFIER], [Level] [INT] DEFAULT 0, [Path] [NVARCHAR](max) COLLATE ARABIC_CI_AI)  
BEGIN

	DECLARE @FatherBuf_S	TABLE([GUID] [UNIQUEIDENTIFIER], [OK] [BIT], [Level] [INT], [Path] [NVARCHAR](max) COLLATE ARABIC_CI_AI, [ID] [INT] IDENTITY( 1, 1))  
	DECLARE @SonsBuf_S	TABLE([GUID] [UNIQUEIDENTIFIER], [Path] [NVARCHAR](max) COLLATE ARABIC_CI_AI, [ID] [INT] IDENTITY( 1, 1))  

	DECLARE  
		@Continue_S [INT],  
		@Level_S [INT]
		

	SET @Level_S = 0  
	SET @StGuid = ISNULL(@stGUID, 0x0)  

	IF @StGuid = 0x0  
		INSERT INTO @FatherBuf_S ([GUID]  , [OK] , [Level], [Path] ) SELECT [stGUID], 0, @Level_S , ''  FROM [vwSt] WHERE (([stParent] IS NULL) OR ([stParent] = 0x0))  ORDER BY CASE @Sorted  WHEN 0 THEN [stCode] ELSE [stName] END 
	ELSE  
		INSERT INTO @FatherBuf_S ([GUID]  , OK , [Level], [Path] ) SELECT [stGUID], 0, @Level_S, '' FROM [vwSt] WHERE stGUID = @StGUID ORDER BY CASE @Sorted  WHEN 0 THEN [stCode] ELSE [stName] END
			 
		UPDATE @FatherBuf_S  SET [Path] = CAST( ( 0.0000001 * [ID]) AS [NVARCHAR](40))  
		 
	SET @Continue_S = 1  
	IF (@stGUID = 0x0)  
	BEGIN  
		WHILE @Continue_S <> 0  
		BEGIN  
			SET @Level_S = @Level_S + 1  
			INSERT INTO @SonsBuf_S([GUID],[Path]) SELECT [st].[stGUID], [fb].[Path] 
						FROM [vwSt] AS [st] INNER JOIN @FatherBuf_S AS [fb] ON [st].[stparent] = [fb].[GUID]  
						WHERE [fb].[OK] = 0  
						ORDER BY CASE @Sorted  WHEN 0 THEN [stCode] ELSE [stName] END 
			SET @Continue_S = @@ROWCOUNT  
			UPDATE @FatherBuf_S SET [OK] = 1 WHERE [OK] = 0  
			INSERT INTO @FatherBuf_S SELECT [GUID], 0, @Level_S , [Path] FROM @SonsBuf_S  
			UPDATE @FatherBuf_S  SET [Path] = [Path] + CAST( ( 0.0000001 * [ID]) AS [NVARCHAR](40))  WHERE [OK] = 0  
			DELETE FROM @SonsBuf_S  
		END  
			INSERT INTO @Result SELECT [GUID], [Level] , [Path] FROM @FatherBuf_S GROUP BY [GUID], [Level], [Path] ORDER BY [Path] 
	END ELSE BEGIN  
		WHILE @Continue_S <> 0  
		BEGIN  
			SET @Level_S = @Level_S + 1  
			INSERT INTO @SonsBuf_S([GUID] , [Path]) SELECT [stGUID],  [fb].[Path] 
					FROM [vwSt] AS [st] INNER JOIN @FatherBuf_S AS [fb] ON [st].[stParent] = [fb].[GUID]  
					WHERE [fb].[OK] = 0 
					ORDER BY [stCode]  
			SET @Continue_S = @@ROWCOUNT  
					
			--SET @Continue_S = @Continue_S + @@ROWCOUNT  --this line has no meaning at least for me , it caused "Bug 37439"
			UPDATE @FatherBuf_S SET [OK] = 1 WHERE [OK] = 0  
			INSERT INTO @FatherBuf_S  
			SELECT GUID, 0, @Level_S, [Path]  
						FROM @SonsBuf_S  
			UPDATE @FatherBuf_S  SET [Path] = [Path] + CAST( ( 0.0000001 * [ID]) AS [NVARCHAR](40))  WHERE [OK] = 0  
			DELETE FROM @SonsBuf_S  
		END  
		INSERT INTO @Result SELECT [GUID], [Level], [Path] FROM @FatherBuf_S GROUP BY GUID, [Level], [Path] ORDER BY [Path] 
	END  
		 
	RETURN 

END
#########################################################
#END
 