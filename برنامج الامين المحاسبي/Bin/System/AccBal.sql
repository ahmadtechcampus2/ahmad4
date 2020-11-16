################################################################################
##أرصدة الحسابات
## ------------------------------
CREATE PROCEDURE repAccBalRep
	@StartDate [DATETIME],
	@EndDate [DATETIME],
	@SecEntry [INT],
	@SecAcc [INT],
	@AccPtr [UNIQUEIDENTIFIER],
	@CurPtr [UNIQUEIDENTIFIER],
	@CurVal [FLOAT],
	@Contain AS [NVARCHAR](200),
	@NotContain AS [NVARCHAR](200),
	@Type AS [INT],
	@ShowZero AS [INT]
	
AS
	DECLARE @strContain AS [NVARCHAR]( 1000) 
	DECLARE @strNotContain AS [NVARCHAR]( 1000) 
	 
	DECLARE @AllAcc AS [INT]  
	DECLARE @DebitAcc AS [INT]  
	DECLARE @CreditAcc AS [INT]  
	DECLARE @Exceed AS [INT]  
	 
	SET @AllAcc = 0 
	SET @DebitAcc = 1 
	SET @CreditAcc = 2 
	SET @Exceed = 3 
	 
	 
	SET @strNotContain = '%'+ @NotContain + '%' 
	SET @strContain = '%'+ @Contain + '%' 
	 
	DECLARE @t table (
			[AccPtr] [UNIQUEIDENTIFIER], 
			[AccName] [NVARCHAR](500) COLLATE ARABIC_CI_AI,
			[AccLName] [NVARCHAR](500) COLLATE ARABIC_CI_AI,
			[AccCode] [NVARCHAR](500) COLLATE ARABIC_CI_AI,
			[AccMaxDebit] [FLOAT],
			[AccWarn] [INT],
			[AccNSons] [INT],
			[AccNotes] [NVARCHAR](500) COLLATE ARABIC_CI_AI,
			[SumDebit] [FLOAT],
			[SumCredit] [FLOAT],
			[Balanc] [FLOAT])
	INSERT INTO @t SELECT
			[VWAC].[acGuid] AS [AccPtr],
			[VWAC].[acName] AS [AccName],
			[VWAC].[acLatinName] AS [AccLName],
			[VWAC].[acCode] AS [AccCode],
			[VWAC].[acMaxDebit] AS [AccMaxDebit],
			[VWAC].[acWarn] AS [AccWarn],
			[VWAC].[acNSons] AS [AccNSons],
			[VWAC].[acNotes] AS [AccNotes],
			ISNULL( SUM( [vwEx].[FixedEnDebit]), 0) AS [SumDebit1],
			ISNULL( SUM( [vwEx].[FixedEnCredit]), 0) AS [SumCredit1],
			--( SUM( vwEx.FixedEnDebit) - SUM( vwEx.FixedEnCredit)) AS SumDebit,
			--( SUM( vwEx.FixedEnDebit) - SUM( vwEx.FixedEnCredit)) AS SumCredit,
			(CASE [VWAC].[acWarn]
			WHEN 2 THEN -( SUM( [vwEx].[FixedEnDebit]) - SUM( [vwEx].[FixedEnCredit]))
			ELSE  SUM( [vwEx].[FixedEnDebit]) - SUM( [vwEx].[FixedEnCredit])
			END) AS [Balanc]
		FROM
			[fnExtended_en_Fixed]( @CurPtr) AS [vwEx]
			RIGHT JOIN [VWAC] ON [vwEx].[enAccount] = [VWAC].[acGuid]
			INNER JOIN ( SELECT * FROM [dbo].[fnGetAccountsList]( @AccPtr , DEFAULT)) AS [ac]
			ON [vwEx].[enAccount] = [ac].[Guid]
		WHERE
			[vwEx].[enDate] BETWEEN @StartDate AND @EndDate
			AND [vwEx].[ceIsPosted] = 1
			AND [vwEx].[ceSecurity] <= @SecEntry AND [VWAC].[acSecurity] <= @SecAcc
			AND [VWAC].[acType] <> 2 AND  [VWAC].[acNSons] = 0
			AND ( @Contain = '' or [VWAC].[acNotes] Like @strContain)
			AND ( @NotContain = '' or [VWAC].[acNotes] NOT Like @strNotContain)
		GROUP BY
			[VWAC].[acGuid],
			[VWAC].[acName],
			[VWAC].[acLatinName],
			[VWAC].[acCode],
			[VWAC].[acMaxDebit],
			[VWAC].[acWarn],
			[VWAC].[acNSons],
			[VWAC].[acNotes]
SELECT
	[AccPtr],
	[AccName],
	[AccLName],
	[AccCode],
	[dbo].[fnCurrency_fix]( [VWAC].[acMaxDebit], [VWAC].[acCurrencyPtr], [VWAC].[acCurrencyVal], @CurPtr , @CurVal ) AS [AccMaxDebit],
	[AccWarn],
	[AccNSons],
	[AccNotes],
	[SumDebit],
	[SumCredit]
FROM
	@t AS [Res] INNER JOIN [VWAC]
	ON [Res].[AccPtr] = [VWAC].[acGuid]
WHERE
	( @Type = @AllAcc AND ( (@ShowZero = 1) OR ( (@ShowZero = 0) AND ([Balanc] <> 0) )))
	OR ( @Type = @DebitAcc AND ([SumDebit] - [SumCredit])  > 0 AND( (@ShowZero = 1) OR ( (@ShowZero = 0) AND ([Balanc] <> 0) )))
	OR ( @type = @CreditAcc AND ([SumDebit] - [SumCredit])  < 0 AND( (@ShowZero = 1) OR ( @ShowZero = 0 AND ([Balanc] <> 0) )))
	OR ( @type = @Exceed AND [accWarn] <> 0 AND [dbo].[fnCurrency_fix]( [VWAC].[acMaxDebit], [VWAC].[acCurrencyPtr], [VWAC].[acCurrencyVal], @CurPtr , @CurVal ) <= [Balanc])
################################################################################
#END
