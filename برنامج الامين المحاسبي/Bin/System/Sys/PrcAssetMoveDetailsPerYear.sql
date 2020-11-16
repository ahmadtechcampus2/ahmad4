######################################################
CREATE PROCEDURE PrcAssetMoveDetailsPerYear
	@AssetDetailGuid	UNIQUEIDENTIFIER,
	@StartDate			DATETIME,
	@EndDate			DATETIME,
	@SrcsFlag			INT			
AS
BEGIN
	SET NOCOUNT ON;
	
	DECLARE @Lang [INT];
	SET @Lang = dbo.fnConnections_GetLanguage();

	CREATE TABLE [#SecViol]( [Type] [INT], [Cnt] [INTEGER]) 

	CREATE TABLE #Result(
		[buGuid]			UNIQUEIDENTIFIER,
		[Type]				INT,
		[TypeName]			NVARCHAR(250) COLLATE ARABIC_CI_AI,
		[Num]				NVARCHAR(250),
		[Date]				DATETIME,
		[Value]				FLOAT,
		[MoveType]			INT,
		[Spec]				NVARCHAR(250) COLLATE ARABIC_CI_AI,
		[StoreGuid]			UNIQUEIDENTIFIER,
		[CostGuid]			UNIQUEIDENTIFIER,
		[BranchGuid]		UNIQUEIDENTIFIER,	
		[StoreName]			NVARCHAR(250) COLLATE ARABIC_CI_AI,
		[CostName]			NVARCHAR(250) COLLATE ARABIC_CI_AI,
		[BranchName]		NVARCHAR(250) COLLATE ARABIC_CI_AI,
		[apSecurity]		INT,
		[addSecurity]		INT,
		[dedSecurity]		INT,
		[mainSecurity]		INT,
		[conSecurity]		INT,
		[dpSecurity]		INT,
		[asdSecurity]		INT	
	)
