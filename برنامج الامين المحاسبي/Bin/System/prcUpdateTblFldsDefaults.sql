#######################################################################
CREATE PROC prcUpdateTblFldsDefaults
	@TblName [NVARCHAR](128),
	@Correct [INT] = 0,
	@UsName	[NVARCHAR](128) = 'dbo'
AS 
	/*
		this store proc add the default value to colums of table @TblName
	*/

	DECLARE @TblId [INT]
	SELECT @TblId = [id] from [sysObjects] WHERE [name] = @TblName
	
	DECLARE @Tbl1 TABLE ( [FldName] [NVARCHAR](255), [xType] [INT])
	DECLARE @Tbl2 TABLE ( [FldName] [NVARCHAR](255), [xType] [INT])
	DECLARE @Tbl3 TABLE ( [FldName] [NVARCHAR](255), [xType] [INT], [IsPKey] [INT])


	INSERT INTO @Tbl1 
		select [col].[Name], [col].[xType] from 
			[syscolumns] AS [col] INNER JOIN [sysObjects] AS [obj]
			ON [col].[colid] = [obj].[info] AND [obj].[xtype] = 'D' AND [col].[id] = [obj].[parent_obj]
		where 
			[col].[id] = @TblId
	
	INSERT INTO @Tbl2 
		select [Name], [xType]
		from [syscolumns]
		where [id] = @TblId and [autoVal] is null -- this will excludes identity fields
	
	INSERT INTO @Tbl3 
		SELECT [Tbl2].[FldName], [Tbl2].[xType], 0
		FROM 
			@Tbl1 AS [Tbl1] RIGHT JOIN @Tbl2 AS [Tbl2]
			ON [Tbl1].[FldName] = [Tbl2].[FldName]
		WHERE 
			[Tbl1].[FldName] IS NULL
	
	CREATE TABLE [#PKey] ( [TABLE_QUALIFIER] [NVARCHAR](255), [TABLE_OWNER] [NVARCHAR](255), [TABLE_NAME] [NVARCHAR](255), [COLUMN_NAME] [NVARCHAR](255), [KEY_SEQ] [INT], [PK_NAME] [NVARCHAR](255))
	INSERT INTO [#PKey] exec [sp_pkeys] @TblName
	
	UPDATE [Tbl3] SET [IsPKey] = 1 
	FROM 
		@Tbl3 AS [Tbl3] INNER JOIN [#PKey] AS [PKey]
		ON [PKey].[COLUMN_NAME] = [Tbl3].[FldName]

	--------------------------------------------------------------------------------------
	-- Begin add constrain
	--------------------------------------------------------------------------------------
	DECLARE @c_Col CURSOR, 		
		@ColName [NVARCHAR](1000),
		@Type [INT],
		@IsPKey [INT]


	SET @c_Col = CURSOR FAST_FORWARD FOR 
		SELECT  [FldName], [xType], [IsPKey] FROM @Tbl3
	
	DECLARE @Update AS [INT], @SqlStr AS [NVARCHAR](max) --, @G AS UNIQUEIDENTIFIER

	OPEN @c_Col FETCH NEXT FROM @c_Col INTO @ColName, @Type, @IsPKey
	WHILE @@FETCH_STATUS = 0 
	BEGIN
		SET @Update = 0
		SET @SqlStr = 'ALTER TABLE [' + @UsName + '].['+ @TblName +'] ADD CONSTRAINT [DF__'+ @TblName +'__'+ @ColName  +'] '

		--   Float            INT              BIGINT            BIT
		IF(( @Type = 62) OR ( @Type = 56) OR ( @Type = 127) OR ( @Type = 104))
		BEGIN
			SET @SqlStr = @SqlStr + 'DEFAULT (0) FOR ['+ @ColName + ']'
			SET @Update = 1
		END

		-- STRING
		IF ( @Type = 231) OR ( @Type = 167)
		BEGIN
			SET @SqlStr = @SqlStr + 'DEFAULT ('+ '''''' +') FOR ['+ @ColName + ']'
			SET @Update = 1
		END

		-- DATE
		IF ( @Type = 61)
		BEGIN
			SET @SqlStr = @SqlStr + 'DEFAULT ('+'''1/1/1980'''+') FOR ['+ @ColName + ']'
			SET @Update = 1
		END

		-- UNIQUEIDENTIFIER
		IF @Type = 36
		BEGIN
			IF @IsPKey = 1
				SET @SqlStr = @SqlStr + 'DEFAULT (newid()) FOR ['+ @ColName + ']'
			ELSE
				SET @SqlStr = @SqlStr + 'DEFAULT (0x0) FOR ['+ @ColName + ']'

			SET @Update = 1
		END
		--PRINT @SqlStr
		--PRINT @Type
		IF @Update = 1
		BEGIN
			IF @Correct <> 1
				INSERT INTO [ErrorLog]([Type], [c1],[c2])
					SELECT 0xAA1, @TblName, @ColName

			IF @Correct <> 0
				EXEC ( @SqlStr)
		END
		FETCH NEXT FROM @c_Col INTO @ColName, @Type, @IsPKey
	END
	CLOSE @c_Col
	DEALLOCATE @c_Col
#######################################################################
#END