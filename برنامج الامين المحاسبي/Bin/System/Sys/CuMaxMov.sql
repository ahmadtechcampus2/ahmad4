################################################################################
## «·“»«∆‰ «·√ﬂÀ— Õ—ﬂ…
CREATE PROCEDURE repCustMaxMove
	@StartDate AS [DATETIME], 	--????? ???????  
	@EndDate AS [DATETIME], 		--????? ???????  
	@Mat AS [UNIQUEIDENTIFIER], 	--??????  
	@Src AS [UNIQUEIDENTIFIER], 	--????? ??????????????  
	@Store AS [UNIQUEIDENTIFIER], 			--????????  
	@Gr AS [UNIQUEIDENTIFIER], 			--????????  
	@Acc AS [UNIQUEIDENTIFIER], 			--??????  
	@CurPtr AS [UNIQUEIDENTIFIER],         	--??????  
	@CurVal AS [INT],			--???????  
	@Contain AS [NVARCHAR](200),	--??????? ???????? ????  
	@NotContain AS [NVARCHAR](200),	--??????? ???????? ????  
	@in_out AS [INT],
	@CostGuid AS [UNIQUEIDENTIFIER],
	@Post	[INT] = 2,
	@CustCondGuid AS [UNIQUEIDENTIFIER] = 0x00,
	@MatCondGuid AS [UNIQUEIDENTIFIER] = 0x00
