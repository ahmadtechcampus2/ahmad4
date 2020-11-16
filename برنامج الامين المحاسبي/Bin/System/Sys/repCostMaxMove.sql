#######################################################
CREATE PROCEDURE repCostMaxMove
	@StartDate AS [DATETIME], 	
	@EndDate AS [DATETIME], 	
	@Gr AS [UNIQUEIDENTIFIER], 	
	@Mat AS [UNIQUEIDENTIFIER], 
	@Store AS [UNIQUEIDENTIFIER],
	@Acc AS [UNIQUEIDENTIFIER],
	@Cost AS [UNIQUEIDENTIFIER],
	@CurPtr AS [UNIQUEIDENTIFIER],
	@CurVal AS [INT],		
	@Src AS [UNIQUEIDENTIFIER], 
	@Contain AS [NVARCHAR](200),	
	@NotContain AS [NVARCHAR](200),	
	@CntCost AS [INT], 
	@ReportType AS [INT], 
	@in_out AS [INT],
	@Post	[INT] = -1,
	@BillCondGuid AS [UNIQUEIDENTIFIER] = 0x00,
	@CustCondGuid AS [UNIQUEIDENTIFIER] = 0x00,
	@MatCondGuid AS [UNIQUEIDENTIFIER] = 0x00,
	@ReportType2 AS [INT] = 0,
	@ReportType3 AS [INT] = 0
