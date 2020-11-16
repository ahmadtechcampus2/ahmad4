#######################################################
CREATE FUNCTION fnGetBranchesList(  
			@BrGUID UNIQUEIDENTIFIER, 
			@Sorted INT = 0 /* 0: without sort, 1:Sort By Cod, 2:Sort By Name*/) 
		RETURNS @Result TABLE (GUID UNIQUEIDENTIFIER, [Level] INT DEFAULT 0, [Path] NVARCHAR(max) COLLATE ARABIC_CI_AI)  
AS BEGIN 
	DECLARE @FatherBuf TABLE( GUID UNIQUEIDENTIFIER, [Level] INT, [Path] NVARCHAR(max) COLLATE ARABIC_CI_AI, ID INT IDENTITY( 1, 1))  
	DECLARE @Continue INT, @Level INT   
	SET @Level = 0    
	 
	
	IF ISNULL( @BrGUID, 0x0) = 0x0  
		INSERT INTO @FatherBuf ( GUID, Level, [Path]) 
			SELECT brGUID, @Level, '' FROM vwBr WHERE ISNULL( brParentGuid, 0x0) = 0x0 ORDER BY CASE @Sorted WHEN 1 THEN brCode ELSE brName END
	ELSE  
		INSERT INTO @FatherBuf ( GUID, Level, [Path]) 
			SELECT brGUID, @Level, '' FROM vwBr WHERE brGUID = @BrGUID
	 
	UPDATE @FatherBuf SET [Path] = CAST( ( 0.0000001 * ID) AS NVARCHAR(40))  
	SET @Continue = 1  
	---/////////////////////////////////////////////////////////////  
	WHILE @Continue <> 0    
	BEGIN  
		SET @Level = @Level + 1    
		INSERT INTO @FatherBuf( GUID, Level, [Path])  
			SELECT br.brGUID, @Level, fb.[Path] 
				FROM vwBr AS Br INNER JOIN @FatherBuf AS fb ON Br.brParentGuid = fb.GUID 
				WHERE fb.Level = @Level - 1
				ORDER BY CASE @Sorted WHEN 1 THEN brCode ELSE brName END 
			SET @Continue = @@ROWCOUNT    

			UPDATE @FatherBuf  SET [Path] = [Path] + CAST( ( 0.0000001 * ID) AS NVARCHAR(40))  WHERE [Level] = @Level    
	END 
	INSERT INTO @Result SELECT GUID, [Level], [Path] FROM @FatherBuf GROUP BY GUID, [Level], [Path] ORDER BY [Path]
	RETURN 
END
#######################################################
#END