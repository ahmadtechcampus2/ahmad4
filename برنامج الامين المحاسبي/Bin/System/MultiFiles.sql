##########################################################################################
CREATE FUNCTION fnIsLocalServer(@ServerName NVARCHAR(1000))
	RETURNS BIT  
AS 
BEGIN
	IF @ServerName = @@SERVERNAME OR @ServerName = '.' OR @ServerName = '' OR @ServerName = 'local' OR @ServerName = '(local)' OR @ServerName = '[local]'
		RETURN 1

	RETURN 0
END 
##########################################################################################
CREATE FUNCTION fnGetColumnsFromStr(@Str NVARCHAR(1000))
	RETURNS @Tbl TABLE ([String] NVARCHAR(100))
AS 
BEGIN
	DECLARE @I INT,@I1	INT,@I2 INT
	SET @I1 = 0
	SET @I2 = 1
	SET @I = 0
	WHILE @I <> 1
	BEGIN
		SET @I1 =@I 

		SET @I = CHARINDEX(',',@Str,@I)
		--PRINT @I
		IF (@I = 0)
			SET @I2 = LEN(@Str) + 2
		ELSE 
			SET @I2 = @I + 1
		INSERT INTO @Tbl VALUES(SUBSTRING (@Str,@I1,@I2 - @I1 -1))
		SET @I = @I + 1
	END
	RETURN
END
##########################################################################################
CREATE FUNCTION fnCurrencyMuli_Fix(@Value AS [FLOAT], @OldCurGUID [UNIQUEIDENTIFIER], @OldCurVal [FLOAT], @NewCurGUID [UNIQUEIDENTIFIER], @NewCurDate AS [DATETIME] = NULL) 
	RETURNS [FLOAT] 
AS BEGIN 
	DECLARE 
		@newCurVal [FLOAT], 
		@Result [FLOAT] 
	
	IF @NewCurDate IS NOT NULL 
		SET @newCurVal = (SELECT TOP 1 [CurrencyVal] FROM [mh000] WHERE [CurrencyGUID] = @NewCurGUID AND [Date] <= @NewCurDate ORDER BY [Date] DESC) 
	IF @newCurVal IS NULL 
		SET @newCurVal = (SELECT [CurrencyVal] FROM [my000] WHERE [GUID] = @newCurGUID) 
	SET @Result = @Value / (CASE @NewCurVal WHEN 0 THEN 1 ELSE @NewCurVal END) 
	
	RETURN @Result  
END 
##########################################################################################
CREATE FUNCTION fnGetTblColumn(@Tbl NVARCHAR(100),@Prev NVARCHAR(100))
		RETURNS NVARCHAR(max)
	AS
	BEGIN
		DECLARE @c_bi CURSOR,@Sql NVARCHAR(1000),@Col NVARCHAR(100),@Columns NVARCHAR(max),@Start BIT
		SET @Columns = ''
		SET @Start = 0
		set @Tbl = '..' + @Tbl
		SET @c_bi = CURSOR FAST_FORWARD FOR  SELECT [name] FROM syscolumns where id = object_id(@Tbl) ORDER BY colid
		OPEN @c_bi FETCH NEXT FROM @c_bi INTO 	@Col
		WHILE @@FETCH_STATUS = 0
		BEGIN
			IF @Start > 0
				SET @Columns = @Columns + ','
			IF @Prev <> ''
				SET @Columns = @Columns + ' ' + @Prev + '.'
			SET @Columns = @Columns + @Col + ' '
			IF @Start = 0
				SET @Start = 1
			FETCH NEXT FROM @c_bi INTO 	@Col
		END
		CLOSE @c_bi
		DEALLOCATE @c_bi
		RETURN @Columns
	END