AS  
	SET NOCOUNT ON
	DECLARE @MAXVAL AS [INT] 
	DECLARE @MAXMOVE	 AS [INT] 
	DECLARE @MAXQTY AS [INT] 
	SET @MAXQTY 	= 0 	
	SET @MAXMOVE	= 1 	
	SET @MAXVAL 	= 2 	
	-------------------------------------------------------------------------- 
	CREATE TABLE [#Src] ( [Type] [UNIQUEIDENTIFIER], [Sec] [INT], [ReadPrice] [INT], [UnPostedSec] [INT]) 
	INSERT INTO [#Src] EXEC [prcGetBillsTypesList2] @Src
	-------------  
	CREATE TABLE [#Mat] ( [mtGUID] [UNIQUEIDENTIFIER], [mtSecurity] [INT])  
	INSERT INTO [#Mat] EXEC [prcGetMatsList]  @Mat, @Gr,-1,@MatCondGuid 
	------------- 
	CREATE TABLE [#Store] ( [stGUID] [UNIQUEIDENTIFIER])  
	INSERT INTO [#Store] SELECT [GUID] FROM [fnGetStoresList]( @Store)  
	-------------
	CREATE TABLE [#CustTbl] ( [cuGUID] [UNIQUEIDENTIFIER], [cuSecurity] [INT])
	INSERT INTO [#CustTbl] EXEC [prcGetCustsList] DEFAULT, @Acc,@CustCondGuid
	IF @Acc = 0x0
		INSERT INTO [#CustTbl] SELECT 0x0, 1
	------------	
	 CREATE TABLE #BillCond
	  ( 
            [buGuid] [UNIQUEIDENTIFIER], 
            [biGuid] [UNIQUEIDENTIFIER]
	  ) 
	
	    DECLARE @Sql1 NVARCHAR(max), @Criteria NVARCHAR(2000) 
	    SET @Sql1 = 'INSERT INTO #BillCond SELECT [buGuid],[biGuid] FROM vwBuBi_Address ' 
		DECLARE @CurrencyGUID UNIQUEIDENTIFIER
		SET @CurrencyGUID = (SELECT TOP 1 [guid] FROM [my000] WHERE [CurrencyVal] = 1)
		SET @Criteria = [dbo].[fnGetBillConditionStr] (NULL, @BillCondGuid, @CurrencyGUID) 
		IF @Criteria <> ''
			SET @Criteria = ' WHERE (' + @Criteria + ') ' 
		SET @Sql1 = @Sql1 + @Criteria 
		EXEC(@Sql1)
	-------------------------------------------------
	CREATE TABLE [#CostTbl] ([GUID] [UNIQUEIDENTIFIER])  
	INSERT INTO [#CostTbl]  SELECT [GUID] FROM [dbo].[fnGetCostsList](@Cost) 
	IF ISNULL(@Cost, 0x0) = 0x0
		INSERT INTO [#CostTbl] VALUES(0x0)
	-----------
	CREATE TABLE [#SecViol]([Type] [INT], [Cnt] [INT])

	CREATE TABLE [#Result] ( 
						[coGUID] [UNIQUEIDENTIFIER], 
						[buCount] [INT],
						[QtyIn] [FLOAT], 
						[QtyOut] [FLOAT], 
						[PriceIn] [FLOAT], 
						[PriceOut] [FLOAT], 
						[Security] [INT], 
						[UserSecurity] [INT],
						[Direction] [INT],
						[MaxDate] [DATETIME])
	-------------------------------------------------------
	SELECT
			[Bill].[BiCostPtr] AS BuCostPtr,
			[Bill].[BuType],
			COUNT( DISTINCT CAST([Bill].[buGUID] AS NVARCHAR(40))) AS CstCnt,
			SUM(CASE [Bill].[btIsInput] WHEN 1 THEN ( [Bill].[BiQty] + [Bill].[BiBonusQnt])/ [Bill].[mtDefUnitFact] ELSE 0 END ) AS INQTY,
			SUM(CASE [Bill].[btIsOutput] WHEN 1 THEN ( [Bill].[BiQty] + [Bill].[BiBonusQnt])/ [Bill].[mtDefUnitFact] ELSE 0 END) AS OutQty,
			SUM(CASE [Bill].[btIsInput] WHEN 1 THEN ( [Bill].[BiQty] * ( [Bill].[FixedBiUnitPrice] - [FixedbiUnitDiscount] + [FixedbiUnitExtra]) +ISNULL([FixedBiVat],0) ) ELSE 0 END) InPrice,
			SUM(CASE [Bill].[btIsOutput] WHEN 1 THEN ( [Bill].[BiQty] * ( [Bill].[FixedBiUnitPrice] - [FixedbiUnitDiscount] + [FixedbiUnitExtra])+ ISNULL([FixedBiVat],0) ) ELSE 0 END ) OutPrice,
			[Bill].[buSecurity],
			[Bill].[buIsPosted],
			[buDirection],
			MAX([buDate]) AS MaxDate
		INTO #Bu
		FROM
			[dbo].[fnExtended_bi_Fixed](  @CurPtr ) AS [Bill]
			INNER JOIN [#Mat] AS [mt] ON [Bill].[BiMatPtr] = [mt].[mtGUID]
			INNER JOIN [#CustTbl] AS [cust] ON [Bill].[buCustPtr] = [cust].[cuGUID]
			INNER JOIN [#Store] AS [store] ON [Bill].[BiStorePtr] = [store].[stGUID]
			INNER JOIN [#CostTbl] AS [cost] ON [Bill].[BiCostPtr] = [cost].[GUID]
			INNER JOIN [#BillCond] AS [Bi] ON  [Bill].[biGUID] = [Bi].[biGuid]
		WHERE
			(( @Post   = -1 ) OR ((@Post  = 1 ) AND ([Bill].[buIsPosted] = 1)) OR (( @Post = 0 ) AND ([Bill].[buIsPosted] = 0)))
			AND [Bill].[buDate] BETWEEN @StartDate AND @EndDate 
			AND ( (@NotContain = '') OR ( [Bill].[BuNotes] NOT Like '%'+ @NotContain +'%' AND [Bill].[BiNotes] NOT Like '%'+ @NotContain +'%' ))
			AND ( (@Contain = '') OR ( [Bill].[BuNotes] Like '%'+ @Contain +'%' OR [Bill].[BiNotes] Like '%'+ @Contain +'%' )) 

		GROUP BY 
			[Bill].[BiCostPtr],
			[Bill].[BuType],
			[Bill].[buSecurity],
			[Bill].[buIsPosted],
			[buDirection]

	INSERT INTO [#Result]
		SELECT
			[Bill].[buCostPtr],
			CstCnt,
			INQTY,
			OutQty,
			InPrice,
			OutPrice,
			[Bill].[buSecurity],
			CASE [Bill].[buIsPosted] WHEN 1 THEN [Src].[Sec] ELSE [Src].[UnPostedSec] END,
			[buDirection],
			MaxDate
		FROM
			#Bu AS [Bill]
			INNER JOIN [#Src] AS [Src] ON [Bill].[BuType] = [Src].[Type]
		
		----------------------------
		EXEC [prcCheckSecurity]
		----------------------------	
	SELECT
		[Res].[coGUID] As [coGUID],
		[Co].[coCode] + '-' + CASE [dbo].fnConnections_GetLanguage() WHEN 0 THEN [Co].[coName] WHEN 1 THEN CASE [Co].[coLatinName] WHEN '''' THEN [Co].[coName] ELSE [Co].[coLatinName] END END AS [coName],
		CASE
			WHEN  @ReportType = @MAXQTY THEN
				SUM(CASE( @in_out) 
					WHEN 0 THEN ( [Res].[QtyOut] + [Res].[QtyIn])  
					WHEN 1 THEN ( [Res].[QtyIn]  - [Res].[QtyOut]) 
					WHEN 2 THEN ( [Res].[QtyOut] - [Res].[QtyIn])  END)
			WHEN @ReportType = @MAXVAL THEN	
				SUM(case ( @in_out) 
					WHEN 0 THEN ( [Res].[PriceOut] + [Res].[PriceIn])  
					WHEN 1 THEN ( [Res].[PriceIn]  - [Res].[PriceOut])
					WHEN 2 THEN ( [Res].[PriceOut] - [Res].[PriceIn]) END)
			WHEN @ReportType = @MAXMOVE AND @in_out = 0 THEN
				SUM([buCount])
			WHEN @ReportType = @MAXMOVE AND @in_out = 1 THEN
				SUM([buCount]*[Direction]) 
			WHEN @ReportType = @MAXMOVE AND @in_out = 2 THEN
				SUM([buCount]*[Direction]) * -1
			ELSE 0
		END AS [Result],
		CASE
			WHEN  @ReportType2 = @MAXQTY THEN
				SUM(CASE( @in_out) 
					WHEN 0 THEN ( [Res].[QtyOut] + [Res].[QtyIn])  
					WHEN 1 THEN ( [Res].[QtyIn]  - [Res].[QtyOut]) 
					WHEN 2 THEN ( [Res].[QtyOut] - [Res].[QtyIn])  END)
			WHEN @ReportType2 = @MAXVAL THEN	
				SUM(case ( @in_out) 
					WHEN 0 THEN ( [Res].[PriceOut] + [Res].[PriceIn])  
					WHEN 1 THEN ( [Res].[PriceIn]  - [Res].[PriceOut])
					WHEN 2 THEN ( [Res].[PriceOut] - [Res].[PriceIn]) END)
			WHEN @ReportType2 = @MAXMOVE AND @in_out = 0 THEN
				SUM([buCount])
			WHEN @ReportType = @MAXMOVE AND @in_out = 1 THEN
				SUM([buCount]*[Direction]) 
			WHEN @ReportType2 = @MAXMOVE AND @in_out = 2 THEN
				SUM([buCount]*[Direction]) * -1
			ELSE 0
		END AS [Result2],
		CASE
			WHEN  @ReportType3 = @MAXQTY THEN
				SUM(CASE( @in_out) 
					WHEN 0 THEN ( [Res].[QtyOut] + [Res].[QtyIn])  
					WHEN 1 THEN ( [Res].[QtyIn]  - [Res].[QtyOut]) 
					WHEN 2 THEN ( [Res].[QtyOut] - [Res].[QtyIn])  END)
			WHEN @ReportType3 = @MAXVAL THEN	
				SUM(case ( @in_out) 
					WHEN 0 THEN ( [Res].[PriceOut] + [Res].[PriceIn])  
					WHEN 1 THEN ( [Res].[PriceIn]  - [Res].[PriceOut])
					WHEN 2 THEN ( [Res].[PriceOut] - [Res].[PriceIn]) END)
			WHEN @ReportType3 = @MAXMOVE AND @in_out = 0 THEN
				SUM([buCount])
			WHEN @ReportType3 = @MAXMOVE AND @in_out = 1 THEN
				SUM([buCount]*[Direction]) 
			WHEN @ReportType3 = @MAXMOVE AND @in_out = 2 THEN
				SUM([buCount]*[Direction]) * -1
			ELSE 0
		END AS [Result3],
		MAX([MaxDate]) AS [MaxDate]
	INTO #CO
	FROM 
		[#Result] AS [Res]
		 inner join [vwco] AS [Co]
		on [Res].[coGUID] = [Co].[coGUID]
	GROUP BY 
		[Res].[coGUID],
		[Co].[coName],
		[Co].[coLatinName],
		[Co].[coCode]
	
	CREATE INDEX SDF ON #CO([Result],[Result2],[Result3])
	DECLARE @Sql NVARCHAR(max)
	SET @Sql = 'SELECT '
	IF @CntCost > 0
		SET @Sql = @Sql  + ' TOP ' + CAST ( @CntCost  AS NVARCHAR(20))
	SET @Sql = @Sql  + ' Co.* FROM #Co Co ORDER BY  [Result] desc'
	IF @ReportType2 > = 0 
		SET @Sql = @Sql  + ', [Result2] desc'
	IF @ReportType3 > = 0 
		SET @Sql = @Sql  + ', [Result3] desc '
	EXEC (@Sql)
	SELECT * FROM [#SecViol]
/*
prcConnections_add2 '„œÌ—'
[repCostMaxMove] '1/1/2008 0:0:0.0', '12/31/2009 23:59:59.998', '00000000-0000-0000-0000-000000000000', '00000000-0000-0000-0000-000000000000', '00000000-0000-0000-0000-000000000000', '00000000-0000-0000-0000-000000000000', 'b6f289c6-1e75-4098-949e-79512d87d77c', 1.000000, '74f38176-1ea5-42d4-b1a4-a632c4aad625', '', '', 3, 1, 0, 1, '00000000-0000-0000-0000-000000000000', '00000000-0000-0000-0000-000000000000', '00000000-0000-0000-0000-000000000000', 0, 2, 0
*/

###########################################################
#END