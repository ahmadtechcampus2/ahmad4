############################
CREATE FUNCTION fnGetCostsListWithLevel( @CostGUID [UNIQUEIDENTIFIER], @Sorted [INT] = 0 /* 0: without sort, 1:Sort By Cod, 2:Sort By Name*/)
	RETURNS @Result TABLE ([GUID] [UNIQUEIDENTIFIER], [Level] [INT] DEFAULT 0, [Path] [NVARCHAR](max) COLLATE ARABIC_CI_AI) 
AS BEGIN
	IF @Sorted = 0
	BEGIN
		DECLARE @FatherBuf	TABLE([GUID] [UNIQUEIDENTIFIER], [OK] [BIT], [Level] [INT])
		DECLARE @SonsBuf	TABLE([GUID] [UNIQUEIDENTIFIER])
		DECLARE
			@Continue [INT],
			@Level [INT]
	
		SET @Level = 0
		SET @CostGUID = ISNULL(@CostGUID, 0x0)
	
		IF @CostGUID = 0x0
			INSERT INTO @FatherBuf SELECT [coGUID], 0, @Level FROM [vwco] WHERE (([coParent] IS NULL) OR ([coParent] = 0x0))
		ELSE BEGIN 
			DECLARE @Type [INT]
			SET @Type = 0

			SELECT @Type = [Type] FROM [Co000] WHERE [Guid] = @CostGUID
			IF (@Type = 0) 
				INSERT INTO @FatherBuf SELECT [coGUID], 0, @Level FROM [vwCo] WHERE [coGUID] = @CostGUID
			ELSE
			IF(@Type = 1)
				INSERT INTO @FatherBuf SELECT [SonGUID], 0, @Level FROM [CostItem000] WHERE [ParentGUID] = @CostGUID 
		END 
		SET @Continue = 1

		IF (@CostGUID = 0x0)
		BEGIN
			WHILE @Continue <> 0
			BEGIN
				SET @Level = @Level + 1
	
				INSERT INTO @SonsBuf
					SELECT [co].[coGUID]
					FROM [vwCo] AS [co] INNER JOIN @FatherBuf AS [fb] ON [co].[coParent] = [fb].[GUID]
					WHERE [fb].[OK] = 0
	
				SET @Continue = @@ROWCOUNT
	
				UPDATE @FatherBuf SET [OK] = 1 WHERE [OK] = 0
				INSERT INTO @FatherBuf SELECT [GUID], 0, @Level FROM @SonsBuf
	
				DELETE FROM @SonsBuf
			END
	
			INSERT INTO @Result SELECT [GUID], [Level], '' FROM @FatherBuf GROUP BY [GUID], [Level]
	
		END ELSE BEGIN
			WHILE @Continue <> 0
			BEGIN
				SET @Level = @Level + 1
				INSERT INTO @SonsBuf
					SELECT [coGUID]
					FROM [vwCo] AS [co] INNER JOIN @FatherBuf AS [fb] ON [co].[coParent] = [fb].[GUID]
					WHERE [fb].[OK] = 0
	
				SET @Continue = @@ROWCOUNT
	
				UPDATE @FatherBuf SET [OK] = 1 WHERE [OK] = 0
	
				INSERT INTO @FatherBuf
					SELECT [GUID], 0, @Level
					FROM @SonsBuf
	
				DELETE FROM @SonsBuf
			END
			INSERT INTO @Result SELECT [GUID], [Level], '' FROM @FatherBuf GROUP BY [GUID], [Level]
		END
	END
	ELSE
	BEGIN
		DECLARE @FatherBuf_S	TABLE([GUID] [UNIQUEIDENTIFIER], [OK] [BIT], [Level] [INT], [Path] [NVARCHAR](max) COLLATE ARABIC_CI_AI, [ID] [INT] IDENTITY( 1, 1)) 
		DECLARE @SonsBuf_S	TABLE([GUID] [UNIQUEIDENTIFIER], [Path] [NVARCHAR](max) COLLATE ARABIC_CI_AI, [ID] [INT] IDENTITY( 1, 1)) 
		DECLARE 
			@Continue_S [INT], 
			@Level_S [INT]
		SET @Level_S = 0 
		
		SET @CostGUID = ISNULL(@CostGUID, 0x0) 
		IF @CostGUID = 0x0 
			INSERT INTO @FatherBuf_S ([GUID] , [OK], [Level], [Path] ) SELECT [coGUID], 0, @Level_S , '' FROM [vwCo] WHERE (([coParent] IS NULL) OR ([coParent] = 0x0)) ORDER BY CASE @Sorted WHEN 1 THEN [coCode] ELSE [coName] END
		ELSE BEGIN 
			DECLARE @CoType [INT]
			SET @CoType = 0

			SELECT @CoType = [Type] FROM [Co000] WHERE [Guid] = @CostGUID
			IF (@CoType = 0) 
				INSERT INTO @FatherBuf_S ([GUID] , [OK] , [Level], [Path] ) SELECT [coGUID], 0, @Level_S, '' FROM [vwCo] WHERE [coGUID] = @CostGUID ORDER BY CASE @Sorted WHEN 1 THEN [coCode] ELSE [coName] END
			ELSE
			IF (@CoType = 1)
				INSERT INTO @FatherBuf_S ([GUID] , [OK] , [Level], [Path] ) 
				SELECT co.[coGUID], 0, @Level_S, '' 
				FROM
					[CostItem000] coi 
					INNER JOIN [vwCo] co ON coi.[SonGUID] = co.coGUID
				WHERE coi.ParentGUID = @CostGUID 
				ORDER BY CASE @Sorted WHEN 1 THEN co.[coCode] ELSE co.[coName] END
		END 
		
		UPDATE @FatherBuf_S  SET [Path] = CAST( ( 0.0000001 * [ID]) AS [NVARCHAR](40))
	
		SET @Continue_S = 1
		IF (@CostGUID = 0x0)
		BEGIN
			WHILE @Continue_S <> 0
			BEGIN
				SET @Level_S = @Level_S + 1
				INSERT INTO @SonsBuf_S( [GUID], [Path]) SELECT [co].[coGUID], [fb].[Path]
					FROM [vwCo] AS [co] INNER JOIN @FatherBuf_S AS [fb] ON [co].[coParent] = [fb].[GUID]
					WHERE fb.[OK] = 0 
					ORDER BY CASE @Sorted WHEN 1 THEN [coCode] ELSE [coName] END
				SET @Continue_S = @@ROWCOUNT 
				UPDATE @FatherBuf_S SET [OK] = 1 WHERE [OK] = 0 
				INSERT INTO @FatherBuf_S SELECT [GUID], 0, @Level_S ,[Path] FROM @SonsBuf_S
				UPDATE @FatherBuf_S  SET [Path] = [Path] + CAST( ( 0.0000001 * [ID]) AS [NVARCHAR](40))  WHERE [OK]= 0 
				DELETE FROM @SonsBuf_S 
			END 
			INSERT INTO @Result SELECT [GUID], [Level] ,[Path] FROM @FatherBuf_S GROUP BY [GUID], [Level], [Path] ORDER BY [Path]
		END ELSE BEGIN 
			WHILE @Continue_S <> 0 
			BEGIN 
				SET @Level_S = @Level_S + 1 
				INSERT INTO @SonsBuf_S([GUID] , [Path]) SELECT [coGUID], [fb].[Path]
					FROM [vwCo] AS [co] INNER JOIN @FatherBuf_S AS [fb] ON [co].[coParent] = [fb].[GUID]
					WHERE [fb].[OK] = 0
					ORDER BY CASE @Sorted WHEN 1 THEN [coCode] ELSE [coName] END
				SET @Continue_S = @@ROWCOUNT 
				UPDATE @FatherBuf_S SET [OK] = 1 WHERE [OK] = 0 
				INSERT INTO @FatherBuf_S 
					SELECT [GUID], 0, @Level_S, [Path] 
					FROM @SonsBuf_S 
				UPDATE @FatherBuf_S  SET [Path] = [Path] + CAST( ( 0.0000001 * [ID]) AS [NVARCHAR](40))  WHERE [OK] = 0 
				DELETE FROM @SonsBuf_S 
			END 
			INSERT INTO @Result SELECT [GUID], [Level], [Path] FROM @FatherBuf_S GROUP BY [GUID], [Level], [Path] ORDER BY [Path]
		END 
	END
	RETURN
END
/*
select f.guid, f.level, co.name, co.code from fnGetCostsListWithLevel( 0x0, 2) as f inner join co000 as co on f.guid = co.guid 
*/
#########################################
#END