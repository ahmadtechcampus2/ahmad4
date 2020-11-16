######################################################
CREATE PROCEDURE PrcAssetMoveReport
	@AssetDetailGuid	UNIQUEIDENTIFIER,
	@AssetGuid			UNIQUEIDENTIFIER,
	@GroupGuid			UNIQUEIDENTIFIER,
	@EndDate			DATETIME,
	@SrcsFlag			INT		
AS
BEGIN
	SET NOCOUNT ON;


	DECLARE @Lang [INT];
	SET @Lang = dbo.fnConnections_GetLanguage();
	
	CREATE TABLE [#SecViol]( [Type] [INT], [Cnt] [INTEGER]) 

	CREATE TABLE #SELECTEDASSETS (
		[asGuid]			UNIQUEIDENTIFIER,	
		[adGuid]			UNIQUEIDENTIFIER,
		[mtGuid]			UNIQUEIDENTIFIER,
		[asSecurity]		INT,
		[adSecurity]		INT,
		[mtSecurity]		INT
	)

	CREATE TABLE #CurrentValues(
		[adGuid]			UNIQUEIDENTIFIER,
		[CurAddVal]			FLOAT,
		[CurDedVal]			FLOAT,
		[CurDepVal]			FLOAT,
		[CurMainVal]		FLOAT
	)

	CREATE TABLE #MatTbl([mtGuid] UNIQUEIDENTIFIER , [mtSecurity] INT)

	INSERT INTO #MatTbl	
	  EXEC [prcGetMatsList] @AssetGuid, @GroupGuid,-1,0x0

	INSERT  INTO #SELECTEDASSETS ([asGuid], [adGuid], [mtGuid], [asSecurity], [adSecurity], [mtSecurity])
	SELECT  [as].[GUID],
			[ad].[adGuid],
			[mt].[mtGuid],
			[as].[Security],
			[ad].[adSecurity],
			[mt].[mtSecurity]
	  FROM 	vtAs AS [as] 
			INNER JOIN vwAd AS [ad] ON [as].[GUID] = [ad].[adAssGuid]
			INNER JOIN #MatTbl AS [mt] ON [mt].[mtGuid] = [as].[ParentGUID]
	 WHERE	(ISNULL(@AssetDetailGuid, 0x0) = 0x0 OR @AssetDetailGuid = [ad].[adGUID])
			AND ([ad].[adInDate] <= @EndDate)

	EXEC [prcCheckSecurity] @result = #SELECTEDASSETS
	EXEC [prcCheckAssetSecurity] @result = #SELECTEDASSETS

	INSERT INTO #CurrentValues([adGuid],[CurAddVal],[CurDedVal],[CurDepVal],[CurMainVal]) 
	SELECT [ad].[adGuid],0,0,0,0
	  FROM  #SELECTEDASSETS AS [ad]

	CREATE TABLE #MasterResult(
		[adGuid]			UNIQUEIDENTIFIER,
		[asName]			NVARCHAR(250),
		[adSN]				NVARCHAR(250),
		[adInDate]			DATETIME,
		[adInVal]			FLOAT,
		[adTotAddVal]		FLOAT,
		[adTotDedVal]		FLOAT,
		[adTotalVal]		FLOAT,
		[adTotDepVal]		FLOAT,
		[adCurTotalVal]		FLOAT,
		[adTotMainVal]		FLOAT,
		[adScrapVal]		FLOAT,
		[asLifeExp]			FLOAT,
		[adEmployee]		UNIQUEIDENTIFIER, 
		[adPosDate]			DATETIME 
	)

	CREATE TABLE #TotalsResult(
		[adGuid]			UNIQUEIDENTIFIER,
		[adSNGuid]			UNIQUEIDENTIFIER,
		[IsPrev]			BIT,
		[adAddedVal]		FLOAT,
		[adDeductVal]		FLOAT,
		[adDeprectaionVal]	FLOAT,
		[adMaintainVal]		FLOAT
	)

	CREATE TABLE #DetailedResult(
		[adGuid]			UNIQUEIDENTIFIER,
		[adSNGuid]			UNIQUEIDENTIFIER,
		[buGuid]			UNIQUEIDENTIFIER,
		[Type]				INT,
		[TypeName]			NVARCHAR(250),
		[Num]				NVARCHAR(250),
		[Date]				DATETIME,
		[Value]				FLOAT,
		[MoveType]			INT,
		[Spec]				NVARCHAR(250),
		[StoreGuid]			UNIQUEIDENTIFIER,
		[CostGuid]			UNIQUEIDENTIFIER,
		[BranchGuid]		UNIQUEIDENTIFIER,	
		[StoreName]			NVARCHAR(250),
		[CostName]			NVARCHAR(250),
		[BranchName]		NVARCHAR(250),
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
		INSERT INTO #DetailedResult(
				[adGuid],[adSNGuid],[buGuid],[Type],[Num],[Date],[Value],[Spec],[CostGuid],[BranchGuid],[addSecurity],[dedSecurity],[mainSecurity]
				)
		SELECT  [ad].[adGuid],
				[ad].[adSNGuid],
				[ax].[axGUID],
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
		  FROM	#SELECTEDASSETS AS [sa] 
				INNER JOIN vwAd AS [ad] ON [ad].[adGuid] = [sa].[adGuid]
				INNER JOIN vwAx AS [ax] ON [ax].[axAssDetailGUID] = [ad].[adGuid]
		 WHERE  (([ax].[axType] = 0 AND (@SrcsFlag & 0x004) > 0)
				OR ([ax].[axType] = 1 AND (@SrcsFlag & 0x008) > 0)
				OR ([ax].[axType] = 2 AND (@SrcsFlag & 0x010) > 0))
				AND [ax].[axDate] <= @EndDate 
	END
	
	-- ãÐßÑÉ ÅÎÇÌ ãä ÃÕá
	IF (@SrcsFlag & 0x080) > 0
	BEGIN
		INSERT INTO #DetailedResult(
			[adGuid],[adSNGuid],[buGuid],[Type],[Num],[Date],[Value],[Spec],[StoreGuid],[CostGuid],[BranchGuid]
		)
		SELECT	[ad].[adGuid],
				[ad].[adSNGuid],
				[ex].[Guid],
				0x080,
				[ed].[Number],
				[ex].[Date],
				[ed].[Price],
				CASE ISNULL([ed].[Notes], '') WHEN '' THEN [ex].[Notes] ELSE [ed].[Notes] END,
				CASE ISNULL([ed].[storeGuid], 0x0) WHEN 0x0 THEN ISNULL([ex].[StoreGuid], 0x0) ELSE [ed].[storeGuid] END,
				CASE ISNULL([ed].[costGuid], 0x0) WHEN 0x0 THEN ISNULL([ex].[CostGuid], 0x0) ELSE [ed].[costGuid] END,
				ISNULL([ex].[BranchGuid], 0x0)
		  FROM  #SELECTEDASSETS AS [sa] 
				INNER JOIN vwAd AS [ad] ON [ad].[adGuid] = [sa].[adGuid]
			    INNER JOIN AssetExcludeDetails000 AS [ed] ON [ed].[adGuid] = [ad].[adGuid]
				INNER JOIN vbassetExclude AS [ex] ON [ex].[Guid] = [ed].[ParentGuid]
		 WHERE  [ex].[Date] <= @EndDate  
	END

	-- ãÐßÑÉ ÇåÊáÇß
	IF (@SrcsFlag & 0x002) > 0
	BEGIN
		INSERT INTO #DetailedResult(
			[adGuid],[adSNGuid],[buGuid],[Type],[Num],[Date],[Value],[Spec],[StoreGuid],[CostGuid],[BranchGuid],[dpSecurity]
		)
		SELECT  [ad].[adGuid],
				[ad].[adSNGuid],
				[dp].[GUID],
				0x002,
				[dp].[Number],
				[dp].[Date],
				[dd].[Value],
				[dp].[Notes],
				CASE ISNULL([dd].[StoreGUID], 0x0) WHEN 0x0 THEN ISNULL([dp].[StoreGuid], 0x0) ELSE [dd].[StoreGUID] END,
				CASE ISNULL([dd].[CostGUID], 0x0) WHEN 0x0 THEN ISNULL([dp].[CostGUID], 0x0) ELSE [dd].[CostGUID] END,
				ISNULL([dp].[BranchGUID], 0x0),
				[dp].[Security] 			
 		  FROM  #SELECTEDASSETS AS [sa] 
				INNER JOIN vwAd AS [ad] ON [ad].[adGuid] = [sa].[adGuid]
				INNER JOIN dd000 AS [dd] ON [dd].[ADGUID] = [ad].[adGuid]
				INNER JOIN vbDP AS [dp] ON [dp].[GUID] = [dd].[ParentGUID]
		 WHERE  [dp].[Date] <= @EndDate 
	END

	-- ãÐßÑÉ ÇÓÊáÇã æ ÊÓáíã
	IF (@SrcsFlag & 0x020) > 0
	BEGIN
		INSERT INTO #DetailedResult(
			[adGuid],[adSNGuid],[buGuid],[Type],[Num],[Date],[MoveType],[Spec],[StoreGuid],[BranchGuid],[apSecurity]
		)
		SELECT  [ad].[adGuid],
				[ad].[adSNGuid],
				[ap].[GUID],
				0x020,
				[ap].[Number],
				[ap].[Date],
				[ap].[OperationType],
				CASE @Lang WHEN 0 THEN [ae].[Name] ELSE (CASE [ae].[LatinName] WHEN N'' THEN [ae].[Name] ELSE [ae].[LatinName] END) END,	
				CASE [ap].[OperationType] WHEN 1 THEN [ap].[OutStoreGuid] ELSE [ap].[InStoreGuid] END,
				[ap].[Branch],
				[ap].[Security]
		  FROM  #SELECTEDASSETS AS [sa] 
				INNER JOIN vwAd AS [ad] ON [ad].[adGuid] = [sa].[adGuid]
				INNER JOIN AssetPossessionsFormItem000 AS [api] ON [api].[AssetGuid] = [ad].[adGuid]
				INNER JOIN AssetPossessionsForm000 AS [ap] ON [ap].[GUID] = [api].[ParentGuid]
				INNER JOIN vbAssetEmployee AS [ae] ON [ae].[GUID] = [ap].[Employee] 
		 WHERE  [ap].[Date] <= @EndDate
				AND ISNULL([ap].[ParentGuid], 0x0) = 0x0  
	END

	-- ÚÞÏ ÇÓÊËãÇÑ
	IF (@SrcsFlag & 0x040) > 0
	BEGIN
		INSERT INTO #DetailedResult(
			[adGuid],[adSNGuid],[buGuid],[Type],[Num],[Date],[MoveType],[Spec],[StoreGuid],[BranchGuid],[conSecurity]
		)
		SELECT  [ad].[adGuid],
				[ad].[adSNGuid],
				[con].[GUID],
				0x040,
				[con].[Number],
				[con].[Date],
				3,					--ÚÞÏ	
				(CASE @Lang WHEN 0 THEN [cu].[cuCustomerName] ELSE (CASE [cu].[cuLatinName] WHEN N'' THEN [cu].[cuCustomerName] ELSE [cu].[cuLatinName] END) END) +'-'+ CONVERT(NVARCHAR(10),[con].[Number]),
				[con].[DestinationStore],
				[con].[Branch],
				[con].[Security] 
		  FROM  #SELECTEDASSETS AS [sa] 
				INNER JOIN vwAd AS [ad] ON [ad].[adGuid] = [sa].[adGuid]
				INNER JOIN AssetUtilizeContract000 AS [con] ON [con].[Asset] = [ad].[adGuid]
				INNER JOIN vwCu AS [cu] ON [cu].[cuGUID] = [con].[Customer]
		 WHERE  [con].[Date] <= @EndDate
		 UNION
		SELECT  [ad].[adGuid],
				[ad].[adSNGuid],
				[con].[GUID],
				0x040,
				[con].[Number],
				[con].[CloseDate],
				4,					-- ÅÛáÇÞ ÚÞÏ 	
				(CASE @Lang WHEN 0 THEN [cu].[cuCustomerName] ELSE (CASE [cu].[cuLatinName] WHEN N'' THEN [cu].[cuCustomerName] ELSE [cu].[cuLatinName] END) END) +'-'+ CONVERT(NVARCHAR(10),[con].[Number]),
				[con].[SourceStore],
				[con].[Branch],
				[con].[Security] 
		  FROM  #SELECTEDASSETS AS [sa] 
				INNER JOIN vwAd AS [ad] ON [ad].[adGuid] = [sa].[adGuid]
				INNER JOIN AssetUtilizeContract000 AS [con] ON [con].[Asset] = [ad].[adGuid]
				INNER JOIN vwCu AS [cu] ON [cu].[cuGUID] = [con].[Customer]
		 WHERE	[con].[IsCloseDateActive] = 1
				AND [con].[CloseDate] <= @EndDate
	END

	-- ÚåÏÉ Ãæá ÇáãÏÉ
	IF (@SrcsFlag & 0x100) > 0
	BEGIN
		INSERT INTO #DetailedResult(
			[adGuid],[adSNGuid],[buGuid],[Type],[Num],[Date],[MoveType],[Spec],[BranchGuid],[asdSecurity]
		) 
		SELECT  [ad].[adGuid],
				[ad].[adSNGuid],
				[ap].[ParentGuid],
				0x100,
				[asd].[Number],
				[ap].[Date],
				[ap].[OperationType],
				CASE @Lang WHEN 0 THEN [ae].[Name] ELSE (CASE [ae].[LatinName] WHEN N'' THEN [ae].[Name] ELSE [ae].[LatinName] END) END,
				[ap].[Branch],
				[ap].[Security]			
		  FROM  #SELECTEDASSETS AS [sa] 
				INNER JOIN vwAd AS [ad] ON [ad].[adGuid] = [sa].[adGuid]
				INNER JOIN AssetPossessionsFormItem000 AS [api] ON [api].[AssetGuid] = [ad].[adGuid]
				INNER JOIN AssetPossessionsForm000 AS [ap] ON [ap].[GUID] = [api].[ParentGuid]
				INNER JOIN AssetStartDatePossessions000 AS [asd] ON [asd].[GUID] = [ap].[ParentGuid]
				INNER JOIN vbAssetEmployee AS [ae] ON [ae].[GUID] = [ap].[Employee] 
	END

	-- ÇáÝæÇÊíÑ Ãæ ÇáãäÇÞáÉ ÇáÚÇÏíÉ Ãæ ãäÇÞáÉ ÃÕæá
	IF (@SrcsFlag & 0x001) > 0
	BEGIN
		INSERT INTO #DetailedResult(
			[adGuid],[adSNGuid],[buGuid],[Type],[TypeName],[Num],[Date],[Value],[Spec],[StoreGuid],[CostGuid],[BranchGuid], MoveType
		)
		SELECT  [ad].[adGuid],
				[ad].[adSNGuid],
				[b].[buGUID],
				0x001,
				CASE @Lang WHEN 0 THEN [bt].[btAbbrev] ELSE (CASE [bt].[btLatinAbbrev] WHEN '' THEN [bt].[btAbbrev] ELSE [bt].[btLatinAbbrev] END) END,
				[b].[buNumber],
				[b].[buDate],
				[b].[biUnitPrice] + [b].[biUnitExtra] - [b].[biUnitDiscount],
				CASE ISNULL([b].[biNotes], '') WHEN '' THEN [b].[buNotes] ELSE [b].[biNotes] END,
				CASE ISNULL([b].[biStorePtr], 0x0) WHEN 0x0 THEN ISNULL([b].[buStorePtr], 0x0) ELSE [b].[biStorePtr] END,
				CASE ISNULL([b].[biCostPtr], 0x0) WHEN 0x0 THEN ISNULL([b].[buCostPtr], 0x0) ELSE [b].[biCostPtr] END,
				ISNULL([b].[buBranch], 0x0),
				bt.btIsInput
		  FROM  #SELECTEDASSETS AS [sa] 
				INNER JOIN vwAd AS [ad] ON [ad].[adGuid] = [sa].[adGuid]
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
				AND [b].[buDate] <= @EndDate
				AND [b].[buIsPosted] = 1
				AND [b].[buSecurity] <= [dbo].[fnGetUserBillSec_Browse]([dbo].[fnGetCurrentUserGUID](), [b].[buType])

	END
	
	EXEC [prcCheckAssetSecurity] @result = #DetailedResult

	--------- Master Result ---------

	UPDATE	#CurrentValues 
	   SET	[CurAddVal] = (
			SELECT ISNULL(SUM([r].[Value]),0)
			  FROM #DetailedResult AS [r] 
			 WHERE [r].[Type] = 0x004 AND [r].[adGuid] = [#CurrentValues].[adGuid]
			)	 
			
	UPDATE #CurrentValues
	   SET [CurDedVal] = (
			SELECT ISNULL(SUM([r].[Value]),0)
			  FROM #DetailedResult AS [r] 
			 WHERE [r].[Type] = 0x008 AND [r].[adGuid] = [#CurrentValues].[adGuid]
			)

	UPDATE #CurrentValues 
	   SET [CurDepVal] = (
			SELECT ISNULL(SUM([r].[Value]),0)
			  FROM #DetailedResult AS [r] 
			 WHERE [r].[Type] = 0x002 AND [r].[adGuid] = [#CurrentValues].[adGuid]
			)	

	UPDATE #CurrentValues
	   SET [CurMainVal] = (
			SELECT ISNULL(SUM([r].[Value]),0)
			  FROM #DetailedResult AS [r] 
			 WHERE [r].[Type] = 0x010 AND [r].[adGuid] = [#CurrentValues].[adGuid]
			)	
	 
	INSERT INTO #MasterResult(
			[adGuid],[asName],[adSN],[adInDate],[adInVal],[adTotAddVal],[adTotDedVal],[adTotalVal],
			[adTotDepVal],[adCurTotalVal],[adTotMainVal],[adScrapVal],[asLifeExp]
			)
	SELECT  [ad].[adGuid],
			CASE @Lang WHEN 0 THEN [as].[Name] ELSE (CASE [as].[LatinName] WHEN N'' THEN [as].[Name] ELSE [as].[LatinName] END) END,
			[ad].[adSN],
			[ad].[adInDate],
			[ad].[adInVal],
			[ad].[adAddedVal] + [val].[CurAddVal],
			[ad].[adDeductVal] + [val].[CurDedVal],
			0,
			[ad].[adDeprecationVal] + [val].[CurDepVal],
			0,
			[ad].[adMaintenVal] + [val].[CurMainVal],
			[ad].[adScrapValue],
			CASE(ISNULL([ad].[adAge],0)) WHEN 0 THEN [as].[LifeExp] ELSE [ad].[adAge] END
	  FROM  #SELECTEDASSETS AS [sa] 
			INNER JOIN vwAd AS [ad] ON [sa].[adGUID] = [ad].[adGuid]
			INNER JOIN vtAs AS [as] ON [as].[GUID] = [ad].[adAssGuid]
			INNER JOIN #CurrentValues AS [val] ON [ad].[adGuid] = [val].[adGuid]
		

	UPDATE #MasterResult
	   SET [adTotalVal] = [adInVal] + [adTotAddVal] - [adTotDedVal]

	UPDATE #MasterResult
	   SET [adCurTotalVal] = [adTotalVal] - [adTotDepVal]

	UPDATE #MasterResult
	   SET [adEmployee] = [ap].[Employee],
			[adPosDate] = [ap].[Date]
	  FROM AssetPossessionsFormItem000 AS [api]
		   INNER JOIN AssetPossessionsForm000 AS [ap] ON [ap].[GUID] = [api].[ParentGuid]
	 WHERE [ap].[OperationType] = 2 AND [api].[AssetGuid] = [adGuid]

--------- Totals Result ---------

	INSERT INTO #TotalsResult([adGuid],[adSNGuid],[IsPrev],[adAddedVal],[adDeductVal],[adDeprectaionVal],[adMaintainVal])
	SELECT [ad].[adGuid],
		   0x0,
		   1,
		   ISNULL([ad].[adAddedVal],0),
		   ISNULL([ad].[adDeductVal],0),
		   ISNULL([ad].[adDeprecationVal],0),
		   ISNULL([ad].[adMaintenVal],0)
	  FROM #SELECTEDASSETS AS [sa] 
		   INNER JOIN vwAd AS [ad] ON [ad].[adGuid] = [sa].[adGuid]

	INSERT INTO #TotalsResult([adGuid],[adSNGuid],[IsPrev],[adAddedVal],[adDeductVal],[adDeprectaionVal],[adMaintainVal])
	SELECT [val].[adGuid],
		   [ad].[adSnGuid],
		   0,
		   [val].[CurAddVal],
		   [val].[CurDedVal],
		   [val].[CurDepVal],
		   [val].[CurMainVal]
	  FROM #CurrentValues AS [val]
		   INNER JOIN vwAd AS [ad] ON [ad].[adGuid] = [val].[adGuid]

--------- Final Result ---------	
					
	SELECT  [r].[adGuid]						AS [adGuid],
			[r].[asName]						AS [asName],
			[r].[asName] + '-' + [r].[adSN]		AS [adNameSN],
			[r].[adInDate]						AS [adInDate],
			[r].[adInVal]						AS [adInVal],
			ISNULL([r].[adTotAddVal],0)			AS [adTotAddVal],
			ISNULL([r].[adTotDedVal],0)			AS [adTotDedVal],
			ISNULL([r].[adTotalVal],0)			AS [adTotalVal],
			ISNULL([r].[adTotDepVal],0)			AS [adTotDepVal],
			ISNULL([r].[adCurTotalVal],0)		AS [adCurTotalVal],
			ISNULL([r].[adTotMainVal],0)		AS [adTotMainVal],
			[r].[adScrapVal]					AS [adScrapVal],
			[r].[asLifeExp]						AS [asLifeExp],
			[vad].[adPurchaseOrder]				AS [adPurchaseOrder],				
			[vad].[adModel]						AS [adModel],					
			[vad].[adOrigin]					AS [adOrigin],					
			[vad].[adCompany]					AS [adCompany],					
			[vad].[adManufDate]					AS [adManufDate],				
			[vad].[adSupplier]					AS [adSupplier],				
			[vad].[adLKind]						AS [adLKind],					
			[vad].[adLCNum]						AS [adLCNum],					
			[vad].[adLCDate]					AS [adLCDate],					
			[vad].[adImportPermit]				AS [adImportPermit],			
			[vad].[adArrvDate]					AS [adArrvDate],				
			[vad].[adArrvPlace]					AS [adArrvPlace],				
			[vad].[adCustomStatement]			AS [adCustomStatement],			
			[vad].[adCustomCost]				AS [adCustomCost],				
			[vad].[adCustomDate]				AS [adCustomDate],				
			[vad].[adContractGuaranty]			AS [adContractGuaranty],		
			[vad].[adContractGuarantyDate]		AS [adContractGuarantyDate],	
			[vad].[adContractGuarantyEndDate]	AS [adContractGuarantyEndDate],
			[vad].[adJobPolicy]					AS [adJobPolicy],				
			[vad].[adNotes]						AS [adNotes],									
			[vad].[adDailyRental]				AS [adDailyRental],
			[ad].[SITE]							AS [adSite],				
			[ad].[GUARANTEE]					AS [adGuarantee],				
			[vad].[adGuarantyBeginDate]			AS [adGuarantyBeginDate],		
			[vad].[adGuarantyEndDate]			AS [adGuarantyEndDate],			
			[ad].[DEPARTMENT]					AS [adDepartment],				
			[vad].[adBarCode]					AS [adBarCode],
			CASE @Lang WHEN 0 THEN [ae].[Name] ELSE (CASE [ae].[LatinName] WHEN N'' THEN [ae].[Name] ELSE [ae].[LatinName] END) END AS [adEmployee],
			[r].[adPosDate]							AS [adPosDate]			
	  FROM  #MasterResult AS [r]
			LEFT JOIN vwAd AS [vad] ON [vad].[adGuid] = [r].[adGuid]
			LEFT JOIN ad000 AS [ad] ON [ad].[GUID] = [vad].[adGuid]
			LEFT JOIN vbAssetEmployee AS [ae] ON [ae].[GUID] = [r].[adEmployee] 
	 ORDER BY [adNameSN] 
	
	SELECT [adGuid],
		   [adSNGuid],			
		   [IsPrev],			
		   [adAddedVal],		
		   [adDeductVal],		
		   [adDeprectaionVal],	
		   [adMaintainVal]		
	  FROM #TotalsResult

	SELECT [adGuid],
		   [adSNGuid],	
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
	 FROM  #DetailedResult AS [r]
		   LEFT JOIN vwSt AS [st] ON [st].[stGUID] = [r].[StoreGuid]
		   LEFT JOIN vwCo AS [co] ON [co].[coGUID] = [r].[CostGuid]
		   LEFT JOIN vwBr AS [br] ON [br].[brGUID] = [r].[BranchGuid]
	 ORDER BY [r].[Date], [MoveType]

	 DROP TABLE #SELECTEDASSETS
	 DROP TABLE #CurrentValues
	 DROP TABLE #MasterResult
	 DROP TABLE #TotalsResult
	 DROP TABLE #DetailedResult

END
######################################################
#END