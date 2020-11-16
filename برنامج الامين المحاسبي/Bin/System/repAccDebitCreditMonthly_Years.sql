#########################################################
CREATE PROCEDURE repAccDebitCreditMonthly_Years 
	@AccGUID				[UNIQUEIDENTIFIER],
    @StartDate				[DATETIME],
    @EndDate				[DATETIME],
    @CurrencyGUID			[UNIQUEIDENTIFIER],
    @CurrencyVal			[FLOAT],
    @SrcGuid				[UNIQUEIDENTIFIER] = 0X0,
    @CollectionGUID			[UNIQUEIDENTIFIER] = 0x0,-- files groups
    @Sort					[INT] = 0,
    @Str2					[NVARCHAR](max),
    @Lang					[INT] = 0,
    @PostedVal				[INT] = -1,-- 1 posted or 0 unposted -1 all posted & unposted 
    @CostGUID				[UNIQUEIDENTIFIER] = 0x0,
    @Level					[INT] = 0,
    @ShowEmptyAcc			[BIT] = 0,
    @ShowBaseAcc			[BIT] = 0,
    @ShowComposeAcc			[BIT] = 0,
	@CustomerGUID			[UNIQUEIDENTIFIER] = 0X0,
	@DetailOnlyAccCustomers	BIT = 0,
	@DetailByCustomer		BIT = 0
