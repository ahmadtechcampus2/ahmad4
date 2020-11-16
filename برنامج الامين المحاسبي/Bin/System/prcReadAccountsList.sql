####################################
CREATE PROCEDURE prcReadAccountsList
	@ProcessCostPoint	INT = 1,
	@ProcessBranch 		INT = 1,
	@ProcessMaturity	BIT = 1,
	@SourceGUID	UNIQUEIDENTIFIER = NULL
AS

	SET NOCOUNT ON;
	DECLARE @ZeroVal [FLOAT]
	SET @ZeroVal = dbo.fnGetZeroValuePrice() 
	CREATE TABLE [#Detailed]
	(
		[enAccount]			[UNIQUEIDENTIFIER],
		[enCostPoint]		[UNIQUEIDENTIFIER],
		[ceBranch]			[UNIQUEIDENTIFIER],
		[acType]			[INT],
		[acNSons]			[INT],	
		[acFinal]			[UNIQUEIDENTIFIER],
		[acWarn]			[FLOAT],
		[acCode]			[NVARCHAR](256) COLLATE ARABIC_CI_AI,
		[acName]			[NVARCHAR](256) COLLATE ARABIC_CI_AI,
		[acCurrencyPtr]		[UNIQUEIDENTIFIER],
		
	-------------- added by Amira 
		[acCurVal]			[FLOAT],
	------------------------
		[SumDebit]			[FLOAT],
		[SumCredit]			[FLOAT],
		[SumDebitInEnCurr]	[FLOAT],
		[SumCreditInEnCurr]	[FLOAT],
		[enCustGuid]		[UNIQUEIDENTIFIER]
	)

	CREATE TABLE [#ResultTbl]
	(
		[enAccount]				[UNIQUEIDENTIFIER],
		[enCostPoint]			[UNIQUEIDENTIFIER],
		[ceBranch]				[UNIQUEIDENTIFIER],
		[acType]				[INT],
		[acNSons]				[INT],
		[acFinal]				[UNIQUEIDENTIFIER],
		[acWarn]				[FLOAT],
		[acCode]				[NVARCHAR](256) COLLATE ARABIC_CI_AI,
		[acName]				[NVARCHAR](256) COLLATE ARABIC_CI_AI,
		[acCurrencyPtr]			[UNIQUEIDENTIFIER],
		[acCurVal]				[FLOAT],
		[SumDebit]				[FLOAT],
		[SumCredit]				[FLOAT],
		[SumDebitInEnCurr]		[FLOAT],
		[SumCreditInEnCurr]		[FLOAT],
		[NeedsExchangevariation] 	[INT] DEFAULT  0,
		[enCustGuid]			[UNIQUEIDENTIFIER]
	)

	CREATE TABLE [#BTBill]( [Type] [UNIQUEIDENTIFIER], [Sec] [INT], [ReadPrice] [INT])   
	INSERT INTO [#BTBill] EXEC [prcGetBillsTypesList] @SourceGUID 

	DECLARE @DefCur [UNIQUEIDENTIFIER]
	SET @DefCur = (SELECT Top 1 [myGUID] FROM [vwmy] WHERE [myNumber] = 1)
	SELECT [bu].[date] AS [endate],CASE @ProcessCostPoint WHEN 0 THEN 0x0 ELSE ISNULL( [bu].[CostGuid], 0x0) END AS [enCostPoint] , 
		CASE @ProcessBranch WHEN 0 THEN 0x0 ELSE ISNULL( [bu].[Branch], 0x0) END AS [ceBranch], 
		[pt].[CustAcc],
		SUM(CASE WHEN pt.Credit > 0 THEN pt.Credit - ( ISNULL(bp.Value,0) + ISNULL(bp2.Value,0) ) ELSE 0 END) AS [enDebit],
		SUM( CASE WHEN pt.Debit > 0 THEN pt.Debit - ( ISNULL(bp.Value,0) + ISNULL(bp2.Value,0) ) ELSE 0 END) AS [enCredit],					
		[bu].[CurrencyGuid],
		[bu].[CurrencyVal],
		ISNULL([cu].[GUID], 0x0) AS [CustomerGUID]
		INTO #PT
		FROM pt000 pt 		
		LEFT JOIN [bu000] [bu] ON [bu].[Guid] = pt.RefGuid
		INNER JOIN [#BTBill]    ON [bu].[TypeGuid] = [#BTBill].[Type]
		LEFT  JOIN [cu000] [cu] ON [cu].[GUID] = bu.CustGUID 
		LEFT JOIN (SELECT DebtGuid,sum(Val) AS Value FROM bp000 GROUP BY DebtGuid) bp ON bp.DebtGuid = [bu].[Guid]
		LEFT JOIN (SELECT PayGuid,sum(Val) AS Value FROM bp000 GROUP BY PayGuid) bp2 ON bp2.PayGuid = [bu].[Guid]
		WHERE
			@ProcessMaturity = 1 
			AND ISNULL(bu.PayType, 1) <> 0
			AND
			( CASE WHEN pt.Debit > 0 THEN pt.Debit -( ISNULL(bp.Value,0) + ISNULL(bp2.Value,0) ) ELSE 0 END > 0 OR
			 CASE WHEN pt.Credit > 0 THEN pt.Credit - ( ISNULL(bp.Value,0) + ISNULL(bp2.Value,0) ) ELSE 0 END > 0)
	GROUP BY
		[bu].[date] ,CASE @ProcessCostPoint WHEN 0 THEN 0x0 ELSE ISNULL( [bu].[CostGuid], 0x0) END  , 
		CASE @ProcessBranch WHEN 0 THEN 0x0 ELSE ISNULL( [bu].[Branch], 0x0) END , 
		[pt].[CustAcc],
		[bu].[CurrencyGuid],
		[bu].[CurrencyVal],
		ISNULL([cu].[GUID], 0x0)

	SELECT [enDate],
	CASE @ProcessCostPoint WHEN 0 THEN 0x0 ELSE ISNULL( [en].[enCostPoint], 0x0) END as [enCostPoint] , 
	CASE @ProcessBranch WHEN 0 THEN 0x0 ELSE ISNULL( [en].[ceBranch], 0x0) END as [ceBranch], 
	[enAccount],
	SUM([en].[enDebit]) AS [enDebit],
	SUM([en].[enCredit]) AS [enCredit],
	[en].[enCurrencyPtr],
	[enCurrencyVal],
	ISNULL([cu].[GUID], 0x0) AS [enCustomerGUID]
	INTO [#CE]
	FROM [vwceen] [en]
		 LEFT JOIN [cu000] [cu] ON [cu].[GUID] = [en].[enCustomerGUID] AND [cu].[AccountGUID] = [en].[enAccount]
	WHERE  [en].[ceIsPosted] > 0  
	--AND [ceGuid] NOT IN (SELECT [EntryGuid] FROM [ER000] AS [er] INNER JOIN [CH000] AS [ch] ON [er].[ParentGuid] = [ch].[Guid] WHERE [ch].[State] = 0)
	--AND [enGuid] NOT IN (SELECT [enGuid] FROM [#PT])
	GROUP BY 
	[enDate], 
	CASE @ProcessCostPoint WHEN 0 THEN 0x0 ELSE ISNULL( [en].[enCostPoint], 0x0) END  , 
	CASE @ProcessBranch WHEN 0 THEN 0x0 ELSE ISNULL( [en].[ceBranch], 0x0) END , 
	[enAccount],
	[en].[enCurrencyPtr],
	[enCurrencyVal],
	ISNULL([cu].[GUID], 0x0)
	IF @ProcessMaturity = 1 
		INSERT INTO #CE SELECT * FROM #PT
	
	INSERT INTO [#Detailed] 
	SELECT 
		[ac].[acGUID],  
		ISNULL( [en].[enCostPoint],0x00)  , 
		ISNULL( [en].[ceBranch], 0x0)  , 
		[ac].[acType], 
		[ac].[acNSons], 
		[ac].[acFinal], 
		[ac].[acWarn], 
		[ac].[acCode], 
		[ac].[acName], 
		ISNULL( [ac].[acCurrencyPtr], @DefCur),-- AS acCurrencyPtr, 
		[ac].[acCurrencyVal], 
		ISNULL([en].[enDebit], 0),-- 	AS SumDebit, 
		ISNULL([en].[enCredit], 0),-- AS SumCredit, 
		ISNULL([dbo].[fnCurrency_fix]([en].[enDebit], ISNULL( [en].[enCurrencyPtr], @DefCur), ISNULL([enCurrencyVal],1), [ac].[acCurrencyPtr], [enDate]) , 0),-- AS SumDebitInEnCurr, 
		ISNULL( [dbo].[fnCurrency_fix]( [en].[enCredit], ISNULL( [en].[enCurrencyPtr], @DefCur), ISNULL([enCurrencyVal],1), [ac].[acCurrencyPtr], [enDate]), 0),-- AS SumCreditInEnCurr  
		[en].[enCustomerGUID]
	FROM 
		[vwAc] As [ac] LEFT JOIN [#CE] AS [en] ON 
		[ac].[acGUID] = [en].[enAccount] 
	WHERE  
		[en].[enAccount]  IS NOT NULL OR [ac].[acType] = 2 
	--- select acCurrencyPtr, enCurrencyPtr, enCurrencyVal from vwExtended_en where enCurrencyVal = 1 and  enAccount = '88940DCA-C006-4358-9199-50C70F81FBB0'
	
	
	IF (@ProcessCostPoint = 1)
		UPDATE [#Detailed] SET [enCostPoint] = 0X0 WHERE [enCostPoint] NOT IN (SELECT [Guid] FROM [co000])
	INSERT INTO [#ResultTbl]
	(
		[enAccount],
		[enCostPoint],
		[ceBranch],
		[acType],
		[acNSons],
		[acFinal],
		[acWarn],
		[acCode],
		[acName],
		[acCurrencyPtr],
		[acCurVal],
		[SumDebit],
		[SumCredit],
		[SumDebitInEnCurr],
		[SumCreditInEnCurr],
		[enCustGuid]
	)
	SELECT
		[enAccount],
		[enCostPoint],
		[ceBranch],
		[acType],
		[acNSons],
		[acFinal],
		[acWarn],
		[acCode],
		[acName],
		[acCurrencyPtr],
		[acCurVal],
		SUM( ISNULL( [SumDebit] , 0)) 	AS [SumDebit],
		SUM( ISNULL( [SumCredit], 0)) 	AS [SumCredit],
		SUM( ISNULL( [SumDebitInEnCurr], 0)) AS [SumDebitInEnCurr],
		SUM( ISNULL( [SumCreditInEnCurr], 0)) AS [SumCreditInEnCurr],
		[enCustGuid]
	FROM
		[#Detailed] AS [R]
	GROUP BY
		[enAccount],
		[enCustGuid],
		[enCostPoint],
		[ceBranch],
		[acType],
		[acNSons],
		[acFinal],
		[acWarn],
		[acCode],
		[acName],
		[acCurrencyPtr],
		[acCurVal]
	--HAVING ABS(SUM([SumDebit] - [SumCredit])) > @ZeroVal OR ABS(SUM([SumDebitInEnCurr] - [SumCreditInEnCurr])) > @ZeroVal
	UPDATE [#ResultTbl]  SET [acCurVal] = ABS([SumDebit] -[SumCredit]) / ABS([SumDebitInEnCurr]- [SumCreditInEnCurr])
			WHERE ABS([SumDebitInEnCurr]- [SumCreditInEnCurr]) < dbo.fnGetZeroValuePrice() AND ABS([SumDebitInEnCurr]- [SumCreditInEnCurr]) >@ZeroVal	

	DELETE [#ResultTbl] FROM [#ResultTbl] AS [r2] WHERE [enAccount] IN (SELECT [enAccount] FROM [#ResultTbl] AS [r] WHERE [r].[acType] <> 2 GROUP BY [r].[enAccount],[r].[CeBranch] HAVING ABS(SUM([r].[SumDebit]) - SUM ([r].[SumCredit])) < dbo.fnGetZeroValuePrice() AND ABS(SUM([SumDebitInEnCurr])- SUM([SumCreditInEnCurr])) < dbo.fnGetZeroValuePrice() and [r].[CeBranch] = [r2].[CeBranch])  
		
	SELECT 
		[enAccount],
		[enCostPoint],
		[ceBranch],
		[acType],
		[acNSons],
		[acFinal],
		[acWarn],
		[acCode],
		[acName],
		[acCurrencyPtr],
		[acCurVal] AS [AcCurrencyVal],
		[SumDebit],
		[SumCredit],
		[SumDebitInEnCurr],
		[SumCreditInEnCurr],
		[NeedsExchangevariation],
		[enCustGuid]
	FROM
		[#ResultTbl]

	ORDER BY
		[ceBranch] 
		
/*
prcConnections_add2 'ãÏíÑ'
exec prcReadAccountsList
drop database amndb00
*/
####################################
CREATE PROCEDURE prcGnerateMaturityBillEntris
	@ProfitAcc UNIQUEIDENTIFIER,
	@DistDb	NVARCHAR(250),
	@Date	DATETIME,
    @SourceGUID  UNIQUEIDENTIFIER
AS
    CREATE TABLE [#BTBill]( [Type] [UNIQUEIDENTIFIER], [Sec] [INT], [ReadPrice] [INT])   
	INSERT INTO [#BTBill] EXEC [prcGetBillsTypesList] @SourceGUID 
	SET NOCOUNT ON
		SET @DistDb = '[' + @DistDb + ']';
	DECLARE @Branch UNIQUEIDENTIFIER,@Sql NVARCHAR(max),@Number INT
	CREATE TABLE #EN
	(
		[Id] INT IDENTITY(1,1),
		[Guid] UNIQUEIDENTIFIER
	)
	CREATE TABLE #EN2
	(
		[Num] INT ,
		[Guid] UNIQUEIDENTIFIER
	)
	SET @Sql = 'INSERT INTO #EN2 SELECT MAX(Number) ,Branch FROM ' + @DistDb + '..ce000 GROUP BY Branch'
	EXEC(@Sql)
	CREATE TABLE #BT
	(
		[id]				INT IDENTITY(1,1),
		[Guid]				UNIQUEIDENTIFIER,
		RefGuid				UNIQUEIDENTIFIER,
		[DueDate]			DATETIME,
		Debit				FLOAT,
		CreDit				FLOAT,
		[CurrencyGuid]		UNIQUEIDENTIFIER,
		[CurrencyVal]		FLOAT,
		[CostGuid]			UNIQUEIDENTIFIER,
		[CustGuid]			UNIQUEIDENTIFIER,
		CustAcc				UNIQUEIDENTIFIER,	
		[Note]				NVARCHAR(255) COLLATE ARABIC_CI_AI, 
		[Branch]			UNIQUEIDENTIFIER, 
		[Number]			INT,
		[TypeGuid]			UNIQUEIDENTIFIER,
		[buDate]			DATETIME, 
		[TransferedInfo]	NVARCHAR(2048) DEFAULT ''
	)
	INSERT INTO #BT
	(
		[Guid],			
		RefGuid	,		
		[DueDate],		
		Debit,			
		CreDit,			
		[CurrencyGuid]	,
		[CurrencyVal],	
		[CostGuid],	
		[CustGuid],	
		CustAcc,			
		[Note],			
		[Branch],		
		[Number],		
		[TypeGuid],		
		[buDate],
		[TransferedInfo]
	)		
		
	SELECT pt.Guid,pt.RefGuid,[DueDate]
		,SUM(CASE WHEN pt.Debit > 0 THEN pt.Debit - (ISNULL(bp.[Value],0) + ISNULL(bp2.[Value],0)) ELSE 0 END) AS Debit
		,SUM(CASE WHEN pt.Credit > 0 THEN pt.Credit - (ISNULL(bp.[Value],0) + ISNULL(bp2.[Value],0)) ELSE 0 END) AS CreDit
		,pt.[CurrencyGuid],pt.[CurrencyVal],bu.CostGUID , bu.CustGUID
		,CustAcc,bt.Name  + ':' + CAST ( bu.Number AS NVARCHAR(100)) + ':' + 
		CAST( DATEPART(dd,[bu].[Date]) AS NVARCHAR(2)) + '/' +
		 CAST( DATEPART(mm,[bu].[Date]) AS NVARCHAR(2)) + '/' + 
		 CAST( DATEPART(yyyy,[bu].[Date]) AS NVARCHAR(4)) AS [Note],
		 [bu].[Branch],0 [Number],bt.Guid AS [TypeGuid],[bu].[Date] AS [buDate] , 
		 CAST( ( SELECT (
			SELECT  [Number]  , CASE WHEN [Credit] > 0 THEN [Credit] ELSE [Debit] END  AS [Total] , 
			[bu].[Date] AS [Date]
			FOR XML PATH('') , TYPE )
		 ) AS NVARCHAR(MAX) )
		FROM pt000 pt 
		INNER JOIN [bu000] [bu] ON [bu].[Guid] = pt.RefGuid
		INNER JOIN [bt000] [bt] ON [bt].[Guid] = [bu].[TypeGuid]
		INNER JOIN [#BTBill]    ON [bu].[TypeGuid] = [#BTBill].[Type]
		LEFT JOIN (SELECT DebtGuid,sum(Val) AS Value FROM bp000 GROUP BY DebtGuid) bp ON bp.DebtGuid = bu.GUID
		LEFT JOIN (SELECT PayGUID,sum(Val) AS Value FROM bp000 GROUP BY PayGUID) bp2 ON bp2.PayGUID = bu.GUID
		WHERE
			bu.PayType <> 0
			AND [bu].[Isposted] > 0 
			AND			
				( CASE WHEN pt.Debit > 0 THEN CAST((pt.Debit - (ISNULL(bp.[Value],0) + ISNULL(bp2.[Value],0))) AS MONEY) ELSE 0 END > 0 OR
				CASE WHEN pt.Credit > 0 THEN CAST((pt.Credit - (ISNULL(bp.[Value],0) + ISNULL(bp2.[Value],0))) AS MONEY) ELSE 0 END > 0)		
		GROUP BY pt.Guid,pt.RefGuid,[DueDate],pt.[CurrencyGuid],pt.[CurrencyVal],bu.CostGUID,CustAcc,bt.Name , 
		bu.Number,[bu].[Date],bt.Guid ,[bu].[Branch],bu.CustGUID , pt.Credit , pt.Debit
				
	INSERT INTO #BT
	(
		[Guid],			
		RefGuid	,		
		[DueDate],		
		Debit,			
		CreDit,			
		[CurrencyGuid],	
		[CurrencyVal],	
		[CostGuid],	
		[CustGuid],	
		CustAcc	,		
		[Note],		
		[Branch],		
		[Number],		
		[TypeGuid],		
		[buDate],
		[TransferedInfo]
	)		
	SELECT pt.Guid,pt.RefGuid,[DueDate]
		,SUM(CASE WHEN pt.Debit > 0 THEN pt.Debit - (ISNULL(bp.[Value],0) + ISNULL(bp2.[Value],0)) ELSE 0 END) AS Debit
		,SUM(CASE WHEN pt.Credit > 0 THEN pt.Credit - (ISNULL(bp.[Value],0) + ISNULL(bp2.[Value],0)) ELSE 0 END) AS CreDit
		,pt.[CurrencyGuid],pt.[CurrencyVal],[en].[CostGuid],[en].[CustomerGUID]
		,CustAcc,ce.Notes [Note],[ce].[Branch],0 [Number],bt.Guid AS [TypeGuid],[pt].[OriginDate] AS [buDate],
		[pt].[TransferedInfo]
		FROM pt000 pt 
		INNER JOIN ER000 er ON er.ParentGuid = pt.RefGuid
		INNER JOIN [ce000] [ce] ON [ce].[Guid] = er.entryguid
		INNER JOIN [en000] [en] ON [en].[ParentGuid] = [ce].[Guid]
		INNER JOIN [bt000] [bt] ON [bt].[Guid] = [PT].[TypeGuid]
		LEFT JOIN (SELECT DebtGuid,sum(Val) AS Value FROM bp000 GROUP BY DebtGuid) bp ON bp.DebtGuid = [en].[Guid]
		LEFT JOIN (SELECT PayGUID,sum(Val) AS Value FROM bp000 GROUP BY PayGUID) bp2 ON bp2.PayGUID = [en].[Guid]
		WHERE
			[en].[accountGuid] = PT.[CustAcc] and refguid not in (select guid from bu000)
			AND
			( CASE WHEN pt.Debit > 0 THEN pt.Debit - (ISNULL(bp.[Value],0) + ISNULL(bp2.[Value],0)) ELSE 0 END > 0 OR
				CASE WHEN pt.Credit > 0 THEN pt.Credit - (ISNULL(bp.[Value],0) + ISNULL(bp2.[Value],0)) ELSE 0 END > 0)
			AND [ce].[Isposted] > 0 AND pt.Type = 3
		GROUP BY pt.Guid,pt.RefGuid,[DueDate],pt.[CurrencyGuid],pt.[CurrencyVal],[en].[CostGuid],CustAcc,bt.Name ,[pt].[OriginDate],bt.Guid ,[ce].[Branch],[ce].[Notes],[en].[CustomerGUID], [pt].[TransferedInfo]
		HAVING
			SUM(CASE WHEN pt.Debit > 0 THEN CAST((en.Debit - en.Credit) AS MONEY) - CAST((ISNULL(bp.[Value],0) + ISNULL(bp2.[Value],0)) AS MONEY) ELSE 0 END) > 0
			OR SUM(CASE WHEN pt.Credit > 0 THEN CAST((en.Credit - en.Debit) AS MONEY) - CAST((ISNULL(bp.[Value],0) + ISNULL(bp2.[Value],0)) AS MONEY) ELSE 0 END) > 0

	UPDATE #BT SET Debit = Debit - CreDit WHERE CreDit > 0 AND Debit > CreDit
	UPDATE #BT SET CreDit = CreDit -  Debit WHERE Debit > 0 AND CreDit > Debit
	SELECT RefGuid,MAX(Id) ID INTO #BT2 FROM #BT GROUP BY RefGuid HAVING COUNT(*) > 1
	DELETE A FROM #BT A INNER JOIN #BT B ON a.RefGuid = b.RefGuid WHERE a.id <> b.Id
	SET @Sql = 'DELETE ' + @DistDb + '..PT000 WHERE Type = 3'
	EXEC(@Sql)
	DECLARE @c_bi CURSOR
	DECLARE @g UNIQUEIDENTIFIER 
	SET @G = 0X00
	IF EXISTS(SELECT * FROM #BT WHERE [Branch] <> 0x00)
	BEGIN
		SET @c_bi = CURSOR FAST_FORWARD FOR 
			SELECT DISTINCT BRANCH FROM #bt
			OPEN @c_bi FETCH NEXT FROM @c_bi INTO @Branch
			WHILE @@FETCH_STATUS = 0 
			BEGIN 
				SELECT @Number = NUM FROM #EN2 WHERE [Guid] = @Branch
				IF @Number IS NULL
					SET @Number = 0
				INSERT INTO #EN([Guid]) SELECT RefGuid FROM #BT WHERE Branch = @Branch ORDER BY [DueDate]
				UPDATE bt SET [Number] = en.ID + @Number FROM #BT bt INNER JOIN #EN en ON bt.RefGuid = en.Guid
				SET @Sql = 'INSERT #EN2 SELECT MAX(NUMBER), ''' + CAST(@G AS NVARCHAR(36)) + '''  FROM ' + @DistDb +'..MC000 '
				EXEC(@Sql)
				SELECT @Number = NUM FROM #EN2 WHERE [Guid] = 0X00
				SET @Sql = 'INSERT INTO ' + @DistDb +'..MC000 (ASC2,TYPE,Item,Number) select cast(refguid as NVARCHAR(40)),36,number + 3,number + '+ CAST (@Number AS NVARCHAR(5))+'  from #bt WHERE Branch = ''' + CAST( @Branch AS NVARCHAR(40)) + ''''
				EXEC(@Sql)
				DELETE #EN2 WHERE [Guid] = 0X00
				TRUNCATE TABLE #EN
				FETCH NEXT FROM @c_bi INTO @Branch
			END
			CLOSE @c_bi
			DEALLOCATE @c_bi
	END
	ELSE
	BEGIN
		SELECT @Number = NUM FROM #EN2 WHERE [Guid] = 0X00
		IF @Number IS NULL
			SET @Number = 0
		INSERT INTO #EN([Guid]) SELECT RefGuid FROM #BT ORDER BY [DueDate]
		UPDATE bt SET [Number] = en.ID + @Number FROM #BT bt INNER JOIN #EN en ON bt.RefGuid = en.Guid
		SET @Sql = 'INSERT #EN2 SELECT MAX(NUMBER), ''' + CAST(@G AS NVARCHAR(36)) + '''  FROM ' + @DistDb +'..MC000 '
		EXEC(@Sql)
		SELECT @Number = NUM FROM #EN2 WHERE [Guid] = 0X00
		SET @Sql = 'INSERT INTO ' + @DistDb +'..MC000 (ASC2,TYPE,Item,Number) select cast(refguid as NVARCHAR(40)),36,3,number + '''+ CAST (@Number AS NVARCHAR(5))+''' from #bt  '
		EXEC(@Sql)
	END
	SET @Sql = 'INSERT INTO ' + @DistDb + '..MaturityBills000 SELECT * FROM MaturityBills000'
	EXEC(@Sql)
	SET @Sql = 'INSERT INTO ' + @DistDb +'..pt000(Guid,Type,RefGuid,CustAcc,Debit,CreDit,CurrencyGuid,CurrencyVal,DueDate,IsTransfered,[TypeGuid],[OriginDate],[TransferedInfo])
		SELECT Guid,3,RefGuid,CustAcc,Debit,CreDit,CurrencyGuid,CurrencyVal,DueDate,1,[TypeGuid],[buDate],[TransferedInfo] FROM #BT'
	EXEC(@Sql)
	SET @Sql = 'INSERT INTO ' + @DistDb +'..ce000 (Guid,Type,Number,Branch,CurrencyGuid,CurrencyVal,[Date],Notes,Security,[TypeGuid], [PostDate]) SELECT RefGuid,1,Number,Branch,CurrencyGuid,CurrencyVal,' + DBO.fnDateString(@Date) +' ,[Note],3,0x00, ' + DBO.fnDateString(@Date) + 'FROM [#bt]'
	EXEC(@Sql)
	SET @Sql = 'INSERT INTO ' + @DistDb +'..en000 ([AccountGuid],[Debit],[Credit],[ParentGuid],Number,CurrencyGuid,CurrencyVal,[Date],[CostGuid],[ContraAccGUID],notes,[CustomerGUID]) SELECT CustAcc,[Debit],[Credit],RefGuid,1,CurrencyGuid,CurrencyVal,' + DBO.fnDateString(@Date) +',[CostGuid],'''+ CAST (@ProfitAcc AS NVARCHAR(40))+ ''',[Note],CustGuid FROM [#bt] '
	EXEC(@Sql)	
	SET @Sql = 'INSERT INTO ' + @DistDb +'..en000 ([AccountGuid],[Debit],[ParentGuid],Number,CurrencyGuid,CurrencyVal,[Date],[ContraAccGUID],[CustomerGUID]) SELECT ''' + CAST (@ProfitAcc AS NVARCHAR(40))+ ''',[Credit],RefGuid,2,CurrencyGuid,CurrencyVal,' + DBO.fnDateString(@Date) +',CustAcc,0x0 FROM [#bt] WHERE [Credit] > 0'
	EXEC(@Sql)	
	SET @Sql = 'INSERT INTO ' + @DistDb +'..en000 ([AccountGuid],[Credit],[ParentGuid],Number,CurrencyGuid,CurrencyVal,[Date],[ContraAccGUID],[CustomerGUID]) SELECT ''' + CAST (@ProfitAcc AS NVARCHAR(40))+ ''',[Debit],RefGuid,2,CurrencyGuid,CurrencyVal,' + DBO.fnDateString(@Date) +',CustAcc,0x0 FROM [#bt] WHERE [Debit] > 0'
	EXEC(@Sql)
	SET @Sql = 'ALTER TABLE ' + @DistDb +'..ce000 DISABLE TRIGGER trg_ce000_post '
	EXEC(@Sql)
	SET @Sql = 'UPDATE ce SET [IsPosted] = 1 FROM ' + @DistDb +'..ce000 ce INNER JOIN  [#bt] bt ON bt.[RefGuid] = ce.Guid'
	EXEC(@Sql)
	SET @Sql = 'ALTER TABLE ' + @DistDb +'..ce000 ENABLE TRIGGER trg_ce000_post '
	EXEC(@Sql)
--exec [prcGnerateMaturityBillEntris] '0faeab33-48d9-47ba-977b-bb6729b9c1b9', 'Fifo_tset', '10/9/2007'
####################################
CREATE  PROCEDURE prcTransAccAge
	@EveryBranchHasBill [BIT], 
	@SrecDb NVARCHAR(100), 
    @ProcessCost bit = 0  
AS  
	SET NOCOUNT ON 

		SET @SrecDb = @SrecDb;


	DECLARE @Sql NVARCHAR(1000)  
	DECLARE @c CURSOR  
	DECLARE @Val2 FLOAT,@CurrVal FLOAT,@ID INT ,@DefVal FLOAT  
	DECLARE @Acc UNIQUEIDENTIFIER,@Branch UNIQUEIDENTIFIER,@Val [FLOAT],@CurrencyGuid UNIQUEIDENTIFIER,@CurrencyVal FLOAT,@Guid UNIQUEIDENTIFIER,@Date DATETIME, @CostGuid UNIQUEIDENTIFIER ,@Cu UNIQUEIDENTIFIER 
	CREATE TABLE #CE  
	(  
		   ID INT IDENTITY(1,1),  
		   [Guid] UNIQUEIDENTIFIER,  
		   [AccountGuid] UNIQUEIDENTIFIER,
		   [CustomerGuid] UNIQUEIDENTIFIER,   
		   Debit FLOAT,  
		   Credit FLOAT,  
		   [Branch] UNIQUEIDENTIFIER,  
		   [CurrencyGuid]         UNIQUEIDENTIFIER,  
		   [CurrencyVal] FLOAT,  
		   [Date] DATETIME , 
		   [CostGuid] UNIQUEIDENTIFIER 
	)  
	CREATE TABLE #ERR (EntryGuid UNIQUEIDENTIFIER) 
	EXEC ('INSERT INTO #ERR SELECT EntryGuid from ' + @SrecDb + '..er000 er INNER JOIN pt000 p ON p.refGuid = er.parentGuid where type = 3') 
	INSERT INTO #ce(Debit,Credit,[Guid],AccountGuid,CustomerGuid,[Branch],[CurrencyGuid],[CurrencyVal],[Date],[CostGuid])  
	SELECT en.Debit ,en.Credit ,[en].[Guid],en.AccountGuid,en.CustomerGuid,CASE @EveryBranchHasBill WHEN 0 THEN 0X00 ELSE a.Branch END,en.[CurrencyGuid],en.[CurrencyVal],en.[Date] ,case @processCost when 0 then 0x00 else CostGuid END 
	FROM en000 en INNER JOIN   
	(  
	SELECT ce.Guid,ce.IsPosted,ce.Number as ceNumber,Branch FROM ce000 ce INNER JOIN mc000 on  CAST(ce.Guid as NVARCHAR(40))=asc2  
	UNION ALL  
	SELECT ce.[Guid],ce.IsPosted,ce.Number as ceNumber,Branch   
	from ce000 ce   
	INNER JOIN er000 ER ON er.EntryGUID = ce.[guid]  
	INNER JOIN mc000 on  CAST(er.ParentGUID  as NVARCHAR(40))=asc2  
	) a  
	ON a.Guid = en.ParentGuid  
	WHERE a.Guid NOT IN (SELECT refGuid FROM PT000 WHERE TYPE = 3)  
	ORDER BY en.AccountGuid,CASE @EveryBranchHasBill WHEN 0 THEN 0X00 ELSE a.Branch END,[en].[Date],[ceNumber]  
	--GROUP BY [a].[Guid],en.AccountGuid 
	CREATE TABLE #oldce  
	(  
		   ID INT IDENTITY(1,1),  
		   [Acc]   UNIQUEIDENTIFIER,  
		   [Cu]   UNIQUEIDENTIFIER, 
		   [CurrencyGuid]         UNIQUEIDENTIFIER,  
		   [CurrencyVal] FLOAT,  
		   [debit]                    FLOAT,  
		   [Credit]                   FLOAT,  
		   [Date]                     DATETIME,  
		   [Branch] UNIQUEIDENTIFIER,  
		   [CostGuid] UNIQUEIDENTIFIER  
	)  
	DECLARE  @oldce TABLE 
	(  
		   ID INT ,  
		   [Acc]   UNIQUEIDENTIFIER, 
		   [Cu]   UNIQUEIDENTIFIER, 
		   [CurrencyGuid]         UNIQUEIDENTIFIER,  
		   [CurrencyVal] FLOAT,  
		   [debit]                    FLOAT,  
		   [Credit]                   FLOAT,  
		   [Date]                     DATETIME,  
		   [Branch] UNIQUEIDENTIFIER,  
		   [CostGuid] UNIQUEIDENTIFIER  
	)  
	CREATE TABLE #dates  
	(  
		   id INT IDENTITY(1,1),  
		   [Date] DATETIME  
	)  
	SET @Sql = 'INSERT INTO #oldce ([Acc],[Cu],[CurrencyGuid],[CurrencyVal],[debit],[Credit],[Date],[Branch],[CostGuid]) SELECT EN.[AccountGuid],EN.[CustomerGuid],[en].[CurrencyGuid],[en].[CurrencyVal],[en].[debit],[en].[Credit],[en].[Date]'  
	IF @EveryBranchHasBill = 1  
	  SET @Sql = @Sql + ',ce.Branch'  
	ELSE  
	  SET @Sql = @Sql + ',0X00'  
	        
	IF @ProcessCost = 1  
	  SET @Sql = @Sql + ', en.CostGuid'  
	ELSE  
	  SET @Sql = @Sql + ', 0X00'  
	        
	SET @Sql = @Sql + ' FROM '+ @SrecDb +'..[en000] en INNER JOIN '+ @SrecDb +'..ce000 ce ON ce.Guid = en.ParentGuid INNER JOIN #CE CC ON  en.[AccountGuid] = cc.[AccountGuid] AND ISNULL(en.[CustomerGuid],0x0) = ISNULL(cc.[CustomerGuid],0x0)'  
	SET @Sql = @Sql +  ' LEFT JOIN #ERR err ON err.EntryGuid = ce.Guid ' 
	SET @Sql = @Sql + ' WHERE ce.IsPosted = 1 AND err.EntryGuid IS NULL AND EN.Guid NOT IN (SELECT refGuid FROM '+ @SrecDb +'..Ages000)' 
	IF @EveryBranchHasBill = 1  
		SET @Sql = @Sql +  'AND ce.Branch = cc.Branch' 
	IF @ProcessCost = 1  
		   SET @Sql = @Sql + 'AND en.CostGuid =  cc.[CostGuid] '  
	SET @Sql = @Sql + ' ORDER BY EN.[AccountGuid],ISNULL(EN.[CustomerGuid],0x0)'  
	IF @EveryBranchHasBill = 1  
		   SET @Sql = @Sql + ',ce.Branch'  
	IF @ProcessCost = 1  
		   SET @Sql = @Sql + ', en.CostGuid'  
	        
	SET @Sql = @Sql +',[en].[Date] DESC ,[ce].[Number] DESC '  
	EXEC(@Sql) 
	SET @Sql = 'INSERT INTO #oldce ([Acc],[Cu],[CurrencyGuid],[CurrencyVal],[debit],[Credit],[Date],[Branch],[CostGuid]) SELECT [en].[AccountGuid],EN.[CustomerGuid],[en].[CurrencyGuid],[en].[CurrencyVal],[en].[debit],[en].[Credit],[a].[Date]'  
	IF @EveryBranchHasBill = 1  
		   SET @Sql = @Sql + ',ce.Branch'  
	ELSE  
		   SET @Sql = @Sql + ',0X00'  
	        
	IF @ProcessCost = 1  
	  SET @Sql = @Sql + ', en.CostGuid'  
	ELSE  
	  SET @Sql = @Sql + ', 0X00'  
	   
	SET @Sql = @Sql + ' FROM '+ @SrecDb +'..[en000] en INNER JOIN '+ @SrecDb +'..ce000 ce ON ce.Guid = en.ParentGuid INNER JOIN '+ @SrecDb +'..AGES000 a ON a.refGuid = en.Guid INNER JOIN #CE CC ON  en.[AccountGuid] = cc.[AccountGuid] AND ISNULL(EN.[CustomerGuid],0x0) = ISNULL(cc.[CustomerGuid],0x0)'  
	IF @EveryBranchHasBill = 1  
	BEGIN 
		SET @Sql = @Sql + ' WHERE ce.Branch = cc.Branch  ' 
	END 
	IF @ProcessCost = 1 
	BEGIN 
		IF @EveryBranchHasBill = 1  
			 SET @Sql = @Sql + ' AND ' 
		ELSE 
			SET @Sql = @Sql + ' WHERE ' 
		SET @Sql = @Sql + ' en.CostGuid =  cc.[CostGuid] '  
	END 
	SET @Sql = @Sql +  ' ORDER BY EN.[AccountGuid],ISNULL(EN.[CustomerGuid],0x0)'  
	IF @EveryBranchHasBill = 1  
		   SET @Sql = @Sql + ',ce.Branch'  
	        
	IF @ProcessCost = 1  
	  SET @Sql = @Sql + ', en.CostGuid'  
	  
	SET @Sql = @Sql +',[a].[Date] DESC ,[ce].[Number] DESC '  
	EXEC(@Sql)  
	INSERT INTO  @oldce  
	SELECT MIN(ID),[Acc],ISNULL([Cu],0x0),[CurrencyGuid],[CurrencyVal] ,SUM([debit]),0,[Date],[Branch],[CostGuid] FROM #oldce 
	WHERE [debit] >  0 
	GROUP BY [Acc],ISNULL([Cu],0x0),[CurrencyGuid],[CurrencyVal] ,[Date],[Branch],[CostGuid] 
	UNION ALL 
	SELECT MIN(ID),[Acc],ISNULL([Cu],0x0),[CurrencyGuid],[CurrencyVal] ,0,SUM([Credit]),[Date],[Branch],[CostGuid] FROM #oldce 
	WHERE [Credit] >  0 
	GROUP BY [Acc],ISNULL([Cu],0x0),[CurrencyGuid],[CurrencyVal] ,[Date],[Branch],[CostGuid] 
	
	DELETE c FROM #CE c LEFT JOIN @oldce O ON o.[Acc] = c.[AccountGuid] AND ISNULL(o.[Cu], 0x) = ISNULL(c.[CustomerGuid],0x) AND O.CostGuid =  c.CostGuid AND o.[Branch] = C.[Branch] 
	WHERE c.[AccountGuid] IS NULL 

	INSERT INTO  AGES000(Type,RefGuid,VAL,CurrencyGuid,CurrencyVal,[Date])  
	SELECT 0,en.Guid,CASE pt.Debit WHEN 0 THEN pt.Credit ELSE pt.Debit END,pt.CurrencyGuid,pt.CurrencyVal,OriginDate  
	FROM [en000] [en] INNER JOIN [pt000] [pt] ON pt.RefGuid = en.ParentGuid AND en.AccountGuid = pt.CustAcc  
	WHERE pt.Type = 3 AND [istransfered] = 1  

	DECLARE @CurrentAcc UNIQUEIDENTIFIER  ,@CurrentBranch UNIQUEIDENTIFIER ,@CurrentCost UNIQUEIDENTIFIER ,@CurrentCu  UNIQUEIDENTIFIER 
	 
	Set @CurrentAcc = 0x00 
	Set @CurrentCu = 0x00
	Set @CurrentBranch = 0x00 
	Set @CurrentCost = 0x00 
	
	CREATE TABLE #InsertedAges(GUID UNIQUEIDENTIFIER)

	SET @c = CURSOR FAST_FORWARD FOR  
		   SELECT AccountGuid,CustomerGuid,Branch,Debit,[CurrencyGuid],CurrencyVal,[Guid],[Date],[CostGuid]  FROM #CE WHERE Debit > 0  ORDER BY id  
	OPEN @c FETCH NEXT FROM @c INTO @Acc,@Cu,@Branch,@Val,@CurrencyGuid,@CurrencyVal,@Guid,@Date,@CostGuid 
	WHILE @@FETCH_STATUS = 0  
	BEGIN  
		IF (@CurrentAcc <> @Acc) OR (@CurrentCu <> @Cu) OR (@CurrentBranch <> @Branch) OR (@ProcessCost > 0 AND @CurrentCost <> @CostGuid) 
		BEGIN  
			DELETE @oldce WHERE [Acc] = @CurrentAcc AND  [Cu]= @CurrentCu AND [Branch] = @CurrentBranch 
			
			AND  (@ProcessCost = 0 OR CostGuid = @CostGuid) 
			AND Debit > 0  
			SET @CurrentAcc = @Acc  
			SET @CurrentCu = @Cu
			SET @CurrentBranch = @Branch 
			 
		END 
	   SET @Val2 = @Val  
	   WHILE (@Val2 > 0)  
	   BEGIN  
			 
			 SELECT @id = MIN([ID]) FROM @oldce  
			 WHERE [Acc] = @Acc  
			 AND ISNULL([Cu],0x0) = ISNULL(@Cu ,0x0)
			 AND [Branch] = @Branch  

			 AND Debit > 0  
			 AND (@ProcessCost = 0 OR CostGuid = @CostGuid) 
	          
			 IF (@ID IS NULL)  
			 BEGIN  
				IF ((@Val - @Val2) > 0) 
				BEGIN
					INSERT INTO AGES000(Type, RefGuid, VAL, CurrencyGuid, CurrencyVal, [Date])					
					VALUES(0, @Guid, @Val - @Val2, @CurrencyGuid, @CurrencyVal, @Date) 

					INSERT INTO #InsertedAges SELECT @Guid
				END 
				BREAK  
			 END  
	          
			 SELECT @CurrVal = debit from @oldce WHERE id = @id  
			 SET @Val2 = @Val2 - @CurrVal  
	          
			 IF (@Val2 > 0)  
					  SET @DefVal = @CurrVal  
			 ELSE  
					  SET @DefVal = @CurrVal + @Val2  
			 IF @DefVal = 0  
					  BREAK  
			 INSERT INTO  AGES000(Type,RefGuid,VAL,CurrencyGuid,CurrencyVal,[Date])  
			 SELECT 0,@Guid,@DefVal,CurrencyGuid,CurrencyVal,[Date]  FROM @oldce WHERE id = @id  
			 IF @@ROWCOUNT > 0
				INSERT INTO #InsertedAges SELECT @Guid
				
			 IF (@Val2 > 0)  
					  DELETE @oldce WHERE id = @id  
			 ELSE  
					   UPDATE @oldce SET Credit = @CurrVal - @DefVal WHERE id = @id  
	          
	   END  
	   FETCH NEXT FROM @c INTO @Acc,@CU,@Branch,@Val,@CurrencyGuid,@CurrencyVal,@Guid,@Date,@CostGuid 
	END  
	CLOSE @C  

	DELETE @oldce WHERE DEBIT > 0	 
	DELETE #CE WHERE DEBIT >0 OR (DEBIT =0 AND CREDIT = 0)  
	SET @CurrentAcc = 0X00 
	SET @CurrentCu = 0X00 
	SET @CurrentBranch = 0X00 
	SET @CurrentCost = 0X00 
	SET @c = CURSOR FAST_FORWARD FOR  
		   SELECT AccountGuid,CustomerGuid,Branch,Credit,[CurrencyGuid],CurrencyVal,[Guid],[Date],[CostGuid] FROM #CE WHERE Credit > 0  ORDER BY id  
	OPEN @c FETCH NEXT FROM @c INTO @Acc,@Cu,@Branch,@Val,@CurrencyGuid,@CurrencyVal,@Guid,@Date,@CostGuid 
	WHILE @@FETCH_STATUS = 0  
	BEGIN  
		IF (@CurrentAcc <> @Acc) OR (@CurrentCu <> @Cu) OR (@CurrentBranch <> @Branch) OR (@ProcessCost <> 0  AND @CurrentCost <> @CostGuid) 
			BEGIN  
				DELETE @oldce WHERE [Acc] = @CurrentAcc AND  [Cu]= @CurrentCu AND [Branch] = @CurrentBranch 
				AND Credit > 0  
				AND  (@ProcessCost = 0 OR CostGuid = @CostGuid) 
				SET @CurrentAcc = @Acc 
				SET @CurrentCu = @Cu 
				SET @CurrentBranch = @Branch 
			END 
	   SET @Val2 = @Val  
	   WHILE (@Val2 > 0)  
	   BEGIN  
				 SELECT @id = MIN([ID]) FROM @oldce  
				 WHERE [Acc] = @Acc  
				 AND ISNULL([Cu],0x0)= ISNULL(@Cu,0x0)
				 AND [Branch] = @Branch  

				 AND Credit > 0  
				 AND (@ProcessCost = 0 OR CostGuid = @CostGuid) 
	          
				 IF (@ID IS NULL)  
				 BEGIN  
					INSERT INTO  AGES000(Type,RefGuid,VAL,CurrencyGuid,CurrencyVal,[Date]) 
					VALUES(0,@Guid,@Val2,@CurrencyGuid,@CurrencyVal,@Date)
					
					INSERT INTO #InsertedAges SELECT @Guid 

					BREAK  
				 END  
	              
				 SELECT @CurrVal = credit from @oldce WHERE id = @id  
				 SET @Val2 = @Val2 - @CurrVal  
	              
				 IF (@Val2 > 0)  
						  SET @DefVal = @CurrVal  
				 ELSE  
						  SET @DefVal = @CurrVal + @Val2  
				 IF @DefVal = 0  
						  BREAK  
				 INSERT INTO  AGES000(Type,RefGuid,VAL,CurrencyGuid,CurrencyVal,[Date])  
				 SELECT 0,@Guid,@DefVal,CurrencyGuid,CurrencyVal,[Date]  FROM @oldce WHERE id = @id  
				 IF @@ROWCOUNT > 0
					INSERT INTO #InsertedAges SELECT @Guid 

				 IF (@Val2 > 0)  
						  DELETE @oldce WHERE id = @id  
				 ELSE  
						   UPDATE @oldce SET Debit = @CurrVal - @DefVal WHERE id = @id  
	   END  
	   FETCH NEXT FROM @c INTO @Acc,@Cu,@Branch,@Val,@CurrencyGuid,@CurrencyVal,@Guid,@Date,@CostGuid 
	END  
	CLOSE @c
	DEALLOCATE @c
	INSERT INTO #dates  
	SELECT DISTINCT [date] from ages000 WHERE type = 0 and currencyguid <> 0x00 ORDER BY [date]  
	SELECT a.[date] [startdate], ISNULL(dateadd(dd,-1,b.[date]),a.[date]) [endDate]  
	INTO [#currdates] FROM  #dates a left join #dates b on (a.id + 1) = b.id  
	SET @Sql = 'INSERT INTO mh000 SELECT a.Guid,a.CurrencyGuid,CurrencyVal,a.[Date] FROM ' + @SrecDb + '..mh000 a INNER JOIN [#currdates] b ON a.[date] BETWEEN [startdate] and [endDate] WHERE a.guid not in (SELECT guid FROM mh000) and CurrencyGuid NOT IN (SELECT guid FROM my000 WHERE number = 1)'  
	EXEC(@Sql)  
	
	UPDATE ag 
		SET CurrencyVal = [dbo].[fnGetCurVal](ag.CurrencyGUID, ag.[Date])
	FROM 
		Ages000 ag
		INNER JOIN #InsertedAges i ON ag.RefGuid = i.GUID 
		INNER JOIN my000 my ON my.GUID = ag.CurrencyGUID
	WHERE 
		my.Number != 1  
####################################
CREATE PROCEDURE prcTransMatAge
	@EveryBranchHasBill [BIT],
	@SrecDb NVARCHAR(100)
AS 
	SET @SrecDb = @SrecDb;

    DECLARE @Sql NVARCHAR(1000) 
    DECLARE @c CURSOR 
    DECLARE @Qty2 FLOAT,@ID INT ,@CurrQty FLOAT,@DefQty FLOAT 
    DECLARE @Mat UNIQUEIDENTIFIER,@Branch UNIQUEIDENTIFIER,@Qty [FLOAT],@Guid UNIQUEIDENTIFIER,@Date DATETIME 
    SET @Guid =(select top 1 guid from us000 where bAdmin = 1)
    IF NOT( @Guid is  null)
    BEGIN
            SET  @Sql = 'exec '+ @SrecDb +'..prcConnections_add ''' + cast(@Guid as NVARCHAR(36)) +''''
            EXEC(@Sql) 
    END
    CREATE TABLE #bu 
    ( 
        ID INT IDENTITY(1,1), 
        [Guid] UNIQUEIDENTIFIER, 
        [MatGuid] UNIQUEIDENTIFIER, 
        [qty] FLOAT, 
        [Branch] UNIQUEIDENTIFIER, 
        [CurrencyGuid]         UNIQUEIDENTIFIER, 
        [CurrencyVal] FLOAT, 
        [Date] DATETIME 
    ) 
    INSERT INTO #bu([qty],[Guid],[MatGuid],[Branch],[Date]) 
    SELECT [bi].[qty] ,[bi].[Guid],[MatGuid],CASE @EveryBranchHasBill WHEN 0 THEN 0X00 ELSE a.Branch END,a.[Date] 
    FROM [bi000] bi INNER JOIN (SELECT bu.Guid,bu.IsPosted,bu.[date],bu.Number AS [buNumber],Branch FROM [bu000] bu INNER JOIN [mc000] ON CAST(bu.Guid AS NVARCHAR(40))=[asc2]) a 
    ON a.Guid = bi.ParentGuid 
           
    ORDER BY [MatGuid],CASE @EveryBranchHasBill WHEN 0 THEN 0X00 ELSE a.Branch END, a.Guid, [a].[Date],buNumber 

    --GROUP BY [a].[Guid],en.AccountGuid 
    CREATE TABLE #oldbu 
    ( 
        ID				 INT IDENTITY(1,1), 
        [MatGuid]        UNIQUEIDENTIFIER, 
        [Qty]            FLOAT, 
        [Date]           DATETIME, 
        [Branch]		 UNIQUEIDENTIFIER ,
		[btBillType]	 INT
	 ) 
    SET @Sql = 'INSERT INTO #oldbu ([MatGuid],[Qty],[Date],[Branch],[btBillType]) SELECT [MatGuid],([bi].[Qty]),[buDate]' 
    IF @EveryBranchHasBill = 1 
            SET @Sql = @Sql + ',buBranch, [btBillType]' 
    ELSE 
            SET @Sql = @Sql + ',0X00, [btBillType]' 
    SET @Sql = @Sql + ' FROM '+ @SrecDb +'..[bi000] bi INNER JOIN '+ @SrecDb +'..vwbu bu ON bu.buGuid = bi.ParentGuid '+'
			WHERE [MatGuid] IN (SELECT [MatGuid] FROM #bu) AND bi.Guid NOT IN (SELECT refGuid from ' + @SrecDb + '..Ages000 where type = 1) 
			ORDER BY [MatGuid]'
    IF @EveryBranchHasBill = 1 
            SET @Sql = @Sql + ',buBranch' 
    SET @Sql = @Sql +',[buDate] DESC ,busortflag desc,[buNumber] DESC ' 
    EXEC(@Sql)  
 
    SET @Sql = 'INSERT INTO #oldbu ([MatGuid],[Qty],[Date],[Branch],[btBillType]) SELECT [MatGuid],[bi].[Qty],[a].[Date] as Date' 
    IF @EveryBranchHasBill = 1 
            SET @Sql = @Sql + ',bu.buBranch as Branch,[bu].[btBillType]' 
    ELSE 
            SET @Sql = @Sql + ',0X00, [bu].[btBillType]' 
    SET @Sql = @Sql + ' FROM '+ @SrecDb +'..[bi000] bi INNER JOIN '+ @SrecDb +'..vwBu bu ON bu.buGuid = bi.ParentGuid INNER JOIN ' + @SrecDb + '..AGES000 a ON a.refGuid = bi.Guid ' 
    SET @Sql = @Sql + ' WHERE [MatGuid] IN (SELECT [MatGuid] FROM #bu)   ORDER BY [MatGuid]' 
    IF @EveryBranchHasBill = 1 
            SET @Sql = @Sql + ',bu.buBranch, [bu].[btBillType]'  
    SET @Sql = @Sql +',a.Guid, [a].[Date] DESC ,[bu].[buNumber] DESC ' 
    EXEC(@Sql)   



	--Insert all Sales
	INSERT INTO AGES000(Type,RefGuid,VAL,[Date])
	SELECT 2,bu.Guid,oldbu.Qty,oldbu.Date  FROM #oldbu oldbu inner join #bu bu on bu.MatGuid = oldbu.MatGuid WHERE oldbu.btBillType = 1 


	--Insert ALL ReturnSales 
	INSERT INTO AGES000(Type,RefGuid,VAL,[Date])
	SELECT 3,bu.Guid,oldbu.Qty,oldbu.Date  FROM #oldbu oldbu inner join #bu bu on bu.MatGuid = oldbu.MatGuid WHERE oldbu.btBillType = 3
	

    SET @c = CURSOR FAST_FORWARD FOR 
            SELECT MatGuid,Branch,[qty],[Guid],[Date]  FROM #bu   ORDER BY id 
    OPEN @c FETCH NEXT FROM @c INTO @Mat,@Branch,@Qty,@Guid,@Date 
    WHILE @@FETCH_STATUS = 0 
    BEGIN 
        SET @Qty2 = @Qty 
        WHILE (@Qty2 > 0) 
        BEGIN 
		
            SELECT @id = MIN([ID]) from #oldbu WHERE [MatGuid] = @Mat AND [Branch] = @Branch  

            IF (@ID IS NULL) 
            BEGIN
			
			IF ( (@Qty - @Qty2) >= 0 AND (NOT EXISTS(SELECT * FROM AGES000 WHERE RefGUID = @Guid and val = @DefQty and type = 1 ) ) )
				INSERT INTO AGES000(Type,RefGuid,VAL,[Date])
				VALUES(1,@Guid,@Qty - @Qty2,@Date)
                BREAK 
            END

            SELECT @CurrQty = [qty] FROM #oldbu WHERE id = @id 
            SET @Qty2 = @Qty2 - @CurrQty 

            IF (@Qty2 > 0) 
                SET @DefQty = @CurrQty 
            ELSE 
                SET @DefQty = @CurrQty + @Qty2 

            IF @DefQty = 0 
               BREAK 
			 
			 IF (NOT EXISTS(SELECT * FROM AGES000 WHERE RefGUID = @Guid and val = @DefQty and type = 1 ) )
             BEGIN
				INSERT INTO  AGES000(Type,RefGuid,VAL,[Date]) 
				SELECT 1,@Guid,@DefQty, Date FROM #oldbu WHERE id = @id 
			 END
			 
            IF (@Qty2 >= 0) 
              DELETE #oldbu WHERE id = @id 
            ELSE 
              UPDATE #oldbu SET qty = @CurrQty - @DefQty WHERE id = @id 
        END 
        FETCH NEXT FROM @c INTO @Mat,@Branch,@Qty,@Guid,@Date 
    END 
    CLOSE @C  DEALLOCATE @C
####################################
CREATE PROCEDURE prcTransMatAccAges
	@EveryBranchHasBill [BIT],
	@SrecDb NVARCHAR(100),
	@AccAge		 [BIT],
	@MatAge		 [BIT],
    @ProcessCost [BIT] = 0,
    @SetLog BIT  = 0
AS
	SET NOCOUNT ON
		SET @SrecDb = '[' + @SrecDb + ']';

	DECLARE @Parms NVARCHAR(2000),@LgGuid UNIQUEIDENTIFIER
	SET @Parms =  'EveryBranchHasBill' + CAST(@EveryBranchHasBill AS NVARCHAR(10)) + CHAR(13) +
	'EveryBranchHasBill' + @SrecDb + CHAR(13) + 
	'AccAge' + CAST(@AccAge AS NVARCHAR(10)) + CHAR(13)
	+ 'MatAge' + CAST(@MatAge AS NVARCHAR(10)) + CHAR(13)
	+ 'ProcessCost' + CAST(@ProcessCost AS NVARCHAR(10)) + CHAR(13)
	IF (@ProcessCost > 0)
		EXEC prcCreateMaintenanceLog 19,@LgGuid OUTPUT,@Parms  
	DELETE AGES000 
	IF @AccAge > 0
		EXEC prcTransAccAge @EveryBranchHasBill,@SrecDb, @ProcessCost
	IF @MatAge > 0
		EXEC prcTransMatAge @EveryBranchHasBill,@SrecDb
	IF (@ProcessCost > 0)
		EXEC prcCreateMaintenanceLog 19,@LgGuid OUTPUT,@Parms  
#################################################
#END
