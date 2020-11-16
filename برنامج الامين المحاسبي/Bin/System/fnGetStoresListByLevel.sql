#########################################################
CREATE FUNCTION fnGetStoresListByLevel(@StoreGUID  [UNIQUEIDENTIFIER], @Level [INT] = 0)
   RETURNS @Result TABLE ([GUID]  [UNIQUEIDENTIFIER], [Level] [INT])
BEGIN
	DECLARE @Init TABLE(Guid UNIQUEIDENTIFIER, Level INT);

	IF @Level = 0 SET @Level = POWER(2, 16) - 1;

	IF @StoreGUID = 0x0
		INSERT INTO @Init SELECT stGUID, 1 FROM vwSt WHERE stParent = 0x0 AND stKind = 0;
	ELSE IF EXISTS(SELECT * FROM sti000 WHERE ParentGuid = @StoreGUID)
		BEGIN
			WITH C AS
			(
				SELECT @StoreGUID AS Guid, 1 AS Level
				UNION ALL
				SELECT S.StoreGuid, 1
				FROM C JOIN sti000 S ON C.Guid = S.ParentGuid
			)
			INSERT INTO @Init SELECT * FROM C;
		END 
	ELSE
		INSERT INTO @Init VALUES(@StoreGUID, 1);

	WITH C AS
	(
		SELECT Guid, Level FROM @Init
		UNION ALL
		SELECT S.stGUID, C.Level + 1
		FROM C JOIN vwSt S ON C.Guid = S.stParent
		WHERE C.Level < @Level
	)
	INSERT INTO @Result SELECT * FROM C;

	RETURN;
END
 /*
	Commented out by Ziad Abdel Majeed
	 
  This Function Returns the List of stres with level  
  This means that if We call the function with storeGuid and level  
   returns the list of stores from the the store with storeGuid unit stores follow  
   this store which have level @Level 
  If the StoreGuid is Null retun the List of stores from Start to level @Level 
     
 
BEGIN  
	DECLARE @FatherBuf	TABLE([GUID] [UNIQUEIDENTIFIER], [Level] [INT],  [OK] [BIT])  
	DECLARE @SonsBuf	TABLE([GUID] [UNIQUEIDENTIFIER], [LEVEL] [INT])  
	 
	DECLARE @Continue       [INT]  
     
	IF (@StoreGUID=0X0)  
		INSERT INTO @FatherBuf  SELECT [stGUID], 1,0 FROM [vwSt] WHERE [stParent]=0X0 
	ELSE 
		INSERT INTO @FatherBuf SELECT [stGUID], 1,0 FROM [vwSt] WHERE [stGUID] = @StoreGUID 
    
	SET @Continue = 2  
	WHILE (@Continue <=@Level OR @Level=0) 
	BEGIN 
		INSERT INTO @SonsBuf  
		    SELECT [stGUID] ,@Continue 
				FROM [vwSt] AS [st] INNER JOIN @FatherBuf AS [fb] ON [st].[stParent] = [fb].[GUID]  
				WHERE [fb].[OK] = 0  
		IF NOT EXISTS(SELECT * FROM @SonsBuf)  
			BREAK 
		SET @Continue =  @Continue + 1 
		UPDATE @FatherBuf SET  
	        [OK] = 1 WHERE [OK] = 0    
		INSERT INTO @FatherBuf  
			SELECT [GUID],[LEVEL],0 FROM @SonsBuf  
                 
		DELETE FROM @SonsBuf  
	END  
	INSERT INTO @Result SELECT [GUID], [LEVEL] FROM @FatherBuf 
	RETURN   
END*/

#########################################################
#END