AS  
	SET NOCOUNT ON

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
	-------------
	DECLARE @Cost_Tbl TABLE( [GUID] [UNIQUEIDENTIFIER]) 
	INSERT INTO @Cost_Tbl  SELECT [GUID] FROM [dbo].[fnGetCostsList]( @CostGUID)  
	IF ISNULL( @CostGUID, 0x0) = 0x0   
		INSERT INTO @Cost_Tbl VALUES(0x0)  
	------------	
	CREATE TABLE [#SecViol]([Type] [INT], [Cnt] [INT])
	CREATE TABLE [#Result] ( 
						[cuGUID] [UNIQUEIDENTIFIER], 
						[buCount] [INT],
						[QtyIn] [FLOAT], 
						[QtyOut] [FLOAT], 
						[PriceIn] [FLOAT], 
						[PriceOut] [FLOAT], 
						[Security] [INT], 
						[CustSecurity] [INT], 
						[UserSecurity] [INT],
						[Direction] [INT],
						[MaxDate] [DATETIME])
	-------------------------------------------------------
	SELECT
			[Bill].[BuCustPtr],
			[Bill].[BuType],
			COUNT( DISTINCT CAST([Bill].[buGUID] AS NVARCHAR(40))) AS CstCnt,
			SUM(CASE [Bill].[btIsInput] WHEN 1 THEN ( [Bill].[BiQty] + [Bill].[BiBonusQnt])/ [Bill].[mtDefUnitFact] ELSE 0 END ) AS INQTY,
			SUM(CASE [Bill].[btIsOutput] WHEN 1 THEN ( [Bill].[BiQty] + [Bill].[BiBonusQnt])/ [Bill].[mtDefUnitFact] ELSE 0 END) AS OutQty,
			SUM(CASE [Bill].[btIsInput] WHEN 1 THEN ( [Bill].[BiQty] * ( [Bill].[FixedBiUnitPrice] - [FixedbiUnitDiscount] + [FixedbiUnitExtra]) +ISNULL([FixedBiVat],0) ) ELSE 0 END) InPrice,
			SUM(CASE [Bill].[btIsOutput] WHEN 1 THEN ( [Bill].[BiQty] * ( [Bill].[FixedBiUnitPrice] - [FixedbiUnitDiscount] + [FixedbiUnitExtra])+ ISNULL([FixedBiVat],0) ) ELSE 0 END ) OutPrice,
			[Bill].[buSecurity],
			[Bill].[buIsPosted],
			[buDirection],MAX([buDate]) AS MaxDate 
		INTO #Bu
		FROM
			[dbo].[fnExtended_bi_Fixed]( @CurPtr) AS [Bill]
			INNER JOIN [#Mat] AS [mt] ON [Bill].[BiMatPtr] = [mt].[mtGUID]
			INNER JOIN @Cost_Tbl AS [cost] ON [Bill].[biCostPtr] = [cost].[Guid]
			INNER JOIN [#Store] AS [store] ON [Bill].[BiStorePtr] = [store].[stGUID]
			
		WHERE 
			((@Post = -1 ) OR ((@Post = 1 ) AND ([Bill].[buIsPosted] = 1)) OR ((@Post = 0 ) AND ([Bill].[buIsPosted] = 0)))
			AND [Bill].[buCustPtr] <> 0x0
			AND [Bill].[buDate] BETWEEN @StartDate AND @EndDate 
			AND ( (@NotContain = '') OR ( [Bill].[BuNotes] NOT Like '%'+ @NotContain +'%' AND [Bill].[BiNotes] NOT Like '%'+ @NotContain +'%' ))
			AND ( (@Contain = '') OR ( [Bill].[BuNotes] Like '%'+ @Contain +'%' OR [Bill].[BiNotes] Like '%'+ @Contain +'%' )) 
		GROUP BY 
			[Bill].[BuCustPtr],
			[Bill].[BuType],
			[Bill].[buCustPtr],
			[Bill].[buSecurity],
			[Bill].[buIsPosted],
			[buDirection]
	INSERT INTO [#Result]
		SELECT
			[Bill].[buCustPtr],
			CstCnt,
			INQTY,
			OutQty,
			InPrice,
			OutPrice,
			[Bill].[buSecurity],
			[cst].[cuSecurity],
			CASE [Bill].[buIsPosted] WHEN 1 THEN [Src].[Sec] ELSE [Src].[UnPostedSec] END,
			[buDirection],MaxDate
		FROM
			#Bu AS [Bill]
			INNER JOIN [#CustTbl] AS [cst] ON [Bill].[BuCustPtr] = [cst].[cuGUID]
			INNER JOIN [#Src] AS [Src] ON [Bill].[BuType] = [Src].[Type]
			
		----------------------------
		EXEC [prcCheckSecurity]
		----------------------------	
	-- this will limit the number of returned values
	SELECT
		[Res].[cuGUID] As [cuGUID],
		[vwCu].[CustomerName] As [CuName],
		[vwCu].[LatinName] As [CuLatinName],
		SUM(CASE( @in_out) 
					WHEN 0 THEN ( [Res].[QtyOut] + [Res].[QtyIn])  
					WHEN 1 THEN ( [Res].[QtyIn]  - [Res].[QtyOut]) 
					WHEN 2 THEN ( [Res].[QtyOut] - [Res].[QtyIn])  END) AS [Result],
		SUM(case ( @in_out) 
					WHEN 0 THEN ( [Res].[PriceOut] + [Res].[PriceIn])  
					WHEN 1 THEN ( [Res].[PriceIn]  - [Res].[PriceOut])
					WHEN 2 THEN ( [Res].[PriceOut] - [Res].[PriceIn]) END) AS [Result2],
		case ( @in_out) 
					WHEN 0 THEN (SUM([buCount]))  
					WHEN 1 THEN (SUM([buCount]*[Direction]))
					WHEN 2 THEN ( SUM([buCount]*[Direction]) * -1) END AS [Result3],
		MAX([MaxDate]) AS [MaxDate]
	FROM 
		[#Result] AS [Res]
		INNER JOIN [cu000] [vwCu] ON [Res].[cuGUID] = [vwCu].[GUID]
	GROUP BY 
		[Res].[cuGUID],
		[vwCu].[CustomerName],
		[vwCu].[LatinName]

	SELECT * FROM [#SecViol]
/*
prcConnections_add2 '„œÌ—'
exec  [repCustMaxMove] '9/1/2007  0:0:0:0', '9/30/2007  0:0:0:0', '00000000-0000-0000-0000-000000000000', 0x00, '00000000-0000-0000-0000-000000000000', '00000000-0000-0000-0000-000000000000', '00000000-0000-0000-0000-000000000000', 'e43eae22-3187-493f-9a0f-3b919b3e41ed', 1.000000, '', '', 3, 2, 0, '00000000-0000-0000-0000-000000000000', 1, 0, -842150451 
*/

################################################################################
#END