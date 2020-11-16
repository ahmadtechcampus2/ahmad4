########################################
CREATE PROCEDURE prcDBCFinalizeMultiFiles
	@ProcedureName	[NVARCHAR](256),
	@ParamStr		[NVARCHAR](2000),

	@SrcTypesguid	[UNIQUEIDENTIFIER] = NULL,
	@MatGuid		[UNIQUEIDENTIFIER] = NULL,
	@GroupGuid		[UNIQUEIDENTIFIER] = NULL,
	@MatType		[INT] = NULL,
	@StoreGuid		[UNIQUEIDENTIFIER] = NULL,
	@CostGuid		[UNIQUEIDENTIFIER] = NULL,
	@CustGuid		[UNIQUEIDENTIFIER] = NULL,
	@AccGuid		[UNIQUEIDENTIFIER] = NULL
AS 
	
	-- ≈‰‘«¡ „‰ onnection  «·Õ«·Ì…
	-- ›—Ì€ »⁄œ ﬂ· „·›
	CREATE TABLE [#SecViol]( [Type] [INT], [Cnt] [INTEGER])
	DECLARE @AmnName 		[NVARCHAR](256)
	DECLARE @FPDate 		[DATETIME]
	DECLARE @DbId 			[INT]
	DECLARE @ExcludeFPBills	[BIT]
	DECLARE @userName [NVARCHAR](256)
	SELECT @userName = [dbo].[fnGetCurrentUserName]()

	--IF @SrcTypesguid <> NULL 
	CREATE TABLE [#BillsTypesTbl]( [TypeGuid] [UNIQUEIDENTIFIER], [UserSecurity] [INTEGER], [UserReadPriceSecurity] [INTEGER])
	--IF @MatGuid	<> NULL AND @GroupGuid <> NULL AND @MatType	<> NULL
		CREATE TABLE [#MatTbl]( [MatGuid] [UNIQUEIDENTIFIER], [mtSecurity] [INT])
	--IF @StoreGuid <> NULL
		CREATE TABLE [#StoreTbl]( [StoreGuid] [UNIQUEIDENTIFIER], [Security] [INT])
	--IF @CostGuid <> NULL
		CREATE TABLE [#CostTbl]( [CostGuid] [UNIQUEIDENTIFIER], [Security] [INT])
	--IF @CustGuid <> NULL AND @AccGuid <> NULL
		CREATE TABLE [#CustTbl]( [CustGuid] [UNIQUEIDENTIFIER], [Security] [INT])

	DECLARE c CURSOR FOR SELECT [DBName], [FPDate], [dbid], [ExcludeFPBills] FROM [#DataBases] ORDER BY [Order]
	--DECLARE c CURSOR
	--SET c = CURSOR FAST_FORWARD FOR SELECT DBName, FPDate, dbid, ExcludeFPBills FROM #DataBases ORDER BY [Order]
	OPEN c
	
	FETCH NEXT FROM c INTO @AmnName, @FPDate, @DbId, @ExcludeFPBills
	DECLARE @s NVARCHAR(2000)
	WHILE @@FETCH_STATUS = 0
	BEGIN
		SET @s = 'EXEC ['+ @AmnName + ']..[prcConnections_Add2] '''+ CAST( @userName AS [NVARCHAR](128)) + ''''
		print @s
		EXECUTE( @s)
		BEGIN TRAN
		--Clearing temporary tables
			SET @s = ' DELETE FROM [' + @AmnName + ']..[RepSrcs] 
			INSERT INTO [' + @AmnName + ']..[RepSrcs] 
				SELECT 
						[GUID],
						[SPID],
						[IdTbl],
						[IdType],
						[IdSubType]
					 FROM [dbcRepSrcs] WHERE [dbId] = ' + CAST(@DbId AS NVARCHAR)
			print @s
			EXECUTE( @s)

			DECLARE @str [NVARCHAR](2000)
			-- IF @SrcTypesguid <> NULL
			SET @Str = ' DELETE FROM [#BillsTypesTbl]'

			--IF @MatGuid	<> NULL AND @GroupGuid <> NULL AND @MatType	<> NULL
				SET @Str = @Str + ' DELETE FROM [#MatTbl]'
			--IF @StoreGuid <> NULL
				SET @Str = @Str + ' DELETE FROM [#StoreTbl]'
			--IF @CostGuid <> NULL
				SET @Str = @Str + ' DELETE FROM [#CostTbl]'
			--IF @CustGuid <> NULL AND @AccGuid <> NULL
				SET @Str = @Str + ' DELETE FROM [#CustTbl]'

		-- Filling temporary tables
			-- IF @SrcTypesguid <> NULL
			SET @str = @str + ' INSERT INTO [#BillsTypesTbl] EXEC [' + @AmnName + '].. [prcGetBillsTypesList] ''' + CONVERT( [NVARCHAR](2000), @SrcTypesguid) + ''''
			--IF @MatGuid	<> NULL AND @GroupGuid <> NULL AND @MatType	<> NULL
				SET @str = @str + ' INSERT INTO [#MatTbl] EXEC [' + @AmnName + '].. [prcGetMatsList] ''' +CONVERT( [NVARCHAR](2000), @MatGuid) +''',''' + CONVERT( [NVARCHAR](2000), @GroupGuid) +''',' +CONVERT( [NVARCHAR](2000), @MatType)
			--IF @StoreGuid <> NULL
				SET @str = @str + ' INSERT INTO [#StoreTbl] EXEC ['+ @AmnName + '].. [prcGetStoresList] ''' + CONVERT( [NVARCHAR](2000), @StoreGuid) + ''''
			--IF @CostGuid <> NULL
				SET @str = @str + ' INSERT INTO #CostTbl EXEC [' + @AmnName + '].. prcGetCostsList '''  + CONVERT( NVARCHAR(2000), @CostGuid) + ''''
			--IF @CustGuid <> NULL AND @AccGuid <> NULL
				SET @str = @str + ' INSERT INTO #CustTbl EXEC [' + @AmnName + '].. prcGetCustsList ''' + CONVERT( NVARCHAR(2000), @CustGuid) +''',''' + CONVERT( NVARCHAR(2000), @AccGuid) + ''''
			

			print @str
			EXECUTE( @str)
--select *from  RepSrcs
--select * from #BillsTypesTbl
-- select *from #MatTbl

		-- Fill Ex tbl with deleted entries 
			SET @s = ' INSERT INTO [' + @AmnName + ']..[Ex] SELECT [EntryGUID] FROM [dbcdd] WHERE [ParentGuid] = (SELECT TOP 1 [Guid] FROM [dbcd] WHERE [dbid] = ' + CAST( @DbId AS NVARCHAR) +')'
		-- Fill ex tbl with deleted FPBills
			IF @ExcludeFPBills = 1
				SET @s = @s + ' INSERT INTO [' + @AmnName + ']..[Ex] SELECT [Guid] FROM [' + @AmnName +']..[bu000] WHERE [TypeGuid] = (SELECT TOP 1 [GUID] FROM [' + @AmnName + ']..[bt000] WHERE [Type] = 2 AND [SortNum] = 1)'
			print @s
			EXECUTE( @s)
			SET @s = ' INSERT INTO [#TmpResult] EXEC '
			SET @s = @s + @AmnName
			SET @s = @s + '..' + @ProcedureName
			SET @s = @s + @ParamStr

			print @s
			EXECUTE( @s)

--select * from #TmpResult

			SET @s = ' UPDATE [#TmpResult] SET [DbFlag] = ''' + CAST (@AmnName AS NVARCHAR) + ''''
			SET @s = @s + ' INSERT INTO [#MainResult] SELECT * FROM [#TmpResult]'
			SET @s = @s +  ' DELETE FROM [#TmpResult]'
			print @s
			EXECUTE( @s)
		-- Clear Ex tbl
			SET @s = ' DELETE FROM ' + @AmnName + '..[Ex]'
			print @s
			EXECUTE(@s)
			
			SET @s = ' DELETE FROM ' + @AmnName + '..[RepSrcs] '
			print @s
			EXECUTE(@s)

		COMMIT TRAN
		IF @@FETCH_STATUS <> 0
			BREAK
		FETCH NEXT FROM c INTO @AmnName, @FPDate, @DbId, @ExcludeFPBills
	END
	CLOSE c
	DEALLOCATE c

/*
EXEC prcDBCFinalizeMultiFiles
	@ProcedureName	 NVARCHAR(256),
	@ParamStr		 NVARCHAR(2000)
*/
#############################################
#END