#########################################################################
CREATE PROCEDURE prcDBCGetBillsTypesList
	--@StartDate		DATETIME,
	--@EndDate		DATETIME,
	@CollectionGUID [UNIQUEIDENTIFIER] = 0x0
AS
	SET NOCOUNT ON
	SELECT TOP 0 * INTO [#TmpResult] FROM [bt000]
	SELECT TOP 0 * INTO [#MainResult] FROM [bt000]
	ALTER TABLE [#MainResult] ADD [DbFlag] [NVARCHAR](256) COLLATE ARABIC_CI_AI
	ALTER TABLE [#MainResult] ADD [DbID] [INT]
	/*
	CREATE TABLE #TmpResult
	(
		btGUID				UNIQUEIDENTIFIER,
		btType				INT,
		btSortNum			INT,
		btBillType			INT,
		btName				NVARCHAR(256) COLLATE ARABIC_CI_AI,
		btLatinName			NVARCHAR(256) COLLATE ARABIC_CI_AI,
		btAbbrev			NVARCHAR(256) COLLATE ARABIC_CI_AI,
		btLatinAbbrev		NVARCHAR(256) COLLATE ARABIC_CI_AI,
		DbFlag				NVARCHAR(256) COLLATE ARABIC_CI_AI
	)
	CREATE TABLE #MainResult
	(
		btGUID				UNIQUEIDENTIFIER,
		btType				INT,
		btSortNum			INT,
		btBillType			INT,
		btName				NVARCHAR(256) COLLATE ARABIC_CI_AI,
		btLatinName			NVARCHAR(256) COLLATE ARABIC_CI_AI,
		btAbbrev			NVARCHAR(256) COLLATE ARABIC_CI_AI,
		btLatinAbbrev		NVARCHAR(256) COLLATE ARABIC_CI_AI,		
		DbFlag				NVARCHAR(256) COLLATE ARABIC_CI_AI
	)
	*/
	-- ≈‰‘«¡ „‰ onnection  «·Õ«·Ì…
	-- ›—Ì€ »⁄œ ﬂ· „·›
	CREATE TABLE [#SecViol]( [Type] [INT], [Cnt] [INTEGER])
	---’·«ÕÌ«  „’«œ—  ﬁ—Ì— „⁄Ì‰…

	CREATE TABLE [#DataBases]
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
	EXEC [prcDbcPrepMultiFilesProcs] 	NULL/*@StartDate*/, NULL/*@EndDate*/, @CollectionGUID

------------- start

	DECLARE @AmnName 		[NVARCHAR](256)
	DECLARE @dataName 		[NVARCHAR](256)
	DECLARE @FPDate 		[DATETIME]
	DECLARE @DbId 			[INT]
	DECLARE @ExcludeFPBills	[BIT]
	DECLARE @userName [NVARCHAR](256)
	SELECT @userName = [dbo].[fnGetCurrentUserName]()

	--IF @SrcTypesguid <> NULL 
	--CREATE TABLE #BillsTypesTbl( TypeGuid UNIQUEIDENTIFIER, UserSecurity INTEGER, UserReadPriceSecurity INTEGER)
print '2'	
	DECLARE c CURSOR FOR SELECT [AmnName], [DBName], [FPDate], [dbid], [ExcludeFPBills] FROM [#DataBases] ORDER BY [Order]
	OPEN c
	
	FETCH NEXT FROM c INTO @AmnName, @dataName, @FPDate, @DbId, @ExcludeFPBills
	DECLARE @s NVARCHAR(2000)
	WHILE @@FETCH_STATUS = 0
	BEGIN
		SET @s = 'EXEC ['+ @dataName + ']..[prcConnections_add2] '''+ CAST( @userName AS [NVARCHAR](128)) + ''''
		print @s
		EXECUTE( @s)
		BEGIN TRAN
		-- Clearing temporary tables
			DECLARE @str [NVARCHAR](2000)
			--SET @Str = ' DELETE FROM #BillsTypesTbl'

		-- Filling temporary tables
			--SET @str = @str + ' INSERT INTO #BillsTypesTbl EXEC ' + @AmnName + '.. prcGetBillsTypesList ''' + CONVERT( NVARCHAR(2000), @SrcTypesguid) + ''''
			print @str
			EXECUTE( @str)
		/*
		-- Fill Ex tbl with deleted entries 
			SET @s = ' INSERT INTO ' + @AmnName + '..Ex SELECT EntryGUID FROM dbcdd WHERE ParentGuid = (SELECT Guid FROM dbcd WHERE dbid = ' + CAST( @DbId AS NVARCHAR) +')'
		-- Fill ex tbl with deleted FPBills
			IF @ExcludeFPBills = 1
				SET @s = @s + ' INSERT INTO ' + @AmnName + '..Ex SELECT Guid FROM ' + @AmnName +'..bu000 WHERE TypeGuid = (SELECT GUID FROM ' + @AmnName + '..bt000 WHERE Type = 2 AND SortNum = 1)'
			EXECUTE( @s)
		*/
--- select * from amndb314..vwbt
print 'before tmpresult'
			SET @s = ' INSERT INTO [#TmpResult]
		/*( 
				[btGUID],
				[btType],
				[btSortNum],
				[btBillType],
				[btName],
				[btLatinName],
				[btAbbrev],
				[btLatinAbbrev]
		)*/ 
		SELECT 
				*
				/*
				[btGUID],
				[btType],
				[btSortNum],
				[btBillType],
				[btName],
				[btLatinName],
				[btAbbrev],
				[btLatinAbbrev]
				*/
 			FROM '
			SET @s = @s + @dataName
			SET @s = @s + '..[bt000]'
			print @s
			EXECUTE( @s)

-- select * from #TmpResult
		ALTER TABLE [#TmpResult] ADD [DbFlag]	[NVARCHAR](256) COLLATE ARABIC_CI_AI
		ALTER TABLE [#TmpResult] ADD [DbId]		[INT]
			SET @s = ' UPDATE [#TmpResult] SET [DbFlag] = ''' + @AmnName + ''''
			SET @s = @s + ' UPDATE [#TmpResult] SET [DbId] = ''' + CAST (@DbId AS NVARCHAR) + ''''
			SET @s = @s + ' INSERT INTO [#MainResult] SELECT * FROM [#TmpResult]'
			SET @s = @s +  ' DELETE FROM #TmpResult'
			print @s
			EXECUTE( @s)
		-- Clear Ex tbl
			--SET @s = ' DELETE FROM ' + @AmnName + '..Ex'
			--EXECUTE(@s)
		ALTER TABLE [#TmpResult] DROP COLUMN [DbFlag]
		ALTER TABLE [#TmpResult] DROP COLUMN [DbId]

		COMMIT TRAN
		IF @@FETCH_STATUS <> 0
			BREAK
		FETCH NEXT FROM c INTO @AmnName, @dataName, @FPDate, @DbId, @ExcludeFPBills
	END
	CLOSE c
	DEALLOCATE c

--------------END

	SELECT * FROM [#MainResult]
	SELECT * FROM [#SecViol]

/*
use amndb270
drop table #SecViol

prcDBCGetBillsTypesList '1/1/2001', '1/1/2005', 'F4081683-52A3-41CC-9646-B99DB9C79709'

prcDBCGetBillsTypesList '1/1/2001', '12/31/2001', null --'00000000-0000-0000-0000-000000000000'

SELECT * FROM vwbt000
SELECT * FROM amndb313..vwbt

EXEC prcDBCGetBillsTypesList '1/1/2001', '12/31/2001', '00000000-0000-0000-0000-000000000000'

EXEC prcDBCGetBillsTypesList 'F4081683-52A3-41CC-9646-B99DB9C79709'

EXEC prcDBCGetBillsTypesList 0x0

SELECT * FROM dbc
SELECT * FROM dbcd

SELECT * FROM bt000
SELECT * FROM vwbt
*/
########################################################################
#END  