--------- Detailed Result2 ---------
	--ÅÖÇÝÉ Úáì ÃÕá, ÇÓÊÈÚÇÏ ãä ÃÕá, ÕíÇäÉ Úáì ÃÕá
	IF (((@SrcsFlag & 0x004) > 0) OR ((@SrcsFlag & 0x008) > 0) OR ((@SrcsFlag & 0x010) > 0))
	BEGIN
		INSERT INTO #Result(
				[buGuid],[Type],[Num],[Date],[Value],[Spec],[CostGuid],[BranchGuid],[addSecurity],[dedSecurity],[mainSecurity]
				)
		SELECT  [ax].[axGUID],
				CASE [ax].[axType] WHEN 0 THEN 0x004 WHEN 1 THEN 0x008 ELSE 0x010 END,
				[ax].[axNumber],
				[ax].[axDate],
				[ax].[axValue],
				[ax].[axSpec],
				ISNULL([ax].[axCostGuid], 0x0),
				ISNULL([ax].[axBranchGuid], 0x0),
				CASE [ax].[axType] WHEN 0 THEN [ax].[axSecurity] END,
				CASE [ax].[axType] WHEN 1 THEN [ax].[axSecurity] END,
				CASE [ax].[axType] WHEN 2 THEN [ax].[axSecurity] END
		  FROM	vwAd AS [ad] 
				INNER JOIN vwAx AS [ax] ON [ax].[axAssDetailGUID] = [ad].[adGuid]
		 WHERE  (([ax].[axType] = 0 AND (@SrcsFlag & 0x004) > 0)
				OR ([ax].[axType] = 1 AND (@SrcsFlag & 0x008) > 0)
				OR ([ax].[axType] = 2 AND (@SrcsFlag & 0x010) > 0))
				AND [ax].[axDate] <= @EndDate AND [ax].[axDate] >= @StartDate
				AND [ad].[adGuid] = @AssetDetailGuid
	END
	
	-- ãÐßÑÉ ÅÎÇÌ ãä ÃÕá
	IF (@SrcsFlag & 0x080) > 0
	BEGIN
		INSERT INTO #Result(
			[buGuid],[Type],[Num],[Date],[Value],[Spec],[StoreGuid],[CostGuid],[BranchGuid]
		)
		SELECT	[ex].[Guid],
				0x080,
				[ed].[Number],
				[ex].[Date],
				[ed].[Price],
				CASE ISNULL([ed].[Notes], '') WHEN '' THEN [ex].[Notes] ELSE [ed].[Notes] END,
				CASE ISNULL([ed].[storeGuid], 0x0) WHEN 0x0 THEN ISNULL([ex].[StoreGuid], 0x0) ELSE [ed].[storeGuid] END,
				CASE ISNULL([ed].[costGuid], 0x0) WHEN 0x0 THEN ISNULL([ex].[CostGuid], 0x0) ELSE [ed].[costGuid] END,
				ISNULL([ex].[BranchGuid], 0x0)
		  FROM  vwAd AS [ad]
			    INNER JOIN AssetExcludeDetails000 AS [ed] ON [ed].[adGuid] = [ad].[adGuid]
				INNER JOIN vbassetExclude AS [ex] ON [ex].[Guid] = [ed].[ParentGuid]
		 WHERE  [ex].[Date] <= @EndDate AND [ex].[Date] >= @StartDate
				AND [ad].[adGuid] = @AssetDetailGuid 
	END

	-- ãÐßÑÉ ÇåÊáÇß
	IF (@SrcsFlag & 0x002) > 0
	BEGIN
		INSERT INTO #Result(
			[buGuid],[Type],[Num],[Date],[Value],[Spec],[StoreGuid],[CostGuid],[BranchGuid],[dpSecurity]
		)
		SELECT  [dp].[GUID],
				0x002,
				[dp].[Number],
				[dp].[Date],
				[dd].[Value],
				[dp].[Notes],
				CASE ISNULL([dd].[StoreGUID], 0x0) WHEN 0x0 THEN ISNULL([dp].[StoreGuid], 0x0) ELSE [dd].[StoreGUID] END,
				CASE ISNULL([dd].[CostGUID], 0x0) WHEN 0x0 THEN ISNULL([dp].[CostGUID], 0x0) ELSE [dd].[CostGUID] END,
				ISNULL([dp].[BranchGUID], 0x0),
				[dp].[Security] 			
 		  FROM  vwAd AS [ad]
				INNER JOIN dd000 AS [dd] ON [dd].[ADGUID] = [ad].[adGuid]
				INNER JOIN vbDP AS [dp] ON [dp].[GUID] = [dd].[ParentGUID]
		 WHERE  [dp].[Date] <= @EndDate AND [dp].[Date] >= @StartDate
				AND [ad].[adGuid] = @AssetDetailGuid
	END

	-- ãÐßÑÉ ÇÓÊáÇã æ ÊÓáíã
	IF (@SrcsFlag & 0x020) > 0
	BEGIN
		INSERT INTO #Result(
			[buGuid],[Type],[Num],[Date],[MoveType],[Spec],[StoreGuid],[BranchGuid],[apSecurity]
		)
		SELECT  [ap].[GUID],
				0x020,
				[ap].[Number],
				[ap].[Date],
				[ap].[OperationType],
				CASE @Lang WHEN 0 THEN [ae].[Name] ELSE (CASE [ae].[LatinName] WHEN N'' THEN [ae].[Name] ELSE [ae].[LatinName] END) END,	
				CASE [ap].[OperationType] WHEN 1 THEN [ap].[OutStoreGuid] ELSE [ap].[InStoreGuid] END,
				[ap].[Branch],
				[ap].[Security]
		  FROM  vwAd AS [ad]
				INNER JOIN AssetPossessionsFormItem000 AS [api] ON [api].[AssetGuid] = [ad].[adGuid]
				INNER JOIN AssetPossessionsForm000 AS [ap] ON [ap].[GUID] = [api].[ParentGuid]
				INNER JOIN vbAssetEmployee AS [ae] ON [ae].[GUID] = [ap].[Employee] 
		 WHERE  [ap].[Date] <= @EndDate AND [ap].[Date] >= @StartDate
				AND [ad].[adGuid] = @AssetDetailGuid
				AND ISNULL([ap].[ParentGuid], 0x0) = 0x0  
	END

	-- ÚÞÏ ÇÓÊËãÇÑ
	IF (@SrcsFlag & 0x040) > 0
	BEGIN
		INSERT INTO #Result(
			[buGuid],[Type],[Num],[Date],[MoveType],[Spec],[StoreGuid],[BranchGuid],[conSecurity]
		)
		SELECT  [con].[GUID],
				0x040,
				[con].[Number],
				[con].[Date],
				3,					--ÚÞÏ	
				CASE @Lang WHEN 0 THEN [cu].[cuCustomerName] ELSE (CASE [cu].[cuLatinName] WHEN N'' THEN [cu].[cuCustomerName] ELSE [cu].[cuLatinName] END) END,
				[con].[SourceStore],
				[con].[Branch],
				[con].[Security] 
		  FROM  vwAd AS [ad]
				INNER JOIN AssetUtilizeContract000 AS [con] ON [con].[Asset] = [ad].[adGuid]
				INNER JOIN vwCu AS [cu] ON [cu].[cuGUID] = [con].[Customer]
		 WHERE  [con].[Date] <= @EndDate AND [con].[Date] >= @StartDate
				AND [ad].[adGuid] = @AssetDetailGuid
		 UNION
		SELECT  [con].[GUID],
				0x040,
				[con].[Number],
				[con].[CloseDate],
				4,					-- ÅÛáÇÞ ÚÞÏ 	
				CASE @Lang WHEN 0 THEN [cu].[cuCustomerName] ELSE (CASE [cu].[cuLatinName] WHEN N'' THEN [cu].[cuCustomerName] ELSE [cu].[cuLatinName] END) END,
				[con].[DestinationStore],
				[con].[Branch],
				[con].[Security] 
		  FROM  vwAd AS [ad]
				INNER JOIN AssetUtilizeContract000 AS [con] ON [con].[Asset] = [ad].[adGuid]
				INNER JOIN vwCu AS [cu] ON [cu].[cuGUID] = [con].[Customer]
		 WHERE	[con].[IsCloseDateActive] = 1
				AND [con].[CloseDate] <= @EndDate AND [con].[CloseDate] >= @StartDate
				AND [ad].[adGuid] = @AssetDetailGuid
	END

	-- ÚåÏÉ Ãæá ÇáãÏÉ
	IF (@SrcsFlag & 0x100) > 0
	BEGIN
		INSERT INTO #Result(
			[buGuid],[Type],[Num],[Date],[MoveType],[Spec],[BranchGuid],[asdSecurity]
		) 
		SELECT  [ap].[ParentGuid],
				0x100,
				[asd].[Number],
				[ap].[Date],
				[ap].[OperationType],
				CASE @Lang WHEN 0 THEN [ae].[Name] ELSE (CASE [ae].[LatinName] WHEN N'' THEN [ae].[Name] ELSE [ae].[LatinName] END) END,
				[ap].[Branch],
				[ap].[Security]			
		  FROM  vwAd AS [ad]
				INNER JOIN AssetPossessionsFormItem000 AS [api] ON [api].[AssetGuid] = [ad].[adGuid]
				INNER JOIN AssetPossessionsForm000 AS [ap] ON [ap].[GUID] = [api].[ParentGuid]
				INNER JOIN AssetStartDatePossessions000 AS [asd] ON [asd].[GUID] = [ap].[ParentGuid]
				INNER JOIN vbAssetEmployee AS [ae] ON [ae].[GUID] = [ap].[Employee] 
		 WHERE  [ad].[adGuid] = @AssetDetailGuid
	END

	-- ÇáÝæÇÊíÑ Ãæ ÇáãäÇÞáÉ ÇáÚÇÏíÉ Ãæ ãäÇÞáÉ ÃÕæá
	IF (@SrcsFlag & 0x001) > 0
	BEGIN
		INSERT INTO #Result(
			[buGuid],[Type],[TypeName],[Num],[Date],[Value],[Spec],[StoreGuid],[CostGuid],[BranchGuid]
		)
		SELECT  [b].[buGUID],
				0x001,
				CASE @Lang WHEN 0 THEN [bt].[btAbbrev] ELSE (CASE [bt].[btLatinAbbrev] WHEN '' THEN [bt].[btAbbrev] ELSE [bt].[btLatinAbbrev] END) END,
				[b].[buNumber],
				[b].[buDate],
				[b].[biUnitPrice] + [b].[biUnitExtra] - [b].[biUnitDiscount],
				CASE ISNULL([b].[biNotes], '') WHEN '' THEN [b].[buNotes] ELSE [b].[biNotes] END,
				CASE ISNULL([b].[biStorePtr], 0x0) WHEN 0x0 THEN ISNULL([b].[buStorePtr], 0x0) ELSE [b].[biStorePtr] END,
				CASE ISNULL([b].[biCostPtr], 0x0) WHEN 0x0 THEN ISNULL([b].[buCostPtr], 0x0) ELSE [b].[biCostPtr] END,
				ISNULL([b].[buBranch], 0x0)
		  FROM  vwAd AS [ad]
				INNER JOIN vwExtended_sn AS [b] ON [ad].[adSnGuid]  = [b].[snGuid] 
				INNER JOIN vwBt AS [bt] ON [bt].[btGUID] = [b].[buType]
		 WHERE  [b].[buGuid] NOT IN (
					SELECT [ex].[BillGuid] FROM vbassetExclude AS [ex]
					UNION SELECT [ap].[TransBillGuid] FROM AssetPossessionsForm000 AS [ap]
					UNION SELECT [ts].[InBillGUID] FROM AssetPossessionsForm000 AS [ap] INNER JOIN ts000 AS [ts] ON [ts].[OutBillGUID] = [ap].[TransBillGuid]
					UNION SELECT [con].[InBillGuid] FROM AssetUtilizeContract000 AS [con] 
					UNION SELECT [con].[OutBillGuid] FROM AssetUtilizeContract000 AS [con]
					UNION SELECT [con].[ClosureInBillGuid] FROM AssetUtilizeContract000 AS [con]
					UNION SELECT [con].[ClosureOutBillGuid] FROM AssetUtilizeContract000 AS [con]
				)
				AND [b].[buDate] <= @EndDate AND [b].[buDate] >= @StartDate
				AND [ad].[adGuid] = @AssetDetailGuid
				AND [b].[buIsPosted] = 1
				AND [b].[buSecurity] <= [dbo].[fnGetUserBillSec_Browse]([dbo].[fnGetCurrentUserGUID](), [b].[buType])
	END
	
	EXEC [prcCheckAssetSecurity] @result = #Result
	   
