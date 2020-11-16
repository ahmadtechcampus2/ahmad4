#########################################################
CREATE PROCEDURE prcInsertUniFileCardsMoves
AS
	
	INSERT INTO #Cards (Card,ColumnName) VALUES ('us000','LogInName' )
	INSERT INTO #Cards (Card) VALUES ('my000')
	INSERT INTO #Cards (Card) VALUES ('BR000')
	INSERT INTO #Cards (Card) VALUES ('AC000')
	INSERT INTO #Cards (Card) VALUES ('co000')
	INSERT INTO #Cards (Card) VALUES ('gr000')
	INSERT INTO #Cards (Card,ColumnName) VALUES ('cu000','CustomerName' )
	INSERT INTO #Cards (Card) VALUES ('mt000')
	INSERT INTO #Cards (Card) VALUES ('st000')
	INSERT INTO #Cards (Card,ColumnName,ColumnName2) VALUES ('mh000','CurrencyGUID','Date')
	-- us000 
	SELECT c.Name AS tbl,b.name ColumnGuid,'us000' as Card
	INTO #Mov
	from sysforeignkeys a INNER JOIN SYSCOLUMNS b ON a.fkeyid = b.id
	INNER JOIN SYSOBJECTS c ON c.id = fkeyid
	WHERE rkeyid = OBJECT_ID('us000') and fkey = colOrder
	INSERT INTO #Mov (tbl,ColumnGuid,Card)
		SELECT b.Name,a.Name,'us000' from syscolumns a INNER JOIN SYSOBJECTS B on a.id = b.id 
		where a.name like '%user%' and a.xtype = 36 and b.Xtype = 'u'
	
	INSERT INTO  #Mov (tbl,ColumnGuid,Card) VALUES('ac000','ParentGuid','ac000')
	-- AC000 
	INSERT INTO #Mov
	SELECT c.Name AS tbl,b.name ColumnGuid,'ac000' as Card
	
	from sysforeignkeys a INNER JOIN SYSCOLUMNS b ON a.fkeyid = b.id
	INNER JOIN SYSOBJECTS c ON c.id = fkeyid
	WHERE rkeyid = OBJECT_ID('AC000') and fkey = colOrder
	INSERT INTO #Mov (tbl,ColumnGuid,Card)
		SELECT b.Name,a.Name,'AC000' from syscolumns a INNER JOIN SYSOBJECTS B on a.id = b.id 
		where a.name like '%Acc%' and a.xtype = 36 and b.Xtype = 'u'
	
	INSERT INTO  #Mov (tbl,ColumnGuid,Card) VALUES('ac000','ParentGuid','ac000')
	--CU000
	INSERT INTO #Mov (tbl,ColumnGuid,Card)
	select c.Name ,b.name ,'CU000' 
	from sysforeignkeys a INNER JOIN SYSCOLUMNS b ON a.fkeyid = b.id
	INNER JOIN SYSOBJECTS c ON c.id = fkeyid
	WHERE rkeyid = OBJECT_ID('CU000') and fkey = colOrder

	INSERT INTO #Mov (tbl,ColumnGuid,Card)
		SELECT b.Name,a.Name,'CU000' from syscolumns a INNER JOIN SYSOBJECTS B on a.id = b.id 
		where a.name like '%CUST%' and a.xtype = 36 and b.Xtype = 'u'
	--CO000
	INSERT INTO #Mov (tbl,ColumnGuid,Card) VALUES('co000','ParentGuid','co000')
	INSERT INTO #Mov (tbl,ColumnGuid,Card) SELECT c.Name ,b.name,'co000'
	from sysforeignkeys a INNER JOIN SYSCOLUMNS b ON a.fkeyid = b.id
	INNER JOIN SYSOBJECTS c ON c.id = fkeyid
	WHERE rkeyid = OBJECT_ID('co000') and fkey = colOrder
	INSERT INTO #Mov (tbl,ColumnGuid,Card)
		SELECT b.Name,a.Name,'co000' from syscolumns a INNER JOIN SYSOBJECTS B on a.id = b.id 
		where a.name like '%cost%' and a.xtype = 36 and b.Xtype = 'u'
	--GR000
	INSERT INTO #Mov (tbl,ColumnGuid,Card) VALUES('gr000','ParentGuid','gr000')
	INSERT INTO #Mov (tbl,ColumnGuid,Card) VALUES('ma000','ObjGuid','gr000')
	INSERT INTO #Mov (tbl,ColumnGuid,Card)
	SELECT c.Name ,b.name ,'gr000'
	from sysforeignkeys a INNER JOIN SYSCOLUMNS b ON a.fkeyid = b.id
	INNER JOIN SYSOBJECTS c ON c.id = fkeyid
	WHERE rkeyid = OBJECT_ID('gr000') and fkey = colOrder
	INSERT INTO #Mov (tbl,ColumnGuid,Card)
		SELECT b.Name,a.Name,'gr000' from syscolumns a INNER JOIN SYSOBJECTS B on a.id = b.id 
		where a.name like '%group%' and a.xtype = 36 and b.Xtype = 'u'
	--mt000
	INSERT INTO #Mov (tbl,ColumnGuid,Card) VALUES('ma000','ObjGuid','mt000')
	INSERT INTO #Mov (tbl,ColumnGuid,Card) VALUES('as000','parentGuid','mt000')
	INSERT INTO #Mov (tbl,ColumnGuid,Card)
	SELECT c.Name,b.name ,'mt000' 
	from sysforeignkeys a INNER JOIN SYSCOLUMNS b ON a.fkeyid = b.id
	INNER JOIN SYSOBJECTS c ON c.id = fkeyid
	WHERE rkeyid = OBJECT_ID('mt000') and fkey = colOrder
	INSERT INTO #Mov (tbl,ColumnGuid,Card)
		SELECT b.Name,a.Name,'mt000' from syscolumns a INNER JOIN SYSOBJECTS B on a.id = b.id 
		WHERE (a.name like '%mat%' or a.name like '%mt%') and a.xtype = 36 and b.Xtype = 'u'
	--st000
	INSERT INTO #Mov (tbl,ColumnGuid,Card)
	SELECT c.Name ,b.name,'st000'
	FROM SYSFOREIGNKEYS A INNER JOIN SYSCOLUMNS B ON A.FKEYID = B.ID
	INNER JOIN SYSOBJECTS c ON c.id = fkeyid
	WHERE rkeyid = OBJECT_ID('st000') and fkey = colOrder
	INSERT INTO #Mov (tbl,ColumnGuid,Card)
	SELECT b.Name,a.Name,'st000' from syscolumns a INNER JOIN SYSOBJECTS B on a.id = b.id 
	WHERE a.name like '%st%' and a.xtype = 36 and b.Xtype = 'u'
	--my000
	INSERT INTO #Mov (tbl,ColumnGuid,Card)
	SELECT c.Name ,b.name,'my000' 
	FROM sysforeignkeys a INNER JOIN SYSCOLUMNS b ON a.fkeyid = b.id
	INNER JOIN SYSOBJECTS c ON c.id = fkeyid
	WHERE rkeyid = OBJECT_ID('my000') and fkey = colOrder
	INSERT INTO #Mov (tbl,ColumnGuid,Card)
	SELECT b.Name,a.Name,'my000' from syscolumns a INNER JOIN SYSOBJECTS B on a.id = b.id 
	WHERE a.name like '%curr%' and a.xtype = 36 and b.Xtype = 'u'
	
	INSERT INTO #Mov (tbl,ColumnGuid,Card)
	SELECT c.Name ,b.name,'BR000' 
	FROM sysforeignkeys a INNER JOIN SYSCOLUMNS b ON a.fkeyid = b.id
	INNER JOIN SYSOBJECTS c ON c.id = fkeyid
	WHERE rkeyid = OBJECT_ID('BR000') and fkey = colOrder
	INSERT INTO #Mov (tbl,ColumnGuid,Card)
	SELECT b.Name,a.Name,'BR000' from syscolumns a INNER JOIN SYSOBJECTS B on a.id = b.id 
	WHERE a.name like '%Branch%' and a.xtype = 36 and b.Xtype = 'u'
	
	INSERT INTO  #Move (tbl,ColumnGuid,Card) SELECT DISTINCT tbl,ColumnGuid,Card FROM #Mov 
