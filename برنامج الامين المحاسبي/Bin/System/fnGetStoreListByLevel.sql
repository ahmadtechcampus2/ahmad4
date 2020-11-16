#########################################################
CREATE FUNCTION fnGetStoresListByLevel(@StoreGUID  UNIQUEIDENTIFIER, @Level INT = 0)
   RETURNS @Result TABLE (GUID  UNIQUEIDENTIFIER, Level INT)
 /*
  This Function Returns the List of stres with level 
  This means that if We call the function with storeGuid and level 
   returns the list of stores from the the store with storeGuid unit stores follow 
   this store which have level @Level
  If the StoreGuid is Null retun the List of stores from Start to level @Level
    
 */ 

BEGIN 
	DECLARE @FatherBuf	TABLE(GUID UNIQUEIDENTIFIER, Level INT,  OK BIT) 
	DECLARE @SonsBuf	TABLE(GUID UNIQUEIDENTIFIER, LEVEL INT) 
	
	DECLARE @Continue       INT 

    
	IF (@StoreGUID=0X0) 
		INSERT INTO @FatherBuf  SELECT stGUID, 1,0 FROM vwSt WHERE stParent=0X0
	ELSE
		INSERT INTO @FatherBuf SELECT stGUID, 1,0 FROM vwSt WHERE stGUID = @StoreGUID
   
	SET @Continue = 2 
	WHILE (@Continue <=@Level OR @Level=0)
	BEGIN
		INSERT INTO @SonsBuf 
		    SELECT stGUID ,@Continue
				FROM vwSt AS st INNER JOIN @FatherBuf AS fb ON st.stParent = fb.GUID 
				WHERE fb.OK = 0 
		IF NOT EXISTS(SELECT * FROM @SonsBuf) 
			BREAK
		SET @Continue =  @Continue + 1
		UPDATE @FatherBuf SET 
	        OK = 1 WHERE OK = 0   
		INSERT INTO @FatherBuf 
			SELECT GUID,LEVEL,0 FROM @SonsBuf 
                
		DELETE FROM @SonsBuf 
	END 
	INSERT INTO @Result SELECT GUID,LEVEL FROM @FatherBuf
	RETURN  
END
--prcConnections_add2 'ãÏíÑ'
--SELECT GUID,LEVEL,STnAME FROM fnGetStoreListByLevel('2CF1030B-ABEC-462B-9D82-1E9DDA64D7A9',1) INNER JOIN vwSt ON GUID=stGUID

#########################################################