##############################################
CREATE PROCEDURE repSalesManMovement
	@SalesManGuid	UNIQUEIDENTIFIER,
	@StartDate	DATETIME,
	@EndDate	DATETIME,
	@CurrencyGuid	UNIQUEIDENTIFIER,
	@UseUnit	INT = 3,
	@PriceType	INT = 0,
	@ShowCustBal	INT = 0 -- -1 all 2 CREDIT 3 COLLECTED
AS 
	SET NOCOUNT ON
	DECLARE @JobCost UNIQUEIDENTIFIER
	DECLARE @CurrencyVal FLOAT
	DECLARE @ZeroValue FLOAT
	SET @ZeroValue = dbo.fnGetZeroValuePrice()
	SELECT @CurrencyVal = CurrencyVal FROM my000 WHERE Guid = @CurrencyGuid
	IF (ISNULL(@SalesManGuid,0X0) = 0X0)
		SELECT @JobCost = ISNULL(CostGuid,0X0) FROM DISTSALESMAN000 WHERE GUID = @SalesManGuid
	ELSE
		SET @JobCost = 0X0

	CREATE TABLE [#SecViol]([Type] [INT],[Cnt] [INT])
	
	CREATE TABLE [#CostTbl]( [CostGUID] [UNIQUEIDENTIFIER],[Security] [INT])
	CREATE TABLE [#MatTbl]( [MatGUID] [UNIQUEIDENTIFIER], [mtSecurity] [INT])
	CREATE TABLE [#BillTbl]( [Type] UNIQUEIDENTIFIER, [Security] INT, [ReadPriceSecurity] INT, [UnPostedSecurity] INT)
	CREATE TABLE #AccTbl( Number UNIQUEIDENTIFIER, Security INT, Lvl INT)
	
	
	CREATE TABLE #t_Prices
	(
		mtNumber 	UNIQUEIDENTIFIER,
		APrice 		FLOAT
	)
	CREATE TABLE [#MT1]
	(
		[mtGuid]		[UNIQUEIDENTIFIER],
		[mtSecurity]	[INT],
		[mtUnitFact]	[FLOAT] DEFAULT 1,
		
	)

	CREATE TABLE #RESULT
	(
		[Guid]		UNIQUEIDENTIFIER,
		[MatGuid] 	UNIQUEIDENTIFIER DEFAULT 0X00,
		[AccGuid]		UNIQUEIDENTIFIER DEFAULT 0X00,
		[CustGuid]	UNIQUEIDENTIFIER DEFAULT 0X00,
		[biQty]		FLOAT DEFAULT 0,
		[biBonus]		FLOAT DEFAULT 0,
		[MtVal]		FLOAT DEFAULT 0,
		[MtBonusVal]	FLOAT DEFAULT 0,
		[Debit]		FLOAT DEFAULT 0,
		[Credit]		FLOAT DEFAULT 0,
		[Securty]		INT DEFAULT 0,
		[AccSecurity]	INT DEFAULT 0,
		[CustSecurity]	INT DEFAULT 0,
		[Date]		DATETIME DEFAULT '1/1/1980',
		Number		FLOAT,
		MatSecurity	INT DEFAULT 	0,
		btSecurity	INT DEFAULT 	0,
		[Pay]		FLOAT DEFAULT 0,
		[buTotal]		FLOAT DEFAULT 0,
		[Flag]		INT DEFAULT 	0, --2 bills 6 discount 10  
		[buDirection]	INT DEFAULT 	0,
		CostGuid	UNIQUEIDENTIFIER DEFAULT 0X00	
	) 
	CREATE TABLE #FinalResult
	(
		Guid		UNIQUEIDENTIFIER,
		Code		NVARCHAR(256) COLLATE ARABIC_CI_AI, 
		[Name]		NVARCHAR(256) COLLATE ARABIC_CI_AI,
		biQty		FLOAT DEFAULT 0,
		biBonus		FLOAT DEFAULT 0,
		MtVal		FLOAT DEFAULT 0,
		MtBonusVal	FLOAT DEFAULT 0,
		Sales		FLOAT DEFAULT 0,
		Debit		FLOAT DEFAULT 0,
		Credit		FLOAT DEFAULT 0,
		[Flag]		INT DEFAULT 0
	)

	INSERT INTO [#AccTbl] EXEC [prcGetAccountsList] 0X0
	INSERT INTO [#CostTbl] EXEC [prcGetCostsList] @JobCost
	INSERT INTO [#BillTbl] EXEC [prcGetBillsTypesList2] 0x0, 0x0 
	INSERT INTO #MatTbl EXEC prcGetMatsList 0X0, 0X0 ,0
	
	SELECT [cuGuid],[cuSecurity], [ac].[Number] AS [AccGuid], [ac].[Security] AS [acSecurity] INTO [#Cust] FROM vwCu as [cu] INNER JOIN [#AccTbl] AS [ac] ON [cu].[cuAccount] = [ac].[Number]
	
	EXEC prcGetMtPrice 0X0,0X0, -1, @CurrencyGUID, @CurrencyVal, 0X0, @PriceType, 64, 0, @UseUnit
	INSERT INTO  #MT1
		SELECT 
			mt1.mtGuid,
			mt1.mtSecurity,
			CASE @UseUnit 
				WHEN 0 THEN 1
				WHEN 1 THEN mt1.mtunit2Fact
				WHEN 2 THEN mt1.mtunit3Fact
				ELSE CASE mt1.mtDefUnit
						WHEN 1 THEN 1
						WHEN 2 THEN mt1.mtunit2Fact
						ELSE mt1.mtunit3Fact
					END
			END 
		FROM 
			vwMt AS mt1 
	
	INSERT INTO #Result (Guid,MatGuid,biQty,biBonus,MtVal,MtBonusVal,Securty,[Date],Number,MatSecurity,btSecurity,buDirection,[Pay],[CustGuid],[AccGuid],[AccSecurity],[CustSecurity],[buTotal],[Flag])
		SELECT 
			[buGuid],
			[biMatPtr],
			[biQty] /CASE mt.mtUnitFact WHEN 0 THEN 1 ELSE mt.mtUnitFact END,
			[biBonusQnt]/CASE mt.mtUnitFact WHEN 0 THEN 1 ELSE mt.mtUnitFact END,
			[biQty]* [FixedBiPrice] *[mt].[mtUnitFact] ,
			[biBonusQnt]* ISNULL([APrice],0) * [mt].[mtUnitFact] ,
			[buSecurity],
			[buDate],
			[buNumber],
			[mt].[mtSecurity],
			CASE [buIsPosted] WHEN 1 THEN [bt].[Security] ELSE [UnPostedSecurity] END,
			buDirection,
			CASE [buPayType] WHEN  0 THEN [FixedBuTotal] - [FixedBuTotalDisc] + [FixedBuTotalExtra] ELSE [FixedbuFirstPay] END,
			ISNULL([buCustPtr],0X0),
			ISNULL([AccGuid],0X0),
			ISNULL([cuSecurity],0),
			ISNULL([acSecurity],0),
			[FixedBuTotal] - [FixedBuTotalDisc] + [FixedBuTotalExtra],
			2	
		FROM fnExtended_bi_Fixed(@CurrencyGuid) AS bi 
		INNER JOIN [#MT1] AS mt ON mt.MtGUID = bi.biMatPtr
		INNER JOIN [#t_Prices] AS tp ON  mt.MtGUID = tp.mtNumber
		INNER JOIN [#BillTbl] AS bt ON bt.Type = bi.buType
		INNER JOIN [#CostTbl] AS co ON co.CostGUID = bi.buCostPtr
		LEFT JOIN [#Cust] AS [cu] ON [cu].[cuGuid] = [buCustPtr]
		WHERE buDate BETWEEN @StartDate AND @EndDate	
	
	INSERT INTO #Result (Guid,AccGuid,Debit,Credit,Securty,AccSecurity,[Date],Number,Flag)
	SELECT DISTINCT di.Guid,di.AccountGuid,
		CASE buDirection WHEN -1 THEN dbo.fnCurrency_Fix(Discount,CurrencyGuid,CurrencyVal,@CurrencyGuid,NULL) ELSE dbo.fnCurrency_Fix(Extra,CurrencyGuid,CurrencyVal,@CurrencyGuid,NULL) END,
		CASE buDirection WHEN 1 THEN dbo.fnCurrency_Fix(Discount,CurrencyGuid,CurrencyVal,@CurrencyGuid,NULL) ELSE dbo.fnCurrency_Fix(Extra,CurrencyGuid,CurrencyVal,@CurrencyGuid,NULL) END,
		r.Securty,ac.Security,r.Date,di.Number,6

	FROM #Result AS r 
	INNER JOIN di000 AS di ON di.ParentGuid = r.Guid
	INNER JOIN #AccTbl AS ac ON ac.Number = di.AccountGuid 
	
	INSERT INTO [#Result] (Guid,AccGuid,Debit,Credit,Securty,AccSecurity,Flag) 
		SELECT [ceGuid],enAccount,FixedEnDebit,FixedEnCredit,ceSecurity,[ac].[acSecurity],15 
			FROM [dbo].[fnExtended_En_Fixed] (@CurrencyGuid) AS f
			INNER JOIN [#Cust] AS ac ON ac.[AccGuid] = f.enAccount
			INNER JOIN [#CostTbl] AS [co] ON [co].[CostGUID] = [f].[enCostPoint]
			INNER JOIN [ER000] AS [er] ON [er].[EntryGuid] =  [f].[ceGuid]
			INNER JOIN [py000] AS [py] ON [er].[ParentGuid] = [py].[Guid]
			WHERE [enDate] BETWEEN @StartDate AND @EndDate

	
	EXEC prcCheckSecurity 
	CREATE CLUSTERED INDEX RESULTINDEX ON #Result (Flag)

	DECLARE @SumPay FLOAT
	DECLARE @SumPay2 FLOAT
	SELECT DISTINCT Guid, [Pay],[buDirection] INTO #BPay FROM [#RESULT] WHERE [FLAG] = 2

	SELECT @SumPay =  SUM([Pay] * -[buDirection] ) FROM #BPay
	SELECT @SumPay2 = SUM([Credit]) - SUM([Debit])FROM [#RESULT] WHERE [FLAG] = 15
	INSERT INTO #FinalResult ([Credit],Flag) VALUES( ISNULL(@SumPay,0) + ISNULL(@SumPay2,0) ,-3)

	INSERT INTO #FinalResult (Guid,Code,[Name],biQty,biBonus,MtVal,MtBonusVal,Flag)
		SELECT r.MatGuid,mt.Code,mt.Name,SUM([biQty] * -[buDirection]),SUM([biBonus] * -[buDirection]),SUM([MtVal] * -[buDirection]),SUM(MtBonusVal * -[buDirection]),r.Flag
		FROM #RESULT AS r INNER JOIN mt000 AS mt ON r.MatGuid = mt.Guid
		WHERE r.Flag = 2
		GROUP BY r.MatGuid,mt.Code,mt.Name,r.Flag

	INSERT INTO #FinalResult (Guid,Code,[Name],Debit,Credit,Flag)
		SELECT r.AccGuid,ac.Code,ac.Name,SUM(r.Debit),SUM(r.Credit),r.Flag
		FROM #RESULT AS r INNER JOIN ac000 AS ac ON r.AccGuid = ac.Guid
		WHERE r.Flag = 6 OR r.Flag = 7
		GROUP BY r.AccGuid,ac.Code,ac.Name,r.Flag
		
	IF  @ShowCustBal <> 0
	BEGIN
		INSERT INTO [#RESULT] ([AccGuid],[Guid],[Pay],[buTotal],[buDirection],FLAG)SELECT DISTINCT [AccGuid],[Guid],[Pay],[buTotal],[buDirection],15 AS [FALG] FROM [#RESULT] WHERE [FLAG] = 2 
		SELECT  [r].[AccGuid] AS [acGuid] ,SUM(ISNULL([buTotal],0) * -[buDirection]) as [buTotal],SUM(ISNULL([r].[Debit] ,0) + ISNULL ([Pay] * CASE [buDirection] WHEN 1 THEN 1 ELSE 0 END,0)) AS Debit,SUM(ISNULL([r].[Credit],0) + ISNULL ([Pay] * CASE [buDirection] WHEN -1 THEN 1 ELSE 0 END,0)) AS Credit
		INTO #CER
		FROM #RESULT AS r 
		WHERE ISNULL([r].[Flag],15) = 15 
			GROUP BY r.AccGuid

		INSERT INTO #FinalResult (Guid,Code,[Name],[Sales],Debit,Credit,Flag)
			SELECT [acGuid],ac.Code,ac.Name,[buTotal],[r].[Debit],[r].[Credit],15
			FROM #CER AS r 
			INNER JOIN [ac000] AS ac ON [r].[acGuid] = [ac].[Guid] 
	END
	SELECT * FROM #FinalResult ORDER BY Flag,Code 
	SELECT * FROM  #SecViol
/*
	prcConnections_add2 '„œÌ—'
	exec repSalesManMovement '2e9e84f1-2a73-4f7b-bbc8-14d3e99e93d3', '1/1/2004', '1/12/2005', '0597be75-9490-4c04-99ad-277a40b66316', 3, 128, 3 
*/
################################################################################
#END