##########################################################################################
CREATE PROCEDURE prcCreateColumnFunction
AS
	IF EXISTS (SELECT * FROM SYS.OBJECTS  where object_id = object_id('[dbo].[fnGetTblColumn]'))
		DROP FUNCTION [dbo].[fnGetTblColumn]
	DECLARE @Sql NVARCHAR(max)
	DECLARE @Db NVARCHAR(100)
	SET @Db = (SELECT top 1 dbname FROM MultiFiles000)

	SET @Sql = 
	'CREATE FUNCTION [dbo].[fnGetTblColumn](@Tbl NVARCHAR(100),@Prev NVARCHAR(100))
		RETURNS NVARCHAR(max)
	AS
	BEGIN
		DECLARE @c_bi CURSOR,@Sql NVARCHAR(1000),@Col NVARCHAR(100),@Columns VARCHAR(max),@Start BIT
		SET @Columns = ''''
		SET @Start = 0
		set @Tbl = '''+ @Db + '.dbo.'' + @Tbl
		SET @c_bi = CURSOR FAST_FORWARD FOR  SELECT [name] FROM ' + @Db + '.sys.columns where object_id = object_id(@Tbl) ORDER BY colid
		OPEN @c_bi FETCH NEXT FROM @c_bi INTO 	@Col
		WHILE @@FETCH_STATUS = 0
		BEGIN
			IF @Start > 0
				SET @Columns = @Columns + '',''
			IF @Prev <> ''''
				SET @Columns = @Columns + '' '' + @Prev + ''.''
			SET @Columns = @Columns + ''['' + @Col + '']'' + '' ''
			IF @Start = 0
				SET @Start = 1
			FETCH NEXT FROM @c_bi INTO 	@Col
		END
		CLOSE @c_bi
		DEALLOCATE @c_bi
		RETURN @Columns
	END
	'
	EXEC (@Sql)
##########################################################################################
CREATE PROCEDURE prcMultiFilesUniGuid
	@TblName	NVARCHAR(100),
	@Field		NVARCHAR(100) = 'Guid',
	@Field2		NVARCHAR(100) = 'Code',
	@Field3		NVARCHAR(100) = ''
AS
	DECLARE @Sql NVARCHAR(max)
	DECLARE @db NVARCHAR(200),@I INT,@Prevdb NVARCHAR(max)
	DECLARE @c		CURSOR
	DECLARE @c2		CURSOR
	DECLARE @Type NVARCHAR(5)	
	DECLARE @subTbl NVARCHAR(200),@subColumn NVARCHAR(200)
	SET @c = CURSOR FAST_FORWARD FOR SELECT CASE WHEN dbo.fnIsLocalServer(SERVERNAME) = 1 THEN '' ELSE '[' + SERVERNAME + ']' + '.' END + DBNAME FROM [Multifiles000] ORDER BY Number DESC
	OPEN @c FETCH FROM @c INTO @db
	SET @I = 0
	CREATE TABLE #ii ( ORG [UNIQUEIDENTIFIER],New [UNIQUEIDENTIFIER])
	WHILE @@FETCH_STATUS = 0 
	BEGIN
		IF (@I = 0)
		BEGIN
			SET @Prevdb = @db
			FETCH FROM @c INTO @db
			SET @I = 1
			CONTINUE
		END
		 
		SET	@Sql = 'INSERT INTO #II  SELECT A.' + @Field +' AS ORG , B.' + @Field +' AS NEW FROM ' 
		SET	@Sql = @Sql +	@Prevdb + '.dbo.' + @TblName + ' A INNER JOIN ' 
		SET	@Sql = @Sql + @db + '.dbo.' + @TblName + ' B ON A.' + @Field2 +' = B.' + @Field2
		IF (@Field3 <> '')
			SET	@Sql = @Sql + ' AND A.' + @Field3 +' = B.' + @Field3
		SET	@Sql = @Sql + ' WHERE A.' + @Field +' <> B.' + @Field
		EXEC(@Sql)
		--SET	@Sql = 'ALTER TABLE ' + @db + '.dbo.' + @TblName + ' DISABLE TRIGGER ALL ' + CHAR(13)
		SET	@Sql = 'UPDATE A SET ' + @Field + ' = B.ORG FROM '+ @db + '.dbo.' + @TblName + ' A INNER JOIN #II B ON A.' + @Field + ' = B.NEW' +  CHAR(13) 		
		--SET	@Sql = @Sql +  'ALTER TABLE ' + @db + '.dbo.' + @TblName + ' ENABLE TRIGGER ALL ' + CHAR(13)
		EXEC(@Sql)
		SET @c2 = CURSOR FAST_FORWARD FOR SELECT [Table],[ParentGuid] FROM [#UNFile] WHERE [ParentTable] = @TblName
		OPEN @c2 FETCH FROM @c2 INTO @subTbl ,@subColumn 
		WHILE @@FETCH_STATUS = 0 
		BEGIN
			--SET	@Sql = 'ALTER TABLE ' + @db + '.dbo.' + @subTbl + ' DISABLE TRIGGER ALL ' + CHAR(13)
			SET	@Sql = 'UPDATE A SET '+ 	@subColumn + ' = B.ORG FROM '+ @db + '.dbo.' + @subTbl + ' A INNER JOIN #II B ON A.' + @subColumn + ' = B.NEW' + CHAR(13)		
			--SET	@Sql = @Sql +  'ALTER TABLE ' + @db + '.dbo.' + @subTbl + ' ENABLE TRIGGER ALL ' + CHAR(13)
			EXEC(@Sql)	
			FETCH FROM @c2 INTO @subTbl ,@subColumn 	
		END
		CLOSE @c2
		DEALLOCATE @c2
		SET @Prevdb = @db
		FETCH FROM @c INTO @db
	END
	CLOSE @c
	DEALLOCATE @c

##########################################################################################
CREATE PROCEDURE prcUniFiles
AS
	CREATE TABLE #UNFile
	(
		[Table]	[NVARCHAR](100),
		[ParentTable]	[NVARCHAR](100),
		[ParentGuid]	[NVARCHAR](100)	
	)
	INSERT INTO #UNFile VALUES ('Snt000','Snc000','ParentGuid')
	EXEC prcMultiFilesUniGuid 'SNC000','Guid','SN','MatGuid'
##########################################################################################
CREATE PROCEDURE prcMultiFileGetCardFrmMainFile
	@TblName	NVARCHAR(100),
	@MainFile	NVARCHAR(100) = ''
AS
	DECLARE @Sql NVARCHAR(max)
	SET @Sql = 'ALTER TABLE ' + @TblName + ' DISABLE TRIGGER ALL'	
	EXEC (@Sql)
	
	SET @Sql = 'TRUNCATE TABLE ' + @TblName
	EXEC (@Sql)
	
	SET @Sql = ' INSERT INTO  ' + @TblName + ' SELECT * FROM ' + @MainFile + '.dbo.' + @TblName 
	EXEC (@Sql)
	SET @Sql = 'ALTER TABLE ' + @TblName + ' ENABLE TRIGGER ALL'	
	EXEC (@Sql)
##########################################################################################
CREATE PROCEDURE prcMultiFileGetCard
	@TblName	NVARCHAR(100),
	@Field		NVARCHAR(100) = 'Guid',
	@Field2		NVARCHAR(100) = '',
	@MultCurr BIT = 0
AS
	DECLARE @Sql NVARCHAR(max)
	DECLARE @db NVARCHAR(max),@I INT
	DECLARE @c		CURSOR
	DECLARE @Type NVARCHAR(5)
	SET @Sql = 'ALTER TABLE ' + @TblName + ' DISABLE TRIGGER ALL'	
	EXEC (@Sql)
	IF @MultCurr = 0
	BEGIN
		SET @Sql = 'TRUNCATE TABLE ' + @TblName
		EXEC (@Sql)
	END
	SET @c = CURSOR FAST_FORWARD FOR SELECT CASE WHEN dbo.fnIsLocalServer(SERVERNAME) = 1 THEN '' ELSE '[' + SERVERNAME + ']' + '.' END + DBNAME FROM [Multifiles000] ORDER BY [number]
	
	OPEN @c FETCH FROM @c INTO @db
	WHILE @@FETCH_STATUS = 0 
	BEGIN 
		
		SET @Sql = ' INSERT INTO  ' + @TblName + ' SELECT * FROM ' + @db + '.dbo.' + @TblName 
		SET @Sql = @Sql + ' WHERE  '+ @Field + ' NOT IN (SELECT '+ @Field + ' FROM '+ @TblName +')'
		IF @Field2 <> ''
			SET @Sql = @Sql + ' AND  '+ @Field2 + ' NOT IN (SELECT '+ @Field2 + ' FROM '+ @TblName +')'	
	
		EXEC (@Sql)
		FETCH FROM @c INTO @db
	END
	CLOSE @c
	DEALLOCATE @c
	SET @Sql = 'ALTER TABLE ' + @TblName + ' ENABLE TRIGGER ALL'
	EXEC (@Sql)	
##########################################################################################
CREATE PROCEDURE prcGetMultiFiles
AS 
	SET NOCOUNT ON
	DECLARE @C CURSOR ,@DbName NVARCHAR(100),@DbId INT,@Sql NVARCHAR(1000),@MainDB NVARCHAR(100),@Properties NVARCHAR(100)
	SET @Properties = '.SYS.EXTENDED_PROPERTIES'
	
	SELECT @MainDB = [Value] FROM [op000] WHERE [Name] = 'AmncfgMainFile'
	CREATE TABLE #VER(Id INT,Ver NVARCHAR(100),bAdmin BIT)
	SET @c = CURSOR FAST_FORWARD FOR SELECT dbId,DBName FROM [MultiFiles000] ORDER BY [number]
	Open @c FETCH FROM @c INTO @DbId,@DbName
	WHILE @@FETCH_STATUS = 0
	BEGIN
		SET @Sql = ' INSERT INTO #VER SELECT ' + CAST(@DbId AS NVARCHAR(30)) + ' ,cast(Value as NVARCHAR(100))'
		IF (@MainDB = @DbName)
			SET @Sql = @Sql + ',1 '
		ELSE
			SET @Sql = @Sql + ',0 '
		SET @sql = @sql + ' FROM ' + @DbName + @Properties + ' where [Name] =''AmnDBVersion'''
		EXEC(@sql)
		FETCH FROM @c INTO @DbId,@DbName
	END
	CLOSE @c
	DEALLOCATE @c
	SELECT A.*,b.Ver DBVer,bADmin FROM MultiFiles000 a INNER JOIN #Ver b on a.dbId = b.Id order by a.Number
##########################################################################################
CREATE PROCEDURE prcMultiFilesGetChentryrepeated
AS
	DECLARE @Sql NVARCHAR(max)
	DECLARE @db NVARCHAR(200),@I INT,@Prevdb NVARCHAR(max)
	DECLARE @c		CURSOR
	CREATE TABLE #chentry
	(
		[entryguid] UNIQUEIDENTIFIER,
		[ParentGuid] UNIQUEIDENTIFIER,
		[Date] datetime
	)
	
	SET @I = 0
	SET @c = CURSOR FAST_FORWARD FOR SELECT CASE WHEN dbo.fnIsLocalServer(SERVERNAME) = 1 THEN '' ELSE '[' + SERVERNAME + ']' + '.' END + DBNAME FROM [Multifiles000] ORDER BY Number DESC
	OPEN @c FETCH FROM @c INTO @db
	WHILE @@FETCH_STATUS = 0 
	BEGIN
		SET @Sql = 'INSERT INTO #chentry SELECT entryguid,ParentGuid,[Date] FROM ' + @db + '.dbo.er000 er INNER JOIN   ' + @db + '.dbo.ce000 ce ON ce.Guid = er.entryguid WHERE parentType = 5'
		EXEC(@Sql)
		FETCH FROM @c INTO @db
	END 
	CLOSE @c
	DEALLOCATE @c
	delete #chentry where parentGuid not in (select parentGuid from #chentry	group by parentGuid having count(*) > 1)
	select parentGuid,MIN ([Date]) AS [DATE] INTO #UU from #chentry	group by parentGuid
	INSERT INTO chkentry select entryGuid from #chentry C INNER JOIN #UU U ON C.[DATE] = U.[DATE] AND C.[parentGuid] = U.[parentGuid]
