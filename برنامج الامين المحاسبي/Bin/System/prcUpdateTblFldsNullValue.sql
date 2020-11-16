######################################################################################
CREATE PROC prcUpdateTblFldsNullValue
		@TblName AS [NVARCHAR](255),
		@Correct [INT] = 0,
		@UsName [NVARCHAR](255) = 'dbo'
AS
	/*
		this store proc update fields null value of table @TblName
	*/
	DECLARE @TblId [INT]
	SELECT @TblId = [id] from [sysObjects] WHERE [name] = @TblName
	
	DECLARE @Tbl TABLE ( [FldName] [NVARCHAR](255), [xType] [INT], [IsPKey] [INT])


	INSERT INTO @Tbl
		SELECT 
			[col].[Name], [col].[xType], 0 
		FROM 
			[syscolumns] AS [col] 
		WHERE 
			[col].[ID] = @TblId and [col].[autoVal] is null -- this will excludes identity fields 
	
	
	CREATE TABLE [#PKey] ( [TABLE_QUALIFIER] [NVARCHAR](255), [TABLE_OWNER] [NVARCHAR](255), [TABLE_NAME] [NVARCHAR](255), [COLUMN_NAME] [NVARCHAR](255), [KEY_SEQ] [INT], [PK_NAME] [NVARCHAR](255))
	INSERT INTO [#PKey] exec [SP_PKEYS] @TblName
	
	UPDATE [Tbl] SET [IsPKey] = 1 
	FROM 
		@Tbl AS [Tbl] INNER JOIN [#PKey] AS [PKey]
		ON [PKey].[COLUMN_NAME] = [Tbl].[FldName]

	--------------------------------------------------------------------------------------
	-- Begin add constrain
	--------------------------------------------------------------------------------------
	DECLARE @c_Col CURSOR, 		
		@ColName [NVARCHAR](1000),
		@Type [INT],
		@IsPKey [INT]
	SET @c_Col = CURSOR FAST_FORWARD FOR
		SELECT  [FldName], [xType], [IsPKey] FROM @Tbl
	
	DECLARE @SqlStr AS [NVARCHAR](max), @SqlStr2 AS [NVARCHAR](max) --, @G AS UNIQUEIDENTIFIER

	OPEN @c_Col FETCH NEXT FROM @c_Col INTO @ColName, @Type, @IsPKey
	WHILE @@FETCH_STATUS = 0 
	BEGIN
		SET @SqlStr2 = 'SELECT [' + @ColName + '] FROM [dbo].['+ @TblName +'] WHERE [' + @ColName + '] IS NULL'
		SET @SqlStr = 'UPDATE [' + @UsName + '].['+ @TblName +'] SET [' + @ColName + '] = '
		IF( ( @Type = 62) OR ( @Type = 56) OR ( @Type = 127) OR ( @Type = 104) OR ( @Type = 36) OR ( @Type = 231) OR ( @Type = 167) OR ( @Type = 61) )
		BEGIN
			--   Float            INT              BIGINT            BIT
			IF(( @Type = 62) OR ( @Type = 56) OR ( @Type = 127) OR ( @Type = 104))
			BEGIN
				SET @SqlStr = @SqlStr + '0'
			END
			-- STRING
			IF ( @Type = 231) OR ( @Type = 167)
			BEGIN
				SET @SqlStr = @SqlStr + ''''''
			END
			-- DATE
			IF ( @Type = 61)
			BEGIN
				SET @SqlStr = @SqlStr + '''1/1/1980'''
			END
			-- UNIQUEIDENTIFIER
			IF @Type = 36
			BEGIN
				IF @IsPKey = 1
					SET @SqlStr = @SqlStr + 'newid()'
				ELSE
					SET @SqlStr = @SqlStr + '0x0'
			END
			SET @SqlStr = @SqlStr + ' WHERE [' + @ColName + '] IS NULL'
			/*
			IF @Correct <> 1 
			BEGIN
				EXEC ( @SqlStr2)
				IF( @@ROWCOUNT <> 0) 
					INSERT INTO ErrorLog(Type, c1,c2)
						VALUES ( 0xA, @TblName, @ColName)
			END
			*/
			IF @Correct <> 0
			BEGIN
				DECLARE @alt NVARCHAR(max) 
				SET @alt = 'ALTER TABLE [' + @UsName + '].[' + @TblName + '] DISABLE TRIGGER ALL'
				EXEC ( @alt)
				EXEC ( @SqlStr)
				SET @alt = 'ALTER TABLE [' + @UsName + '].[' + @TblName + '] ENABLE TRIGGER ALL'
				EXEC ( @alt)
			END

		END
		FETCH NEXT FROM @c_Col INTO @ColName, @Type, @IsPKey
	END	
	CLOSE @c_Col
	DEALLOCATE @c_Col
######################################################################################
#END