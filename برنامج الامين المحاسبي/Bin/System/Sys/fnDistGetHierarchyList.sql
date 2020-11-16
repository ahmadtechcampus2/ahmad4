########################################
## fnDistGetHierarchyList
CREATE FUNCTION fnDistGetHierarchyList(  
	@RouteCount INT, 
	@Sorted INT = 0 /* 0: without sort, 1:Sort By Cod, 2:Sort By Name*/) 
RETURNS @Result TABLE (GUID UNIQUEIDENTIFIER, Number float, Type int/*1:Hi,2:Distributor*/, [Level] INT DEFAULT 0, [Path] NVARCHAR(max) COLLATE ARABIC_CI_AI)    
AS BEGIN   
		DECLARE @FatherBuf_S	TABLE(GUID UNIQUEIDENTIFIER, Number float, Type int/*1:Hi,2:Distributor*/, Level INT, [Path] NVARCHAR(max), ID INT IDENTITY( 1, 1))    
		DECLARE  @Continue_S INT, @Level_S INT   
		SET @Level_S = 0    
		   
		INSERT INTO @FatherBuf_S (GUID , Number, Type, Level, [Path])  
			SELECT GUID, 0, 1, @Level_S , ''  FROM vwDistHi WHERE ((ParentGUID IS NULL) OR (ParentGUID = 0x0))  
			ORDER BY CASE @Sorted WHEN 1 THEN Code ELSE Name END   
		   
		UPDATE @FatherBuf_S  SET [Path] = CAST( ( 0.0000001 * ID) AS NVARCHAR(40))    
	   
		-- for Route ----
		DECLARE @Route	TABLE(GUID UNIQUEIDENTIFIER , Number float) 
		DECLARE @RouteNum float 
		DECLARE @g uniqueidentifier 
		SET @RouteNum = 0; 
		while (@RouteNum < @RouteCount) 
		begin 
			SET @RouteNum = @RouteNum + 1 
			SET @g = 0x0 
			INSERT INTO @Route VALUES(@g, @RouteNum) 
		end
		----------------
		SET @Continue_S = 1    
		WHILE @Continue_S <> 0    
		BEGIN    
			---- Supervisors
			SET @Level_S = @Level_S + 1    
			INSERT INTO @FatherBuf_S(GUID, Number, Type, Level, [Path]) 
				SELECT   
					hi.GUID, 0, 1, @Level_S, fb.[Path]   
				FROM   
					vwDistHi AS hi INNER JOIN @FatherBuf_S AS fb   
					ON hi.ParentGUID = fb.GUID    
				WHERE   
					fb.Level = @Level_S - 1    
				ORDER BY   
					CASE @Sorted WHEN 1 THEN Code ELSE Name END   
			SET @Continue_S = @@ROWCOUNT    
			UPDATE @FatherBuf_S  SET [Path] = [Path] + CAST( ( 0.0000001 * ID) AS NVARCHAR(40))  WHERE [Level] = @Level_S

			---- Distributors
			INSERT INTO @FatherBuf_S(GUID, Number, Type, Level, [Path]) 
				SELECT 
					di.GUID, 0, 2, @Level_S, fb.[Path] 
				FROM   
					vwDistributor AS di INNER JOIN @FatherBuf_S AS fb   
					ON di.HierarchyGUID = fb.GUID    
				WHERE
					fb.Level = @Level_S - 1    

			SET @Continue_S = @Continue_S + @@ROWCOUNT    
			UPDATE @FatherBuf_S  SET [Path] = [Path] + CAST( ( 0.0000001 * ID) AS NVARCHAR(40))  WHERE [Level] = @Level_S
			---- Routes
			SET @Level_S = @Level_S
			INSERT INTO @FatherBuf_S(GUID, Number, Type, Level, [Path]) 
				SELECT 
					fb.GUID, r.Number, 4, @Level_S + 1, fb.[Path] 
				FROM   
					@Route AS r CROSS JOIN @FatherBuf_S AS fb   
				WHERE 
					fb.Type = 2 AND
					fb.Level = @Level_S

			UPDATE @FatherBuf_S  SET [Path] = [Path] + CAST( ( 0.0000001 * ID) AS NVARCHAR(40))  WHERE [Level] = @Level_S + 1
		END    
		INSERT INTO @Result SELECT GUID, Number, Type, [Level], [Path] FROM @FatherBuf_S GROUP BY GUID, Number, Type, [Level], [Path] ORDER BY [Path]  
		RETURN 
