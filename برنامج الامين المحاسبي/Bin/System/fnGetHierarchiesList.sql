#########################################################
CREATE FUNCTION fnGetHierarchiesList( @HiGUID [UNIQUEIDENTIFIER], @Sorted [INT] = 0 /* 0: without sort, 1:Sort By Cod, 2:Sort By Name*/)  
	RETURNS @Result TABLE ([GUID] [UNIQUEIDENTIFIER], [Level] [INT] DEFAULT 0)   
AS BEGIN 
/*
This function return the hierarchies list and the level of each hierarchy , you can sort 
the result by edit the second parameter .
*/
	DECLARE @Continue [INT], @Level [INT]  
	DECLARE @FatherBuf TABLE([GUID] [UNIQUEIDENTIFIER], [Level] [INT])  
	SET @Level = 0  
	SET @HiGUID = ISNULL(@HiGUID, 0x0) 
	IF @HiGUID = 0x0  
		INSERT INTO @FatherBuf SELECT [GUID], @Level FROM [DistHi000] WHERE (([ParentGUID] IS NULL) OR ([ParentGUID] = 0x0)) 
	ELSE  
		INSERT INTO @FatherBuf SELECT [GUID], @Level FROM [DistHi000] WHERE [GUID] = @HiGUID  

	SET @Continue = 1  
	IF (@HiGUID = 0x0) 
	BEGIN 
		WHILE @Continue <> 0  
		BEGIN  
			SET @Level = @Level + 1
			INSERT INTO @FatherBuf
				SELECT
					[hi].[GUID], @Level
				FROM
					[DistHi000] AS [hi] INNER JOIN @FatherBuf AS [fb]
					ON [hi].[ParentGUID] = [fb].[GUID]
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
					[hi].[GUID], @Level
				FROM
					[DistHi000] AS [hi] INNER JOIN @FatherBuf AS [fb]
					ON [hi].[ParentGUID] = [fb].[GUID]
				WHERE
					[fb].[Level] = @Level - 1

			SET @Continue = @@ROWCOUNT
		END
	END
	INSERT INTO @Result SELECT [GUID], [Level] FROM @FatherBuf GROUP BY [GUID], [Level]
	RETURN
END

#########################################################
#END 