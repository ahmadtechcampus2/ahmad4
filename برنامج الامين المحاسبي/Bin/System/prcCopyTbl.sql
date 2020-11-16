###########################################################################
CREATE PROCEDURE prcCopyTbl
	@DestDBName	[NVARCHAR](255),
	@SrcTable	[NVARCHAR](255),
	@Criteria	[NVARCHAR](max) = '',
	@CmpDb		[INT] = 0,
	@DelTable	[BIT] = 1,
	@UpdatePreTransferedData BIT = 0
 
AS
/* 
This procedure: 
	- copies the contents of a given table (@SrcTable) to another table (@DestTable). 
	- can be used to copy a table from a current database to another database, given full destination table name. 
	- truncates ditination table. 
	- this procedure does not create destination table, it  MUST exists before calling this procedure. 
*/ 
	SET NOCOUNT ON
	DECLARE 
		@c			CURSOR, 
		@DestTable	[NVARCHAR](256), 
		@s			[NVARCHAR](2000), 
		@SQL		[NVARCHAR](max), 
		@Flds		[NVARCHAR](max), 
		@Flds2		[NVARCHAR](max), 
		@f			[NVARCHAR](128),
		@IdentityON [NVARCHAR](MAX),
		@IdentityOFF [NVARCHAR](MAX)

	IF SUBSTRING(@DestDBName, 1, 1) != '['
		SET @DestDBName = '[' + @DestDBName + ']'

	SET @DestTable = @DestDBName + '..' + @SrcTable
	SET @SQL = ' ALTER TABLE ' + @DestTable + ' DISABLE TRIGGER ALL ' 
	SET @Flds = '' 
	SET @Flds2 = '' 
	DECLARE @Dsyscolumns [NVARCHAR](200)
	SELECT * INTO [#RES] FROM [syscolumns] WHERE [Xtype]=-2
	
	IF (@CmpDb = 1)
	BEGIN
		SET @Dsyscolumns='SELECT *  FROM ' +@DestDBName + '..[syscolumns] WHERE [id] = object_id(''' + @DestTable + ''')'
		INSERT INTO [#RES] EXEC (@Dsyscolumns)
	END
	
	
	DECLARE @SQL1 [NVARCHAR](2000)
	CREATE TABLE [#RESULT] ([fldNAME] [NVARCHAR](256))
	SET @SQL1 = 'INSERT INTO [#RESULT] SELECT [S].[COLUMN_NAME]  FROM [INFORMATION_SCHEMA].[COLUMNS] AS [S] INNER JOIN ' + @DestDBName +'.[INFORMATION_SCHEMA].[COLUMNS]  AS [D] 
			ON  ([S].[TABLE_NAME]  COLLATE ARABIC_CI_AI)= ([D].[TABLE_NAME]  COLLATE ARABIC_CI_AI) AND  ([S].[COLUMN_NAME]  COLLATE ARABIC_CI_AI)= ([D].[COLUMN_NAME]  COLLATE ARABIC_CI_AI)
			WHERE [S].[TABLE_NAME] = ''' + @SrcTable + ''' ORDER BY [S].[ORDINAL_POSITION]'
	EXEC (@SQL1)
	
	SET @C = CURSOR FAST_FORWARD FOR 
						SELECT * FROM [#RESULT]
	DECLARE @LS INT,@LD INT	 
	
	OPEN @c FETCH FROM @c INTO @f
	IF  @@FETCH_STATUS <> 0
		RETURN
	WHILE @@FETCH_STATUS = 0 
	BEGIN 
		IF (@CmpDb = 1)
		BEGIN
			SELECT @LS=CASE [xType] WHEN 167 THEN [Length] ELSE 0 END FROM [syscolumns] WHERE [id] = object_id(@SrcTable) AND [NAME] = @f

			SELECT @LD=CASE [xType] WHEN 167 THEN [Length] ELSE 0 END FROM [#RES] WHERE /*[id] = object_id(@DestTable) AND*/ [NAME] = @f
		END
		SET @Flds = @Flds + '[' + @f + ']'+ ',' 
		IF (@CmpDb = 1)
		BEGIN
			IF (@LD<@LS)
				SET @Flds2 = @Flds2 + 'LEFT([' + @f + '],'+CAST(@LD AS [NVARCHAR](20)) + '),' 
			ELSE
				SET @Flds2 = @Flds2 + '[' + @f + ']'+ ','
		END 
		ELSE 
			SET @Flds2 = @Flds 
		FETCH FROM @c INTO @f 
	END 
	CLOSE @c DEALLOCATE @c 

	SET @Flds = LEFT(@Flds, LEN(@FLds) - 1) 
	SET @Flds2 = LEFT(@Flds2, LEN(@FLds2) - 1)  

	IF (@DelTable > 0) 
	BEGIN
		SET @SQL = @SQL + ' DELETE ' + @DestTable
		EXEC (@Sql)
		SET @SQL = ' '
	END
	IF  (@UpdatePreTransferedData > 0)
	BEGIN
		SET @SQL = @SQL + ' DELETE ' + @DestTable + ' WHERE ' + @Criteria 
		EXEC (@Sql)
		SET @SQL = ' '
	END
	IF  EXISTS (SELECT
					a.name AS TableName,
					b.name AS IdentityColumn
				FROM
				 SYSOBJECTS a inner join SYSCOLUMNS b on a.id = b.id
				WHERE
					columnproperty(a.id, b.name, 'isIdentity') = 1
					 AND objectproperty(a.id, 'isTable') = 1
					 AND a.name= @SrcTable)
	BEGIN
			SET @IdentityON=' SET IDENTITY_INSERT '+ @DestTable +' ON '
			SET @IdentityOFF=' SET IDENTITY_INSERT '+ @DestTable +' OFF '
	END
	ELSE 
	BEGIN 
	 SET @IdentityON=''
	 SET @IdentityOFF=''
	END
	

	SET @SQL = @SQL +@IdentityON + ' INSERT INTO ' + @DestTable + '(' + @Flds + ')' 
	SET @SQL = @SQL + ' SELECT ' + @Flds2 + ' FROM ' + @SrcTable 
	IF ISNULL(@Criteria, '') <> '' 
		SET @SQL = @SQL + ' WHERE '+ @Criteria 
	SET @SQL = @SQL + ' ALTER TABLE ' + @DestTable + ' ENABLE TRIGGER ALL ' +@IdentityOFF
	
	EXECUTE (@SQL) 

###########################################################################
#END