##########################################################################################
CREATE PROCEDURE prcMultipt
AS
	DECLARE @Sql NVARCHAR(max)
	DECLARE @db NVARCHAR(200),@Prevdb NVARCHAR(max)
	DECLARE @c		CURSOR


	SET @c = CURSOR FAST_FORWARD FOR SELECT CASE WHEN dbo.fnIsLocalServer(SERVERNAME) = 1 THEN '' ELSE '[' + SERVERNAME + ']' + '.' END + DBNAME FROM [Multifiles000] ORDER BY Number DESC
	OPEN @c FETCH FROM @c INTO @db
	WHILE @@FETCH_STATUS = 0 
	BEGIN
		SET @Sql = 'INSERT INTO BillEntryNotExist SELECT CAST(ASC2 AS UNIQUEIDENTIFIER),3 FROM ' + @db + '.dbo.mc000  WHERE TYPE = 36  AND Item > 2'
		SET @Sql = 'INSERT INTO BillEntryNotExist SELECT ENTRYGUID,3 FROM ' + @db + '.dbo.ER000 ER INNER JOIN  '  + @db + '.dbo.mc000 MC ON ASC2 = CAST(er.Parentguid  AS NVARCHAR(36))'
		EXEC(@Sql)
		FETCH FROM @c INTO @db
	END 
	CLOSE @c
	DEALLOCATE @c
