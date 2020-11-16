#########################################################
CREATE PROCEDURE prcGetDatabases
-----------------------------------------   
AS
    SET NOCOUNT ON
-------------------------------------------------------------------------  
	CREATE TABLE #DatabaseInfo
	( 
		Number                        INT IDENTITY(1, 1),
		DatabaseName		          NVARCHAR(250),
		DatabaseFDate		          DATETIME,
		DatabaseEDate		          DATETIME,
		DataFileName		          NVARCHAR(250),
		DatabaseVersion		          NVARCHAR(250),
		PrgVersion			          NVARCHAR(250),
		IsSelected			          INT,
		IsOldVersion		          INT,
		IsBeforeCurrentDataStartDate  INT
	)

	CREATE TABLE #CurrentDatabase
	(
		DatabaseName		NVARCHAR(250),
		DatabaseFDate		DATETIME,
		DatabaseEDate		DATETIME,
		DataFileName		NVARCHAR(250),
		DatabaseVersion		NVARCHAR(250),
		PrgVersion			NVARCHAR(250)
	)

	DECLARE @DatabaseName					NVARCHAR(100)
	DECLARE @InsertStr						NVARCHAR(MAX)
	DECLARE @GetVersion						NVARCHAR(MAX)
	DECLARE @IsOldVersion					INT
	DECLARE @GetBeforeCurrentData			NVARCHAR(MAX)
	DECLARE @IsBeforeCurrentData			INT
	DECLARE @IsAmnDBAndCreatedSuccessFully  INT
	DECLARE @Query							NVARCHAR(MAX)

	DECLARE @CollectDatabases CURSOR 
	SET @CollectDatabases = CURSOR FAST_FORWARD FOR	
		SELECT SystemDB.name AS name
		FROM sys.databases  SystemDB 
		WHERE SystemDB.database_id  > 4 
		AND SystemDB.Name != DB_NAME()
		AND SystemDB.[state] = 0
	OPEN @CollectDatabases;	
	FETCH NEXT FROM @CollectDatabases INTO @DatabaseName;
	WHILE (@@FETCH_STATUS = 0)
	BEGIN  

		SET @IsAmnDBAndCreatedSuccessFully = 1
		SET @Query = 'IF (NOT EXISTS( SELECT * FROM [' + @DatabaseName + '].sys.extended_properties WHERE name = ''AmnDBVersion'' AND value IS NOT  NULL AND value != '''')) SET @IsAmnDBAndCreatedSuccessFully = 0'

		EXEC sp_executesql @Query, N'@IsAmnDBAndCreatedSuccessFully INT out', @IsAmnDBAndCreatedSuccessFully OUT
		
		IF (@IsAmnDBAndCreatedSuccessFully = 1)
		BEGIN 

		------- Is overlapping period with current database
			SET @GetBeforeCurrentData = N'IF(( SELECT [dbo].[fnDate_Amn2Sql]( [VALUE]) FROM op000 WHERE name = ''AmnCfg_FPDate'') >
								(SELECT  [dbo].[fnDate_Amn2Sql]( [VALUE]) FROM ['+@DatabaseName+'].dbo.op000 WHERE name = ''AmnCfg_EPDate''))
										SET @IsBeforeCurrentData = 1
								ELSE
										SET @IsBeforeCurrentData = 0 '
			EXEC sp_executesql @GetBeforeCurrentData, N'@IsBeforeCurrentData INT out', @IsBeforeCurrentData OUT


		------- Is database version number greater than or equal to the current database version number
			SET @GetVersion = N'IF(( SELECT CONVERT(FLOAT, REPLACE(CAST(Value AS NVARCHAR(100)), ''.'', '''')) FROM ['+@DatabaseName+'].sys.extended_properties WHERE name = ''AmnDBVersion'') >= 
								(SELECT CONVERT(FLOAT, REPLACE(CAST(Value AS NVARCHAR(100)), ''.'', '''')) FROM sys.extended_properties WHERE name = ''AmnDBVersion''))
										SET @IsOldVersion =  0 
								ELSE
										SET @IsOldVersion = 1 '

		------- Insert 
			EXEC sp_executesql @GetVersion, N'@IsOldVersion INT out', @IsOldVersion OUT
			SET @InsertStr = 'INSERT INTO #DatabaseInfo (DatabaseName, DatabaseFDate, DatabaseEDate, DataFileName, DatabaseVersion, PrgVersion, IsSelected, IsOldVersion, IsBeforeCurrentDataStartDate) VALUES ('
			SET @InsertStr += CHAR(39)+@DatabaseName+CHAR(39)+ ', '
			SET @InsertStr += '(SELECT TOP 1 [dbo].[fnDate_Amn2Sql]( [VALUE]) FROM ['+@DatabaseName+'].dbo.op000 WHERE name LIKE ''AmnCfg_FPDate''), '
			SET @InsertStr += '(SELECT TOP 1 [dbo].[fnDate_Amn2Sql]( [VALUE]) FROM ['+@DatabaseName+'].dbo.op000 WHERE name LIKE ''AmnCfg_EPDate''), '
			SET @InsertStr += '(SELECT TOP 1 CAST(Value AS NVARCHAR(250))  FROM ['+@DatabaseName+'].sys.extended_properties WHERE name = ''AmnDBName''),  '
			SET @InsertStr += '(SELECT TOP 1 CONVERT(NVARCHAR(250), Value) FROM ['+@DatabaseName+'].sys.extended_properties WHERE name = ''AmnDBVersion'' ), '
			SET @InsertStr += '(SELECT TOP 1 CONVERT(NVARCHAR(250), Value) FROM ['+@DatabaseName+'].sys.extended_properties WHERE name = ''AmnPrgVersion'' ), 0, '
			SET @InsertStr +=  CAST(@IsOldVersion        AS NVARCHAR(25)) + ', '
			SET @InsertStr +=  CAST(@IsBeforeCurrentData AS NVARCHAR(25)) + ' )'
		END 

		EXEC(@InsertStr) 
		SET @InsertStr = ''

	FETCH NEXT FROM @CollectDatabases INTO @DatabaseName;
	END
	CLOSE      @CollectDatabases;
	DEALLOCATE @CollectDatabases;

	SELECT DatabaseName
	INTO #TempSelectedDataNames
	FROM ReportDataSources000


	WHILE (SELECT COUNT(*) FROM #TempSelectedDataNames) > 0
	BEGIN
		SELECT TOP 1 @DatabaseName = DatabaseName FROM #TempSelectedDataNames
		UPDATE #DatabaseInfo 
		SET IsSelected = 1
		WHERE DatabaseName = @DatabaseName
		DELETE #TempSelectedDataNames WHERE DatabaseName = @DatabaseName
	END


	INSERT INTO #CurrentDatabase 
	VALUES( DB_NAME(),
			(SELECT TOP 1 [dbo].[fnDate_Amn2Sql]( [VALUE]) FROM op000 WHERE name LIKE 'AmnCfg_FPDate'),
			(SELECT TOP 1 [dbo].[fnDate_Amn2Sql]( [VALUE]) FROM op000 WHERE name LIKE 'AmnCfg_EPDate'),
			(SELECT CONVERT(NVARCHAR(250), value) FROM sys.extended_properties WHERE name = 'AmnDBName'),
			(SELECT CONVERT(NVARCHAR(250), value) FROM sys.extended_properties WHERE name = 'AmnDBVersion'),
			(SELECT CONVERT(NVARCHAR(250), value) FROM sys.extended_properties WHERE name = 'AmnPrgVersion')  )
	-----------------	RESULTS	  -----------------
	SELECT * 
	FROM #DatabaseInfo 
	WHERE DatabaseFDate IS NOT NULL
	ORDER BY DatabaseFDate  , DatabaseEDate 

	SELECT * 
	FROM #CurrentDatabase
#########################################################
CREATE PROCEDURE PrcTransferLinkedSeveralYears
-- Params -------------------------------
  @NewDatabaseName			NVARCHAR(255),   
  @OldDatabaseName			NVARCHAR(255)
-----------------------------------------   
AS
    SET NOCOUNT ON
----------------------------------------------------------
DECLARE @FirstPeriodNewData		DATETIME
DECLARE @EndPeriodNewData		DATETIME
DECLARE @FileNameNewData		NVARCHAR(250)

DECLARE @FirstPeriodOldData		DATETIME
DECLARE @EndPeriodOldData		DATETIME
DECLARE @FileNameOldData		NVARCHAR(250)

DECLARE @Query					NVARCHAR(500)
DECLARE @InsertQuery			NVARCHAR(MAX)
DECLARE @InsertOldDB			NVARCHAR(MAX)
DECLARE @InsertNewDB			NVARCHAR(MAX)

-------------------------- NEW DATA
SET @Query = 'SELECT @DateOut = CAST(Value AS DATETIME) FROM [' + @NewDatabaseName + '].dbo.op000 WHERE name LIKE ''AmnCfg_FPDate''';
EXEC sp_executesql @Query, N'@DateOut DATETIME OUTPUT', @DateOut=@FirstPeriodNewData OUTPUT;

SET @Query = 'SELECT @DateOut = CAST(Value AS DATETIME) FROM ['+ @NewDatabaseName +'].dbo.op000 WHERE name LIKE ''AmnCfg_EPDate'''
EXEC sp_executesql @Query, N'@DateOut DATETIME OUTPUT', @DateOut=@EndPeriodNewData OUTPUT;

SET @Query = 'SELECT @NameOut = CAST(Value AS NVARCHAR(250))  FROM [' + @NewDatabaseName + '].sys.extended_properties WHERE name = ''AmnDBName'' '
EXEC sp_executesql @Query, N'@NameOut NVARCHAR(250) OUTPUT', @NameOut=@FileNameNewData OUTPUT;

-------------------------- OLD DATA 
SET @Query = 'SELECT @DateOut = CAST(Value AS DATETIME) FROM [' + @OldDatabaseName + '].dbo.op000 WHERE name LIKE ''AmnCfg_FPDate'''
EXEC sp_executesql @Query, N'@DateOut DATETIME OUTPUT', @DateOut=@FirstPeriodOldData OUTPUT;

SET @Query = 'SELECT @DateOut = CAST(Value AS DATETIME) FROM [' + @OldDatabaseName + '].dbo.op000 WHERE name LIKE ''AmnCfg_EPDate''';
EXEC sp_executesql @Query, N'@DateOut DATETIME OUTPUT', @DateOut=@EndPeriodOldData OUTPUT;

SET @Query = 'SELECT @NameOut = CAST(Value AS NVARCHAR(250))  FROM [' + @OldDatabaseName + '].sys.extended_properties WHERE name = ''AmnDBName'' ';
EXEC sp_executesql @Query, N'@NameOut NVARCHAR(250) OUTPUT', @NameOut=@FileNameOldData OUTPUT;


-------------------------- Insert old database if not overlaps 
IF((@FirstPeriodOldData NOT BETWEEN @FirstPeriodNewData AND @EndPeriodNewData) AND 
   (@EndPeriodOldData   NOT BETWEEN @FirstPeriodNewData AND @EndPeriodNewData) )
BEGIN
	SET @InsertOldDB  = 'INSERT INTO ['+ @NewDatabaseName+'].[dbo].ReportDataSources000 '
	SET @InsertOldDB += 'VALUES ('''+CONVERT(NVARCHAR(38), NEWID())+''', 
								 '''+@OldDatabaseName+''', 
								 '''+CAST(@FirstPeriodOldData AS NVARCHAR(36))+''' , 
								 '''+CAST(@EndPeriodOldData AS NVARCHAR(36))+''', 
								 '''+@FileNameOldData+''' )'
END

-------------------------- Insert saved databases in old data
SET @InsertQuery  = 'INSERT INTO ['+ @NewDatabaseName+'].[dbo].ReportDataSources000 '
SET @InsertQuery += '	SELECT * FROM ['+ @OldDatabaseName+'].[dbo].ReportDataSources000 '
SET @InsertQuery += '   WHERE FirstPeriod NOT BETWEEN '+CHAR(39)+CAST(@FirstPeriodNewData AS NVARCHAR(36))+CHAR(39)+ 'AND '+CHAR(39)+CAST(@EndPeriodNewData AS NVARCHAR(36))+CHAR(39)+'  '
SET @InsertQuery += '   AND EndPeriod	  NOT BETWEEN '+CHAR(39)+CAST(@FirstPeriodNewData AS NVARCHAR(36))+CHAR(39)+ 'AND '+CHAR(39)+CAST(@EndPeriodNewData AS NVARCHAR(36))+CHAR(39)+'  '
SET @InsertQuery += '   AND DatabaseName  != ''' + @OldDatabaseName+ CHAR(39)


-------------------------- Insert new database
SET @InsertNewDB  = 'INSERT INTO ['+ @NewDatabaseName+'].[dbo].ReportDataSources000 '
SET @InsertNewDB += 'VALUES ('''+CONVERT(NVARCHAR(38), NEWID())+''', 
							 '''+@NewDatabaseName+''', 
							 '''+CAST(@FirstPeriodNewData AS NVARCHAR(36))+''' , 
							 '''+CAST(@EndPeriodNewData AS NVARCHAR(36))+''', 
							 '''+@FileNameNewData+''' )'


EXEC(@InsertOldDB)
EXEC(@InsertQuery)
EXEC(@InsertNewDB)
#########################################################
#END