END 
########################################
## fnGetHierarchyList
CREATE FUNCTION fnGetHierarchyList( 
	@HierarchyGuid UNIQUEIDENTIFIER,
	@Sorted INT = 0 /* 0: without sort, 1:Sort By Cod, 2:Sort By Name*/)
RETURNS @Result TABLE (GUID UNIQUEIDENTIFIER,  [Level] INT DEFAULT 0, [Path] NVARCHAR(max) COLLATE ARABIC_CI_AI) 
AS BEGIN  
	IF @Sorted = 0  
	BEGIN  
		---- 
		DECLARE @Continue INT, @Level INT  
		DECLARE @FatherBuf TABLE( GUID UNIQUEIDENTIFIER, Level INT)  
		SET @Level = 0  
		SET @HierarchyGuid = ISNULL(@HierarchyGuid, 0x0) 
		IF @HierarchyGuid = 0x0  
			INSERT INTO @FatherBuf SELECT GUID, @Level FROM vwDistHi WHERE ((ParentGuid IS NULL) OR (ParentGuid = 0x0)) 
		ELSE  
			INSERT INTO @FatherBuf SELECT GUID, @Level FROM vwDistHi WHERE GUID = @HierarchyGuid  
				 
		SET @Continue = 1  
		
		WHILE @Continue <> 0  
		BEGIN  
			SET @Level = @Level + 1  
			INSERT INTO @FatherBuf  
				SELECT  
					hi.GUID,  @Level 
				FROM  
					vwDistHi AS hi INNER JOIN @FatherBuf AS fb  
					ON hi.ParentGuid = fb.GUID  
				WHERE  
					fb.Level = @Level -1 
	 		SET @Continue = @@ROWCOUNT  
		END 
		INSERT INTO @Result SELECT [GUID], [Level], '' FROM @FatherBuf GROUP BY GUID, [Level]  
	END 
	ELSE 
	BEGIN 
		DECLARE @FatherBuf_S	TABLE(GUID UNIQUEIDENTIFIER, Level INT, [Path] NVARCHAR(max), ID INT IDENTITY( 1, 1))   
		DECLARE  @Continue_S INT, @Level_S INT  
		SET @Level_S = 0   
		  
		SET @HierarchyGuid = ISNULL(@HierarchyGuid, 0x0)   
		IF @HierarchyGuid = 0x0   
			INSERT INTO @FatherBuf_S (GUID , Level, [Path]) SELECT GUID,  @Level_S , ''  FROM vwDistHi WHERE ((ParentGuid IS NULL) OR (ParentGuid = 0x0))  ORDER BY CASE @Sorted WHEN 1 THEN Code ELSE Name END  
		ELSE   
			INSERT INTO @FatherBuf_S (GUID ,  Level, [Path]) SELECT GUID, @Level_S, '' FROM vwDistHi WHERE GUID = @HierarchyGuid ORDER BY CASE @Sorted WHEN 1 THEN Code ELSE Name END  
		  
		UPDATE @FatherBuf_S  SET [Path] = CAST( ( 0.0000001 * ID) AS NVARCHAR(40))   
	  
		SET @Continue_S = 1   
		 
		WHILE @Continue_S <> 0   
		BEGIN   
			SET @Level_S = @Level_S + 1   
			INSERT INTO @FatherBuf_S(GUID,Level,[Path])  
					SELECT  
						hi.GUID, @Level_S,fb.[Path]  
					FROM  
						vwDistHi AS hi INNER JOIN @FatherBuf_S AS fb  
						ON hi.ParentGuid = fb.GUID   
					WHERE  
						fb.Level = @Level_S - 1   
					ORDER BY  
						CASE @Sorted WHEN 1 THEN Code ELSE Name END  
			SET @Continue_S = @@ROWCOUNT   
			UPDATE @FatherBuf_S  SET [Path] = [Path] + CAST( ( 0.0000001 * ID) AS NVARCHAR(40))  WHERE [Level] = @Level_S 
			  
		END 
		INSERT INTO @Result SELECT GUID, [Level],[Path] FROM @FatherBuf_S GROUP BY GUID, [Level],[Path]  ORDER BY [Path]
	END 
	RETURN  
END 
#############################
#END
