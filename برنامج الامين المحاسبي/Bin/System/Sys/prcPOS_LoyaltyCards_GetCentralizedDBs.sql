################################################################################
CREATE PROCEDURE prcPOS_LoyaltyCards_GetCentralizedDBs
AS
	SET NOCOUNT ON

	DECLARE 
		@c Cursor,
		@DBName NVARCHAR(100),
		@dbID [INT],
		@Sql NVARCHAR(MAX),
		@params NVARCHAR(1000)

	CREATE TABLE #Files (
		[dbID]			[INT],
		[DBName]		[NVARCHAR](100),
		[FileName]		[NVARCHAR](200),
		[FileLatinName]	[NVARCHAR](200),
		[Password]		[NVARCHAR](100) 	 
	)

	CREATE TABLE #DBS([id] INT, [DBName] NVARCHAR(100))
	CREATE TABLE #idS(ID INT)

	--Select databases which state is online 
	INSERT INTO #DBS 
	SELECT 
		database_id, [Name] 
	FROM sys.databases 
	WHERE 
		database_id > 4 
		AND 
		name <> 'AmnConfig' 
		AND 
		state = 0 
		AND 
		name <> DB_NAME()

	SET @c = CURSOR FAST_FORWARD FOR SELECT [id], [DBName] FROM #DBS -- WHERE DBName NOT LIKE '%-%'
	OPEN @c FETCH FROM @c INTO @dbID, @DBName
	WHILE @@FETCH_STATUS = 0 
	BEGIN
		DECLARE @QuotedDBName [NVARCHAR](100) = QUOTENAME(@DBName)
		DECLARE @FullQualifiedName NVARCHAR(300) = @QuotedDBName + '.SYS.EXTENDED_PROPERTIES'
		DECLARE @FileName NVARCHAR(200) = '' , @FileLatinName NVARCHAR(200) = '',  @DBVer NVARCHAR(100) = ''
		SET @Sql = 'SELECT  @FileName = CAST(VALUE  AS NVARCHAR(200)) FROM  ' + @FullQualifiedName + 
		' WHERE [Name] = ''AmnDBName'''

		SET @Sql += 'SELECT  @FileLatinName = CAST(VALUE  AS NVARCHAR(200)) FROM ' + @FullQualifiedName  + 
		' WHERE [Name] = ''AmnDBLatinName'''

		SET @Sql += 'SELECT  @DBVer = CAST(VALUE  AS NVARCHAR(100)) FROM ' + @FullQualifiedName + 
		' WHERE [Name] = ''AmnDBVersion'''

		SET @params = '@FileName NVARCHAR(200) OUTPUT, @FileLatinName NVARCHAR(200) OUTPUT, @DBVer NVARCHAR(100) OUTPUT'
		
		EXEC sp_executesql @Sql, @params, @FileLatinName =  @FileLatinName OUTPUT, @FileName =  @FileName OUTPUT,  @DBVer =  @DBVer OUTPUT

		IF ((@FileName <> '' OR @FileLatinName <> '') AND SUBSTRING(@DBVer, 6, 1) = '9')
		BEGIN
			SET @Sql = ' SELECT object_id FROM '+ @QuotedDBName + '.Sys.objects WHERE object_id = OBJECT_ID('''+ 
			@QuotedDBName + '.dbo.op000'')'			
			INSERT INTO #idS EXEC(@Sql)
			IF @@ROWCOUNT > 0
			BEGIN
				DECLARE @LoyaltyCards_IsCentralizedDB BIT = 0
				DECLARE @Password NVARCHAR(100) = ''
				SET @Sql = 'SELECT @LoyaltyCards_IsCentralizedDB =  CAST(value  AS NVARCHAR(100)) FROM ' +  
				@QuotedDBName + '.dbo.op000 WHERE [Name] = ''AmnCfg_LoyaltyCards_IsCentralizedDB'''

				SET @Sql += 'SELECT  @Password = CAST(value  AS NVARCHAR(100)) FROM ' + 
				@QuotedDBName + '.dbo.op000 WHERE [Name] = ''AmnCfg_LoyaltyCards_Password'''
				SET @params = '@LoyaltyCards_IsCentralizedDB BIT OUTPUT, @Password NVARCHAR(100) OUTPUT'
				EXEC sp_executesql @Sql , @params , @LoyaltyCards_IsCentralizedDB =  @LoyaltyCards_IsCentralizedDB OUTPUT 
				, @Password = @Password OUTPUT

				IF @LoyaltyCards_IsCentralizedDB = 1
				BEGIN
					INSERT INTO #Files VALUES (@dbID, @DBName, @FileName, @FileLatinName, @Password)
				END 
			END
		END 
	FETCH FROM @c INTO @dbID, @DBName
	END
	CLOSE @c
	DEALLOCATE @c

	SELECT [dbID], [DBName], [FileName], [FileLatinName], [Password] FROM #Files
################################################################################
#END	