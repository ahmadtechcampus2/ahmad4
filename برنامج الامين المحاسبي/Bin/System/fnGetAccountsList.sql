######################################################################################################################################################
CREATE FUNCTION fnGetAccountsList( @AccGUID [UNIQUEIDENTIFIER], @Sorted [INT] = 0 /* 0: without sort, 1:Sort By Cod, 2:Sort By Name*/) 
	RETURNS @Result TABLE ([GUID] [UNIQUEIDENTIFIER], [Level] [INT] DEFAULT 0, [Path] [NVARCHAR](max) COLLATE ARABIC_CI_AI)  
AS BEGIN 
	IF @Sorted = 0 
	BEGIN 
		----
		DECLARE @Continue [INT], @Level [INT] 
		DECLARE @FatherBuf TABLE( [GUID] [UNIQUEIDENTIFIER], [Type] [INT], [Level] [INT]) 
		SET @Level = 0 
		SET @AccGUID = ISNULL(@AccGUID, 0x0)

		IF @AccGUID = 0x0 
		BEGIN
			INSERT INTO @FatherBuf SELECT [ac1].[acGUID], [ac1].[acType], @Level FROM [vwAc] [ac1] WHERE ( ISNULL( [ac1].[acParent], 0x0) = 0x0) AND ( [ac1].[acType] = 1 OR [ac1].[acType] = 2)

			INSERT INTO @FatherBuf SELECT [ac1].[acGuid], [ac1].[acType], @Level
			FROM 
				[vwAc] [ac1]
				LEFT JOIN [vwAc] [ac2] ON [ac1].[acParent] = [ac2].[acGuid]
				LEFT JOIN @FatherBuf [f] ON [ac1].[acGuid] = [f].[Guid] 
			WHERE 
				ISNULL( [ac1].[acParent], 0x0) != 0x0
				AND [ac2].[acGuid] IS NULL
				AND [f].[Guid]IS NULL
		END
		ELSE 
			INSERT INTO @FatherBuf SELECT [acGUID], [acType], @Level FROM [vwAc] WHERE [acGUID] = @AccGUID 
				

		SET @Continue = 1 
		IF (@AccGUID = 0x0) OR ((SELECT [acType] FROM [vwAc] WHERE [acGUID] = @AccGUID) = 1) 
		BEGIN
			WHILE @Continue <> 0 
			BEGIN 
				SET @Level = @Level + 1 
				INSERT INTO @FatherBuf 
					SELECT 
						[ac].[acGUID], [ac].[acType], @Level
					FROM 
						[vwAc] AS [ac] INNER JOIN @FatherBuf AS [fb] 
						ON [ac].[acParent] = [fb].[GUID] 
					WHERE 
						[fb].[Level] = @Level -1
	 			SET @Continue = @@ROWCOUNT 
			END
		END
		ELSE
		BEGIN
			WHILE @Continue <> 0 
			BEGIN 
				SET @Level = @Level + 1 
				INSERT INTO @FatherBuf
					SELECT 
						[acGUID], [acType], @Level 
					FROM 
						[vwAc] AS [ac] INNER JOIN @FatherBuf AS [fb] 
						ON [ac].[acParent] = [fb].[GUID] 
					WHERE 
						[fb].[Level] = @Level - 1 
	 
				SET @Continue = @@ROWCOUNT 
				INSERT INTO @FatherBuf 
					SELECT 
						[ci].[SonGUID], [Ac].[acType], @Level
					FROM 
						[ci000] AS [ci] INNER JOIN [vwac] AS [Ac]
						ON [ci].[SonGUID] = [Ac].[acGUID] 
						INNER JOIN @FatherBuf AS [fb] 
						ON [ci].[ParentGUID] = [fb].[GUID]
					WHERE 
						[fb].[Type] = 4 and [fb].[Level] = @Level -1 
	 
				SET @Continue = @Continue + @@ROWCOUNT 
			END
		END
		INSERT INTO @Result SELECT [GUID], [Level], '' FROM @FatherBuf GROUP BY [GUID], [Level] 
	END
	ELSE
	BEGIN
		DECLARE @FatherBuf_S	TABLE([GUID] [UNIQUEIDENTIFIER], [Type] [INT], [Level] [INT], [Path] [NVARCHAR](max) COLLATE ARABIC_CI_AI, [ID] [INT] IDENTITY( 1, 1))  
		DECLARE  @Continue_S [INT], @Level_S [INT] 
		SET @Level_S = 0  
		 
		SET @AccGUID = ISNULL(@AccGUID, 0x0)  
		IF @AccGUID = 0x0  
		BEGIN
			INSERT INTO @FatherBuf_S ( [GUID], [Type], [Level], [Path]) SELECT [ac1].[acGUID], [ac1].[acType], @Level_S, ''  FROM [vwAc] [ac1] WHERE ( ISNULL( [ac1].[acParent], 0x0) = 0x0 ) AND ( [ac1].[acType] = 1 OR [ac1].[acType] = 2) ORDER BY CASE @Sorted WHEN 1 THEN [ac1].[acCode] WHEN 2 THEN  [ac1].[acName] ELSE [ac1].[acLatinName] END
			INSERT INTO @fatherBuf_s ( [GUID], [Type], [Level], [Path]) SELECT [ac1].[acGuid], [ac1].[acType], @Level_S, '' 
			FROM 
				[vwAc] [ac1]
				LEFT JOIN [vwAc] [ac2] ON [ac1].[acParent] = [ac2].[acGuid]
				LEFT JOIN @fatherBuf_s [f] ON [ac1].[acGuid] = [f].[Guid] 
			WHERE 
				ISNULL( [ac1].[acParent], 0x0) != 0x0
				AND [ac2].[acGuid] IS NULL
				AND [f].[Guid]IS NULL
			ORDER BY 
				CASE @Sorted WHEN 1 THEN [ac1].[acCode] ELSE [ac1].[acName] END
		END
		ELSE  
			INSERT INTO @FatherBuf_S ([GUID] , [Type] , [Level], [Path]) SELECT [acGUID], [acType], @Level_S, '' FROM [vwAc] WHERE [acGUID] = @AccGUID ORDER BY CASE @Sorted WHEN 1 THEN [acCode] ELSE [acName] END 
		 
		UPDATE @FatherBuf_S  SET [Path] = CAST( ( 0.0000001 * ID) AS [NVARCHAR](40))  
	 
		SET @Continue_S = 1  

		IF (@AccGUID = 0x0) OR ((SELECT [acType] FROM [vwAc] WHERE [acGUID] = @AccGUID) = 1)  
		BEGIN  
			WHILE @Continue_S <> 0  
			BEGIN  
				SET @Level_S = @Level_S + 1  
				INSERT INTO @FatherBuf_S([GUID],[Type],[Level],[Path]) 
					SELECT 
						[ac].[acGUID], [ac].[acType],@Level_S,[fb].[Path] 
					FROM 
						[vwAc] AS [ac] INNER JOIN @FatherBuf_S AS [fb] 
						ON [ac].[acParent] = [fb].[GUID]  
					WHERE 
						[fb].[Level] = @Level_S - 1  
					ORDER BY 
						CASE @Sorted WHEN 1 THEN [acCode] ELSE [acName] END 
				SET @Continue_S = @@ROWCOUNT  
				UPDATE @FatherBuf_S  SET [Path] = [Path] + CAST( ( 0.0000001 * [ID]) AS NVARCHAR(40))  WHERE [Level] = @Level_S
			END  
		END 
		ELSE 
		BEGIN  
			WHILE @Continue_S <> 0  
			BEGIN  
				SET @Level_S = @Level_S + 1  
				INSERT INTO @FatherBuf_S([GUID], [Type], [Level], [Path]) 
					SELECT 
						[acGUID],[acType],@Level_S,[fb].[Path] 
					FROM 
						[vwAc] AS [ac] INNER JOIN @FatherBuf_S AS [fb] 
						ON [ac].[acParent] = [fb].[GUID]  
					WHERE 
						[fb].[Level] = @Level_S - 1 
					ORDER BY 
						CASE @Sorted WHEN 1 THEN [acCode] ELSE [acName] END 

				SET @Continue_S = @@ROWCOUNT  
				INSERT INTO @FatherBuf_S ([GUID], [Type], [Level], [Path]) 
					SELECT 
						[SonGUID],[acType],@Level_S, [fb].[Path] 
					FROM 	
						[ci000] AS [ci] INNER JOIN [vwac]
						ON [ci].[SonGUID] = [vwAc].[acGUID] 
						INNER JOIN @FatherBuf_S AS [fb] 
						ON [ci].[ParentGUID] = [fb].[GUID] 
					WHERE 
						[fb].[Type] = 4 and [fb].[Level] = @Level_S - 1  
					ORDER BY 
						CASE @Sorted WHEN 1 THEN [acCode] ELSE [acName] END 

				SET @Continue_S = @Continue_S + @@ROWCOUNT  
				UPDATE @FatherBuf_S  SET [Path] = [Path] + CAST( ( 0.0000001 * ID) AS [NVARCHAR](40))  WHERE [Level] = @Level_S
			END  
		END  
		INSERT INTO @Result SELECT [GUID], [Level], [Path] FROM @FatherBuf_S GROUP BY [GUID], [Level], [Path] ORDER BY [Path]
	END	
