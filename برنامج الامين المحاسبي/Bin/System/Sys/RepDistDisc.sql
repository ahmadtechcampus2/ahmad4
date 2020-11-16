##############################################
CREATE PROCEDURE repDistDisc
	@StartDate 		[DATETIME],
	@EndDate 		[DATETIME],
	@AccGUID 		[UNIQUEIDENTIFIER],
	@CostGUID 		[UNIQUEIDENTIFIER],
	@GroupFlag		[INT],				-- 0 no group, 1 group
	@GroupType		[INT],				-- 0 group by cost, 1 group by cust
	@SrctypesGUID	[UNIQUEIDENTIFIER],
	@CustType		[INT] = 0,			-- 1 Contracted, 2 NotContracted, 0 Both
	@bShowCustType	[INT] = 0
AS
	SET NOCOUNT ON

	CREATE TABLE [#SecViol]( [Type] [INT], [Cnt] [INTEGER])
	CREATE TABLE [#BillsTypesTbl]( [TypeGuid] [UNIQUEIDENTIFIER], [UserSecurity] [INTEGER], [UserReadPriceSecurity] [INTEGER])
	CREATE TABLE [#CustTable]( [cuGUID] [UNIQUEIDENTIFIER], [cuSec] [INT])
	CREATE TABLE [#CostTable]( [GUID] [UNIQUEIDENTIFIER])

	INSERT INTO [#BillsTypesTbl] EXEC [prcGetBillsTypesList] @SrcTypesguid
	INSERT INTO [#CustTable] EXEC [prcGetCustsList] NULL, @AccGUID
	INSERT INTO [#CostTable] SELECT [GUID] FROM [dbo].[fnGetCostsList]( @CostGUID)
	IF ISNULL( @CostGUID, 0x0) = 0x0
		INSERT INTO [#CostTable] VALUES(0x0)

	CREATE TABLE [#Result]
	(
		[buGUID]		[UNIQUEIDENTIFIER],
		[buItemsDisc]	[FLOAT],
		[buTotal]		[FLOAT],
		[CostGUID]		[UNIQUEIDENTIFIER],
		[CustGUID]		[UNIQUEIDENTIFIER]
	)

	CREATE TABLE [#AccRes]
	(
		[AccDiscGUID]		[UNIQUEIDENTIFIER],
		[AccDiscCode]		[NVARCHAR](1000) COLLATE Arabic_CI_AI,
		[AccDiscName]		[NVARCHAR](1000) COLLATE Arabic_CI_AI
	)

	CREATE TABLE [#Res]
	( 
		[buGUID]		[UNIQUEIDENTIFIER], 
		[CostGUID]		[UNIQUEIDENTIFIER], 
		[CustGUID]		[UNIQUEIDENTIFIER], 
		[AccDiscGUID]	[UNIQUEIDENTIFIER],
		[Disc]			[FLOAT] 
	) 

	CREATE TABLE [#EndResult]
	( 
		[buGUID]		[UNIQUEIDENTIFIER], 
		[buItemsDisc]	[FLOAT],
		[buTotal]		[FLOAT],
		[CostGUID]		[UNIQUEIDENTIFIER], 
		[CostCode]		[NVARCHAR](1000) COLLATE Arabic_CI_AI,
		[CostName]		[NVARCHAR](1000) COLLATE Arabic_CI_AI,
		[CustGUID]		[UNIQUEIDENTIFIER], 
		[CustName]		[NVARCHAR](1000) COLLATE Arabic_CI_AI
	) 


	INSERT INTO [#Result]
	SELECT 
		[bu].[buGUID],
		CASE [vw].[btIsOutput] 
			WHEN 1 THEN [bu].[buItemsDisc] 
			ELSE -([bu].[buItemsDisc]) 
		END,
		CASE [vw].[btIsOutput] 
			WHEN 1 THEN [bu].[buTotal] 
			ELSE -([bu].[buTotal]) 
		END,
		ISNULL([co].[GUID], 0X0),
		ISNULL([cu].[cuGUID], 0X0)
	FROM 
		[vwBu] [bu]
		INNER JOIN [vwBt] [vw] ON [vw].[btGUID] = [bu].[buType]
		INNER JOIN [#BillsTypesTbl] [bt] ON [bu].[buType] = [bt].[TypeGuid] 
		INNER JOIN [#CostTable] [co] ON [bu].[buCostPtr] = [co].[GUID]
		INNER JOIN [#CustTable] [cu] ON [cu].[cuGUID] = [bu].[buCustPtr]
		LEFT JOIN [DistCe000] [dce] ON [dce].[CustomerGUID] = [cu].[cuGUID]
	WHERE 
		[budate] BETWEEN @StartDate AND @EndDate
		AND 
		(( @CustType = 0) OR ((@CustType = 1) AND ( ISNULL([dce].[contracted], 0) = 1 )) OR (((@CustType = 2)) AND (ISNULL([dce].[contracted], 0) = 0)))
	
	EXEC [prcCheckSecurity]

	INSERT INTO [#Res]
	SELECT
		(CASE @GroupFlag
			WHEN 0 THEN [buGUID]
			ELSE 0X0
		END),
		(CASE @GroupFlag 
			WHEN 0 THEN [CostGUID]
			ELSE (CASE @GroupType WHEN 0 THEN [CostGUID] ELSE 0X0 END) 
		END),
		(CASE @GroupFlag
			WHEN 0 THEN [CustGUID] 
			ELSE (CASE @GroupType WHEN 0 THEN 0X0 ELSE [CustGUID] END) 
		END),
		[di].[diAccount],
		SUM( CASE WHEN [r].[buTotal] >= 0  THEN [di].[diDiscount] ELSE -[di].[diDiscount] END)
	FROM 
		[#Result] [r] 
		INNER JOIN [vwdi] [di] ON [r].[buGUID] = [di].[diParent]
	GROUP BY
		(CASE @GroupFlag
			WHEN 0 THEN [buGUID]
			ELSE 0X0
		END),
		(CASE @GroupFlag
			WHEN 0 THEN [CostGUID]
			ELSE (CASE @GroupType WHEN 0 THEN [CostGUID] ELSE 0X0 END)
		END),
		(CASE @GroupFlag
			WHEN 0 THEN [CustGUID]
			ELSE (CASE @GroupType WHEN 0 THEN 0X0 ELSE [CustGUID] END)
		END),
		[di].[diAccount]


	INSERT INTO [#EndResult]
	SELECT
		(CASE @GroupFlag
			WHEN 0 THEN [buGUID]
			ELSE 0X0
		END),
		SUM([buItemsDisc]),
		SUM([buTotal]),
		
		(CASE @GroupFlag 
			WHEN 0 THEN [CostGUID]
			ELSE (CASE @GroupType WHEN 0 THEN [CostGUID] ELSE 0X0 END) 
		END),
		'',
		'',
		(CASE @GroupFlag
			WHEN 0 THEN [CustGUID] 
			ELSE (CASE @GroupType WHEN 0 THEN 0X0 ELSE [CustGUID] END) 
		END),
		''
	FROM
		[#Result] [r] 
	GROUP BY
		(CASE @GroupFlag
			WHEN 0 THEN [buGUID]
			ELSE 0X0
		END),
		(CASE @GroupFlag
			WHEN 0 THEN [CostGUID]
			ELSE (CASE @GroupType WHEN 0 THEN [CostGUID] ELSE 0X0 END)
		END),
		(CASE @GroupFlag
			WHEN 0 THEN [CustGUID]
			ELSE (CASE @GroupType WHEN 0 THEN 0X0 ELSE [CustGUID] END)
		END)



	INSERT INTO [#AccRes]
	SELECT 
		DISTINCT [AccDiscGUID], 
		'', 
		'' 
	FROM 
		[#Res]


	UPDATE [#AccRes]
	SET 
		[AccDiscCode] = [ac].[acCode],
		[AccDiscName] = [ac].[acName]
	FROM
		[#AccRes] [ar]
		INNER JOIN [vwAc] [ac] ON [ar].[AccDiscGUID] = [ac].[acGUID]

	SELECT
		*
	FROM
		[#AccRes]
	ORDER BY
		[AccDiscCode], [AccDiscName]

	DECLARE @SQL NVARCHAR(max)
	SET @SQL = '
	SELECT
		ISNULL([e].[buGUID], 0X0) AS [buGUID],
		[e].[buItemsDisc] AS [buItemsDisc],
		[e].[buTotal] AS [buTotal],
		ISNULL([e].[CostGUID], 0X0) AS [CostGUID],
		ISNULL([co].[coCode], '''') AS [coCode],
		ISNULL([co].[coName], '''') AS [coName],
		ISNULL([e].[CustGUID], 0X0) AS [CustGUID],
		ISNULL([cu].[cuCustomerName], '''') AS [cuCustomerName],
		[s].[AccDiscGUID] AS [AccDiscGUID],
		[s].[Disc] AS [Disc] '

	IF @bShowCustType = 1
	SET @SQL = @SQL + '
	, ISNULL([dce].[Contracted], 0) AS [Contracted] '

	SET @SQL = @SQL + '	
	FROM
		[#EndResult] [e] '
	IF @GroupFlag = 0
	BEGIN
		SET @SQL = @SQL + '
		INNER JOIN [#RES] [s] ON [s].[buGUID] = [e].[buGUID] '
	END
	ELSE
	BEGIN
		IF @GroupType = 0
			SET @SQL = @SQL + '
			INNER JOIN [#RES] [s] ON [s].[CostGUID] = [e].[CostGUID] '
		ELSE
			SET @SQL = @SQL + '
			INNER JOIN [#RES] [s] ON [s].[CustGUID] = [e].[CustGUID] '
	END
	SET @SQL = @SQL + '
	INNER JOIN [#AccRes] [ac] ON [ac].[AccDiscGUID] = [s].[AccDiscGUID]
	LEFT JOIN [vwco] [co] ON [e].[CostGUID] = [co].[coGUID]
	LEFT JOIN [vwcu] [cu] ON [e].[CustGUID] = [cu].[cuGUID] '
	IF @bShowCustType = 1
		SET @SQL = @SQL + '
		LEFT JOIN [DistCe000] [dce] ON [dce].[CustomerGUID] = [e].[CustGUID] '

	SET @SQL = @SQL + '
	ORDER BY
		[co].[coCode],
		[co].[coName],
		[cu].[cuCustomerName],
		[ac].[AccDiscCode],
		[ac].[AccDiscName] '

	EXECUTE( @SQL)

/*
PRCcONNECTIONS_ADD2 '„œÌ—'

EXEC REPDISTDISC 
	'1/1/2005', 
	'12/12/2005', 
	0X0,
	0X0,
	1,
	0,	
	0X0
*/
################################################################################
#END