#########################################################
CREATE PROCEDURE prcUniFilesByCode
AS
	SET NOCOUNT ON
	BEGIN TRAN 
	DECLARE @Sql   NVARCHAR(4000),@tbl NVARCHAR(100),@ColumnGuidName NVARCHAR(100),@id2 INT,@ColumnName2 NVARCHAR(100)
	CREATE TABLE #Cards (Card NVARCHAR(100),ColumnName NVARCHAR(100) DEFAULT 'Code',ColunGuid NVARCHAR(100) DEFAULT 'GUID',ColumnName2 NVARCHAR(100) DEFAULT '')
	CREATE TABLE #Multi([ID] INT IDENTITY(1,1),[DB] NVARCHAR(100))
	CREATE TABLE #Move 
		(tbl NVARCHAR(100)	COLLATE ARABIC_CI_AI,ColumnGuid NVARCHAR(100) COLLATE ARABIC_CI_AI,Card NVARCHAR(100) COLLATE ARABIC_CI_AI)
	DECLARE @MainFile NVARCHAR(100),@rcnt INT
	CREATE TABLE #resut
	(
		[dbName] NVARCHAR(100)	COLLATE ARABIC_CI_AI,
		[tbl]	 NVARCHAR(100)	COLLATE ARABIC_CI_AI,
		cnt		INT	,
		SepType BIT DEFAULT 0,
		[CardName] NVARCHAR(100)	COLLATE ARABIC_CI_AI DEFAULT ''
	)

	
	
	SELECT @MainFile = [VALUE] FROM op000 where name = 'AmncfgMainFile'
	INSERT INTO #Multi(DB) SELECT DBNAme FROM dbo.MultiFiles000 WHERE DBNAme <> @MainFile
	SET @Sql = 'EXEC '+ @MainFile+ '..prcInsertUniFileCardsMoves'
	EXEC( @Sql)
	DECLARE @c CURSOR ,@Db NVARCHAR(100),@Id INT,@MaxId INT,@Card NVARCHAR(100),@ColumnName NVARCHAR(100),@ColumnCuid NVARCHAR(100)
	DECLARE @ctbl CURSOR 
	
	SELECT @MaxId = MAX(ID) FROM #Multi
	DECLARE @Fetch INT
		CREATE TABLE #ContraGuid
	(
		orgGuid UNIQUEIDENTIFIER,
		newguid UNIQUEIDENTIFIER
	) 	
	------Seperate Guids-----------
	
	SELECT COUNT(*) AS CARDCNT FROM #Cards
	SET @c = CURSOR FAST_FORWARD FOR SELECT Card,ColumnName,ColunGuid,ColumnName2 FROM #Cards WHERE CARD LIKE '%000'
	OPEN @c

	DECLARE @sql2 NVARCHAR(100)
	FETCH  FROM @c  INTO @Card ,@ColumnName,@ColumnCuid,@ColumnName2
	SET @Fetch = @@FETCH_STATUS
	WHILE @Fetch = 0
	BEGIN
		set @Id = 1
		while (@Id <= @MaxId)
		BEGIN
			TRUNCATE TABLE #ContraGuid	
			SELECT @Db = DB FROM #Multi WHERE @Id = Id
			IF (@ColumnName2 <> '')
				SET @sql2 = ' AND A.' + @ColumnName2 + '= b.' +  @ColumnName2 + ' '
			ELSE
				SET  @sql2 = ''
			SET @Sql = 'INSERT INTO #ContraGuid SELECT A.' + @ColumnCuid +',NewID() FROM ' + @Db + '.dbo.'+  @Card + ' a INNER JOIN  '+ @MainFile + '.dbo.' +  @Card + ' b ON a.'+ @ColumnCuid + '= b.' + @ColumnCuid + @sql2 + ' WHERE a.'+ @ColumnName + ' <> b.' + @ColumnName 
			
			EXEC sp_executesql @Sql
			SET @Sql = 'EXEC '+ @Db + '.dbo.prcDisableTriggers	'''+  @Card + ''', 0'
			EXEC sp_executesql @Sql
			SET @Sql = ' UPDATE a SET ' + @ColumnCuid + ' = b.newguid FROM  '  + @Db + '.dbo.'+  @Card + ' a INNER JOIN #ContraGuid b ON a.'+ @ColumnCuid + '= b.orgGuid '
			EXEC sp_executesql @Sql
			SET @rcnt = @@ROWCOUNT
			IF (@rcnt > 0)
			BEGIN
				SET @Sql = 'INSERT INTO #resut SELECT ''' + @Db + ''',''' +@Card + ''',' + cast(@rcnt as NVARCHAR(20)) + ',1,' + @ColumnName + ' FROM ' + @Db + '.dbo.'+  @Card + ' a INNER JOIN #ContraGuid b ON a.'+ @ColumnCuid + '= b.newguid WHERE b.orgGuid <> b.newguid'
				EXEC sp_executesql @Sql
			END
			SET @Sql = 'EXEC '+ @Db + '.dbo.prcEnableTriggers '''+  @Card +''''
			EXEC sp_executesql @Sql
			SET @ctbl = CURSOR FAST_FORWARD FOR SELECT tbl,'[' + ColumnGuid +']' from #Move WHERE Card = @Card AND tbl LIKE '%000'
			OPEN @ctbl
			FETCH  FROM @ctbl  INTO @tbl ,@ColumnGuidName
			WHILE @@FETCH_STATUS = 0
			BEGIN
				SET @Sql = 'EXEC '+ @Db + '.dbo.prcDisableTriggers	'''+  @tbl + ''', 0'
				EXEC sp_executesql @Sql
				SET @Sql = ' UPDATE A SET ' + @ColumnGuidName + '= b.newguid FROM  ' +  @Db + '.dbo.'+  @tbl + ' a INNER JOIN #ContraGuid b ON a.'+ @ColumnGuidName + '= b.orgGuid '
				EXEC sp_executesql @Sql
				SET @rcnt = @@ROWCOUNT
				IF (@rcnt > 0)
					INSERT INTO #resut ([dbName],[tbl],cnt,SepType)  VALUES (@Db,@tbl,@rcnt,1)
				SET @Sql = 'EXEC '+ @Db + '.dbo.prcEnableTriggers '''+  @tbl +''''
				EXEC sp_executesql @Sql	
				FETCH  FROM @ctbl  INTO @tbl ,@ColumnGuidName
			END
			CLOSE @ctbl
			SET @ID = @ID + 1					   
		END
		
		FETCH  FROM @c  INTO @Card ,@ColumnName,@ColumnCuid,@ColumnName2
		SET @Fetch = @@FETCH_STATUS
	END
	close @c
	----------------------------------

	SET @c = CURSOR FAST_FORWARD FOR SELECT Card,ColumnName,'['+ ColunGuid + ']',ColumnName2 FROM #Cards WHERE CARD LIKE '%000'
	OPEN @c
	
	FETCH  FROM @c  INTO @Card ,@ColumnName,@ColumnCuid,@ColumnName2
	SET @Fetch = @@FETCH_STATUS
	WHILE @Fetch = 0
	BEGIN
		SELECT @Card AS Res
		set @Id = 1
		while (@Id <= @MaxId)
		BEGIN
			TRUNCATE TABLE #ContraGuid	
			SELECT @Db = DB FROM #Multi WHERE @Id = Id
			IF (@ColumnName2 <> '')
				SET @sql2 = ' AND A.' + @ColumnName2 + '= b.' +  @ColumnName2 + ' '
			ELSE
				SET  @sql2 = ''
			SET @Sql = 'INSERT INTO #ContraGuid SELECT A.' + @ColumnCuid +',b.' + @ColumnCuid + ' from ' + @Db + '.dbo.'+  @Card + ' a INNER JOIN  '+ @MainFile + '.dbo.' +  @Card + ' b ON a.'+ @ColumnName + '= b.' + @ColumnName + @sql2 + ' WHERE a.'+ @ColumnCuid + ' <> b.' + @ColumnCuid 
			EXEC sp_executesql @Sql

			SET @Sql = 'EXEC '+ @Db + '.dbo.prcDisableTriggers	'''+  @Card + ''', 0'
			EXEC sp_executesql @Sql
			SET @Sql = ' UPDATE a SET ' + @ColumnCuid + ' = b.newguid FROM  '  + @Db + '.dbo.'+  @Card + ' a INNER JOIN #ContraGuid b ON a.'+ @ColumnCuid + '= b.orgGuid '

			EXEC sp_executesql @Sql

			SET @rcnt = @@ROWCOUNT
			IF (@rcnt > 0)
			BEGIN
				SET @Sql = 'INSERT INTO #resut SELECT ''' + @Db + ''',''' +@Card + ''',' + cast(@rcnt as NVARCHAR(20)) + ',1,' + @ColumnName + ' FROM ' + @Db + '.dbo.'+  @Card + ' a INNER JOIN #ContraGuid b ON a.'+ @ColumnCuid + '= b.newguid WHERE b.orgGuid <> b.newguid'
				EXEC sp_executesql @Sql
			END
			SET @Sql = 'EXEC '+ @Db + '.dbo.prcEnableTriggers '''+  @Card +''''
			EXEC sp_executesql @Sql
			SET @ctbl = CURSOR FAST_FORWARD FOR SELECT tbl,'[' + ColumnGuid +']' from #Move WHERE Card = @Card AND tbl LIKE '%000'
			OPEN @ctbl
			FETCH  FROM @ctbl  INTO @tbl ,@ColumnGuidName
			WHILE @@FETCH_STATUS = 0
			BEGIN
				SET @Sql = 'EXEC '+ @Db + '.dbo.prcDisableTriggers	'''+  @tbl + ''', 0'
				EXEC sp_executesql @Sql
				SET @Sql = ' UPDATE A SET ' + @ColumnGuidName + '= b.newguid FROM  ' +  @Db + '.dbo.'+  @tbl + ' a INNER JOIN #ContraGuid b ON a.'+ @ColumnGuidName + '= b.orgGuid '
				EXEC sp_executesql @Sql
				SET @rcnt = @@ROWCOUNT
				IF (@rcnt > 0)
					INSERT INTO #resut ([dbName],[tbl],cnt,SepType)  VALUES (@Db,@tbl,@rcnt,0)
				SET @Sql = 'EXEC '+ @Db + '.dbo.prcEnableTriggers '''+  @tbl +''''
				EXEC sp_executesql @Sql	
				FETCH  FROM @ctbl  INTO @tbl ,@ColumnGuidName
			END
			CLOSE @ctbl
			DEALLOCATE @ctbl
			SET @ID = @ID + 1					   
		END
		
		FETCH  FROM @c  INTO @Card ,@ColumnName,@ColumnCuid,@ColumnName2
		SET @Fetch = @@FETCH_STATUS
	END
	CLOSE @c
	DEALLOCATE @c
	SELECT 'END' AS Res	
	COMMIT
	SELECT * FROM #resut

#########################################################
#END