--		DELETE r FROM @Result AS r (SELECT GUID ,MAX ([Path]) AS [Path] FROM @Result GROUP BY [Guid] HAVING COUNT(*) > 1) AS r2 ON r.Guid = r2.Guid NAD r.Path = r2.Path
	RETURN 
END
###########################################################################
CREATE FUNCTION fnGetDAcc(@mainAcc UNIQUEIDENTIFIER) 
RETURNS UNIQUEIDENTIFIER 
AS
BEGIN
	IF ISNULL(@mainAcc,0x0) = 0x0  RETURN 0x0
	IF EXISTS(SELECT GUID FROM vbAc WHERE ((type = 1 AND NSons = 0) OR type = 8) AND GUID = @mainAcc) 
		RETURN @mainAcc
	RETURN ( [dbo].fnGetDAcc( (SELECT TOP 1 GUID FROM fnGetAccountsList(@mainAcc,1)  WHERE Level > 0)))  
END
############################################################################
CREATE FUNCTION fnGetAccountsListWitthComppositAndCostAccounts ( @AccGUID [UNIQUEIDENTIFIER], @Sorted [INT] = 0/* 0: without sort, 1:Sort By Cod, 2:Sort By Name*/) 
	RETURNS @Result TABLE ([GUID] [UNIQUEIDENTIFIER], [Level] [INT] DEFAULT 0, [Path] [NVARCHAR](max) COLLATE ARABIC_CI_AI)  
