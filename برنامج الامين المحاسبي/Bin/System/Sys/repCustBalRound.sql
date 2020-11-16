################################################################################
##
CREATE PROCEDURE repCustBalRound 
	@StartDate [DATETIME],
	@EndDate [DATETIME],
	@AccGUID [UNIQUEIDENTIFIER],
	@CurGUID [UNIQUEIDENTIFIER],
	@CostGuid AS [UNIQUEIDENTIFIER],
	@Branch AS [UNIQUEIDENTIFIER] = 0x0,
	@Type AS [INT],
	@bCustOnly [INT] = 1,
	@CustCondGuid			[UNIQUEIDENTIFIER] = 0X00,
	@Balance [FLOAT] = 0,
	@OperationType [INT] = 1, -- Operation type 1 Roundation 2 Equalization 	
	@FilterByAccountCurrency BIT = 0,
	@HandleCostCenters BIT = 1,
	@CustGUID	[UNIQUEIDENTIFIER] = 0x0
AS    
	SET NOCOUNT ON

	IF  @OperationType = 2 AND  @Balance = 0 
	BEGIN
		SELECT
		0x0 AS [AccPtr],
		'' AS [AccCode],
		'' AS [AccName],
		'' AS [AccLName], 
		'' AS [CostCode],
		'' AS [CostName],
		'' AS [CostLName],
		0x0 AS [CostGUID], 
		0x0 AS [CustPtr],
		'' AS [CustName],
		'' AS [CustLName], 
		0.0 AS [AccMaxDebit],
		0 AS [AccWarn],
		0.0 AS [Balance]
		WHERE 0 <> 0 
		RETURN 
	END
	
	DECLARE @AllAcc AS [INT],
			@DebitAcc AS [INT],
			@CreditAcc AS [INT],
			@BranchMask [BIGINT],
			@BranchGuid [UNIQUEIDENTIFIER], 
 			@Sql AS [NVARCHAR]( max)

	CREATE TABLE [#SecViol]		([Type] [INT], [Cnt] [INT])
	CREATE TABLE [#CustTable]	([cuGuid] [UNIQUEIDENTIFIER], [cuSec] [INT])
	CREATE TABLE [#AccTable]	([accGuid] [UNIQUEIDENTIFIER], [accSec] [INT], [accLevel] [INT])
	CREATE TABLE [#Cost_Tbl]    (CostGuid [UNIQUEIDENTIFIER], CostCode NVARCHAR(250), CostName NVARCHAR(250), CostLatinName NVARCHAR(250))

	CREATE TABLE [#Result]		
			([AccPtr] [UNIQUEIDENTIFIER], 
			 [Debit] [FLOAT], 
			 [Credit] [FLOAT], 
			 [AccSecurity] [INT], 
			 [CustSecurity] [INT],
 			 [CostGuid] [UNIQUEIDENTIFIER],
			 [CustGuid]	[UNIQUEIDENTIFIER]
			)

	CREATE TABLE [#EndResult] 
			([AccPtr] [UNIQUEIDENTIFIER], 
			 [Debit] [FLOAT],
			 [Credit] [FLOAT], 
			 [Balance] [FLOAT],
			 [CostGuid] [UNIQUEIDENTIFIER],
			 [CustGuid] [UNIQUEIDENTIFIER]
			)

	INSERT INTO [#AccTable] 
	SELECT 
		fn.[GUID],
		ac.[Security],
		fn.[Level]
	FROM fnGetAccountsList(@AccGUID, DEFAULT) AS fn
	INNER JOIN ac000 AS ac ON ac.Guid = fn.[Guid]
	WHERE @FilterByAccountCurrency = 0 OR (@FilterByAccountCurrency = 1 AND ac.CurrencyGuid = @CurGUID)

	IF (@bCustOnly = 1)
	DELETE FROM #acctable WHERE accGuid NOT IN (SELECT accountguid FROM cu000)	

	INSERT INTO [#CustTable] EXEC [prcGetCustsList] @CustGUID, @AccGUID, @CustCondGuid

	IF @CustGUID = 0x0  AND @CustCondGuid = 0x0 -- AND @bCustOnly = 0
		INSERT INTO [#CustTable] SELECT 0x0, 0


	SET @BranchGuid = ( CASE WHEN ISNULL( @Branch, 0x0) = 0x0 THEN [dbo].[fnBranch_getDefaultGuid]( ) ELSE @Branch END)
	IF ISNULL( @BranchGuid, 0x0) != 0x0
		SET @BranchMask = ( SELECT ISNULL([brBranchMask], 0) FROM [vwbr] WHERE [brGuid] = @BranchGuid)
	SET @BranchMask = ISNULL( @BranchMask, 0)
	SET @AllAcc = 0
	SET @DebitAcc = 1
	SET @CreditAcc = 2

	INSERT INTO [#Cost_Tbl]
	SELECT 
		co.[GUID] AS CostGuid,
		co.[Code] AS CostCode,
		co.[Name] AS CostName,		
		co.[LatinName] AS CostLatinName
	FROM co000 AS co
	INNER JOIN [fnGetCostsList](@CostGUID) AS fn ON co.Guid = fn.[Guid]
	
	INSERT INTO [#Result] 
	SELECT
		[ac].[acGuid],
		[vwEx].[FixedEnDebit],
		[vwEx].[FixedEnCredit],
		[ac].[acSecurity], 
		[cu].[cuSecurity],	
		ISNULL([Co].CostGuid,0x0),
		ISNULL([cu].[cuGUID], 0x0)
	FROM 
		[fnExtended_en_Fixed](@CurGUID)  AS [vwEx]
		INNER JOIN [vwAC] AS [ac] ON [vwEx].[enAccount] = [ac].[acGuid]
		INNER JOIN [#AccTable] AS [acc] ON [acc].[accGuid] = [ac].[acGuid]
		LEFT JOIN [#Cost_Tbl] AS [Co] ON [vwEx].[enCostPoint] = [Co].[CostGUID] 		
		LEFT JOIN [vwCu] AS [cu] ON [cu].[cuAccount] = [ac].[acGuid] AND [cu].[cuGUID] = [vwEx].[enCustomerGUID]

	WHERE 
		[vwEx].[enDate] BETWEEN @StartDate AND @EndDate
		AND [vwEx].[ceIsPosted] = 1
		AND (([ac].[acBranchMask] = 0) OR ( CAST( [ac].[acBranchMask] AS [BIGINT]) &  CAST( @BranchMask AS  [BIGINT])) <>  0)
		AND ( [vwEx].[CeBranch] = @BranchGuid)

	EXEC (@Sql)
	EXEC [prcCheckSecurity] @Check_AccBalanceSec = 1
	
	INSERT INTO [#EndResult]
	SELECT
		[Res].[AccPtr],
		SUM([Res].[Debit]),
		SUM([Res].[Credit]),
		(CASE [ac].[acWarn]
			WHEN 2 THEN -( SUM( [Res].[Debit]) - SUM( [Res].[Credit]))
			ELSE SUM( [Res].[Debit]) - SUM( [Res].[Credit])
		END),
		CASE @HandleCostCenters
			WHEN 1 THEN ISNULL(Res.[CostGuid], 0x0)
			ELSE 0x0
		END,
		Res.[CustGuid]
	FROM
		[#Result] As [Res] INNER JOIN [vwAc] AS [ac]
		ON [Res].[AccPtr] = [ac].[acGUID]
		INNER JOIN [#CustTable] AS [CustTB] ON [CustTB].[cuGuid] = [Res].[CustGuid]
	GROUP BY
		[Res].[AccPtr],
		CASE @HandleCostCenters
			WHEN 1 THEN ISNULL(Res.[CostGuid], 0x0)
			ELSE 0x0
		END,
		[ac].[acWarn],
		Res.[CustGuid]

	SET @SQL = '
	SELECT
		[ac].[acGUID] AS [AccPtr],
		[ac].[acCode] AS [AccCode],
		[ac].[acName] AS [AccName],
		[ac].[acLatinName] AS [AccLName], 
		ISNULL([co].CostCode, '''') AS [CostCode],
		ISNULL([co].CostName, '''') AS [CostName],
		ISNULL([co].CostLatinName, '''') AS [CostLName],
		ISNULL([co].CostGuid, 0x0) AS [CostGUID], 

		[cu].[cuGUID] AS [CustPtr],
		[cu].[cuCustomerName] AS [CustName],
		[cu].[cuLatinName] AS [CustLName], '

	SET @Sql = @Sql + '
		[dbo].[fnCurrency_fix]( [ac].[acMaxDebit], [ac].[acCurrencyPtr], [ac].[acCurrencyVal], ''' + CAST( @CurGUID AS NVARCHAR(250)) + ''', ''' + CAST( @EndDate AS NVARCHAR(250)) + ''') AS [AccMaxDebit],
		[ac].[acWarn] AS [AccWarn],
		ISNULL( [Res].[Balance],0) AS [Balance] '

	SET @Sql = @Sql + 
	' FROM 
		[#EndResult] AS [Res]
		INNER JOIN [VWAC] AS [ac] ON [Res].[AccPtr] = [ac].[acGuid] 
		LEFT JOIN [#Cost_Tbl] AS [Co] ON [Res].[CostGUID] = [Co].[CostGUID] 
		LEFT JOIN [vwCu] As [cu] ON [cu].[cuAccount] = [ac].[acGuid] AND [Res].[CustGuid] = [cu].[cuGUID]'
-------------------------------------------------------------------------------------------------------
	SET @Sql = @Sql + ' WHERE '
	
	IF @OperationType = 2 AND  @Balance > 0
		SET @Sql=@SQL + ' [Balance] > 0 AND [Balance] <= ''' + CAST((@Balance) AS NVARCHAR(250)) + ''' AND ' 

	IF @OperationType = 2 AND  @Balance < 0
		SET @Sql=@SQL + ' [Balance] < 0 AND [Balance] >= ''' + CAST((@Balance) AS NVARCHAR(250)) + ''' AND ' 

	SET @Sql = @Sql + '    
		( ''' + CAST(@Type AS NVARCHAR(250)) + '''  =  ''' + CAST(@AllAcc AS NVARCHAR(250)) + ''')    
		OR ( ''' + CAST(@Type AS NVARCHAR(250)) + ''' = ''' + CAST(@DebitAcc AS NVARCHAR(250)) + ''' AND ( [Res].[Debit] - [Res].[Credit]) > 0)
		OR ( ''' + CAST(@Type AS NVARCHAR(250)) + ''' = ''' + CAST(@CreditAcc AS NVARCHAR(250)) + ''' AND ( [Res].[Debit] - [Res].[Credit]) < 0) '

	IF @OperationType = 2
		SET @Sql = @Sql + ' ORDER BY [Balance] '
	ELSE 
		SET @Sql = @Sql + ' ORDER BY [ac].[acCode], [cu].[cuCustomerName], [Balance] '
	
	EXEC (@Sql)
	SELECT * FROM [#SecViol]  	  	
################################################################################
#END
	

