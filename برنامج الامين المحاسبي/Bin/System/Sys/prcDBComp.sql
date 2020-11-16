##########################################################################
CREATE PROCEDURE repDATABASECOMP 
	@CurrDB		NVARCHAR(100) , 
	@CompDB		NVARCHAR(100) , 
	@CompServerName NVARCHAR(100)  
AS 
	SET NOCOUNT ON 
	DECLARE @SQL NVARCHAR(2000) 
	CREATE TABLE #CurrDBtbl ([NAME] NVARCHAR(100),[id] int) 
	CREATE TABLE #CompDBtbl ([NAME] NVARCHAR(100),[id] int) 
	CREATE TABLE #CurrDBTR ([Tblname] NVARCHAR(100),TRName NVARCHAR(100),Status INT,DBNAME NVARCHAR(100)) 
	CREATE TABLE #CompDBTR ([cTblname] NVARCHAR(100),cTRName NVARCHAR(100),cStatus INT,cDBNAME NVARCHAR(100)) 
	CREATE TABLE #CurrDBtblcol([Tblname] NVARCHAR(100),ColumnName NVARCHAR(100) , TYPE NVARCHAR(30), LENGTH INT ,DBNAME NVARCHAR(50)) 
	CREATE TABLE #CompDBtblcol([cTblname] NVARCHAR(100),cColumnName NVARCHAR(100) , cTYPE NVARCHAR(30), cLENGTH INT , cDBNAME NVARCHAR(50)) 
	CREATE TABLE #CurrDBtblAddtionalcol([Tblname] NVARCHAR(100),ColumnName NVARCHAR(100) , TYPE NVARCHAR(30), LENGTH INT,DBNAME NVARCHAR(50)) 
	CREATE TABLE #CompDBtblAddtionalcol([Tblname] NVARCHAR(100),ColumnName NVARCHAR(100) , TYPE NVARCHAR(30), LENGTH INT,DBNAME NVARCHAR(50)) 
	CREATE TABLE #CurInd([Tblname] NVARCHAR(100),ColumnName NVARCHAR(100) , IndName NVARCHAR(100),indid NVARCHAR(100),uniqe bit,DBNAME NVARCHAR(50)) 
	CREATE TABLE #CompInd([cTblname] NVARCHAR(100),cColumnName NVARCHAR(100) , cIndName NVARCHAR(100),cindid NVARCHAR(100),cuniqe bit,cDBNAME NVARCHAR(50)) 
	CREATE TABLE #IND([Tblname] NVARCHAR(100),ColumnName NVARCHAR(100) , IndName NVARCHAR(1000),indid NVARCHAR(100),DBNAME NVARCHAR(50)) 
	CREATE TABLE #RESULT([Tblname] NVARCHAR(100),ColumnName NVARCHAR(100),ColType NVARCHAR(30), LENGTH INT,DBNAME NVARCHAR(50),[cTblname] NVARCHAR(100),cColumnName NVARCHAR(100),cColType NVARCHAR(30),cLENGTH INT,cDBNAME NVARCHAR(50),IndName NVARCHAR(1000),cIndName NVARCHAR(1000),indid NVARCHAR(100),cindid NVARCHAR(100),TRNAME NVARCHAR(100),cTRNAME NVARCHAR(100),cStatus INT ,Status INT , TYPE NVARCHAR(100)) 
	SET @SQL ='INSERT INTO #CurrDBtbl SELECT Name,id FROM '+@CurrDB+'..sysobjects WHERE xtype = ''U''' 
	EXEC (@SQL) 
	SET @SQL ='INSERT INTO #CompDBtbl SELECT Name,id FROM ' 
	IF(@CompServerName <> '') 
		SET @SQL = @SQL + @CompServerName+'.'+ @CompDB+'..sysobjects WHERE xtype = ''U'''  
	ELSE 
		SET @SQL = @SQL + @CompDB+'..sysobjects WHERE xtype = ''U'''  
	EXEC (@SQL) 
	SELECT A.NAME CURRTBL, B.NAME COMPTBL INTO #DIFTBL FROM #CurrDBtbl A FULL JOIN #CompDBtbl B ON A.[NAME] = B.[NAME] WHERE (A.[NAME] IS NULL) OR (B.[NAME] IS NULL) 
	SELECT A.NAME CURRTBL, B.NAME COMPTBL,b.[id] compid , a.[id] currid INTO #SAMETBL FROM #CurrDBtbl A INNER JOIN #CompDBtbl B ON A.[NAME] = B.[NAME]  
	
	INSERT INTO #RESULT ([Tblname] , DBNAME ,TYPE) SELECT CURRTBL , 'CURR' , '1DIFTBL' FROM #DIFTBL WHERE COMPTBL IS NULL
	INSERT INTO #RESULT ([Tblname] , DBNAME ,TYPE) SELECT COMPTBL , 'COMP' , '1DIFTBL' FROM #DIFTBL WHERE CURRTBL IS NULL
	
	SET @SQL = 'INSERT INTO #CurrDBtblcol SELECT b.CURRTBL,a.name columnName,t.name TYPENAME,a.[length],''CURR'' FROM '+ @CurrDB+'..syscolumns a INNER JOIN #SAMETBL b on OBJECT_ID(b.CURRTBL) = ID INNER JOIN SYSTYPES t ON a.xtype = t.xtype' 
	EXEC (@SQL) 
	SET @SQL = 'INSERT INTO #CompDBtblcol SELECT b.CURRTBL,a.name columnName,t.name TYPENAME,a.[length],''COMP'' FROM ' 
	IF(@CompServerName <> '') 
		SET @SQL = @SQL + @CompServerName+'.'+ @CompDB+'..syscolumns a INNER JOIN #SAMETBL b on OBJECT_ID(b.CURRTBL) = ID INNER JOIN SYSTYPES t ON a.xtype = t.xtype' 
	ELSE 
		SET @SQL = @SQL + @CompDB+'..syscolumns a INNER JOIN #SAMETBL b on compid = ID INNER JOIN SYSTYPES t ON a.xtype = t.xtype' 

	EXEC (@SQL) 
	SET @SQL = 'INSERT INTO #CurrDBTR SELECT b.CURRTBL ,A.NAME TRNAME ,A.status & 0X800 , ''CURR'' FROM '+@CurrDB+'..sysobjects A INNER JOIN #SAMETBL b on OBJECT_ID(b.CURRTBL) = A.PARENT_OBJ WHERE A.XTYPE = ''TR'' ' 
	EXEC (@SQL) 
	SET @SQL = 'INSERT INTO #CompDBTR SELECT b.CURRTBL ,A.NAME TRNAME,A.status & 0X800 , ''COMP'' FROM ' 
	IF(@CompServerName <> '') 
		SET @SQL = @SQL + @CompServerName+'.'+@CompDB+'..sysobjects A INNER JOIN #SAMETBL b on compid= A.PARENT_OBJ WHERE XTYPE = ''TR'' ' 
	ELSE 
		SET @SQL = @SQL +@CompDB+'..sysobjects A INNER JOIN #SAMETBL b on compid = A.PARENT_OBJ WHERE XTYPE = ''TR'' ' 
	EXEC (@SQL)

	SET @SQL = 'INSERT INTO #CurInd SELECT b.CURRTBL tbl,c.Name col ,n.Name Indname,a.indid ,(case n.Status & 0x0002 when 2 then 1 else 0 end) ,''CURR''   FROM '+@CurrDB+'..sysindexkeys a INNER JOIN #SAMETBL b ON OBJECT_ID(b.CURRTBL) = a.ID 
		INNER JOIN '+@CurrDB+'..SYSCOLUMNS C ON c.ColId = a.ColId AND c.id = a.id 
		INNER JOIN '+@CurrDB+'..SYSINDEXES n ON n.indid = a.indid AND n.id = a.id  
		ORDER BY b.CURRTBL,a.indid,keyno ,n.Name,c.Name' 
	EXEC (@SQL) 

	IF(@CompServerName <> '') 
		SET @SQL = 'INSERT INTO #CompInd SELECT b.CURRTBL tbl,c.Name col ,n.Name Indname,a.indid, (case n.Status & 0x0002 when 2 then 1 else 0 end) ,''COMP'' FROM '+@CompServerName+'.'+@CompDB+'..sysindexkeys a INNER JOIN #SAMETBL b ON b.compid = a.ID 
			INNER JOIN '+@CompServerName+'.'+@CompDB+'..SYSCOLUMNS C ON c.ColId = a.ColId AND c.id = a.id 
			INNER JOIN '++@CompServerName+'.'+@CompDB+'..SYSINDEXES n ON n.indid = a.indid AND n.id = a.id  
			ORDER BY b.CURRTBL,a.indid,keyno ,n.Name,c.Name' 
	ELSE 
		 
		SET @SQL = 'INSERT INTO #CompInd SELECT b.CURRTBL tbl,c.Name col ,n.Name Indname,a.indid, (case n.Status & 0x0002 when 2 then 1 else 0 end) ,''COMP'' FROM '+@CompDB+'..sysindexkeys a INNER JOIN #SAMETBL b ON b.compid  = a.ID 
			INNER JOIN '+@CompDB+'..SYSCOLUMNS C ON c.ColId = a.ColId AND c.id = a.id 
			INNER JOIN '+@CompDB+'..SYSINDEXES n ON n.indid = a.indid AND n.id = a.id  
			--WHERE (n.status & 2) > 0 
			ORDER BY b.CURRTBL,a.indid,keyno ,n.Name,c.Name'	 
	EXEC (@SQL) 
	
	INSERT INTO #CurrDBtblAddtionalcol SELECT * FROM #CurrDBtblcol 
	INSERT INTO #CompDBtblAddtionalcol SELECT * FROM #CompDBtblcol 
	DECLARE  
		@C CURSOR,@C2 CURSOR, 
		@tblName NVARCHAR(50),@tblName2 NVARCHAR(50), 
		@columnName NVARCHAR(50),@columnName2 NVARCHAR(50), 
		@xtypename NVARCHAR(50),@xtypename2 NVARCHAR(50), 
		@length INT,@length2 INT, 
		@DBname NVARCHAR(50),@DBname2 NVARCHAR(50), 
		@TRNAME NVARCHAR(100),@TRNAME2 NVARCHAR(100), 
		@IndName NVARCHAR(100),@count INT ,@Status INT,@Indid NVARCHAR(100)
	SET @C = CURSOR FAST_FORWARD FOR  
				SELECT * FROM #CurrDBtblcol  
	 
	OPEN @C FETCH FROM @C INTO @tblName , 
		@columnName, 
		@xtypename , 
		@length, 
		@DBname   
	WHILE (@@FETCH_STATUS = 0) 
	BEGIN 
		DELETE #CompDBtblAddtionalcol WHERE [Tblname]=@tblName AND [ColumnName]=@columnName  --AND TYPE=@xtypename 
		FETCH FROM @C INTO @tblName , @columnName , @xtypename , @length ,@DBname 
	END	 
	 
	SET @C = CURSOR FAST_FORWARD FOR  
				SELECT * FROM #CompDBtblcol  
	 
	OPEN @C FETCH FROM @C INTO @tblName , 
		@columnName, 
		@xtypename , 
		@length, 
		@DBname  
	WHILE (@@FETCH_STATUS = 0) 
	BEGIN 
		DELETE #CurrDBtblAddtionalcol WHERE [Tblname]=@tblName AND [ColumnName]=@columnName --AND TYPE=@xtypename 
		FETCH FROM @C INTO @tblName , @columnName , @xtypename , @length ,@DBname 
	END	
	
	INSERT INTO #RESULT (tblName , columnName , ColType , LENGTH ,DBname , TYPE)
			SELECT [Tblname] ,ColumnName , TYPE , LENGTH ,DBNAME ,'2MISSCOL' FROM #CurrDBtblAddtionalcol
	INSERT INTO #RESULT (tblName , columnName , ColType , LENGTH ,DBname , TYPE)
			SELECT [Tblname] ,ColumnName , TYPE , LENGTH ,DBNAME ,'2MISSCOL' FROM #CompDBtblAddtionalcol

	SELECT * INTO #TempCompDBTR FROM #CompDBTR  
	SELECT * INTO #TempCurrDBTR FROM #CurrDBTR

	--
	SELECT * INTO #TempCurrIND1 FROM #CurInd  
	SELECT * INTO #TempCompIND1  FROM #CompInd

	DELETE #CurInd
	DELETE #CompInd
	
	SET @C = CURSOR FAST_FORWARD FOR  
				SELECT * FROM #TempCurrIND1 
	 
	OPEN @C FETCH FROM @C INTO @tblName , 
		@columnName, 
		@IndName , 
		@indid,
		@Status, 
		@DBname 
	WHILE (@@FETCH_STATUS = 0)
	BEGIN
		SELECT @count= COUNT(*) FROM #CurInd WHERE tblName = @tblName AND IndName = @IndName
		IF(@count = 0)
			INSERT INTO #CurInd VALUES (@tblName,@columnName ,@IndName , @indid , @Status , @DBname)
		ELSE
			UPDATE #CurInd SET columnName = columnName +' ,'+ @columnName WHERE tblName = @tblName AND IndName = @IndName

		FETCH FROM @C INTO @tblName , 
		@columnName, 
		@IndName , 
		@indid,
		@Status, 
		@DBname 
		
	END

	SET @C = CURSOR FAST_FORWARD FOR  
				SELECT * FROM #TempCompIND1 
	 
	OPEN @C FETCH FROM @C INTO @tblName , 
		@columnName, 
		@IndName , 
		@indid,
		@Status, 
		@DBname 
	WHILE (@@FETCH_STATUS = 0)
	BEGIN
		SELECT @count= COUNT(*) FROM #CompInd WHERE ctblName = @tblName AND cIndName = @IndName
		IF(@count = 0)
			INSERT INTO #CompInd VALUES (@tblName,@columnName ,@IndName , @indid , @Status , @DBname)
		ELSE
			UPDATE #CompInd SET ccolumnName = ccolumnName +' ,'+ @columnName WHERE ctblName = @tblName AND cIndName = @IndName

		FETCH FROM @C INTO @tblName , 
		@columnName, 
		@IndName , 
		@indid,
		@Status, 
		@DBname 
		
	END

	SET @C = CURSOR FAST_FORWARD FOR  
				SELECT * FROM #CurrDBTR  
	OPEN @C FETCH FROM @C INTO @tblName , 
			@TRNAME ,@Status, 
			@DBname
	 
	WHILE (@@FETCH_STATUS = 0) 
	BEGIN 
		DELETE #TempCompDBTR WHERE ctblname = @tblName AND cTRNAME = @TRNAME  
		FETCH FROM @C INTO @tblName , 
			@TRNAME,@Status , 
			@DBname
	END	 
	SET @C = CURSOR FAST_FORWARD FOR  
				SELECT * FROM #CompDBTR  
	OPEN @C FETCH FROM @C INTO @tblName , 
			@TRNAME, @Status,
			@DBname
			
	WHILE (@@FETCH_STATUS = 0) 
	BEGIN 
		DELETE #TempCurrDBTR WHERE tblname = @tblName AND TRNAME = @TRNAME  
		FETCH FROM @C INTO @tblName , 
			@TRNAME, @Status,
			@DBname
	END	 
	INSERT INTO #RESULT (tblName , TRName ,DBname,Status, TYPE)
			SELECT Tblname ,TRName ,DBNAME,Status ,'4MISTR' FROM #TempCurrDBTR
	INSERT INTO #RESULT (tblName , TRName ,DBname  ,Status, TYPE)
			SELECT cTblname ,cTRName ,cDBNAME,cStatus ,'4MISTR' FROM #TempCompDBTR
	
	SELECT * INTO #Tempcurind FROM #CurInd 
	SELECT * INTO #Tempcompind FROM #CompInd 
	SET @C = CURSOR FAST_FORWARD FOR  
				SELECT Tblname , ColumnName FROM #CurInd  
	OPEN @C FETCH FROM @C INTO @tblName , 
				@columnName 
	WHILE (@@FETCH_STATUS = 0) 
	BEGIN 
		DELETE #Tempcompind WHERE ctblname = @tblName AND ccolumnName  = @columnName  
		FETCH FROM @C INTO @tblName ,@columnName 
	END 
	 
	SET @C = CURSOR FAST_FORWARD FOR  
				SELECT cTblname , cColumnName FROM #CompInd  
	OPEN @C FETCH FROM @C INTO @tblName , 
				@columnName 
	WHILE (@@FETCH_STATUS = 0) 
	BEGIN 
		DELETE #Tempcurind WHERE tblname = @tblName AND columnName  = @columnName  
		FETCH FROM @C INTO @tblName ,@columnName 
	END 
	CLOSE @c 
	DEALLOCATE @c

	INSERT INTO #RESULT (tblName , IndName , ColumnName , Indid, DBname , TYPE)
			SELECT Tblname ,IndName ,columnName,Indid, DBNAME ,'6MISIND' FROM #Tempcurind

	INSERT INTO #RESULT (tblName , IndName , ColumnName , Indid, DBname , TYPE)
			SELECT cTblname ,cIndName ,ccolumnName,cIndid, cDBNAME ,'6MISIND' FROM #Tempcompind

	SELECT * INTO #DIFCol FROM #CompDBtblcol a INNER JOIN #CurrDBtblcol b 
	ON a.cColumnName = b.ColumnName AND a.cTblname = b.Tblname
	WHERE a.cTYPE <> b.TYPE OR a.cLENGTH <> b.LENGTH 

	INSERT INTO #RESULT (tblName , columnName , ColType , LENGTH ,DBname ,ctblName , ccolumnName ,cColType , cLENGTH ,cDBname, TYPE)
			SELECT [Tblname] ,ColumnName , TYPE , LENGTH ,DBNAME,cTblname ,cColumnName , cTYPE , cLENGTH ,cDBNAME ,'3DIFCOL' FROM #DIFCol

	SELECT * INTO #DIFTR FROM #CurrDBTR a INNER JOIN #CompDBTR b 
	ON a.TRName = b.cTRName AND a.Tblname = b.cTblname
	WHERE a.Status <> b.cStatus

	INSERT INTO #RESULT (tblName , TRName , Status , DBname ,ctblName , cTRName ,cStatus ,cDBname, TYPE)
			SELECT tblName , TRName , Status , DBname ,ctblName , cTRName ,cStatus ,cDBname, '5DIFTR' FROM #DIFTR

	SELECT * INTO #DIFIND FROM #CurInd a INNER JOIN #CompInd b 
	ON a.Tblname = b.cTblname AND  a.columnName = b.ccolumnName
	WHERE  a.uniqe <> b.cuniqe
	INSERT INTO #RESULT (tblName , ColumnName , IndName , indid ,Status,DBNAME ,ctblName , cColumnName , cIndName , cindid ,cStatus,cDBNAME , TYPE)
			SELECT tblName , ColumnName , IndName , indid ,uniqe,DBNAME , ctblName ,cColumnName ,cIndName,cindid,cuniqe,cDBNAME, '7DIFIND' FROM #DIFIND
	SELECT * FROM #RESULT 
	order by Type ,dbname
-- [repDATABASECOMP] 'AmnDb029', 'AmnDb028', '' 
###########################################################################END