AS BEGIN 
	IF @Sorted = 0 
	BEGIN 
		----
		DECLARE @Continue [INT], @Level [INT] 
		DECLARE @FatherBuf TABLE( [GUID] [UNIQUEIDENTIFIER], [Type] [INT], [Level] [INT]) 
		SET @Level = 0 
		SET @AccGUID = ISNULL(@AccGUID, 0x0)
		IF @AccGUID = 0x0 
		BEGIN
			INSERT INTO @FatherBuf SELECT [ac1].[acGUID], [ac1].[acType], @Level FROM [vwAc] [ac1] WHERE ( ISNULL( [ac1].[acParent], 0x0) = 0x0)
			INSERT INTO @FatherBuf SELECT [ac1].[acGuid], [ac1].[acType], @Level
			FROM 
				[vwAc] [ac1]
				LEFT JOIN [vwAc] [ac2] ON [ac1].[acParent] = [ac2].[acGuid]
				LEFT JOIN @FatherBuf [f] ON [ac1].[acGuid] = [f].[Guid] 
			WHERE 
				ISNULL( [ac1].[acParent], 0x0) != 0x0
				AND [ac2].[acGuid] IS NULL
				AND [f].[Guid]IS NULL
		END
		ELSE 
			INSERT INTO @FatherBuf SELECT [acGUID], [acType], @Level FROM [vwAc] WHERE [acGUID] = @AccGUID 
				
		SET @Continue = 1 
		IF (@AccGUID = 0x0) OR ((SELECT [acType] FROM [vwAc] WHERE [acGUID] = @AccGUID) = 1) 
		BEGIN
			WHILE @Continue <> 0 
			BEGIN 
				SET @Level = @Level + 1 
				INSERT INTO @FatherBuf 
					SELECT 
						[ac].[acGUID], [ac].[acType], @Level
					FROM 
						[vwAc] AS [ac] INNER JOIN @FatherBuf AS [fb] 
						ON [ac].[acParent] = [fb].[GUID] 
					WHERE 
						[fb].[Level] = @Level -1
	 			SET @Continue = @@ROWCOUNT 
			END
		END
		ELSE
		BEGIN
			WHILE @Continue <> 0 
			BEGIN 
				SET @Level = @Level + 1 
				INSERT INTO @FatherBuf
					SELECT 
						[acGUID], [acType], @Level 
					FROM 
						[vwAc] AS [ac] INNER JOIN @FatherBuf AS [fb] 
						ON [ac].[acParent] = [fb].[GUID] 
					WHERE 
						[fb].[Level] = @Level - 1 
	 
				SET @Continue = @@ROWCOUNT 
				INSERT INTO @FatherBuf 
					SELECT 
						[ci].[SonGUID], [Ac].[acType], @Level
					FROM 
						[ci000] AS [ci] INNER JOIN [vwac] AS [Ac]
						ON [ci].[SonGUID] = [Ac].[acGUID] 
						INNER JOIN @FatherBuf AS [fb] 
						ON [ci].[ParentGUID] = [fb].[GUID]
					WHERE 
						[fb].[Level] = @Level -1 
	 
				SET @Continue = @Continue + @@ROWCOUNT 
			END
		END
		INSERT INTO @Result SELECT [GUID], [Level], '' FROM @FatherBuf GROUP BY [GUID], [Level] 
	END
	ELSE
	BEGIN
		DECLARE @FatherBuf_S	TABLE([GUID] [UNIQUEIDENTIFIER], [Type] [INT], [Level] [INT], [Path] [NVARCHAR](max) COLLATE ARABIC_CI_AI, [ID] [INT] IDENTITY( 1, 1))  
		DECLARE  @Continue_S [INT], @Level_S [INT] 
		SET @Level_S = 0  
		 
		SET @AccGUID = ISNULL(@AccGUID, 0x0)  
		IF @AccGUID = 0x0  
		BEGIN
			INSERT INTO @FatherBuf_S ( [GUID], [Type], [Level], [Path]) SELECT [ac1].[acGUID], [ac1].[acType], @Level_S, ''  FROM [vwAc] [ac1] WHERE ( ISNULL( [ac1].[acParent], 0x0) = 0x0 ) ORDER BY CASE @Sorted WHEN 1 THEN [ac1].[acCode] WHEN 2 THEN  [ac1].[acName] ELSE [ac1].[acLatinName] END
			INSERT INTO @fatherBuf_s ( [GUID], [Type], [Level], [Path]) SELECT [ac1].[acGuid], [ac1].[acType], @Level_S, '' 
			FROM 
				[vwAc] [ac1]
				LEFT JOIN [vwAc] [ac2] ON [ac1].[acParent] = [ac2].[acGuid]
				LEFT JOIN @fatherBuf_s [f] ON [ac1].[acGuid] = [f].[Guid] 
			WHERE 
				ISNULL( [ac1].[acParent], 0x0) != 0x0
				AND [ac2].[acGuid] IS NULL
				AND [f].[Guid]IS NULL
			ORDER BY 
				CASE @Sorted WHEN 1 THEN [ac1].[acCode] ELSE [ac1].[acName] END
		END
		ELSE  
			INSERT INTO @FatherBuf_S ([GUID] , [Type] , [Level], [Path]) SELECT [acGUID], [acType], @Level_S, '' FROM [vwAc] WHERE [acGUID] = @AccGUID ORDER BY CASE @Sorted WHEN 1 THEN [acCode] ELSE [acName] END 
		 
		UPDATE @FatherBuf_S  SET [Path] = CAST( ( 0.0000001 * ID) AS [NVARCHAR](40))  
	 
		SET @Continue_S = 1  
		IF (@AccGUID = 0x0) OR ((SELECT [acType] FROM [vwAc] WHERE [acGUID] = @AccGUID) = 1)  
		BEGIN  
			WHILE @Continue_S <> 0  
			BEGIN  
				SET @Level_S = @Level_S + 1  
				INSERT INTO @FatherBuf_S([GUID],[Type],[Level],[Path]) 
					SELECT 
						[ac].[acGUID], [ac].[acType],@Level_S,[fb].[Path] 
					FROM 
						[vwAc] AS [ac] INNER JOIN @FatherBuf_S AS [fb] 
						ON [ac].[acParent] = [fb].[GUID]  
					WHERE 
						[fb].[Level] = @Level_S - 1  
					ORDER BY 
						CASE @Sorted WHEN 1 THEN [acCode] ELSE [acName] END 
				SET @Continue_S = @@ROWCOUNT  
				UPDATE @FatherBuf_S  SET [Path] = [Path] + CAST( ( 0.0000001 * [ID]) AS NVARCHAR(40))  WHERE [Level] = @Level_S
			END  
		END 
		ELSE 
		BEGIN  
			WHILE @Continue_S <> 0  
			BEGIN  
				SET @Level_S = @Level_S + 1  
				INSERT INTO @FatherBuf_S([GUID], [Type], [Level], [Path]) 
					SELECT 
						[acGUID],[acType],@Level_S,[fb].[Path] 
					FROM 
						[vwAc] AS [ac] INNER JOIN @FatherBuf_S AS [fb] 
						ON [ac].[acParent] = [fb].[GUID]  
					WHERE 
						[fb].[Level] = @Level_S - 1 
					ORDER BY 
						CASE @Sorted WHEN 1 THEN [acCode] ELSE [acName] END 
				SET @Continue_S = @@ROWCOUNT  
				INSERT INTO @FatherBuf_S ([GUID], [Type], [Level], [Path]) 
					SELECT 
						[SonGUID],[acType],@Level_S, [fb].[Path] 
					FROM 	
						[ci000] AS [ci] INNER JOIN [vwac]
						ON [ci].[SonGUID] = [vwAc].[acGUID] 
						INNER JOIN @FatherBuf_S AS [fb] 
						ON [ci].[ParentGUID] = [fb].[GUID] 
					WHERE 
						[fb].[Level] = @Level_S - 1  
					ORDER BY 
						CASE @Sorted WHEN 1 THEN [acCode] ELSE [acName] END 
				SET @Continue_S = @Continue_S + @@ROWCOUNT  
				UPDATE @FatherBuf_S  SET [Path] = [Path] + CAST( ( 0.0000001 * ID) AS [NVARCHAR](40))  WHERE [Level] = @Level_S
			END  
		END  
		INSERT INTO @Result SELECT [GUID], [Level], [Path] FROM @FatherBuf_S GROUP BY [GUID], [Level], [Path] ORDER BY [Path]
	END	
--		DELETE r FROM @Result AS r (SELECT GUID ,MAX ([Path]) AS [Path] FROM @Result GROUP BY [Guid] HAVING COUNT(*) > 1) AS r2 ON r.Guid = r2.Guid NAD r.Path = r2.Path
	RETURN 
END
############################################################################
#END