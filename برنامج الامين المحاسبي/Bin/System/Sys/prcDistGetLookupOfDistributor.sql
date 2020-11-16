########################################
CREATE PROC prcDistGetLookupFlages
AS
	SET NOCOUNT ON     
	INSERT INTO PalmGUID     
	SELECT DISTINCT     
		l.GUID     
	FROM     
		DistLookup000 AS l LEFT JOIN PalmGUID AS pg ON pg.GUID = l.GUID     
	WHERE     
		pg.GUID IS NULL  
	CREATE TABLE #lookup(GUID uniqueidentifier, ID int , Type int, Number int , Name NVARCHAR(255) COLLATE Arabic_CI_AI, Used int, Flag int) 
	INSERT INTO #lookup 
	SELECT      
		pg.GUID, 
		pg.Number AS ID, 
		l.Type, 
		l.Number, 
		l.Name, 
		l.Used, 
		0 
	FROM     
		DistLookup000 AS l INNER JOIN    
		PalmGUID AS pg ON pg.GUID = l.GUID     
	DECLARE @Flag int 
	SET @Flag = 1 
	DECLARE @GUID uniqueidentifier 
	DECLARE c CURSOR FOR SELECT GUID FROM #lookup ORDER BY Type ASC, Number ASC 
	OPEN c 
	FETCH NEXT FROM c INTO @GUID 
	WHILE @@FETCH_STATUS = 0 
	BEGIN 
		UPDATE #lookup SET Flag = @Flag WHERE GUID = @GUID 
		SET @Flag = @Flag * 2 
		FETCH NEXT FROM c INTO @GUID 
	END 
	 
	CLOSE c 
	DEALLOCATE c 

	SELECT * FROM #lookup WHERE used = 1 ORDER BY Flag

########################################
## prcDistGetLookupOfDistributor
CREATE PROCEDURE prcDistGetLookupOfDistributor
		@PalmUserName NVARCHAR(250) 
AS     
	SET NOCOUNT ON     
	CREATE TABLE #lookupTbl(GUID uniqueidentifier, ID int , Type int, Number int , Name NVARCHAR(255) COLLATE Arabic_CI_AI, Used int, Flag int) 
	INSERT INTO #lookupTbl EXEC prcDistGetLookupFlages

	SELECT * FROM #lookupTbl WHERE used = 1  AND Type = 0 ORDER BY Flag
	SELECT * FROM #lookupTbl WHERE used = 1  AND Type = 1 ORDER BY Flag 
#############################
#END
