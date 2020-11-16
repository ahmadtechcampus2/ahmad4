################################################################################
CREATE PROCEDURE RepFirstLastEntry
AS
	SET NOCOUNT ON 
	
	SELECT
		MIN([ceNumber]) AS [MinEn],
		MAX([ceNumber]) AS [MaxEn],
		MIN([enDate]) AS [MinEnDate],
		MAX([enDate]) AS [MaxEnDAte]
	FROM
		[vwCe] AS [Ce] INNER JOIN [vwEn]  [En] ON [Ce].[ceGUID] = [En].[enParent]

################################################################################
CREATE PROCEDURE repTrialBal 
	@IsCalledByWeb		BIT,
	@AccPtr					[UNIQUEIDENTIFIER],
    @StartDate				[DATETIME],
    @EndDate				[DATETIME],
    @PrevStartDate			[DATETIME],
    @PrevEndDate			[DATETIME],
    @PostedVal				[INT] = -1,-- 1 posted or 0 unposted -1 all posted & unposted  
    @FirstEntryNumber		[INT],
    @LastEntryNumber		[INT],
    -- @UserSec				 [INT],
    @MaxLevel				[INT],-- show this level  
    @ShowEmptyAcc			[INT],
    @ShowComposeAcc			[INT],
    @ShowBalancedAcc		[INT],
    @ShowBranchAcc			[INT],
    @CurGUID				[UNIQUEIDENTIFIER],
    @CurVal					[FLOAT],
    -- @AccType				 [INT],
    @CostPtr				[UNIQUEIDENTIFIER] = 0X0,
    @AllEntries				[INT] = 0,
    @ShowMainAcc			[INT] = 0,
    @SrcGuid				[UNIQUEIDENTIFIER] = 0X0,
    @CostType				[INT] = 0,
    @NotShowCustAcc			[INT] = 0,
    @FilterCurr				UNIQUEIDENTIFIER = 0X00,
    @ClassFilter			[NVARCHAR](250) = '',
    @DetClass				BIT = 0,
    @Hospermission			BIT = 0,
	@ShowPrevBalance		BIT = 0,
	@CustomerGUID			[UNIQUEIDENTIFIER] = 0X0,
	@DetailOnlyAccCustomers	BIT = 0,
	@DetailByCustomer		BIT = 0