##########################################################################################
CREATE PROCEDURE prcMuliFilesUpDateDefaultValues
AS 
	DECLARE @Sql NVARCHAR(max)
	DECLARE @db NVARCHAR(max),@I INT
	DECLARE @c		CURSOR
	CREATE TABLE #VAL (NAME NVARCHAR(100), VALUE NVARCHAR(100))
	SET @c = CURSOR FAST_FORWARD FOR SELECT CASE WHEN dbo.fnIsLocalServer(SERVERNAME) = 1 THEN '' ELSE '[' + SERVERNAME + ']'+  '.' END + DBNAME FROM [Multifiles000] 
	SET @I = 0
	OPEN @c FETCH FROM @c INTO @db
	WHILE @@FETCH_STATUS = 0 	
	BEGIN
		IF (@I = 0)
			SET @Sql = 'INSERT INTO #VAL SELECT Name,[Value] FROM ' + @db + '.dbo.[Op000] WHERE NAME = ''AmnCfg_DefaultCurrency''	'
		SET @i = 1
		SET @Sql = @Sql + 'INSERT INTO #VAL SELECT Name,[Value] FROM ' + @db + '.dbo.[Op000] WHERE NAME = ''AmnCfg_FPDate''	'
		SET @Sql = @Sql + 'INSERT INTO #VAL SELECT Name,[Value] FROM ' + @db + '.dbo.[Op000] WHERE NAME = ''AmnCfg_EPDate''	'
		EXEC(@Sql)
		FETCH FROM @c INTO @db
	END
	CLOSE @c
	DEALLOCATE @c
	UPDATE OP000 SET [Value] = (SELECT TOP 1 [Value] FROM #VAL WHERE NAME ='AmnCfg_DefaultCurrency') WHERE NAME = 'AmnCfg_DefaultCurrency' 	
	UPDATE OP000 SET [Value] = (SELECT MIN([Value]) FROM #VAL WHERE  NAME  = 'AmnCfg_FPDate') WHERE NAME = 'AmnCfg_FPDate'
	UPDATE OP000 SET [Value] = (SELECT MAX([Value]) FROM #VAL WHERE NAME = 'AmnCfg_EPDate') WHERE NAME = 'AmnCfg_EPDate'  
##########################################################################################
CREATE PROCEDURE prcInsertIntoFpVaulue
AS
	DECLARE @Sql NVARCHAR(max)
	DECLARE @db NVARCHAR(max)
	DECLARE @c		CURSOR
	SET @c = CURSOR FAST_FORWARD FOR SELECT CASE WHEN dbo.fnIsLocalServer(SERVERNAME) = 1 THEN '' ELSE '[' + SERVERNAME + ']' + '.' END + DBNAME FROM [Multifiles000]
	OPEN @c FETCH FROM @c INTO @db
	WHILE @@FETCH_STATUS = 0 
	BEGIN
		SET @Sql = 'INSERT INTO BillEntryNotExist SELECT CAST([ASc2] AS UNIQUEIDENTIFIER),Item FROM ' + @db + '.dbo.MC000 WHERE TYPE = 36'	
		EXEC (@Sql)
		FETCH FROM @c INTO @db
	END 
	CLOSE @c
	DEALLOCATE @c
##########################################################################################
CREATE PROCEDURE prcMFGetUserspermssion
AS
	 
	DECLARE @Sql NVARCHAR(max)
	DECLARE @Sql2 NVARCHAR(max)
	DECLARE @db NVARCHAR(200),@I INT,@Prevdb NVARCHAR(max)
	DECLARE @c		CURSOR
	DECLARE @c2		CURSOR
	DECLARE @Type NVARCHAR(5)	
	DECLARE @subTbl NVARCHAR(200),@subColumn NVARCHAR(200)
	
	
	CREATE TABLE #US(GUID UNIQUEIDENTIFIER ,bAdmin [BIT])
	CREATE TABLE [#ui](
	[UserGUID] [uniqueidentifier],
	[ReportId] [float] ,
	[SubId] [uniqueidentifier],
	[System] [int] ,
	[PermType] [int] ,
	[Permission] [int] )

	SET @c = CURSOR FAST_FORWARD FOR SELECT CASE WHEN dbo.fnIsLocalServer(SERVERNAME) = 1 THEN '' ELSE '[' + SERVERNAME +']' + '.' END + DBNAME FROM [Multifiles000] ORDER BY Number DESC
	OPEN @c FETCH FROM @c INTO @db
	SET @I = 0
	SET @Sql = 'INSERT INTO #US SELECT GUID ,MIN(CAST(bAdmin as INT )) FROM ( '
	SET @Sql2 = 'INSERT INTO #UI ([UserGUID],[ReportId],[SubId],[System],[PermType],Permission) SELECT [UserGUID],[ReportId],[SubId],[System],[PermType],MIN([Permission]) FROM ( '
	WHILE @@FETCH_STATUS = 0 
	BEGIN
		
			
		IF  @I <> 0
		BEGIN
			SET @Sql = @Sql + ' UNION ALL '	
			SET @Sql2 = @Sql2 + ' UNION ALL '	
		END
		SET @I = @I + 1
		SET @Sql = @Sql + ' SELECT GUID ,bAdmin  FROM ' + @db + '.dbo.US000 '
		SET @Sql2 = @Sql2 + ' SELECT [UserGUID],[ReportId],[SubId],[System],[PermType],Permission FROM ' + @db + '.dbo.UI000'
		FETCH FROM @c INTO @db
	END
	CLOSE @c
	DEALLOCATE @c
	SET @Sql = @Sql + ' )q GROUP BY [GUID] HAVING COUNT(*) = ' + CAST (@I AS NVARCHAR(3))
	SET @Sql2 = @Sql2 + ' )q GROUP BY [UserGUID],[ReportId],[SubId],[System],[PermType]'
	EXEC(@Sql)

	EXEC(@Sql2)
	DELETE US000 WHERE GUID NOT IN (SELECT GUID FROM #US)
	UPDATE US SET bAdmin = a.bAdmin FROM US000 US INNER JOIN #US a ON a.Guid = us.Guid
	TRUNCATE TABLE ui000
	INSERT INTO [ui000]([UserGUID],[ReportId],[SubId],[System],[PermType],Permission)
	SELECT [UserGUID],[ReportId],[SubId],[System],[PermType],Permission
	FROM #UI WHERE [UserGUID] IN (SELECT GUID FROM [US000])
##########################################################################################
CREATE PROCEDURE prcGetMuliFilesvCard
	@TblName		NVARCHAR(100)
AS
	DECLARE @ViewName NVARCHAR(100), @ViewName2 NVARCHAR(100),@c CURSOR,@I int,@db NVARCHAR(100)
	SET @ViewName = @TblName
	SET @ViewName = 'v' + @TblName + '0'
	
	DECLARE @String NVARCHAR(100)
	DECLARE @Sql NVARCHAR(max)
	
	
	IF EXISTS(SELECT * FROM SYS.OBJECTS WHERE NAME =  @ViewName)
	BEGIN 
		
		SET @Sql = ' DROP VIEW ' + @ViewName
		EXEC (@SQL)		
	END
	
	SET @c = CURSOR FAST_FORWARD FOR SELECT CASE WHEN dbo.fnIsLocalServer(SERVERNAME) = 1 THEN '' ELSE '[' + SERVERNAME +']' + '.' END + DBNAME FROM [Multifiles000] ORDER BY [number]
	SET @I = 0
	
	OPEN @c FETCH FROM @c INTO @db
	SET @Sql = '  CREATE VIEW ' + @ViewName + CHAR(13)  + 'AS ' + CHAR (13)
	WHILE @@FETCH_STATUS = 0 
	BEGIN
		IF @I > 0 
			SET @Sql = @Sql + 'UNION ALL ' + CHAR(13)
		SET @I = @I + 1
		SET @Sql = @Sql + ' SELECT a.guid FROM ' + @db + '.dbo.' + @TblName + ' A LEFT JOIN ' + @TblName  + ' b ON a.Guid = b.Guid WHERE b.Guid IS NULL' + CHAR(13) 
		FETCH FROM @c INTO @db
	END
	CLOSE @c
	DEALLOCATE @c
	EXEC (@SQL)
##########################################################################################
CREATE PROCEDURE prcMultiFileGetMatPackageCards
	@MultCurr BIT = 0
AS 
	EXEC prcMultiFileGetCard 'GR000'
	EXEC prcMultiFileGetCard 'MT000'
	EXEC prcMultiFileGetCard 'st000'
	EXEC prcMultiFileGetCard 'md000','ParentGuid','MatGuid'
	IF @MultCurr > 1
	BEGIN
		EXEC prcDisableTriggers 'Mt000'
		
		UPDATE mt
			SET
			Half = Half / cNewVal
			,Retail = Retail / cNewVal
			,EndUser = EndUser /cNewVal
			,Export = Export / cNewVal
			,[Vendor] = [Vendor] / cNewVal
			,MaxPrice = MaxPrice / cNewVal
			,AvgPrice = AvgPrice / cNewVal
			,LastPrice = LastPrice / cNewVal
			,CurrencyVal = CurrencyVal / cNewVal
			,Whole2 = Whole2 / cNewVal
			,Half2	=	Half2 / cNewVal
			,Retail2	=	Retail2 / cNewVal
			,EndUser2=	EndUser2 / cNewVal
			,Export2	=	Export2 / cNewVal
			,Vendor2	=	Vendor2 / cNewVal
			,MaxPrice2 =	MaxPrice2 / cNewVal
			,LastPrice2 =	LastPrice2 / cNewVal
			,Whole3 = Whole3 / cNewVal
			,Half3 =	 Half3 / cNewVal
			,Retail3	 =	Retail3 / cNewVal
			,EndUser3 =	EndUser3 / cNewVal
			,Export3	=	Export3 / cNewVal
			,Vendor3	=	Vendor3 / cNewVal
			,MaxPrice3 =	MaxPrice3/ cNewVal
			,LastPrice3 =	LastPrice3
		FROM MT000 mt INNER JOIN (SELECT DISTINCT [dbo].[fnCurrencyMuli_Fix](1,m.[CurrencyGuid],m.[CurrencyVal],my.[Guid],GetDate()) cNewVal ,my.Guid FROM my000 my INNER JOIN MT000 m ON m.[CurrencyGuid] = my.Guid)  a on a.guid = mt.[CurrencyGuid]
		ALTER TABLE MT000 ENABLE TRIGGER ALL
	END
##########################################################################################
CREATE PROCEDURE prcMultiFileGetAccPackageCards
	@MultCurr BIT = 0
AS 
	EXEC prcMultiFileGetCard 'AC000'
	EXEC prcMultiFileGetCard 'CO000'
	EXEC prcMultiFileGetCard 'CI000','ParentGuid','SonGuid'
	EXEC prcMultiFileGetCard 'Cu000'
	IF @MultCurr > 1
	BEGIN
		EXEC prcDisableTriggers 'ac000'
		SELECT  DISTINCT [dbo].[fnCurrencyMuli_Fix](1,c.[CurrencyGuid],c.[CurrencyVal],my.[Guid],GetDate()) cNewVal ,my.Guid into #ac FROM my000 my INNER JOIN ac000 c ON c.[CurrencyGuid] = my.Guid
		ALTER TABLE ac000 ENABLE TRIGGER ALL
		UPDATE ac
			SET
			InitDebit =	InitDebit / cNewVal,	
			InitCredit =	InitCredit / cNewVal,	
			MaxDebit =	MaxDebit / cNewVal,	
			CurrencyVal = CurrencyVal / cNewVal
		FROM ac000 ac inner join #ac  a on a.guid = ac.[CurrencyGuid]
		ALTER TABLE ac000 ENABLE TRIGGER ALL
	END
##########################################################################################
CREATE PROCEDURE prcWithDrawCardToMainFile
	@MainDb		NVARCHAR(100),
	@Db		NVARCHAR(100),
	@TblName	NVARCHAR(100),
	@Column		NVARCHAR(100) = 'Code'
AS
	DECLARE @Sql NVARCHAR(1000)
	SET @Sql = ' ALTER TABLE ' + @MainDb + '.dbo.' + @TblName + ' DISABLE TRIGGER ALL ' + CHAR(13)
	SET @Sql = @Sql + 'INSERT INTO ' + @MainDb + '.dbo.' + @TblName + ' SELECT a.* FROM ' + @Db + '.dbo.' + @TblName + ' a LEFT JOIN '  + @MainDb + '.dbo.' + @TblName + ' b ON a.' + @Column + '=' + 'b.'+ @Column + ' WHERE b.' + @Column + ' IS NULL' + CHAR(13)
	SET @Sql = @Sql +  ' ALTER TABLE ' + @MainDb + '.dbo.' + @TblName + ' ENABLE TRIGGER ALL '
	EXEC (@Sql)
##########################################################################################
CREATE PROCEDURE prcWithDrawCardToMainFileS
AS
	DECLARE @MainFile NVARCHAR(100)
	DECLARE @C	CURSOR,@DB NVARCHAR(100)
	SELECT @MainFile = value FROM [op000] where [name] = 'AmncfgMainFile'
	SET @c = CURSOR FAST_FORWARD FOR SELECT  CASE WHEN dbo.fnIsLocalServer(SERVERNAME) = 1 THEN '' ELSE '[' + SERVERNAME +']' + '.' END + DBName 
	FROM MultiFiles000 WHERE DBName <> @MainFile
	
	OPEN @c FETCH FROM @c INTO @DB
	WHILE (@@FETCH_STATUS = 0 )
	BEGIN
		EXEC prcWithDrawCardToMainFile @MainFile,@DB,'gr000'
		EXEC prcWithDrawCardToMainFile @MainFile,@DB,'mt000'
		EXEC prcWithDrawCardToMainFile @MainFile,@DB,'st000'
		EXEC prcWithDrawCardToMainFile @MainFile,@DB,'ac000'
		EXEC prcWithDrawCardToMainFile @MainFile,@DB,'co000'
		EXEC prcWithDrawCardToMainFile @MainFile,@DB,'cu000','customerName'
		FETCH FROM @c INTO @DB
	END	
	CLOSE @c
	DEALLOCATE @c
##########################################################################################
CREATE PROCEDURE prcMultiFileGetCards
	 @Flag INT = 0X111111
AS 
	SET NOCOUNT ON
	DECLARE @MultCurr BIT,@MainDb NVARCHAR(100),@HaveContra BIT
	SELECT @MainDb = [VALUE] FROM op000 where name = 'AmncfgMainFile'
	SELECT @MultCurr = CAST([Value] AS BIT)FROM [op000] WHERE  [Name] = 'AmncfgMfMultCurr'
	SELECT @HaveContra = CAST([Value] AS BIT)FROM [op000] WHERE  [Name] = 'AmncfgMfContraTypes'
	IF @MultCurr IS NULL
		SET @MultCurr = 0
	IF @HaveContra IS NULL
		SET @HaveContra = 0
		EXEC prcDisableTriggers 'BR000'
	
	EXEC prcMultiFileGetCard 'br000'
	ALTER TABLE BR000 ENABLE TRIGGER ALL
	IF @MainDb IS NOT NULL AND @MultCurr = 1
		EXEC prcMultiFileGetCardFrmMainFile 'my000',@MainDb
	EXEC prcMultiFileGetCard 'my000','Guid','Code',@MultCurr
	IF (@Flag & 0X000001) > 0
		EXEC prcMultiFileGetMatPackageCards	@MultCurr	
	IF (@Flag & 0X000010 > 0)
		EXEC prcMultiFileGetAccPackageCards	@MultCurr
	IF @MainDb IS NOT NULL AND @HaveContra = 1
	BEGIN
		EXEC prcMultiFileGetCardFrmMainFile 'bt000',@MainDb
		EXEC prcMultiFileGetCardFrmMainFile 'nt000',@MainDb
		EXEC prcMultiFileGetCardFrmMainFile 'et000',@MainDb
	END
	ELSE
	BEGIN
		EXEC prcMultiFileGetCard 'bt000'
		EXEC prcMultiFileGetCard 'nt000'
		EXEC prcMultiFileGetCard 'et000'
	END
	IF (@Flag & 0X000100 > 0)
	BEGIN
		IF (@MainDb IS NOT NULL)
		BEGIN
			TRUNCATE TABLE [US000]
			EXEC('INSERT INTO [US000] SELECT * FROM ' + @MainDb + '.dbo.US000')
			TRUNCATE TABLE [Ui000]
			EXEC('INSERT INTO [Ui000] SELECT * FROM ' + @MainDb + '.dbo.UI000')
		END
		BEGIN
			EXEC prcMultiFileGetCard 'us000'
			EXEC prcMFGetUserspermssion
		END
		UPDATE US000 SET Dirty = 1
	END
	IF (@Flag & 0X000011 = 0X000011)
		EXEC prcMultiFileGetCard 'MA000','ObjGuid','BillTypeGuid'
	IF EXISTS(SELECT * FROM SYS.OBJECTS WHERE NAME = 'chkentry')
		DROP TABLE chkentry
	EXEC prcUniFiles
	CREATE TABLE chkentry
	(
		Guid [UNIQUEIDENTIFIER]
	)
	IF EXISTS(SELECT * FROM SYS.OBJECTS WHERE NAME = 'BillEntryNotExist')
		DROP TABLE BillEntryNotExist
	CREATE TABLE BillEntryNotExist
	(
		Guid [UNIQUEIDENTIFIER],
		Type [INT]
	)
	EXEC prcMultiFilesGetChentryrepeated
	IF (@Flag & 0X001000 > 0)
		EXEC prcWithDrawCardToMainFileS
##########################################################################################
CREATE PROCEDURE prcGetMuliFilesMoves
	@TblName		NVARCHAR(100),
	@hasFP			[BIT] = 0,
	@Field			NVARCHAR(100) = 'Guid',
	@Cheeck			[BIT] = 0,
	@OutTable		NVARCHAR(100) = '',
	@Cond			NVARCHAR(100) = '',
	@CurrValByFile	BIT = 0,
	@CurrValCol		NVARCHAR(1000) = '',
	@ParentDate		NVARCHAR(1000) = '',
	@RefDate		NVARCHAR(1000) = 'ParentGuid',
	@HaveContra		BIT = 0,
	@ContraFlag		TINYINT = 0,
	@ContraField	NVARCHAR(100) = '[TypeGuid]'
AS
	DECLARE @ViewName NVARCHAR(100), @ViewName2 NVARCHAR(100)
	SET @ViewName = @TblName
	IF (@OutTable <> '') 
	BEGIN
		SET @ViewName = @TblName + '0'
	END
	DECLARE @String NVARCHAR(100)
	DECLARE @Sql NVARCHAR(max),@Columns	NVARCHAR(max),@Column	NVARCHAR(max),@Columns2	NVARCHAR(max),@Columns3	NVARCHAR(max)
	DECLARE @db NVARCHAR(max),@I INT,@prvdb NVARCHAR(max)
	DECLARE @c		CURSOR
	DECLARE @Type NVARCHAR(5)
	DECLARE @CH NVARCHAR(max)
	SET @CH = ''	
	SET @Columns = [dbo].[fnGetTblColumn](@TblName,'q')
	SET @Columns2 = [dbo].[fnGetTblColumn](@TblName,'a')
	IF EXISTS(SELECT * FROM SYS.OBJECTS WHERE NAME =  @TblName)
	BEGIN 
		
		SELECT @Type = [type] FROM  SYS.OBJECTS WHERE NAME = @TblName
		SET @Sql = ' DROP '
		IF @Type = 'U'
			SET @Sql = @Sql + ' TABLE '
		ELSE
			SET @Sql = @Sql + ' VIEW '
		SET @Sql = @Sql + @TblName	
		EXEC (@SQL)		
	END
		
	IF (@OutTable <> '') AND EXISTS(SELECT * FROM SYS.OBJECTS WHERE NAME =  @ViewName)
	BEGIN
		SET @Sql =  'DROP VIEW ' + @ViewName
		EXEC(@Sql)
	END
	IF @CurrValByFile > 0
	BEGIN 
		SET @c = CURSOR FAST_FORWARD FOR SELECT * FROM fnGetColumnsFromStr(@CurrValCol)
		OPEN @c FETCH FROM @c INTO @String
		WHILE @@FETCH_STATUS = 0 
		BEGIN
			SET @Columns2 = REPLACE(@Columns2,@String, @String +'/newCurrVal ' + @String)
			FETCH FROM @c INTO @String
		END
		CLOSE @c
		DEALLOCATE @c
	END
	IF (@OutTable <> '')
		SET @Columns3 = @Columns
	IF @HaveContra > 0
		SET @Columns = REPLACE(@Columns, 'q.' + @ContraField, '[MFTGuid] ' + @ContraField) 

	SET @Sql = ' CREATE VIEW ' + @ViewName + CHAR(13) + ' AS ' + CHAR(13)
	SET @c = CURSOR FAST_FORWARD FOR SELECT CASE WHEN dbo.fnIsLocalServer(SERVERNAME) = 1 THEN '' ELSE '[' + SERVERNAME +']' + '.' END + DBNAME FROM [Multifiles000]
	SET @I = 0
	
	OPEN @c FETCH FROM @c INTO @db
	SET @Sql = @Sql + ' SELECT ' + @Columns2 + CHAR(13) + ' FROM ' + CHAR(13) + '('
	WHILE @@FETCH_STATUS = 0 
	BEGIN 
		IF @I <> 0
		BEGIN
			SET @Sql = @Sql + ' UNION ALL ' + char(13)
			IF @Cheeck > 0	AND @I = 1
				SET @CH = @Field + ' NOT IN (SELECT ' +@Field+ ' FROM ' +@prvdb+ '.dbo.' + @TblName 
			ELSE IF  @Cheeck > 0	AND @I > 1 
				SET @CH = @CH + ' UNION ALL SELECT ' +@Field+ ' FROM ' +@prvdb+ '.dbo.' + @TblName
		END
		SET @Sql = @Sql + ' SELECT ' + @Columns 
		IF @CurrValByFile > 0
			SET @Sql = @Sql + ',[dbo].[fnCurrencyMuli_Fix](1,q.[CurrencyGuid],q.[CurrencyVal],q.[CurrencyGuid],[Date]) newCurrVal'
		SET @Sql = @Sql + ' FROM ' + @db + '.dbo.' + @TblName + ' q '
		IF @HaveContra > 0
		BEGIN
			SET @Sql = @Sql + ' INNER JOIN MultContraTypes w ON W.TypeGuid = q.' + @ContraField + char(13)
		END
		
		IF @ParentDate <> ''  AND @CurrValByFile > 0
		BEGIN
			SET @Sql = @Sql + ' INNER JOIN ' + @db + '.dbo.' + @ParentDate + ' v ON v.Guid = q.' + @RefDate
		END
		IF @HaveContra > 0 
		BEGIN 
			SET @Sql = @Sql + ' WHERE DbName = ''' + @db + ''' '
			IF @ContraFlag > 0 
				SET @Sql = @Sql + ' AND ([Flag] &' + CAST(@ContraFlag AS NVARCHAR(10)) +') > 0' 	
			SET @Sql = @Sql + CHAR(13)
		END	
		IF (@Cond <> '' )
		BEGIN 
			IF @HaveContra > 0
				SET @Sql = @Sql + ' AND '  
			ELSE
				SET @Sql = @Sql + ' WHERE ' 
			SET @Sql = @Sql+ @Cond
		END
		IF @Cheeck >0 AND  @I > 0
		BEGIN
			IF (@Cond <> '' ) OR  @HaveContra > 0
				SET @Sql = @Sql + ' AND '
			ELSE 
				SET @Sql = @Sql + ' WHERE '
			SET @Sql = @Sql + @CH + ')'
		END	
		
		SET @Sql = @Sql + CHAR(13)
		SET @prvdb = @db
		SET @I =@I + 1
		FETCH FROM @c INTO @db
	END 
	CLOSE @c
	DEALLOCATE @c
	SET @Sql = @Sql + ') A '
	IF (@hasFP = 0)
			SET @Sql = @Sql + ' LEFT JOIN BillEntryNotExist b ON a.['+ @Field + '] = b.[GUID]  WHERE b.[GUID] IS NULL'
	
	EXEC (@Sql)
	IF (@OutTable <> '')
	BEGIN
		SET @Sql = ' CREATE VIEW ' + @TblName + CHAR(13) +' AS SELECT ' + @Columns3 + ' FROM ' + @ViewName + ' q WHERE GUID NOT IN (SELECT GUID FROM ' + @OutTable + ')'
		EXEC (@Sql)
	END
##########################################################################################
CREATE PROCEDURE prcMultiFileGetMoves
	@hasFP			[BIT] = 0,
	@CurrInMulti	[BIT] = 0,
	@HaveContra		[BIT] = 0
AS
	EXEC prcCreateColumnFunction
	EXEC prcMuliFilesUpDateDefaultValues
	DECLARE @db NVARCHAR(100),@Sql  NVARCHAR(1000)
	IF @CurrInMulti = 0 
		EXEC prcGetMuliFilesMoves 'mh000'
	ELSE 
	BEGIN
		SELECT @db = CASE WHEN dbo.fnIsLocalServer(SERVERNAME) = 1 THEN '' ELSE '[' + SERVERNAME +']' + '.' END + DBNAME
		FROM multifiles000 WHERE DBNAME = (SELECT [Value] FROM OP000 WHERE [NAME] = 'AmncfgMainFile')
		IF @db IS NOT NULL
		BEGIN
		SET @SQL = ''
			IF EXISTS (SELECT * FROM SYS.OBJECTS WHERE [NAME] = 'mh000' AND [TYPE] = 'U')
				SET @SQL = 'DROP TABLE mh000'
			ELSE IF EXISTS (SELECT * FROM SYS.OBJECTS WHERE [NAME] = 'mh000' AND [TYPE] = 'V')
				SET @SQL = 'DROP VIEW mh000'
			EXEC(@SQL)
			SET @SQL = 'CRETE VIEW mh000 ' + CHAR(13) + 'AS ' + CHAR(13) + ' SELECT * FROM ' + @db +'.dbo.mh000'
		END
	END
	EXEC prcGetMuliFilesMoves 'bu000',@hasFP,'Guid',0,'','',@CurrInMulti,'[Total],[TotalDisc],[ItemsDisc],[BonusDisc],[Profits],[TotalExtra],[ItemsExtra],[FirstPay],[VAT],[CurrencyVal]','','',@HaveContra,1
	EXEC prcGetMuliFilesMoves 'bi000',@hasFP,'ParentGuid',0,'','',@CurrInMulti,'[Price],[Discount],[BonusDisc],[Extra],[Profits],[VAT],[CurrencyVal]','bu000'
	EXEC prcGetMuliFilesMoves 'di000',@hasFP,'ParentGuid',0,'','',@CurrInMulti,'[Discount],[Extra],[CurrencyVal]','bu000'
	EXEC prcGetMuliFilesMoves 'ce000',@hasFP,'Guid',0,'Chkentry','',@CurrInMulti,'[Debit],[Credit],[CurrencyVal]','','',@HaveContra,0
	EXEC prcGetMuliFilesMoves 'en000',@hasFP,'ParentGuid',0,'','',@CurrInMulti,'[Debit],[Credit],[CurrencyVal]'
	EXEC prcGetMuliFilesMoves 'er000',@hasFP,'EntryGuid'
	EXEC prcGetMuliFilesMoves 'py000',@hasFP,'Guid',0,'','',@CurrInMulti,'[Debit],[Credit],[CurrencyVal]','','',@HaveContra,2
	EXEC prcGetMuliFilesMoves 'CH000',0,'Guid',1,'','',@CurrInMulti,'[Val],[CurrencyVal]','','',@HaveContra,4
	EXEC prcGetMuliFilesMoves 'SNC000',0,'Guid',1
	EXEC prcGetMuliFilesMoves 'Snt000',0,'biGuid'
	EXEC prcGetMuliFilesMoves 'pt000',@hasFP,'Guid',0,'',' [IsTransfered] = 0'--,case @hasFP when 0 then 0 else @CurrInMulti end,'[Debit],[Credit],[CurrencyVal]','bu000','RefGuid'
	EXEC prcGetMuliFilesMoves 'Bp000',1,'',0,'','',@CurrInMulti,'[Val],[CurrencyVal]','en000','PayGuid'
	EXEC prcGetMuliFilesMoves 'ti000',0
##########################################################################################
CREATE PROCEDURE prcGetAmnDbases
	@SeverName NVARCHAR(1000) = '.'
AS
	SET NOCOUNT ON
	DECLARE @c Cursor,@DBName NVARCHAR(100),@dbID [INT] ,@StartDate [DATETIME],@EndDate [DATETIME]
	DECLARE @Sql NVARCHAR(1000),@FileName NVARCHAR(100),@FileLatinName NVARCHAR(100),@I1 INT,@I2 INT,@DBVer NVARCHAR(100)
	IF dbo.fnIsLocalServer(@SeverName) = 1
		SET @SeverName = ''
	ELSE 
		SET @SeverName = '['+@SeverName + '].' 	
	DECLARE @Properties NVARCHAR(30)
	SET @Properties = 'SYS.EXTENDED_PROPERTIES'
	CREATE TABLE #MultiFiles
	(
		[dbID]			[INT],
		[DBName]		[NVARCHAR](100),
		[StartDate]		[DATETIME],
		[EndDate]		[DATETIME],
		[FileName]		[NVARCHAR](100) COLLATE ARABIC_CI_AI,
		[DBVer]			[NVARCHAR](100) COLLATE ARABIC_CI_AI,
		FileLatinName	[NVARCHAR](100) COLLATE ARABIC_CI_AI
	)
	CREATE TABLE #DBS([id] INT ,[DBName] NVARCHAR(100))
	SET @Sql = ' INSERT INTO #DBS SELECT dbid,name FROM '+ @SeverName +'master.DBO.sysdatabases WHERE dbid  > 4 AND NAME <> ''AmnConfig'' AND ([Status] & 0x83A0)  = 0  '
	EXEC(@Sql)
	CREATE TABLE #idS(ID INT)
	CREATE TABLE #STRVAL([Val] [NVARCHAR](100) COLLATE ARABIC_CI_AI)
	SET @c = CURSOR FAST_FORWARD FOR SELECT [id] , '[' + [DBName] +']' FROM #DBS  WHERE DBName NOT LIKE '%-%'
	OPEN @c FETCH FROM @c INTO @dbID, @DBName
	WHILE @@FETCH_STATUS = 0 
	BEGIN

		SET @FileName = ''
		SET @Sql = 'SELECT  CAST(VALUE  AS NVARCHAR(100)) FROM ' + @DBName + '.' + @Properties + ' WHERE [Name] = ''AmnDBName'''
		insert #STRVAL exec(@Sql)

		select @FileName = [Val] from #STRVAL
		delete #STRVAL
		IF (@FileName <> '')
		BEGIN
			SET @Sql = ' SELECT object_id FROM '+ @DBName + '.Sys.objects WHERE object_id = OBJECT_ID('''+ @DBName + '.dbo.op000'')'
			
			INSERT INTO #idS exec(@Sql)
			IF @@ROWCOUNT > 0
			BEGIN
				SET @Sql = 'SELECT  CAST(VALUE  AS NVARCHAR(100)) FROM ' + @DBName + '.' + @Properties + ' WHERE [Name] = ''AmnDBLatinName'''
				INSERT #STRVAL exec(@Sql)
				select @FileLatinName = [Val] from #STRVAL
				delete #STRVAL	
				SET @Sql = 'SELECT  CAST(VALUE  AS NVARCHAR(100)) FROM ' + @DBName + '.' + @Properties + ' WHERE [Name] = ''AmnDBVersion'''
				INSERT #STRVAL exec(@Sql)
				select @DBVer = [Val] from #STRVAL
				delete #STRVAL	
				SET @Sql = 'SELECT  CAST(value  AS NVARCHAR(100)) FROM ' + @DBName + '.dbo.op000 WHERE [Name] = ''AmnCfg_FPDate'''
				insert #STRVAL exec(@Sql)
				SELECT 
				@I1 = CHARINDEX ('-',[Val],0)
				,@I2 = CHARINDEX ('-',[Val],cHARINDEX ('-',[Val],0)+ 1) 
				FROM #STRVAL 
				select @StartDate =
				CAST(SUBSTRING([Val],@I1 + 1,@I2 -@I1 - 1) + '/' + SUBSTRING([Val],1,@I1 -1 ) + '/' + SUBSTRING([Val],@I2 + 1,4) AS DATETIME)
				FROM #STRVAL
				delete #STRVAL
			
				SET  @Sql = 'select  cast(value  as NVARCHAR(100)) from ' + @DBName + '.dbo.op000 WHERE [Name] = ''AmnCfg_EPDate'''
				insert #STRVAL exec(@Sql)
			
				SELECT 
				@I1 = CHARINDEX ('-',[Val],0)
				,@I2 = CHARINDEX ('-',[Val],cHARINDEX ('-',[Val],0)+ 1) 
				FROM #STRVAL 
				select @EndDate =
				CAST(SUBSTRING([Val],@I1 + 1,@I2 -@I1 - 1) + '/' + SUBSTRING([Val],1,@I1 -1 ) + '/' + SUBSTRING([Val],@I2 + 1,4) AS DATETIME)
				from #STRVAL
				INSERT INTO #MultiFiles([dbID],[DBName],[StartDate],[EndDate],[FileName],[DBVer],FileLatinName) VALUES(@dbID, @DBName,@StartDate,@EndDate,@FileName,@DBVer,@FileLatinName)
			END
		END
		FETCH FROM @c INTO @dbID, @DBName
	END
	CLOSE @c
	DEALLOCATE @c
	SELECT 
		[dbID],		
		SUBSTRING ([DBName],2,LEN([DBName]) - 2) [DBName],	
		[StartDate],	
		[EndDate],	
		[FileName],	
		[DBVer],		
		FileLatinName
	
	
	 FROM #MultiFiles ORDER BY [StartDate],[dbId]
##########################################################################################
CREATE PROCEDURE prcMultiFiles
AS 
	SET NOCOUNT ON
	DECLARE @EXP BIT,@hasFP	[BIT],@MultCurr BIT,@HaveContraTypes BIT
	EXEC prcUmatspcLength
	IF NOT EXISTS (SELECT * FROM SYSOBJECTS WHERE ID = OBJECT_ID('MultContraTypes'))
	BEGIN
		CREATE TABLE MultContraTypes
		(
			id int identity(1,1),
			MFTGuid UNIQUEIDENTIFIER,
			TypeGuid	UNIQUEIDENTIFIER,
			[Flag]			[TINYINT],
			DbName	NVARCHAR(100)
			PRIMARY KEY NONCLUSTERED 
			(
				[ID] ASC
			) 
		) 
	END
	EXEC prcGetMuliFilesvCard 'my000'
	EXEC prcGetMuliFilesvCard 'ac000'
	EXEC prcGetMuliFilesvCard 'cu000'
	EXEC prcGetMuliFilesvCard 'co000'
	EXEC prcGetMuliFilesvCard 'gr000'
	EXEC prcGetMuliFilesvCard 'mt000'
	EXEC prcGetMuliFilesvCard 'st000'
	EXECUTE prcDropFldIndex 'MultContraTypes', 'MultContraTypesInd'
	IF NOT EXISTS( SELECT top 1 * FROM sys.indexes where name = 'MultContraTypesInd')
	CREATE CLUSTERED INDEX MultContraTypesInd ON MultContraTypes(TypeGuid)
	IF EXISTS(SELECT * FROM MultContraTypes)
	BEGIN
		DELETE OP000 WHERE [Name] = 'AmncfgMfContraTypes'
		INSERT OP000 ([Name],[Value],[Computer],[Time],[Type],[OwnerGUID]) VALUES('AmncfgMfContraTypes','1',HOST_ID(),GETDATE(),0,dbo.fnGetCurrentUserGUID())
		SET @HaveContraTypes = 1
	 END
	 ELSE
		SET @HaveContraTypes = 0
	
	SELECT @EXP = CAST([Value] AS BIT)FROM [op000] WHERE  [Name] = 'AmncfgMfExeptFPOE'
	IF @EXP IS NULL 
		SET @EXP = 1
	IF @EXP = 1
		SET @hasFP = 0
	ELSE
		SET @hasFP = 1
	EXEC prcMultiFileGetCards
	IF  @hasFP = 0
	BEGIN
		EXEC prcInsertIntoFpVaulue
		EXEC prcMultipt --'BillEntryNotExist', 'BillEntryNotExistIndex'
		CREATE CLUSTERED INDEX [BillEntryNotExistIndex] ON BillEntryNotExist([Guid],[Type])
	END
	SELECT @MultCurr = CAST([Value] AS BIT)FROM [op000] WHERE  [Name] = 'AmncfgMfMultCurr'
##########################################################################################
CREATE PROCEDURE prcUmatspcLength
AS
	DECLARE @Sql NVARCHAR(max)

	DECLARE @db NVARCHAR(max),@I INT
	DECLARE @c		CURSOR
	DECLARE @Type NVARCHAR(5)
	if exists (select * from syscolumns where id = object_id('mt000') and name = 'Spec' and length > 3000)
		EXECUTE [prcAlterFld] 'mt000', 'Spec', 'NVARCHAR(3000)'
	
	SET @c = CURSOR FAST_FORWARD FOR SELECT CASE WHEN dbo.fnIsLocalServer(SERVERNAME) = 1 THEN '' ELSE '[' + SERVERNAME +']' + '.' END + DBNAME FROM [Multifiles000]
	OPEN @c FETCH FROM @c INTO @db
	WHILE @@FETCH_STATUS = 0 
	BEGIN 
		set @Sql = 'if exists (select * from '+ @db + '.sys.columns where object_id = object_id(''mt000'') and name = ''Spec'' and max_length > 3000)'
		set @Sql = @Sql + 'EXECUTE '+ @db + '.dbo.[prcAlterFld] ''mt000'', ''Spec'', ''NVARCHAR(3000)'''
		EXEC (@Sql)
		FETCH FROM @c INTO @db
	END
	CLOSE @c
	DEALLOCATE @c
##########################################################################################
CREATE PROCEDURE prcCheckallCard 
AS 
	SET NOCOUNT ON
	DECLARE @flag [INT]
	SET @flag = 0
	IF EXISTS (SELECT * FROM vac0000)
		SET @Flag = @Flag | 0x000010
	IF EXISTS (SELECT * FROM vmy0000)
		SET @Flag = @Flag | 0x000010
	IF EXISTS (SELECT guid from vco0000)
		SET @Flag = @Flag | 0x000010
	
	IF EXISTS (select guid from vcu0000)
		SET @Flag = @Flag | 0x000010
	IF EXISTS (select guid from vst0000)
		SET @Flag = @Flag | 0x000001
	IF EXISTS (select guid from vgr0000)
		SET @Flag = @Flag | 0x000001
	IF EXISTS (select guid from vmt0000)
		SET @Flag = @Flag | 0x000001

		
	IF EXISTS (SELECT DISTINCT [UserGUID] FROM bu000 a LEFT JOIN us000 B ON  b.Guid = a.[UserGUID] WHERE a.Guid IS NULL AND [UserGUID]  <>  0x00  )
			SET @Flag = @Flag | 0x000100
	SELECT @Flag AS FLAG
##########################################################################################
CREATE PROCEDURE prcMfGetContraTypes
	@Lang BIT = 0,
	@WitOutMain BIT = 0
AS
	SET NOCOUNT ON
	DECLARE @C	CURSOR,@DB NVARCHAR(100),@File NVARCHAR(100)
	DECLARE @Sql NVARCHAR(3000)
	DECLARE @Main NVARCHAR(100)
	SELECT @Main = Value FROM [op000] WHERE [NAME] = 'AmncfgMainFile'
	CREATE TABLE #Contra
	(
		[ID]			INT IDENTITY(1,1),	
		FileName		NVARCHAR(100) COLLATE ARABIC_CI_AI,
		DBName			NVARCHAR(100) COLLATE ARABIC_CI_AI,
		Type			TINYINT,
		TypeGuid		UNIQUEIDENTIFIER,
		TypeName		NVARCHAR(100) COLLATE ARABIC_CI_AI,
		ContraTypeGuid	UNIQUEIDENTIFIER,
		ContraTypeName	NVARCHAR(100) COLLATE ARABIC_CI_AI,
		btType			TINYINT DEFAULT 0
	)
	DECLARE @Properties NVARCHAR(30)
	SET @Properties = 'SYS.EXTENDED_PROPERTIES'
	CREATE TABLE #File ( F NVARCHAR(100) COLLATE ARABIC_CI_AI)
	SET @c = CURSOR FAST_FORWARD FOR SELECT  CASE WHEN dbo.fnIsLocalServer(SERVERNAME) = 1 THEN '' ELSE '[' + SERVERNAME +']' + '.' END + DBName FROM MultiFiles000 
										WHERE @WitOutMain = 0 OR DBName <> ISNULL(@Main,'') ORDER BY NUMBER 

	OPEN @c FETCH FROM @c INTO @DB
	WHILE (@@FETCH_STATUS = 0 )
	BEGIN
		TRUNCATE TABlE #File
		SET @Sql = 'SELECT  CAST(value AS NVARCHAR(100)) FROM ' + @DB + '.' + @Properties + ' WHERE [name] = CASE '+ CAST( @Lang AS NVARCHAR(1))+ ' WHEN 0 THEN ''AmnDBName'' ELSE ''AmnDBLatinName'' END '
		INSERT #File EXEC(@Sql)
		SELECT @File = f FROM #File
		SET @Sql = 'INSERT INTO #Contra (FileName,DBName,Type,TypeGuid,TypeName,ContraTypeGuid,ContraTypeName,btType)' + CHAR(13)
		SET @Sql = @Sql + ' SELECT  '''+ CAST(@File AS NVARCHAR(100) )+ ''',''' + @DB + ''',1,a.Guid,'
		IF (@Lang = 0)
			SET @Sql = @Sql + 'a.Name,'
		ELSE
			SET @Sql = @Sql + ' CASE a.LatinName WHEN '''' THEN a.Name ELSE  a.LatinName END,'	
		SET @Sql = @Sql + 'ISNULL(MFTGuid,0X00),'
		IF (@Lang = 0)
			SET @Sql = @Sql + ' ISNULL(w.Name,'''')'
		ELSE
			SET @Sql = @Sql + ' ISNULL(CASE w.LatinName WHEN '''' THEN w.Name ELSE  w.LatinName END,'''')'
		SET @Sql = @Sql + ',a.Type '
		SET @Sql = @Sql + ' FROM ' + @DB + '.dbo.bt000 a LEFT JOIN (SELECT * FROM  MultContraTypes WHERE dbname = ''' + @DB + ''' AND [Flag] = 1) B ON a.Guid = b.TypeGuid LEFT JOIN bt000 w ON w.Guid = MFTGuid'
		SET @Sql = @Sql + ' ORDER BY a.Type,a.SortNum'
		EXEC (@Sql)

		SET @Sql = 'INSERT INTO #Contra (FileName,DBName,Type,TypeGuid,TypeName,ContraTypeGuid,ContraTypeName)' + CHAR(13)
		SET @Sql = @Sql + ' SELECT  ''' + CAST(@File AS NVARCHAR(100) )+ ''',''' + @DB + ''',2,a.Guid,'
		IF (@Lang = 0)
			SET @Sql = @Sql + 'a.Name,'
		ELSE
			SET @Sql = @Sql + ' CASE a.LatinName WHEN '''' THEN a.Name ELSE  a.LatinName END,'	
		SET @Sql = @Sql + 'ISNULL(MFTGuid,0X00),'
		IF (@Lang = 0)
			SET @Sql = @Sql + ' ISNULL(w.Name,'''')'
		ELSE
			SET @Sql = @Sql + ' ISNULL(CASE w.LatinName WHEN '''' THEN w.Name ELSE  w.LatinName END,'''')'
		SET @Sql = @Sql + ' FROM ' + @DB + '.dbo.et000 a LEFT JOIN (SELECT * FROM  MultContraTypes WHERE dbname = ''' + @DB + '''  AND [Flag] = 2) B ON a.Guid = b.TypeGuid  LEFT JOIN et000 w ON w.Guid = MFTGuid'
		SET @Sql = @Sql + CHAR(13) + 'UNION ALL' + CHAR(13)
		SET @Sql = @Sql + ' SELECT  ''' + CAST(@File AS NVARCHAR(100) )+''',''' + @DB + ''',4,a.Guid,'
		IF (@Lang = 0)
			SET @Sql = @Sql + 'a.Name,'
		ELSE
			SET @Sql = @Sql + ' CASE a.LatinName WHEN '''' THEN a.Name ELSE  a.LatinName END,'	
		SET @Sql = @Sql + 'ISNULL(MFTGuid,0X00),'
		IF (@Lang = 0)
			SET @Sql = @Sql + ' ISNULL(w.Name,'''')'
		ELSE
			SET @Sql = @Sql + ' ISNULL(CASE w.LatinName WHEN '''' THEN w.Name ELSE  w.LatinName END,'''')'
		SET @Sql = @Sql + ' FROM ' + @DB + '.dbo.nt000 a LEFT JOIN (SELECT * FROM  MultContraTypes WHERE dbname = ''' + @DB + '''  AND [Flag] = 4) B ON a.Guid = b.TypeGuid  LEFT JOIN nt000 w ON w.Guid = MFTGuid'
		EXEC (@Sql)
		FETCH FROM @c INTO  @DB
	END
	CLOSE @c
	DEALLOCATE @c
	SELECT * FROM #Contra ORDER BY ID
	SELECT DBName,FileName FROM #Contra GROUP BY DBName,FileName ORDER BY MIN(ID)
##########################################################################################
CREATE PROCEDURE prcGetMFNameDefbyCode
	@DbName NVARCHAR(100)
AS
	SET NOCOUNT ON
	DECLARE @Sql NVARCHAR(2000),@MainDb NVARCHAR(100)
	SELECT @MainDb = [VALUE] FROM op000 where name = 'AmncfgMainFile'
	IF @MainDb IS NULL
		RETURN	
	SET  @Sql = 'SELECT ISNULL(a.[Code],b.[Code]) Code, ISNULL(a.[Name],'''') FirstName,b.[Name] SeccondName, ISNULL(a.[LatinName],'''') FirstLatinName,b.[LatinName] SeccondLatinName, a.BarCode FirstBarCode,b.BarCode SeccondBarCode '
	SET  @Sql = @Sql + ',ISNULL(a.Spec,'''') FirstSpec,b.Spec SeccondSpec,ISNULL(a.Origin,'''')	FirstOrigin,b.Origin SeccondOrigin,ISNULL(a.Company,'''') FirstCompany,b.Company	SeccondCompany'
	SET  @Sql = @Sql + ',ISNULL(a.Pos,'''') FirstPos,b.Pos SeccondPos,ISNULL(a.Dim,'''') FirstDim,b.Dim SeccondDim,b.Color	SeccondColor,ISNULL(a.Color,'''') FirstColor'
	SET  @Sql = @Sql + ' FROM ' + @MainDb +'.dbo.MT000 a RIGHT JOIN ' + @DbName +'.dbo.mt000 b ON a.Code = b.Code WHERE ISNULL(a.[Name],'''') <>  b.[Name]' + CHAR(13)
	SET  @Sql = @Sql + 'SELECT ISNULL(a.[Code],b.Code) Code,ISNULL(a.[Name],'''') FirstName,b.[Name] SeccondName, ISNULL(a.[LatinName],'''') FirstLatinName,b.[LatinName] SeccondLatinName '
	SET  @Sql = @Sql + ' FROM ' + @MainDb +'.dbo.ac000 a RIGHT JOIN ' + @DbName +'.dbo.ac000 b ON a.Code = b.Code WHERE ISNULL(a.[Name],'''') <>  b.[Name]' + CHAR(13)
	SET  @Sql = @Sql + 'SELECT ISNULL(a.[Code],b.Code) Code,ISNULL(a.[Name],'''') FirstName,b.[Name] SeccondName, ISNULL(a.[LatinName],'''') FirstLatinName,b.[LatinName] SeccondLatinName '
	SET  @Sql = @Sql + ' FROM ' + @MainDb +'.dbo.co000 a RIGHT JOIN ' + @DbName +'.dbo.co000 b ON a.Code = b.Code WHERE ISNULL(a.[Name],'''') <>  b.[Name]' + CHAR(13)
	EXEC(@Sql)
##########################################################################################
#END