--------- Final Result ---------	
					
	SELECT DB_NAME() AS DataBaseName,
		   DB_ID() AS DatabaseId,
		   0,
		   [buGuid],	
		   [Type],
		   [TypeName],		
		   [Num],		
		   [Date],		
		   ISNULL([Value],0)	AS [Value],		
		   ISNULL([MoveType],0) AS [MoveType],	
		   [Spec],
		   CASE @Lang WHEN 0 THEN [st].[stName] ELSE (CASE [st].[stLatinName] WHEN N'' THEN [st].[stName] ELSE [st].[stLatinName] END) END AS [StoreName],	
		   CASE @Lang WHEN 0 THEN [co].[coName] ELSE (CASE [co].[coLatinName] WHEN N'' THEN [co].[coName] ELSE [co].[coLatinName] END) END AS [CostName],	
		   CASE @Lang WHEN 0 THEN [br].[brName] ELSE (CASE [br].[brLatinName] WHEN N'' THEN [br].[brName] ELSE [br].[brLatinName] END) END AS [BranchName]
	 FROM  #Result AS [r]
		   LEFT JOIN vwSt AS [st] ON [st].[stGUID] = [r].[StoreGuid]
		   LEFT JOIN vwCo AS [co] ON [co].[coGUID] = [r].[CostGuid]
		   LEFT JOIN vwBr AS [br] ON [br].[brGUID] = [r].[BranchGuid]
	 ORDER BY [r].[Date], [MoveType]

	 DROP TABLE #Result

END
######################################################
#END