AS  
/*  
this procedure:  
	- ...  
	- ignores ceSecurity if user has readBalance privilage.  
	- algorithm:  
		1. Fill the result from descendings  
		2.  
		3. update parents balances:  
*/  
	SET NOCOUNT ON 
	DECLARE 
		@Test BIT,
		@AccType INT,
		@bUnmatched	BIT

	SET @bUnmatched = 1	
	IF EXISTS(SELECT * FROM [op000] WHERE [Name] = 'AmnCfg_UnmatchedMsg' AND [Type] = 0 AND Value = '0')
		SET @bUnmatched = 0
	
	SET @AccType = -1
	SELECT @AccType = ISNULL(Type, -1) FROM ac000 WHERE [Guid] = @AccPtr

	SET @Test = 0
    DECLARE @Admin    [INT],
            @UserGuid [UNIQUEIDENTIFIER],
            @CNT      INT
	SET @UserGuid = [dbo].[fnGetCurrentUserGUID]()  
    SET @Admin = [dbo].[fnIsAdmin](ISNULL(@userGUID, 0x00))
    DECLARE @Sql NVARCHAR(4000),
            @RES NVARCHAR(4000)
    DECLARE @CostCnt INT,
            @AllCost BIT
	DECLARE @ShowLastDebit  [BIT], @ShowLastCredit   [BIT], @ShowLastPay [BIT]
	SET @ShowLastDebit = 1
	SET @ShowLastCredit = 1
	SET @ShowLastPay = 1
	SET @Sql= '' 
	SET @RES =''  

	IF (@IsCalledByWeb = 1) AND (@ShowPrevBalance = 1)
	BEGIN 
		SET @PrevStartDate = ISNULL((SELECT TOP 1 CAST([Value] AS DATE) FROM op000 WHERE [Name] ='AmnCfg_FPDate' AND [Type] = 0), GETDATE())
		SET @PrevEndDate = DATEADD(dd, -1, @StartDate);
		IF @PrevStartDate >= @StartDate
			SET @PrevStartDate = @PrevEndDate
		IF @PrevEndDate < @PrevStartDate
			SET @PrevEndDate = @PrevStartDate
	END 

    CREATE TABLE [#SecViol]
      (
         [Type] [INT],
         [Cnt]  [INTEGER]
      )
    CREATE TABLE [#CostTbl]
      (
         [CostGUID] [UNIQUEIDENTIFIER],
         [Security] SMALLINT
      )
    CREATE TABLE [#BillTbl]
      (
         [Type]              [UNIQUEIDENTIFIER],
         [Security]          SMALLINT,
         [ReadPriceSecurity] SMALLINT
      )
    CREATE TABLE [#EntryTbl]
      (
         [Type]     [UNIQUEIDENTIFIER],
         [Security] SMALLINT
      )
	--CREATE TABLE #NotesTbl( Type UNIQUEIDENTIFIER, Security INT)    
	-- the #result will hold the un-grouped data before summation, its necessary for security checking:  
	CREATE TABLE [#Result]
	(
         [enAccount]		[UNIQUEIDENTIFIER],
         [ceGuid]			[UNIQUEIDENTIFIER],
         [FixedEnDebit]		[FLOAT],
         [FixedEnCredit]	[FLOAT],
         [enDate]			[DATETIME],
         [ceNumber]			[INT],
         [AcSecurity]		SMALLINT,
         [ce_Security]		SMALLINT,
         [en_Security]		SMALLINT,
         [CurrAccBal]		[FLOAT],
         [classptr]			[NVARCHAR](256) COLLATE ARABIC_CI_AI DEFAULT '',
		 CustomerGUID		[UNIQUEIDENTIFIER]
	)  
	CREATE NONCLUSTERED INDEX [#Resultndx01]
	ON [#Result] (enAccount, CustomerGUID) INCLUDE (enDate, ceNumber, ceGuid, FixedEnDebit, FixedEnCredit)

	CREATE TABLE [#Result2]
	( 
         [enAccount]		[UNIQUEIDENTIFIER],
         [ceGuid]			[UNIQUEIDENTIFIER],
         [FixedEnDebit]		[FLOAT],
         [FixedEnCredit]	[FLOAT],
         [enDate]			[DATETIME],
         [ceNumber]			[INT],
         [AcSecurity]		[INT],
         [ce_Security]		[INT],
         [en_Security]		[INT],
         [TypeGuid]			[UNIQUEIDENTIFIER],
         [CurrAccBal]		[FLOAT],
         [classptr]			[NVARCHAR](256) COLLATE ARABIC_CI_AI DEFAULT '',
		 CustomerGUID		[UNIQUEIDENTIFIER]
	)
	
	-- create #prevBalances table to hold accounts previouse balances  
	DECLARE @PrevBalances TABLE
	(   
         [GUID]				[UNIQUEIDENTIFIER],
         [PrevDebit]		[FLOAT],
         [PrevCredit]		[FLOAT],
         [PrevCurrAccBal]	[FLOAT],
         [classptr]			[NVARCHAR](256) COLLATE ARABIC_CI_AI DEFAULT '',
		 CustomerGUID		[UNIQUEIDENTIFIER]
	)
	-- this is the repors' final result table  
	CREATE TABLE [#EndResult]  
	(   
         [ID]				INT IDENTITY(1, 1),
		 [accGuid]			[UNIQUEIDENTIFIER],
         [GUID]				[UNIQUEIDENTIFIER],
         [Code]				[NVARCHAR](256) COLLATE ARABIC_CI_AI,
         [Name]				[NVARCHAR](256) COLLATE ARABIC_CI_AI,
         [LatinName]		[NVARCHAR](256) COLLATE ARABIC_CI_AI,
         [ParentGUID]		[UNIQUEIDENTIFIER],
         [Type]				[INT],
         [NSons]			[INT],
         [Level]			[INT] DEFAULT 0,
         [PrevDebit]		[FLOAT] DEFAULT 0,
         [PrevCredit]		[FLOAT] DEFAULT 0,
         [PrevBalDebit]		[FLOAT] DEFAULT 0,
         [PrevBalCredit]	[FLOAT] DEFAULT 0,
         [TotalDebit]		[FLOAT] DEFAULT 0,
         [TotalCredit]		[FLOAT] DEFAULT 0,
         [BalDebit]			[FLOAT] DEFAULT 0,
         [BalCredit]		[FLOAT] DEFAULT 0,
         [EndBalDebit]		[FLOAT] DEFAULT 0,
         [EndBalCredit]		[FLOAT] DEFAULT 0,
         [haveBalance]		INT,-- null indicates empty account while 0 indicates balanced account, and 1 not balanced  
         [Status]			[INT],
         [acSecurity]		SMALLINT,
         [LastDebit]		[FLOAT] DEFAULT 0,
         [LastDebitDate]	SMALLDATETIME DEFAULT '1/1/1980',
         [LastCredit]		[FLOAT] DEFAULT 0,
         [LastCreditDate]	SMALLDATETIME DEFAULT '1/1/1980',
         [LastPay]			[FLOAT] DEFAULT 0,
         [LastPayDate]		SMALLDATETIME DEFAULT '1/1/1980',
         [acCurrGuid]		[UNIQUEIDENTIFIER],
         [CurrAccBal]		[FLOAT] DEFAULT 0,
         [PrevCurrAccBal]	[FLOAT] DEFAULT 0,
         [CurCode]			[NVARCHAR](256) COLLATE ARABIC_CI_AI,
         [classptr]			[NVARCHAR](256) COLLATE ARABIC_CI_AI DEFAULT '',
         [Path]				[NVARCHAR](2000) COLLATE ARABIC_CI_AI,
		 CustomerGUID		[UNIQUEIDENTIFIER],
		 [UnMatched]		[INT] DEFAULT 0
	)
	
	-- report footer data:  
    DECLARE @Totals TABLE
      (
         [TotalPrevDebit]     [FLOAT] DEFAULT 0,
         [TotalPrevCredit]    [FLOAT] DEFAULT 0,
         [TotalDebitTotal]    [FLOAT] DEFAULT 0,
         [TotalCreditTotal]   [FLOAT] DEFAULT 0,
         [TotalDebitBalance]  [FLOAT] DEFAULT 0,
         [TotalCreditBalance] [FLOAT] DEFAULT 0,
         [TotalPrevBalDebit]  [FLOAT] DEFAULT 0,
         [TotalPrevBalCredit] [FLOAT] DEFAULT 0
      )
	-- accounts balances table:  
	DECLARE @Balances TABLE 
	(  
         [GUID]				[UNIQUEIDENTIFIER],
         [TotalDebit]		[FLOAT],
         [TotalCredit]		[FLOAT],
         [CurrAccBal]		[FLOAT],
         [classptr]			[NVARCHAR](256) COLLATE ARABIC_CI_AI DEFAULT '',
		 CustomerGUID		[UNIQUEIDENTIFIER]
	)   
	-- declare variables:  
    DECLARE @Level     [INT],
		@ZeroValue [FLOAT],  
            @MinLevel  [INTEGER],
            @str       [NVARCHAR](max)
    DECLARE @UserId  [UNIQUEIDENTIFIER],
		@HosGuid [UNIQUEIDENTIFIER]  
	-- init  
    SET @HosGuid = Newid()
	SET @ZeroValue = [dbo].[fnGetZeroValuePrice]()  
    INSERT INTO [#CostTbl]
    EXEC [prcGetCostsList]
      @CostPtr
	SET @CostCnt = @@ROWCOUNT
    IF( (SELECT Count(*)
         FROM   co000) = @CostCnt )
		SET @AllCost = 1
	ELSE
		SET @AllCost = 0
	
	SET @UserId = [dbo].[fnGetCurrentUserGUID]()       
	  
    INSERT INTO [#EntryTbl]
    EXEC [prcGetNotesTypesList]
      @SrcGuid,
      @UserID
	
    INSERT INTO [#BillTbl]
    EXEC [prcGetBillsTypesList]
      @SrcGuid,
      @UserID
    INSERT INTO [#EntryTbl]
    EXEC [prcGetEntriesTypesList]
      @SrcGuid,
      @UserID
    INSERT INTO [#EntryTbl]
    SELECT [Type],
           [Security]
    FROM   [#BillTbl]
	IF [dbo].[fnObjectExists]('prcGetTransfersTypesList') <> 0	  
      INSERT INTO [#EntryTbl]
      EXEC [prcGetTransfersTypesList]
        @SrcGuid
    IF [dbo].[fnObjectExists]('vwTrnStatementTypes') <> 0
	BEGIN		  
		SET @str = '
		INSERT INTO [#EntryTbl]  
		SELECT  
			[IdType],  
			[dbo].[fnGetUserSec]('''
                     + Cast(@UserID AS NVARCHAR(36))
                     + ''', 0X2000F200, [IdType], 1, 1)  
		FROM
			[dbo].[RepSrcs] AS [r]   
			INNER JOIN [dbo].[vwTrnStatementTypes] AS [b] ON [r].[IdType] = [b].[ttGuid]
		WHERE
			[IdTbl] = '''
                     + Cast(@SrcGuid AS NVARCHAR(36)) + ''''
		EXEC(@str)
	END
	IF [dbo].[fnObjectExists]('vwTrnExchangeTypes') <> 0
	BEGIN		  
		SET @str = '
		INSERT INTO [#EntryTbl]  
		SELECT
			[IdType],  
			[dbo].[fnGetUserSec]('''
                     + Cast(@UserID AS NVARCHAR(36))
                     + ''', 0X2000F200, [IdType], 1, 1)  
		FROM  
			[dbo].[RepSrcs] AS [r]   
			INNER JOIN [dbo].[vwTrnExchangeTypes] AS [b] ON [r].[IdType] = [b].[Guid]  
		WHERE  
			[IdTbl] = '''
                     + Cast(@SrcGuid AS NVARCHAR(36)) + ''''
		EXEC(@str)  
	END 			  
				  
    IF ( @Hospermission = 1 )
       AND EXISTS(SELECT *
                  FROM   [dbo].[RepSrcs]
                  WHERE  [IDSubType] = 303)
      INSERT INTO [#EntryTbl]
      VALUES     (@HosGuid,
                  0)
    IF ISNULL(@CostPtr, 0X00) = 0X0
      INSERT INTO [#CostTbl]
      VALUES     (0X0,
                  0)
	-- 1st. step: Fill the result from descendings:  
	INSERT INTO [#EndResult] (
		[GUID],
		[accGuid],
		[Code],
		[Name],
		[LatinName],
		[ParentGUID],
		[Type],
		[NSons],
		[Level],
		[acSecurity],
		[acCurrGuid],
		[Path],
		[CustomerGUID])
    SELECT 
		[ac].[GUID],
		newid(),
		[ac].[Code],
		[ac].[Name],
		[ac].[LatinName],
		[ac].[ParentGuid],
		[ac].[Type],
		[ac].[NSons],
		[dl].[Level],
		[ac].[Security],
		[ac].[CurrencyGuid],
		[dl].[Path],
		0x0
	FROM
		[dbo].[fnGetAccountsList](@AccPtr, 1) AS [dl]
		INNER JOIN [ac000] AS [ac] ON [dl].[GUID] = [ac].[GUID]
	WHERE
		((@FilterCurr = 0X0) 
		OR
		([CurrencyGuid] = @FilterCurr) 
		OR
		([NSONS] > 0)
		OR
		([Type] = 4))
		AND ([Type] <> 8 AND  [Type] <> 2 )--حذف الحسابات الختامية و التوزيعية من الشجرة

	--IF @ShowCurrAcc > 0  
		UPDATE [e]  
      SET    [CurCode] = [myCode]
      FROM   [#EndResult] AS [e]
             INNER JOIN [vwmy] AS [my]
                     ON [my].[myGuid] = [acCurrGuid]
	
    -- Calc Current Balance: 
    IF @AccPtr IN (SELECT [GUID]
                   FROM   [AC000]
                   WHERE  [Type] = 4)
	BEGIN  
          SET @Cnt = (SELECT Count(*)
                      FROM   [#EndResult]
                      WHERE  [Type] = 4)
		
		WHILE @Cnt > 0  
		BEGIN  
			UPDATE [#EndResult] 
                SET    [LEVEL] = [LEVEL] - 1
                WHERE  GUID IN (SELECT SonGuid
                                FROM   ci000 ci
                                       INNER JOIN [#EndResult] b
                                               ON b.Guid = ci.ParentGuid
                                WHERE  b.Level >= @Cnt - 1)
                        OR GUID IN (SELECT GUID
                                    FROM   [#EndResult] er
                                    WHERE  er.ParentGUID IN (SELECT SonGuid
                                                             FROM   ci000 A
                                                                    INNER JOIN [#EndResult] b
                                                                            ON b.Guid = a.ParentGuid
                                                             WHERE  b.Level >= @Cnt - 1))
			SET @Cnt = @Cnt - 1
		END
		IF( @ShowComposeAcc = 0 )
		BEGIN
                DELETE [#EndResult]
                WHERE  [Type] = 4
		END
          SELECT GUID,
                 Min([LEVEL]) [Level]
          INTO   #V
          FROM   [#EndResult]
          GROUP  BY GUID
          HAVING Count(*) > 1
		  
          DELETE r
          FROM   [#EndResult] r
                 INNER JOIN #V V
                         ON r.Guid = v.Guid
                            AND r.[Level] = v.[Level]
          UPDATE [#EndResult]
          SET    [ParentGUID] = 0X00
          WHERE  [LEVEL] = 0
	END
	DECLARE @stbl NVARCHAR(100) 
    IF ( @Test = 0 )
	BEGIN   
		SET @Sql = '
		CREATE TABLE  #EndResult2
		(
			[GUID]			[UNIQUEIDENTIFIER],
			[Level]			[INT],
			[acSecurity]	smallint,
			[acCurrGuid]	[UNIQUEIDENTIFIER],
			[CurCode]		[NVARCHAR](256) COLLATE ARABIC_CI_AI,
			[classptr]		[NVARCHAR](256) COLLATE ARABIC_CI_AI DEFAULT '''',
			CustomerGUID	[UNIQUEIDENTIFIER]
		)
			
		INSERT INTO #EndResult2 
		SELECT 
			[GUID],
			[Level],
			[acSecurity],
			[acCurrGuid],
			[CurCode],
			[classptr],
			CustomerGUID
		FROM 
			[#EndResult]
		WHERE 
			NSons = 0  
		ORDER BY
			[GUID]
		' + Char(13)
		--CREATE INDEX SDwwFSDA ON   [#EntryTbl]([Type])
		SET @Sql= @Sql + '
		CREATE TABLE #Curr2(
			DATE SMALLDATETIME,
			VAL FLOAT,
			PRIMARY KEY CLUSTERED(Date,VAL))'
		SET @Sql = @Sql + ' 
		INSERT INTO #Curr2
		SELECT DISTINCT [DATE],CurrencyVal FROM 
		( 
		SELECT 
			DATE,
			CurrencyVal
		FROM 
			mh000
		WHERE 
			CurrencyGUID = '''
                     + Cast(@CurGUID AS NVARCHAR(36))
                     + ''' UNION ALL 
		SELECT
			''1/1/1980'',
			CurrencyVal
		FROM 
			MY000
		WHERE
			GUID = '''
                     + Cast(@CurGUID AS NVARCHAR(36))
                     + ''') a ORDER BY DATE DESC' + Nchar(13)
          SET @Sql = @Sql + ' CREATE TABLE #Result222 
		(   
			[enAccount]			[UNIQUEIDENTIFIER],   
			[ceGuid]			[UNIQUEIDENTIFIER],   
			[FixedEnDebit]		[FLOAT],   
			[FixedEnCredit]		[FLOAT],   
			[enDate]			[DATETIME],   
			[ceNumber]			[INT],   
			[AcSecurity]		SMALLINT,   
			[ce_Security]		SMALLINT,  
			[en_Security]		SMALLINT,  
			[TypeGuid]			[UNIQUEIDENTIFIER],  
			[CurrAccBal]		[FLOAT],  
			[classptr]			[NVARCHAR](256) COLLATE ARABIC_CI_AI DEFAULT '''',
			CustomerGUID		[UNIQUEIDENTIFIER]
		) ' + Nchar(13)
			SET @stbl = '#Result222'
	END
	ELSE 
	BEGIN
		SET @Sql = ''
		SET @stbl = '#Result2'
	END

    SET @Sql= @Sql + 'INSERT INTO ' + @stbl
              + '  
			SELECT [en].[AccountGUID], ' 
    IF @ShowLastDebit > 0
        OR @ShowLastCredit > 0
        OR @ShowLastPay > 0
				SET @Sql = @Sql + '[ce].[ceGuid],' 
			ELSE 
				SET @Sql = @Sql + '0X00 ,'  
    IF NOT( @ShowLastDebit > 0
             OR @ShowLastCredit > 0
             OR @ShowLastPay > 0 )
				SET @Sql = @Sql + 'SUM('  
    IF( @CostType = 0 )
			BEGIN
          IF ( @Test = 0 )
					SET @Sql = @Sql + '[en].[Debit] * FACTOR '
				ELSE
            SET @Sql = @Sql
                       + '[dbo].[fnCurrency_fix]([en].[Debit], [en].[CurrencyGUID], [en].[CurrencyVal],'''
                       + Cast(@CurGUID AS NVARCHAR(36))
                       + ''',[en].[Date])'
			END
			ELSE 
      SET @Sql = @Sql + '[en].[Debit]/'
                 + Cast(@CurVal AS NVARCHAR(36))
    IF NOT( @ShowLastDebit > 0
             OR @ShowLastCredit > 0
             OR @ShowLastPay > 0 )
				SET @Sql = @Sql + ')' 
			SET @Sql = @Sql + ',' 
    IF NOT( @ShowLastDebit > 0
             OR @ShowLastCredit > 0
             OR @ShowLastPay > 0 )
				SET @Sql = @Sql + 'SUM('  
    IF ( @CostType = 0 )
			BEGIN
          IF ( @Test = 0 )
					SET @Sql = @Sql + ' [en].[Credit] * FACTOR'
				ELSE
            SET @Sql = @Sql
                       + '[dbo].[fnCurrency_fix]([en].[Credit], [en].[CurrencyGUID], [en].[CurrencyVal],'''
                       + Cast ( @CurGUID AS NVARCHAR(36) )
                       + ''',[en].[Date])'
			END
			ELSE 
      SET @Sql = @Sql + '[en].[Credit]/'
                 + Cast(@CurVal AS NVARCHAR(36))
    IF NOT ( @ShowLastDebit > 0
              OR @ShowLastCredit > 0
              OR @ShowLastPay > 0 )
				SET @Sql = @Sql + ')' 
			SET @Sql = @Sql + ',[en].[Date] '
			SET @Sql = @Sql + ',0,   
					  [AcSecurity],   
					  [ceSecurity],
					  [t].[Security], '
					  
    IF ( @Hospermission = 0 )
		BEGIN 
			SET @Sql = @Sql + ' [ceTypeGuid] [ceTypeGuid], ' 
		END 
		ELSE 
		BEGIN
          SET @Sql = @Sql
                     + '(CASE ISNULL([ceTypeGuid], 0X0)
					WHEN 0X0 THEN 
						CASE ISNULL([er].[ParentGuid], 0x0)   
							WHEN 0X0 THEN 0X0
							ELSE 
								CASE   
									WHEN [er].[ParentType] BETWEEN 300 AND 305 THEN CAST ('''
                     + Cast(@HosGuid AS NVARCHAR (36))
                     + '''AS UNIQUEIDENTIFIER)  
									ELSE 0X0
								END   
						END  
					ELSE [ceTypeGuid] 
			END) [ceTypeGuid] ,' 
		END	
    IF NOT ( @ShowLastDebit > 0
              OR @ShowLastCredit > 0
              OR @ShowLastPay > 0 )
			SET @Sql = @Sql + 'SUM(' 
  --  IF ( @ShowCurrAcc = 0 )
		--	SET @Sql = @Sql + '0' 
		--ELSE 
      SET @Sql = @Sql
                 + '[dbo].[fnCurrency_fix]([en].[Debit] - [en].[Credit], [en].[CurrencyGUID], [en].[CurrencyVal], [ac].[acCurrGuid], [en].[Date])'
    IF NOT( @ShowLastDebit > 0
             OR @ShowLastCredit > 0
             OR @ShowLastPay > 0 )
			SET @Sql = @Sql + ')' 
    IF ( @DetClass = 0 )
			SET @Sql = @Sql + ','''' AS CLASS ' 
		ELSE 
			SET @Sql = @Sql + ',en.class  CLASS '

	IF @DetailByCustomer > 0
		SET @Sql = @Sql + ', [en].CustomerGUID '
	ELSE BEGIN 
		IF @DetailOnlyAccCustomers > 0 
			SET @Sql = @Sql + ', ISNULL(cu.GUID, 0x0) '
		ELSE 
			SET @Sql = @Sql + ', 0x0 '
	END
	------------
	SET @Sql = @Sql + ' FROM   
				 [vwCe] AS [ce] INNER JOIN '
    IF ( @Test = 0 )
      SET @Sql = @Sql
                 + '(SELECT *,1 / CASE WHEN [CurrencyGUID] ='''
                 + Cast(@CurGUID AS NVARCHAR(36))
                 + ''' THEN [CurrencyVal] ELSE dbo.fnGetCurVal(''' + CAST(@CurGUID AS  NVARCHAR(36)) + ''', e.Date) END FACTOR FROM [en000] e)'
		ELSE
			SET @Sql = @Sql + '[en000] '
    SET @Sql = @Sql
               + 'AS [en] ON [en].[ParentGuid] = [ceGuid] '
		DECLARE @enr NVARCHAR(30)
		SET @enr = '#EndResult'
    IF ( @Test = 0 )
			SET @enr = '#EndResult2'
		
    SET @Sql = @Sql + ' INNER JOIN [#EntryTbl] AS [t]  ON [ceTypeGuid] = [t].[Type] '
	IF ( @Hospermission = 1 )
	BEGIN 
		SET @Sql = @Sql + 'LEFT JOIN [er000] AS [er] ON [er].[EntryGUID] = [ceGuid]  
				INNER JOIN ' + @enr + ' AS [ac] ON [ac].[Guid] = [en].[AccountGUID]   
				'
		--IF @AllCost = 0 
        SET @Sql = @Sql
                    + 'INNER JOIN [#CostTbl] AS [co] ON [En].[CostGUID] = [co].[CostGUID]'
	END	 
	ELSE 
	BEGIN
        SET @Sql = @Sql + 'INNER JOIN ' + @enr
                    + ' AS [ac] ON [ac].[Guid] = [en].[AccountGUID]  '
		--IF @AllCost = 0 
        SET @Sql = @Sql
                    + 'INNER JOIN [#CostTbl] AS [co] ON [En].[CostGUID] = [co].[CostGUID]'
	END			         
	SET @Sql = @Sql + ' LEFT JOIN [cu000] AS [cu] ON cu.GUID = en.CustomerGUID AND [en].[AccountGUID] = [cu].[AccountGUID] '
						         
    SET @Sql = @Sql + ' WHERE ([en].[Date] BETWEEN '
               + [dbo].[fnDateString](@StartDate) + ' AND '
               + [dbo].[fnDateString](@EndDate)
               + ' OR [en].[Date] BETWEEN '
               + [dbo].[fnDateString](@PrevStartDate)
               + ' AND' + [dbo].[fnDateString]( @PrevEndDate)
               + ')
				  AND (('
               + Cast(@PostedVal AS NVARCHAR(2))
               + ' = -1) OR ( [ceIsPosted] ='
               + Cast(@PostedVal AS NVARCHAR(2))
               + '))  
				  AND (([ceNumber] BETWEEN '
               + Cast(@FirstEntryNumber AS NVARCHAR (10))
               + ' AND '
               + Cast(@LastEntryNumber AS NVARCHAR(10))
               + ' AND '
               + Cast( @AllEntries AS NVARCHAR (10))
               + ' = 0) OR '
               + Cast(@AllEntries AS NVARCHAR(10))
               + ' = 1)  
				  AND ('''
               + Cast(@ClassFilter AS NVARCHAR(100))
               + ''' = '''' or [en].[class] like ''%'
               + Cast(@ClassFilter AS NVARCHAR(100))
               + '%'') '
			   + ' AND
				(( ''' + CAST(@CustomerGUID AS NVARCHAR(100)) + ''' = ''00000000-0000-0000-0000-000000000000'') 
				OR (en.CustomerGUID = ''' + CAST(@CustomerGUID AS NVARCHAR(100)) + '''))'
    
	IF NOT ( @ShowLastDebit > 0
              OR @ShowLastCredit > 0
              OR @ShowLastPay > 0 )
	BEGIN
		SET @Sql = @Sql + ' GROUP BY  
				  [en].[AccountGUID],  
				  [en].[Date],
		 		  [AcSecurity],   
				  [ceSecurity],
		 		  ceTypeGuid, 
				  CLASS,
				  [t].[Security] '
		IF @DetailByCustomer > 0
			SET @Sql = @Sql + ', [en].CustomerGUID '
		ELSE BEGIN 
			IF @DetailOnlyAccCustomers > 0 
				SET @Sql = @Sql + ', ISNULL(cu.GUID, 0x0) '
			ELSE 
				SET @Sql = @Sql + ', 0x0 '
		END
	END	
    IF ( NOT( @ShowLastDebit > 0
               OR @ShowLastCredit > 0
               OR @ShowLastPay > 0 )
         AND ( @Hospermission = 1 ) )
      SET @Sql = @Sql
                 + ',[er].[ParentGuid] ,[er].[ParentType] '
    SET @Sql = @Sql + Nchar(13)
	--EXEC sp_executesql @Sql	
	 
	SET @RES = @Sql + 'INSERT INTO [#Result]([enAccount],[ceGuid],[FixedEnDebit], [FixedEnCredit], [enDate], [ceNumber], [AcSecurity], [ce_Security],[en_Security],[CurrAccBal],[classptr], [CustomerGUID])  
					SELECT   
						[enAccount],   
						[ceGuid],  
						[FixedEnDebit],   
						[FixedEnCredit],   
						[enDate],   
						[ceNumber],   
						[AcSecurity],   
						[ce_Security], 
						[en_Security],
						[CurrAccBal],  
						[classptr],
						[CustomerGUID]
					FROM   
						' + @stbl + ' AS [f]' 
		
    IF ( @Hospermission = 1 )
      SET @RES = @RES
                 + 'INNER JOIN [#EntryTbl] AS [t]  ON [f].[TypeGuid] = [t].[Type]'
	 EXEC sp_executesql
      @RES
   
	IF (@ShowEmptyAcc = 1)
	BEGIN 
		;with cte AS
		(
		SELECT e.GUID AS AccGUID, cu.GUID AS CuGUID FROM #EndResult e
		LEFT JOIN cu000 cu on cu.AccountGUID = e.GUID
		)
				
		INSERT INTO [#Result]([enAccount], [CustomerGUID])  
		SELECT 
		AccGUID ,
		CuGUID
		FROM 
		cte c
		LEFT JOIN [#Result] r ON r.CustomerGUID = c.CuGUID
		WHERE ISNULL(r.enAccount, 0x0) = 0x0
	END
	
	-- if the use has readBalance privilage, ignore ceSecurity by suppressing ceSecurity to 0:  
	DECLARE @rowCountDeleted INT
	
	DELETE FROM #Result
    WHERE  [en_Security] < [ce_Security]
	SET @rowCountDeleted = @@ROWCOUNT
	
	DECLARE @SecBalPrice [INT]   
	IF @Admin = 0  
	BEGIN  
		SET @SecBalPrice = [dbo].[fnGetUserAccountSec_readBalance]([dbo].[fnGetCurrentUserGuid]())  
          IF @SecBalPrice > 0
            UPDATE [#Result]
            SET    [ce_Security] = -10
            WHERE  [AcSecurity] <= @SecBalPrice
                   AND [ce_Security] <= @SecBalPrice
	END  
	
	-- check #result security:  
	EXEC [prcCheckSecurity]  
    IF ( @rowCountDeleted > 0 )
	BEGIN
          INSERT INTO #SecViol
          VALUES     (9,
                      @rowCountDeleted)
	END	

	-- insert balances from #result:  
	INSERT INTO @Balances  
    SELECT [enAccount],
           Sum([FixedEnDebit]),
           Sum([FixedEnCredit]),
           Sum([CurrAccBal]),
           [classptr],
		   CustomerGUID 
    FROM   [#Result]
    WHERE  ([enDate] BETWEEN @StartDate AND @EndDate) OR ( @ShowEmptyAcc = 1 AND  [enDate] IS NULL)
    GROUP BY 
		[enAccount],
		[classptr],
		CustomerGUID

	-- Calc Prev Balances:  
	INSERT INTO @PrevBalances   
    SELECT [enAccount],
           Sum([FixedEnDebit]),
           Sum([FixedEnCredit]),
           Sum([CurrAccBal]),
           [classptr],
		   CustomerGUID
    FROM   [#Result]
    WHERE  [enDate] BETWEEN @PrevStartDate AND @PrevEndDate
    GROUP BY 
		[enAccount],
		[classptr],
		CustomerGUID 
	
	IF ISNULL(@CustomerGUID, 0x0) != 0x0
	BEGIN 
		UPDATE [#EndResult]
		SET    
			CustomerGUID = @CustomerGUID
		FROM   
			[#EndResult] AS [e]
			INNER JOIN @Balances [b] ON [e].[GUID] = [b].[GUID]
	END 

	-- update #EndResult with Balances  
	UPDATE [#EndResult]     
    SET    
		[TotalDebit] = ISNULL([b].[TotalDebit], 0),
		[TotalCredit] = ISNULL([b].[TotalCredit], 0),  
		[CurrAccBal] = ISNULL([b].[CurrAccBal], 0)  
    FROM   
		[#EndResult] AS [e]
        INNER JOIN @Balances [b] ON [e].[GUID] = [b].[GUID] AND e.CustomerGUID = b.CustomerGUID
    WHERE [b].[classptr] = ''
	
	;WITH AggregateAccounts AS
	(
		SELECT [ci].[ParentGUID] [Guid], SUM([TotalDebit]) TotalDebit, SUM([TotalCredit]) TotalCredit, SUM([CurrAccBal]) TotalCurrAccBal
		FROM [#EndResult] AS [e]
		INNER JOIN [ci000] AS [ci] ON [ci].[SonGUID] = [e].[GUID]
		GROUP BY [ci].[ParentGUID]
	)

	UPDATE [#EndResult]     
    SET    
		[TotalDebit] = ISNULL([aggAcc].[TotalDebit], 0),
		[TotalCredit] = ISNULL([aggAcc].[TotalCredit], 0),
		[CurrAccBal] = ISNULL([aggAcc].[TotalCurrAccBal], 0)  
    FROM   
		[#EndResult] AS [e]
        INNER JOIN AggregateAccounts [aggAcc] ON [e].[GUID] = [aggAcc].[GUID]
	
	IF ISNULL(@CustomerGUID, 0x0) = 0x0 AND (@DetailOnlyAccCustomers > 0 OR @DetailByCustomer > 0)
	BEGIN 
		INSERT INTO [#EndResult] (
			[GUID],
			[TotalDebit],
			[TotalCredit],
			[CurrAccBal],
			[Code],
			[Name],
			[LatinName],
			[ParentGUID],
			[Type],
			[NSons],
			[Level],
			[classptr],
			[Path],
			CustomerGUID)
		SELECT 
			[e].[GUID],
			ISNULL([b].[TotalDebit], 0),  
			ISNULL([b].[TotalCredit], 0),  
			ISNULL([b].[CurrAccBal], 0),  
			[Code],		  
            [Name],
            [LatinName],
            [ParentGUID],
            [Type],
            [NSons],
            [Level],
            b.[classptr],
            [Path],
			b.CustomerGUID
      FROM   
			[#EndResult] AS [e]
			INNER JOIN @Balances [b] ON [e].[GUID] = [b].[GUID]
      WHERE [b].[classptr] = '' AND b.CustomerGUID != 0x0
	
	  DELETE [#EndResult]
      FROM   
			[#EndResult] AS [e]
			INNER JOIN @Balances [b] ON [e].[GUID] = [b].[GUID]
      WHERE 
			ISNULL([b].[classptr], '') = '' 
			AND 
			ISNULL(b.CustomerGUID, 0x0) != 0x0 
			AND 
			ISNULL(e.CustomerGUID, 0x0) = 0x0 
			AND
			ISNULL([e].[TotalDebit], 0) = 0
			AND
			ISNULL([e].[TotalCredit], 0) = 0
	END 

	ELSE IF ISNULL(@CustomerGUID, 0x0) != 0x0 
	BEGIN 
		INSERT INTO [#EndResult] (
			[GUID],
			[TotalDebit],
			[TotalCredit],
			[CurrAccBal],
			[Code],
			[Name],
			[LatinName],
			[ParentGUID],
			[Type],
			[NSons],
			[Level],
			[classptr],
			[Path],
			[CustomerGUID],
			[acCurrGuid],
			[PrevCurrAccBal],
			[CurCode])
		SELECT 
			[e].[GUID],
			ISNULL([b].[TotalDebit], 0),  
			ISNULL([b].[TotalCredit], 0),  
			ISNULL([b].[CurrAccBal], 0),  
			[Code],		  
            [Name],
            [LatinName],
            [ParentGUID],
            [Type],
            [NSons],
            [Level],
            b.[classptr],
            [Path],
			b.[CustomerGUID],
			[acCurrGuid],
			[PrevCurrAccBal],
			[CurCode]
      FROM   
			[#EndResult] AS [e]
			INNER JOIN @Balances [b] ON [e].[GUID] = [b].[GUID]
      WHERE [b].[classptr] = ''

	  DELETE [#EndResult]
      FROM   
			[#EndResult] AS [e]
      WHERE 
			[e].accGuid IS NOT NULL
	END 

    IF @DETCLASS > 0
		INSERT INTO [#EndResult] (
			[GUID],
			[TotalDebit],
			[TotalCredit],
			[CurrAccBal],
			[Code],
			[Name],
			[LatinName],
			[ParentGUID],
			[Type],
			[NSons],
			[Level],
			[classptr],
			[Path],
			CustomerGUID)
		SELECT 
			[e].[GUID],
			ISNULL([b].[TotalDebit], 0),  
			ISNULL([b].[TotalCredit], 0),  
			ISNULL([b].[CurrAccBal], 0),  
			[Code],		  
            [Name],
            [LatinName],
            [ParentGUID],
            [Type],
            [NSons],
            [Level],
            b.[classptr],
            [Path],
			b.CustomerGUID
      FROM   
			[#EndResult] AS [e]
			INNER JOIN @Balances [b] ON [e].[GUID] = [b].[GUID] --AND e.CustomerGUID = b.CustomerGUID 
      WHERE [b].[classptr] <> ''

	-- update #EndResult with PrevBalances:  
	UPDATE [#EndResult]     
    SET    
		[PrevDebit] = ISNULL([b].[PrevDebit], 0),
		[PrevCredit] = ISNULL([b].[PrevCredit], 0),  
		[PrevCurrAccBal] = ISNULL([b].[PrevCurrAccBal], 0)  
    FROM   
		[#EndResult] AS [e]
        INNER JOIN @PrevBalances [b] ON [e].[GUID] = [b].[GUID] AND e.CustomerGUID = b.CustomerGUID 
    WHERE  [e].[ClassPtr] = [b].[ClassPtr]
    
	INSERT INTO [#EndResult]
                ([GUID],
                 [TotalDebit],
                 [TotalCredit],
                 [PrevDebit],
                 [PrevCredit],
                 [Code],
                 [Name],
                 [LatinName],
                 [ParentGUID],
                 [Type],
                 [NSons],
                 [Level],
                 haveBalance,
                 [classptr],
                 [Path],
				 [CustomerGUID])
    SELECT DISTINCT [e].[GUID],
                    0,
                    0,
                    ISNULL([b].[SumPrevDebit], 0),
                    ISNULL([b].[SumPrevCredit], 0),
                    [Code],
                    [Name],
                    [LatinName],
                    [ParentGUID],
                    [Type],
                    [NSons],
                    [Level],
                    haveBalance,
                    [b].[ClassPtr],
                    [Path],
					e.CustomerGUID 
    FROM   [#EndResult] AS [e]
           INNER JOIN (SELECT [Guid],
                              Classptr,
							  CustomerGUID,
                              Sum(ISNULL([b].[PrevDebit], 0))  [SumPrevDebit],
                              Sum(ISNULL([b].[PrevCredit], 0)) [SumPrevCredit]
                       FROM   @PrevBalances [b]
                       GROUP  BY [GUID],
								CustomerGUID,
                                 [Classptr])b
                   ON [e].[GUID] = [b].[GUID] AND e.CustomerGUID = b.CustomerGUID
    WHERE  [b].[classptr] NOT IN (SELECT [e].[ClassPtr]
                                  FROM   #EndResult e
                                  WHERE  e.[Guid] = b.[Guid] AND e.CustomerGUID = b.CustomerGUID)
	 
	IF @ShowLastDebit > 0  
		UPDATE [e]   
      SET    [LastDebit] = ISNULL((SELECT TOP 1 LAST_VALUE([FixedEnDebit]) OVER (PARTITION BY [enAccount] ,[CustomerGUID] ORDER BY [enDate]) AS [LastDebit]
                                   FROM   [#Result]
                                   WHERE  [enAccount] = [GUID] AND CustomerGUID = e.CustomerGUID
                                          AND [FixedEnDebit] > 0
                                   ORDER  BY [enDate] DESC,
                                             [ceNumber] DESC,
											 [LastDebit] DESC), 0),
             [LastDebitDate] = ISNULL((SELECT TOP 1 [enDate]
                                       FROM   [#Result]
                                       WHERE  [enAccount] = [GUID] AND CustomerGUID = e.CustomerGUID
                                              AND [FixedEnDebit] > 0
                                       ORDER  BY [enDate] DESC), '1/1/1980')
      FROM   [#EndResult] AS [e]
	IF @ShowLastCredit > 0  
		UPDATE [e]   
      SET    [LastCredit] = ISNULL((SELECT TOP 1 LAST_VALUE([FixedEnCredit]) OVER (PARTITION BY [enAccount] ,[CustomerGUID] ORDER BY [enDate]) AS [LastCredit]  
                                    FROM   [#Result]
                                    WHERE  [enAccount] = [GUID] AND CustomerGUID = e.CustomerGUID
                                           AND [FixedEnCredit] > 0
                                    ORDER  BY [enDate] DESC,
                                              [ceNumber] DESC,
											  [LastCredit] DESC), 0),
             [LastCreditDate] = ISNULL((SELECT TOP 1 [enDate]
                                        FROM   [#Result]
                                        WHERE  [enAccount] = [GUID] AND CustomerGUID = e.CustomerGUID
                                               AND [FixedEnCredit] > 0
                                        ORDER  BY [enDate] DESC), '1/1/1980')
      FROM   [#EndResult] AS [e]
			
	IF @ShowLastPay > 0  
		UPDATE [e]   
      SET    [LastPay] = ISNULL((SELECT TOP 1 [FixedEnCredit]
                                 FROM   [#Result] AS [en]
                                        INNER JOIN [Er000] AS [er]
                                                ON [en].[ceGuid] = [er].[EntryGuid]
                                        INNER JOIN [py000] AS [py]
                                                ON [er].[ParentGuid] = [py].[Guid]
                                 WHERE  [enAccount] = [e].[GUID] AND CustomerGUID = e.CustomerGUID
                                        AND [FixedEnCredit] > 0
                                 ORDER  BY [enDate] DESC,
                                           [ceNumber] DESC), 0),
             [LastPayDate] = ISNULL((SELECT TOP 1 [enDate]
                                     FROM   [#Result] AS [en]
                                            INNER JOIN [Er000] AS [er]
                                                    ON [en].[ceGuid] = [er].[EntryGuid]
                                            INNER JOIN [py000] AS [py]
                                                    ON [er].[ParentGuid] = [py].[Guid]
                                     WHERE  [enAccount] = [e].[GUID] AND CustomerGUID = e.CustomerGUID
                                            AND [FixedEnCredit] > 0
                                     ORDER  BY [enDate] DESC,
                                               [ceNumber] DESC), '1/1/1980')
      FROM   [#EndResult] AS [e]
	UPDATE [#EndResult]     
    SET    [BalDebit] = CASE
                          WHEN [TotalDebit] - [TotalCredit] < 0 THEN 0
                          ELSE [TotalDebit] - [TotalCredit]
                        END,
           [BalCredit] = CASE
                           WHEN [TotalDebit] - [TotalCredit] < 0 THEN [TotalCredit] - [TotalDebit]
                           ELSE 0
                         END,
           [PrevBalDebit] = CASE
                              WHEN [PrevDebit] - [PrevCredit] < 0 THEN 0
                              ELSE [PrevDebit] - [PrevCredit]
                            END,
           [PrevBalCredit] = CASE
                               WHEN [PrevDebit] - [PrevCredit] < 0 THEN [PrevCredit] - [PrevDebit]
                               ELSE 0
                             END,
           [haveBalance] = CASE
                             WHEN Abs(( [TotalDebit] + [PrevDebit] ) - ( [TotalCredit] + [PrevCredit] )) < @ZeroValue
                                  AND ( [TotalDebit] + [PrevDebit] ) + ( [TotalCredit] + [PrevCredit] ) > @ZeroValue THEN 0
                             WHEN Abs(( [TotalDebit] + [PrevDebit] ) - ( [TotalCredit] + [PrevCredit] )) > @ZeroValue
                                  AND ( [TotalDebit] + [PrevDebit] ) + ( [TotalCredit] + [PrevCredit] ) > @ZeroValue THEN 1
                             ELSE NULL
                           END
	-- 3rd. step: update parents balances:  
	--fill parentguid from ci000 for composite accounts
	IF @ShowComposeAcc = 1
	BEGIN
	UPDATE r
          SET    [r].[ParentGUID] = [ci].[parentGUID]
          FROM   #EndResult [r]
                 INNER JOIN ci000 [ci]
                         ON [ci].[songuid] = [r].[guid]
          WHERE  [r].[Guid] IN (SELECT SonGUID
                                FROM   ci000)
		AND [NSONS] > 0
	--update level for composite children
	UPDATE r
          SET    [Level] = [Level] + 1
          FROM   #EndResult [r]
                 INNER JOIN ci000 [ci]
                         ON [ci].[songuid] = [r].[guid]
          WHERE  [r].[Guid] IN (SELECT SonGUID
                                FROM   ci000)
		AND [NSONS] = 0 
		AND [Type] <> 4
      END
	
    IF @ShowComposeAcc = 1
       AND @ShowMainAcc = 1
	BEGIN
	--insert parent
	UPDATE r
          SET    [ParentGUID] = [ac].[parentGUID]
          FROM   [#EndResult] [r]
                 INNER JOIN ac000 [ac]
                         ON [ac].[guid] = [r].[guid]
          WHERE  r.[Guid] IN (SELECT [SonGUID]
                              FROM   ci000)
			AND r.[NSons] = 0

        INSERT INTO #EndResult (
			[guid],
			[Code],
			[Name],
			[LatinName],
			[ParentGUID],
			[Type],
			[NSons],
			[Level],
			[Path],
			[acSecurity])
		SELECT DISTINCT 
			[ac].[GUID],
			[ac].[Code],
			[ac].[Name],
			[ac].[LatinName],
			(SELECT TOP 1 parentguid
			FROM   ci000
			WHERE  [SonGUID] = e.[Guid]),
			[ac].[Type],
			[ac].[NSons],
			[e].[LEVEL] - 1,
			Substring(e.[Path], 1, Len(e.[Path]) - 1),
			[Security] 
          FROM   ac000 ac
                 INNER JOIN #Endresult e
                         ON e.parentguid = ac.[guid]
          WHERE  e.[Guid] IN (SELECT [SonGUID]
                              FROM   ci000)
				AND e.[NSons] = 0
                 AND NOT EXISTS(SELECT *
                                FROM   #EndResult
                                WHERE  [guid] = e.ParentGUID)
	END	  
	IF @Admin = 0  
	BEGIN  
          DELETE [#EndResult]
          WHERE  [acSecurity] > [dbo].[fnGetUserAccountSec_Browse](@UserGuid)
		SET @Level = @@RowCount  
          IF EXISTS(SELECT *
                    FROM   [#SecViol]
                    WHERE  [Type] = 5)
            INSERT INTO [#SecViol]
            VALUES     (@Level,
                        5)
          IF @ShowMainAcc = 1
              OR @ShowComposeAcc = 1
		BEGIN  
			WHILE @Level > 0  
			BEGIN  
				UPDATE [r] 
                      SET    [Level] = [r].[Level] - 1,
					[ParentGUID] = [ac].[ParentGUID]  
                      FROM   [#EndResult] AS [r]
                             INNER JOIN [ac000] AS [ac]
                                     ON [r].[ParentGUID] = [ac].[Guid]
                             LEFT JOIN [#EndResult] AS [r1]
                                    ON [r1].[GUID] = [ac].[Guid]
                      WHERE  ISNULL([r].[ParentGUID], 0X00) <> @AccPtr
                             AND [r].[GUID] <> @AccPtr
                             AND [r].[Level] <> ( ISNULL([r1].[Level], -2) + 1 )
				
				SET @Level = @@RowCount  
			END  
		END  
	END  
	 
    INSERT INTO @Totals
                ([TotalPrevDebit],
                 [TotalPrevCredit],
                 [TotalDebitTotal],
                 [TotalCreditTotal],
                 [TotalDebitBalance],
                 [TotalCreditBalance],
                 [TotalPrevBalDebit],
                 [TotalPrevBalCredit])
    SELECT Sum([PrevDebit]),
           Sum([PrevCredit]),
           Sum([TotalDebit]),
           Sum([TotalCredit]),
           Sum([BalDebit]),
           Sum([BalCredit]),
           Sum([PrevBalDebit]),
           Sum([PrevBalCredit])
    FROM   [#EndResult]
    WHERE  [NSons] = 0
           AND ( ( @ShowBalancedAcc = 1 )
                  OR ( [haveBalance] > 0 ) )
	AND [Type] <> 4

	IF (@ShowComposeAcc = 1 AND @ShowMainAcc = 0)
	BEGIN
		UPDATE e    
		SET e.[ParentGUID] = ci.[ParentGUID] 
		FROM [#EndResult] e
		INNER JOIN [ci000] ci ON ci.[SonGUID] = e.[GUID] AND ci.[ParentGUID] = @AccPtr
		
		update [#EndResult] set ParentGUID = [GUID] where ParentGUID = 0x0 AND [Type] = 4
	END
			
    IF @ShowMainAcc > 0
        OR @ShowComposeAcc = 1
	BEGIN  
          SET @Level = (SELECT Max([Level])
                        FROM   [#EndResult])
		WHILE @Level >= 0   
		BEGIN  
                UPDATE [#EndResult]
                SET    [PrevDebit] = ISNULL([SumPrevDebit], 0),
                       [PrevCredit] = ISNULL([SumPrevCredit], 0),
                       [TotalDebit] = ISNULL([SumTotalDebit], 0),
                       [TotalCredit] = ISNULL([SumTotalCredit], 0),
                       [BalDebit] = ISNULL([SumBalDebit], 0),
                       [BalCredit] = ISNULL([SumBalCredit], 0),
                       [PrevBalDebit] = ISNULL([SumPrevBalDebit], 0),
                       [PrevBalCredit] = ISNULL([SumPrevBalCredit], 0),
                       [haveBalance] = [sumHaveBalance]
                FROM   [#EndResult] AS [Father]
                       INNER JOIN (SELECT [ParentGUID],
                                          Sum([PrevDebit])     AS [SumPrevDebit],
                                          Sum([PrevCredit])    AS [SumPrevCredit],
                                          Sum([TotalDebit])    AS [SumTotalDebit],
                                          Sum([TotalCredit])   AS [SumTotalCredit],
                                          Sum([BalDebit])      AS [SumBalDebit],
                                          Sum([BalCredit])     AS [SumBalCredit],
                                          Sum([PrevBalDebit])  AS [SumPrevBalDebit],
                                          Sum([PrevBalCredit]) AS [SumPrevBalCredit],
                                          Sum([haveBalance])   AS [sumHaveBalance]
                                   FROM   [#EndResult]
                                   WHERE  [Level] = @Level
                                          AND [haveBalance] IS NOT NULL
                                   GROUP  BY [ParentGUID]) AS [Sons] -- sum sons  
					ON [Father].[GUID] = [Sons].[ParentGUID]  
			SET @Level = @Level - 1  
		END  
	END 
	--   
	IF @ShowEmptyAcc = 0 --dont view acc that bal is 0 And it has'nt move  
      DELETE FROM [#EndResult]
      WHERE  [haveBalance] IS NULL
             AND [Type] <> 4
	  
    IF @ShowBalancedAcc = 0 --AND @ShowEmptyAcc = 0  
      DELETE FROM [#EndResult]
      WHERE  [haveBalance] = 0
	  
    IF @AccType = 4
       AND @ShowBranchAcc = 0
      DELETE [#EndResult]
      FROM   [#EndResult] AS [r]
             INNER JOIN [ci000] AS [c]
                     ON [r].[GUID] = [c].[SonGUID]
      WHERE  [r].[Nsons] = 0
             AND [c].[ParentGUID] = @AccPtr
             AND ISNULL([c].[SonGUID], 0x0) = 0x0
	ELSE IF @ShowBranchAcc = 0  
      DELETE FROM [#EndResult]
      WHERE  [Nsons] = 0
	-- get Min Level if Min > 1 then Update levels to level - 1  
    SET @MinLevel = ISNULL((SELECT Min([Level])
                            FROM   [#EndResult]), 0)
	IF @MinLevel > 1  
      UPDATE [#EndResult]
      SET    [Level] = [Level] - 1
	-- maxLevel  
    SET @MaxLevel = @MaxLevel + ISNULL((SELECT DISTINCT [Level] FROM [#EndResult] WHERE [GUID] = @AccPtr), 0)
    IF @NotShowCustAcc = 1
       AND @ShowMainAcc = 0
      UPDATE [er]
      SET    [NSons] = 0
      FROM   [#EndResult] AS [er]
             INNER JOIN [ac000] AS [ac]
                     ON [ac].[ParentGuid] = [er].[GUID]
             INNER JOIN [cu000] AS [cu]
                     ON [CU].[AccountGuid] = [AC].[Guid]
   
    IF EXISTS(SELECT [GUID], [CustomerGUID]
              FROM   [#EndResult]
              GROUP  BY [GUID], [CustomerGUID]
              HAVING Count(*) > 1)
	BEGIN  
          DELETE e
          FROM   [#EndResult] e
                 INNER JOIN (SELECT [GUID],
									[CustomerGUID],
                                    classptr,
                                    Min(ID) ID
                             FROM   [#EndResult]
                             GROUP  BY	[GUID],
										[CustomerGUID],
										classptr
                             HAVING Count(*) > 1) v
                         ON v.[GUID] = e.[GUID]
          WHERE  v.[ID] <> e.[ID]
	END  
    IF NOT EXISTS(SELECT *
                  FROM   [#EndResult]
                  WHERE  [Level] = 0)
	BEGIN
		DECLARE @miniLevel INT
          SET @miniLevel = (SELECT Min([Level])
                            FROM   [#EndResult])
		
		WHILE @miniLevel > 0  
		BEGIN  
                UPDATE [#EndResult]
                SET    [LEVEL] = [LEVEL] - 1
			SET @miniLevel = @miniLevel - 1
		END
		
          UPDATE [#EndResult]
          SET    [ParentGUID] = 0x0
          WHERE  [LEVEL] = 0
	END
    IF @ShowMainAcc = 1
       AND @ShowBranchAcc = 0
	BEGIN
          DELETE FROM [#EndResult]
          WHERE  [Level] > 0
	END
	--update parent to grandparent
    IF @ShowComposeAcc = 1
       AND @ShowMainAcc = 0
	BEGIN
	UPDATE r
          SET    [r].[ParentGUID] = [ci].[parentGUID]
          FROM   #EndResult [r]
                 INNER JOIN ci000 [ci]
                         ON [ci].[songuid] = [r].[ParentGuid]
                 INNER JOIN ac000 [ac]
                         ON [ac].[guid] = [ci].[SonGUID]
          WHERE  [r].[ParentGuid] IN (SELECT SonGUID
                                      FROM   ci000)
                 AND [ac].[Type] <> 4
                 AND [ac].[NSONS] <> 0
	END 
	--UPDATE e
	--SET ClassPtr = ''
	--FROM 
	--	 #Endresult e 
	--	 INNER JOIN  en000 en ON en.[AccountGUID] = e.[GUID]  
	--	 INNER JOIN er000 er ON er.[entryguid] = en.[parentguid] AND parentType= 5 
	-- 5th. step: return main result set:  
	update [#EndResult]
	set accGuid = NEWID()
	
	CREATE TABLE #MainResult
	(
		[acNumber]				[UNIQUEIDENTIFIER],						
		[accGuid]				[UNIQUEIDENTIFIER],							
		[AcCode]				[NVARCHAR](256) COLLATE ARABIC_CI_AI,		
		[AcName]				[NVARCHAR](256) COLLATE ARABIC_CI_AI,		
		[AcLatinName]			[NVARCHAR](256) COLLATE ARABIC_CI_AI,		
		[acParent]				[UNIQUEIDENTIFIER],							
		[acType]				[INT],										
		[acNSons]				[INT],										
		[Level]					[INT] DEFAULT 0,
		[enPrevDebit]			[FLOAT] DEFAULT 0,							
		[enPrevCredit]			[FLOAT] DEFAULT 0,							
		[enTotalDebit]			[FLOAT] DEFAULT 0,							
		[enTotalCredit]			[FLOAT] DEFAULT 0,							
		[enBalDebit]			[FLOAT] DEFAULT 0,							
		[enBalCredit]			[FLOAT] DEFAULT 0,							
		[enPrevBalDebit]		[FLOAT] DEFAULT 0,							
		[enPrevBalCredit]		[FLOAT] DEFAULT 0,							
		[enEndBalDebit]			[FLOAT] DEFAULT 0,							
		[enEndBalCredit]		[FLOAT] DEFAULT 0,					
		[Status]				[INT],
		[CuGuid]				[UNIQUEIDENTIFIER],							
		[LastDebit]				[FLOAT] DEFAULT 0,
		[LastDebitDate]			SMALLDATETIME DEFAULT '1/1/1980',
		[LastCredit]			[FLOAT] DEFAULT 0,
		[LastCreditDate]		SMALLDATETIME DEFAULT '1/1/1980',
		[LastPay]				[FLOAT] DEFAULT 0,
		[LastPayDate]			SMALLDATETIME DEFAULT '1/1/1980',
		[CurrAccBal]			[FLOAT] DEFAULT 0,
		[PrevCurrAccBal]		[FLOAT] DEFAULT 0,
		[CurCode]				[NVARCHAR](256) COLLATE ARABIC_CI_AI,
		[acCurrGuid]			[UNIQUEIDENTIFIER],
		[ClassPtr]				[NVARCHAR](256) COLLATE ARABIC_CI_AI DEFAULT '',
		[AccCustNumber]			[BIGINT],
		[Path]					[NVARCHAR](2000) COLLATE ARABIC_CI_AI,
		[CustomerGUID]			[UNIQUEIDENTIFIER],
		[CustomerName]			[NVARCHAR](256) COLLATE ARABIC_CI_AI,
		[CustomerLatinName]		[NVARCHAR](256) COLLATE ARABIC_CI_AI,
		[UnMatched]				[INT] 
	)
	update  e
	set e.ParentGUID = (SELECT accGuid FROM [#EndResult] WHERE GUID = e.[ParentGUID])
	from [#EndResult] e
	WHERE ParentGUID <> 0x0 

	;with cte as
	(
	 SELECT 
		[e].[GUID]									AS [acNumber],
		[e].[accGuid]								AS [accGuid],
        [e].[Code]									AS [AcCode],
        [e].[Name]									AS [AcName],
        [e].[LatinName]								AS [AcLatinName],
        ISNULL([e].[ParentGUID], 0x0)				AS [acParent],
        [e].[Type]									AS [acType],
        [e].[NSons]									AS [acNSons],
		[e].[Level],   
        [e].[PrevDebit]								AS [enPrevDebit],
        [e].[PrevCredit]							AS [enPrevCredit],
        [e].[TotalDebit]							AS [enTotalDebit],
        [e].[TotalCredit]							AS [enTotalCredit],
        [e].[BalDebit]								AS [enBalDebit],
        [e].[BalCredit]								AS [enBalCredit],
        [e].[PrevBalDebit]							AS [enPrevBalDebit],
        [e].[PrevBalCredit]							AS [enPrevBalCredit],
        ( [e].[PrevBalDebit] + [e].[BalDebit] )		AS [enEndBalDebit],
        ( [e].[PrevBalCredit] + [e].[BalCredit] )	AS [enEndBalCredit],
        [e].[Status],
        ISNULL ([Cu].[Guid], 0x00)					AS [CuGuid],
		[LastDebit],  
		[LastDebitDate],  
		[LastCredit],  
		[LastCreditDate],  
		[LastPay],  
        [LastPayDate],
        [CurrAccBal],
        [PrevCurrAccBal],
        [CurCode],
        [acCurrGuid],
		[ClassPtr],
		ROW_NUMBER() OVER (PARTITION BY [e].[accGuid] order by [e].[Code]) AS  AccCustNumber,
		[e].[Path]  AS [Path],
		ISNULL(c.GUID, 0x0) AS CustomerGUID,
		ISNULL(c.CustomerName, '') AS CustomerName,
		ISNULL(c.LatinName, '') AS CustomerLatinName,
		e.UnMatched
    FROM   [#EndResult] AS [e]
           LEFT JOIN [CU000] AS [CU]
                  ON [CU].[AccountGuid] = [e].[Guid]
           LEFT JOIN [CU000] AS [C]
                  ON [C].[GUID] = [e].[CustomerGUID]
    WHERE  ( ( [Level] < @MaxLevel
               AND @ShowMainAcc = 1 )
              OR @MaxLevel = 0
              OR @ShowMainAcc = 0 ) -- تتم معالجة المستوى فقط بحالة ظهور الحسابات الرئيسية   
           AND ( @ShowMainAcc = 1
                  OR [NSons] = 0 )
           AND ( @NotShowCustAcc = 0
                  OR ISNULL ([Cu].[Guid], 0x00) = 0X00 )
		  
	)
	
	INSERT INTO #MainResult
	SELECT  * FROM cte
	WHERE
		AccCustNumber =  1 
	ORDER  BY 
		[Path], [AcCode],[CustomerName]

	-- 6th. step: return summury result set:  
	
    IF @bUnmatched = 1
	BEGIN
		CREATE TABLE #UnMatchedAcc(
				[AccountGuid] [UNIQUEIDENTIFIER],
			    [CustomerGUID] [UNIQUEIDENTIFIER],
				[FixedBal]		[FLOAT]
								   ) 
		CREATE TABLE #Curr(
			    [DATE] [SMALLDATETIME],
				[VAL] [FLOAT],
				PRIMARY KEY CLUSTERED(Date,VAL)
							)
		INSERT INTO #Curr 
			SELECT DISTINCT [DATE],CurrencyVal FROM 
			(
				SELECT 
						[DATE],
						CurrencyVal 
				FROM mh000 
				WHERE CURRENCYGuid = @CurGUID
				
				UNION ALL 
				
				SELECT  
						'1/1/1980',
						CurrencyVal 
				FROM MY000 
				WHERE Guid = @CurGUID
		   ) a ORDER BY DATE DESC

		INSERT INTO #UnMatchedAcc
			SELECT 
					r.AccountGuid, r.CustomerGUID, FixedBal 
		FROM (SELECT AccountGuid, CASE WHEN @DetailByCustomer = 0 THEN 0x0 ELSE CustomerGUID END CustomerGUID, SUM(en.FixedBal) FixedBal 
					FROM (SELECT ParentGuid, AccountGuid, CASE WHEN @DetailByCustomer = 0 THEN 0x0 ELSE CustomerGUID END CustomerGUID, 
								(Debit-CreDit)/ CASE WHEN [CurrencyGUID] = @CurGUID THEN [CurrencyVal] 
												ELSE dbo.fnGetCurVal(@CurGUID, en1.date)
												END FixedBal 
							FROM en000 en1-- INNER JOIN	
							WHERE ([en1].[Date] BETWEEN (@StartDate) AND (@EndDate)
								   OR [en1].[Date] BETWEEN (@PrevStartDate) AND (@PrevEndDate))
						) en
					INNER MERGE JOIN ce000 ce ON ce.Guid = EN.ParentGuid 
					--WHERE ce.ISPosted > 0   
					Group by AccountGuid, CustomerGUID
				) r

			--INNER JOIN (SELECT SUM(([TotalDebit] + [PrevDebit]) - ([TotalCredit] + [PrevCredit])) BAL, Guid, CustomerGUID
			--			FROM #endResult 
			--			GROUP BY GUID,
			--					 CustomerGUID
			--		   ) rr ON rr.Guid = r.AccountGuid AND rr.CustomerGUID = CASE WHEN (@DetailOnlyAccCustomers > 0 OR @DetailByCustomer > 0) THEN r.CustomerGUID ELSE rr.CustomerGUID END
			--WHERE ABS(FixedBal- BAL) < @ZeroValue
		
	;with cte AS
		(
			select mr.acNumber, mr.CustomerGUID, sum(mr.enEndBalDebit - mr.enEndBalCredit) AS total
			from #MainResult mr
			group by mr.acNumber, mr.CustomerGUID
		)

		UPDATE MR 
			SET MR.UnMatched = 1
			FROM #MainResult MR 
			inner join cte on cte.acNumber = mr.acNumber and cte.CustomerGUID = mr.CustomerGUID
			INNER JOIN ac000 ac ON MR.acNumber = ac.GUID 
			LEFT JOIN vwCuDetails cudetail ON cudetail.GUID = mr.CustomerGUID AND MR.acNumber = ac.GUID 
			WHERE ((ISNULL(cudetail.GUID, 0x0) = 0x0 OR (@DetailByCustomer = 0 AND  @DetailOnlyAccCustomers = 0 )) AND (CAST((ac.Debit-ac.Credit)/ (SELECT CurrencyVal  FROM my000 WHERE GUID = @CurGUID) AS MONEY) <> CAST((cte.total) AS MONEY))
				OR (ISNULL(cudetail.GUID, 0x0) <> 0x0 AND (@DetailByCustomer = 1 OR @DetailOnlyAccCustomers = 1) AND (CAST(ISNULL((cudetail.Debit - cudetail.Credit),0) / (SELECT CurrencyVal  FROM my000 WHERE GUID = @CurGUID) AS MONEY) <> CAST((cte.total) AS MONEY))) AND (CAST(ISNULL((cudetail.Debit - cudetail.Credit),0) / (SELECT CurrencyVal  FROM my000 WHERE GUID = @CurGUID) AS MONEY) <> CAST((cte.total) AS MONEY)))
	END

	SELECT * FROM #MainResult ORDER BY [Path], [AcCode],[CustomerName]
	SELECT * FROM   @Totals
    SELECT * FROM   [#SecViol]
	
####################################################################################
#END