#########################################################
CREATE PROCEDURE prcDBCPrepMultiFilesProcs
	@StartDate 			[DATETIME],
	@EndDate 			[DATETIME],
	@CollectionGUID		[UNIQUEIDENTIFIER] = 0x0 -- files groups
AS
-----------------------------------------------------------------------------------------------------------------------
--- this procedure fill #DataBases:
---	1- with Current db only if @CollectionGUID is 0x0 
---	2- else it fill it with correct databases
-----------------------------------------------------------------------------------------------------------------------
--- One File: the Current Db
	EXECUTE prcNotSupportedInAzure
	/*
	IF @CollectionGUID = 0x0
	BEGIN
		print 'one file'
		DECLARE @CurDB AS [NVARCHAR](256)
		DECLARE @AmnDB AS [NVARCHAR](256)
		DECLARE @FPDate AS [DATETIME]
		DECLARE @DbId	AS [INTEGER]
		SELECT @CurDB = DB_NAME()
			
		DECLARE @str [NVARCHAR](2000)
		SET @AmnDB = (SELECT TOP 1 CAST([VALUE] AS [NVARCHAR](50)) FROM dbo.fnListExtProp( 'AmnDBName'))
		-- [sysProperties] WHERE [name] = 'AmnDBName')
		SELECT @FPDate = [Value] FROM [op000] WHERE [Name] = 'AmnCfg_FPDate'
		SELECT @DbId = [d].[database_id] FROM [sys].[databases] AS [d] WHERE [d].[Name] = @CurDB
		INSERT INTO [#DataBases]( [AmnName], [DbName], [FPDate], [dbid], [ExcludeFPBills]) VALUES( @AmnDB, @CurDB, @FPDate, @DbId, 0)
		RETURN
	END
	print 'Multi Files'
--ELSE Multi Files
	-- Prep. Databases Temp Tables
	-- 1- #AllDataBases: Tbl of all Ameen Databases
	-- 2- #DataBases:	Tbl of Desired and accepted databases 
	CREATE TABLE [#AllDataBases]
	(
		[GUID]					[UNIQUEIDENTIFIER],
		[dbid]					[INT],
		[dbName]				[NVARCHAR](256) COLLATE ARABIC_CI_AI,
		[amnName]				[NVARCHAR](256) COLLATE ARABIC_CI_AI,
		[FPDate]				[DATETIME],
		[EPDate]				[DATETIME],
		[ExcludeEntries]		[INT],
		[ExcludeFPBills]		[BIT],
		[InCollection]			[BIT],
		[VersionNeedsUpdating]	[BIT],
		[UserIsNotDefined]		[BIT],
		[PasswordError]			[BIT],
		[Order]					[INT]
	)
	-- Accepted Databases
	--All Ameen DataBases
	-- EXEC prcDatabase_Collection 	0x0, 1
	INSERT INTO [#AllDataBases] EXEC [prcDatabase_Collection] 	@CollectionGUID, 1	/*@InCollectionOnly BIT = 0*/
--- Fill #DataBases with accepted databases by date,
--- and check if Version is correct, if user is defined in this db, and if its Password ok.
	DECLARE @AmnName1 				[NVARCHAR](256)
	DECLARE @dbName1 				[NVARCHAR](256)
	DECLARE @FPDate1 				[DATETIME]
	DECLARE @dbId1					[INT]
	DECLARE @ExcludeFPBills1		[BIT]
	DECLARE @EPDate1 				[DATETIME]
	DECLARE @VersionNeedsUpdating	[BIT]
	DECLARE @UserIsNotDefined		[BIT]
	DECLARE @PasswordError			[BIT]
	DECLARE @c1 CURSOR
	SET @c1 = CURSOR FAST_FORWARD FOR SELECT [AmnName], [dbName], [FPDate], [dbId], [ExcludeFPBills], [EPDate], [VersionNeedsUpdating], [UserIsNotDefined], [PasswordError] FROM [#AllDataBases] ORDER BY [Order] --DBName
	OPEN @c1
	FETCH NEXT FROM @c1 INTO @AmnName1, @dbName1, @FPDate1, @dbId1, @ExcludeFPBills1, @EPDate1, @VersionNeedsUpdating, @UserIsNotDefined, @PasswordError 
	WHILE @@FETCH_STATUS = 0
	BEGIN
		--IF ( @StartDate <> NULL AND @EndDate <> NULL )
			IF (@FPDate1 BETWEEN @StartDate AND @EndDate) OR ( @EPDate1 BETWEEN @StartDate AND @EndDate) OR (@StartDate IS NULL) OR ( @EndDate IS NULL )
				IF(( @VersionNeedsUpdating = 0) AND ( @UserIsNotDefined = 0) AND( @PasswordError = 0))
					INSERT INTO [#DataBases]( [AmnName], [dbName], [FPDate], [dbid], [ExcludeFPBills]) VALUES( @AmnName1, @dbName1, @FPDate1, @dbId1, @ExcludeFPBills1)
				ELSE
				BEGIN
					IF( @VersionNeedsUpdating = 1)
						INSERT INTO [#SecViol]( [Type], [Cnt]) VALUES( 100, 1)
					IF( @UserIsNotDefined = 1)
						INSERT INTO [#SecViol]( [Type], [Cnt]) VALUES( 101, 1)
					IF( @PasswordError = 1)
						INSERT INTO [#SecViol]( [Type], [Cnt]) VALUES( 102, 1)
				END
			FETCH NEXT FROM @c1 INTO @AmnName1, @dbName1, @FPDate1, @dbId1, @ExcludeFPBills1, @EPDate1, @VersionNeedsUpdating, @UserIsNotDefined, @PasswordError 
	END
	CLOSE @c1 DEALLOCATE @c1
	*/
#########################################################
#END 