AS
	SET NOCOUNT ON

    DECLARE @OneFile [INT]

	SET @OneFile = 0

    CREATE TABLE [#SecViol] (
         [Type] [INT],
         [Cnt]  [INTEGER])

	CREATE TABLE [#AllDataBases]
	(
         [GUID]                 [UNIQUEIDENTIFIER],
         [dbid]                 [INT],
         [dbName]               [NVARCHAR](256) COLLATE ARABIC_CI_AI,
         [amnName]              [NVARCHAR](256) COLLATE ARABIC_CI_AI,
         [FPDate]               [DATETIME],
         [EPDate]               [DATETIME],
         [ExcludeEntries]       [INT],
         [ExcludeFPBills]       [BIT],
         [InCollection]         [BIT],
         [VersionNeedsUpdating] [BIT],
         [UserIsNotDefined]     [BIT],
         [PasswordError]        [BIT],
         [Order]                [INT]
	)

	CREATE TABLE [#DataBases]
	(
         [GUID]                 [UNIQUEIDENTIFIER],
         [dbid]                 [INT],
         [dbName]               [NVARCHAR](256) COLLATE ARABIC_CI_AI,
         [amnName]              [NVARCHAR](256) COLLATE ARABIC_CI_AI,
         [FPDate]               [DATETIME],
         [EPDate]               [DATETIME],
         [ExcludeEntries]       [BIT],
         [ExcludeFPBills]       [BIT],
         [InCollection]         [BIT],
         [VersionNeedsUpdating] [BIT],
         [UserIsNotDefined]     [BIT],
         [PasswordError]        [BIT],
         [Order]                [INT]
	)

------------------------
	IF @CollectionGUID = 0x0
	BEGIN
		SET @OneFile = 1

		DECLARE @CurDB AS [NVARCHAR](256)
		DECLARE @AmnDB AS [NVARCHAR](256)
		DECLARE @FPDate2 AS [DATETIME]
          DECLARE @DbId2 AS [INTEGER]
			
          SELECT @CurDB = Db_name()

		DECLARE @str [NVARCHAR](2000)

          SET @AmnDB = (SELECT TOP 1 Cast([VALUE] AS [NVARCHAR](50))
                        FROM   [dbo].[fnListExtProp]('AmnDBName'))

		-- [sysProperties] WHERE [name] = 'AmnDBName')
          DECLARE @I1 INT,
                  @I2 INT

          SELECT @I1 = Charindex ('-', [Value], 0),
                 @I2 = Charindex ('-', [Value], Charindex ('-', [Value], 0) + 1)
          FROM   [op000]
          WHERE  [Name] = 'AmnCfg_FPDate'

          SELECT @FPDate2 = Cast(Substring([Value], @I1 + 1, @I2 -@I1 - 1)
                                 + '/' + Substring([Value], 1, @I1 -1 ) + '/'
                                 + Substring([Value], @I2 + 1, 4) AS DATETIME)
          FROM   [op000]
          WHERE  [Name] = 'AmnCfg_FPDate'

          SELECT @DbId2 = [d].[database_id]
          FROM   [sys].[databases] AS [d]
          WHERE  [d].[name] = @CurDB

          INSERT INTO [#DataBases]
                      ([AmnName],
                       [DbName],
                       [FPDate],
                       [dbid],
                       [ExcludeFPBills])
          VALUES     ( @AmnDB,
                       @CurDB,
                       @FPDate2,
                       @DbId2,
                       0)
	END
	ELSE
	BEGIN
	-----------------	
	--- Fill #DataBases with corrects databases by date
          DECLARE @AmnName1 [NVARCHAR](256)
          DECLARE @FPDate1 [DATETIME]
          DECLARE @dbId1 [INT]
          DECLARE @ExcludeFPBills1 [BIT]
          DECLARE @EPDate1 [DATETIME]
          DECLARE @VersionNeedsUpdating [BIT]
          DECLARE @UserIsNotDefined [BIT]
          DECLARE @PasswordError [BIT]
          DECLARE @c1 CURSOR

          SET @c1 = CURSOR FAST_FORWARD
          FOR SELECT [DBName],
                     [FPDate],
                     [dbId],
                     [ExcludeFPBills],
                     [EPDate],
                     [VersionNeedsUpdating],
                     [UserIsNotDefined],
                     [PasswordError]
              FROM   [#AllDataBases]
              ORDER  BY [Order] --DBName
	
		OPEN @c1

		FETCH NEXT FROM @c1 INTO @AmnName1, @FPDate1, @dbId1, @ExcludeFPBills1, @EPDate1, @VersionNeedsUpdating, @UserIsNotDefined, @PasswordError 

		WHILE @@FETCH_STATUS = 0
		BEGIN
                IF ( @FPDate1 BETWEEN @StartDate AND @EndDate )
                    OR ( @EPDate1 BETWEEN @StartDate AND @EndDate )
                  IF( ( @VersionNeedsUpdating = 0 )
                      AND ( @UserIsNotDefined = 0 )
                      AND ( @PasswordError = 0 ) )
                    INSERT INTO [#DataBases]
                                ([DBName],
                                 [FPDate],
                                 [dbid],
                                 [ExcludeFPBills])
                    VALUES     ( @AmnName1,
                                 @FPDate1,
                                 @dbId1,
                                 @ExcludeFPBills1)
				ELSE 
				BEGIN
                        IF( @VersionNeedsUpdating = 1 )
                          INSERT INTO [#SecViol]
                                      ([Type],
                                       [Cnt])
                          VALUES     ( 100,
                                       1)

                        IF( @UserIsNotDefined = 1 )
                          INSERT INTO [#SecViol]
                                      ([Type],
                                       [Cnt])
                          VALUES     ( 101,
                                       1)

                        IF( @PasswordError = 1 )
                          INSERT INTO [#SecViol]
                                      ([Type],
                                       [Cnt])
                          VALUES     ( 102,
                                       1)
				END

			FETCH NEXT FROM @c1 INTO @AmnName1, @FPDate1, @dbId1, @ExcludeFPBills1, @EPDate1, @VersionNeedsUpdating, @UserIsNotDefined, @PasswordError 
		END

          CLOSE @c1

          DEALLOCATE @c1
	END

	CREATE TABLE [#TmpResult]
	(
		[RecordGUID]		[UNIQUEIDENTIFIER],
		[acGUID]			[UNIQUEIDENTIFIER],
		[acName]			[NVARCHAR](500) COLLATE ARABIC_CI_AI,
		[acCode]			[NVARCHAR](256) COLLATE ARABIC_CI_AI,
		[acType]			[INT],
		[acNSons]			[INT],
		[acPath]			NVARCHAR(2000),
		[SumDebit]			[FLOAT],
		[SumCredit]			[FLOAT],
		[PrevSumDebit]		[FLOAT],
		[PrevSumCredit]		[FLOAT],
		[enDate]			[DATETIME],
		[acParentGuid]		[UNIQUEIDENTIFIER],
		[CustomerGUID]		[UNIQUEIDENTIFIER],
		[CustomerName]		[NVARCHAR](500) COLLATE ARABIC_CI_AI,
		[CustomerLatinName]	[NVARCHAR](500) COLLATE ARABIC_CI_AI
	)
	
    DECLARE @AmnName [NVARCHAR](256)
    DECLARE @ProcedureName [NVARCHAR](256)
	DECLARE @Procedure2Name [NVARCHAR](256)
    DECLARE @FPDate [DATETIME]
    DECLARE @DbId [INT]
    DECLARE @ExcludeFPBills [BIT]

	SET @ProcedureName = 'repAccDebitCreditMonthlyTree'

	DECLARE @userName [NVARCHAR](256)

	SELECT @userName = [dbo].[fnGetCurrentUserName]()
	
	--fetch Acc tree
	DECLARE @c CURSOR

    SET @c = CURSOR FAST_FORWARD
    FOR SELECT '[' + [DBName] + ']',
               [FPDate],
               [dbid],
               [ExcludeFPBills]
        FROM   [#DataBases]
        ORDER  BY [Order]

	OPEN @c

	FETCH NEXT FROM @c INTO @AmnName, @FPDate, @DbId, @ExcludeFPBills

	DECLARE @s [NVARCHAR](MAX)

	WHILE @@FETCH_STATUS = 0
	BEGIN
		IF @OneFile = 0
		BEGIN
                SET @s = 'EXEC ' + @AmnName
                         + '..[prcConnections_add2] '''
                         + Cast( @userName AS [NVARCHAR](128)) + ''''

			EXECUTE( @s)

			-- Fill Ex tbl with deleted entries and deleted FPBills
                SET @s = ' INSERT INTO ' + @AmnName
                         + '..[Ex] SELECT [EntryGUID] FROM [dbcdd] WHERE [ParentGuid] = 
										(SELECT [Guid] FROM dbcd WHERE [dbid] = '
                         + Cast( @DbId AS NVARCHAR) + ')'

			IF @ExcludeFPBills = 1
                  SET @s = @s + ' INSERT INTO ' + @AmnName
                           + '..[Ex] SELECT [Guid] FROM [bu000] WHERE [TypeGuid] = (SELECT [GUID] FROM [bt000] WHERE [Type] = 2 AND [SortNum] = 1)'

			EXECUTE( @s)
		END

		BEGIN TRAN

			SET @s = ' INSERT INTO [#TmpResult] EXEC '
			SET @s = @s + @AmnName
          SET @s = @s + '..' + @ProcedureName + ''''
                   + CONVERT( [NVARCHAR](2000), @AccGUID) + ''','
                   + '''' + CONVERT( [NVARCHAR](2000), @CostGUID)
                   + ''',' + '''' + Cast( @StartDate AS NVARCHAR)
                   + ''',' + '''' + Cast( @EndDate AS NVARCHAR)
                   + ''',' + ''''
                   + CONVERT( NVARCHAR(2000), @CurrencyGUID)
                   + ''',' + Cast( @CurrencyVal AS NVARCHAR) + ','
                   + '''' + CONVERT( NVARCHAR(2000), @SrcGuid) + ''''
                   + ',''' + @Str2 + ''','
                   + CONVERT( NVARCHAR(2), @Lang)--+''''
                   + ', '
                   + CONVERT( NVARCHAR(200), @PostedVal) + ', '
                   + Cast( @Level AS NVARCHAR) + ', '
                   + Cast( @ShowEmptyAcc AS NVARCHAR) + ', '
                   + Cast( @ShowBaseAcc AS NVARCHAR) + ', '
                   + Cast( @ShowComposeAcc AS NVARCHAR) + ', '
				   + '''' + CONVERT( [NVARCHAR](2000), @CustomerGUID) + ''','
				   + Cast( @DetailOnlyAccCustomers AS NVARCHAR(2)) + ', '
				   + Cast( @DetailByCustomer AS NVARCHAR(2))
					
			--print @s
			EXECUTE( @s)

		-- Clear Ex tbl
			SET @s = ' DELETE FROM ' + @AmnName + '..[Ex]'

			EXECUTE(@s)

		COMMIT TRAN			

		FETCH NEXT FROM @c INTO @AmnName, @FPDate, @DbId, @ExcludeFPBills
	END

	CLOSE @c

	DEALLOCATE @c

    --SELECT *
    --FROM   [#TmpResult] AS [r]
    --ORDER  BY r.[acPath],
    --          CASE @Sort
    --            WHEN 0 THEN r.[AcCode]
    --            ELSE r.[AcName]
    --          END

	IF (@DetailOnlyAccCustomers != 0) OR (@DetailByCustomer != 0)
	BEGIN
		UPDATE [#TmpResult] 
		SET RecordGUID = g.RecordGUID
		FROM 
			[#TmpResult] e 
			INNER JOIN (
				SELECT 
					NEWID() AS RecordGUID, 
					acGUID AS acGUID, 
					CustomerGUID AS CustomerGUID
				FROM [#TmpResult] 
				WHERE CustomerGUID != 0x0 
				GROUP BY acGUID, CustomerGUID) g ON e.acGUID = g.acGUID AND e.CustomerGUID = g.CustomerGUID
	END 

    SELECT 
		IsNULL([r].enDate, '1-1-1980') as [enDate],
		[r].acCode, 
		[r].acGUID,
		[r].acName,
		[r].acNSons,
		[r].acParentGuid,
		[r].acPath,
		[r].acType,
		[r].PrevSumCredit,
		[r].PrevSumDebit,
		[r].SumCredit,
		[r].SumDebit,
		[r].CustomerGUID,
		[r].[CustomerName],
		[r].[CustomerLatinName],
		[r].RecordGUID
    FROM   
		[#TmpResult] AS [r]
    ORDER BY 
		r.[acPath],
        r.[AcCode],
		[r].[CustomerName],
		r.[enDate] 

    SELECT *
    FROM   [#SecViol] 
#########################################################
#END
