##################################################################################
CREATE PROC repDistSalesCoverage
	@StartDate		DATETIME, 
	@EndDate		DATETIME, 
	@HiGuid			UNIQUEIDENTIFIER, 
	@DistGuid		UNIQUEIDENTIFIER, 
	@GroupGuid		UNIQUEIDENTIFIER, 
	@CurrencyGUID	UNIQUEIDENTIFIER, 
	@UseUnit		INT = 3, 
	@Str			NVARCHAR(max) = '', 
	@ShowGroup		INT = 0, 
	@GroupByDistBit	BIT = FALSE, 
	@SrcGuid 		UNIQUEIDENTIFIER,
	@MatCondGuid 		UNIQUEIDENTIFIER 
AS 

	-- SELECT * FROM #aaaaa		

	SET NOCOUNT ON 
	DECLARE @Level AS INT 
	DECLARE @MaxLevel AS INT 
	CREATE TABLE [#DistTble]	( [DistGuid]	[UNIQUEIDENTIFIER], [Security] 	[INT] ) 
	CREATE TABLE [#SecViol]		( [Type] 	[INT], 		    [Cnt] 	[INT] )  
	CREATE TABLE [#MatTbl]		( [MatGUID] 	[UNIQUEIDENTIFIER], [mtSecurity][INT] ) 
	CREATE TABLE [#Cust] 		( [Number] 	[UNIQUEIDENTIFIER], [Security] 	[INT], [FromDate] 	   [DATETIME] )     
	CREATE TABLE [#BillTbl]		( [Type] 	[UNIQUEIDENTIFIER], [Security] 	[INT], [ReadPriceSecurity] [INT], [UnPostedSecurity] [INT] )      
	CREATE TABLE [#MT1] 
	( 
		[mtGuid]		[UNIQUEIDENTIFIER], 
		[mtCode]		[NVARCHAR](256) COLLATE ARABIC_CI_AI,  
		[mtName] 		[NVARCHAR](256) COLLATE ARABIC_CI_AI, 
		[mtLatinName] 		[NVARCHAR](256) COLLATE ARABIC_CI_AI,   
		[mtSecurity]		[INT], 
		[mtUnitFact]		[FLOAT] DEFAULT 1, 
		[mtUnit2]		[FLOAT] DEFAULT 1, 
		[mtUnit3]		[FLOAT] DEFAULT 1, 
		[mtUnitName]		[NVARCHAR](256) COLLATE ARABIC_CI_AI, 
		[mtGroup]		[UNIQUEIDENTIFIER]  
	)	 
		 
	DECLARE @TOTALCOUNTS TABLE  ( [TOTALCNT] [INT] DEFAULT 0,[TYPE] SMALLINT DEFAULT 0, [StartDate] DATETIME DEFAULT '1/1/1980', [EndDate] DATETIME) 
	DECLARE @PDate TABLE  ( [StartDate] [DATETIME] DEFAULT '1/1/1980', [EndDate] [DATETIME]) 
	-- THESE FOUR VARIABLES ARE USED FOR THE TOTAL CUSTOMERS COUNT CALCULATION 
	-- PLEASE REFER TO THEIR USAGE FORWARD 
	DECLARE @SD DATETIME 
	DECLARE @ED DATETIME 
	DECLARE @TempPDate TABLE ([StartDate] DATETIME, [EndDate] DATETIME)	 
	DECLARE @ROWCOUNT BIGINT 
	DECLARE @TEMPCOUNT BIGINT		 
	INSERT INTO @PDate   SELECT * FROM [fnGetStrToPeriod] (@STR) 
	INSERT INTO [#BillTbl]		EXEC [prcGetBillsTypesList2] 	@SrcGuid, 0X0 
	INSERT INTO [#DistTble] 	EXEC GetDistributionsList @DistGuid, @HiGuid 
	INSERT INTO [#MatTbl]		EXEC prcGetMatsList 0X0, @GroupGUID , -1, @MatCondGuid  
	INSERT INTO [#Cust] ( [Number], [Security] )   EXEC prcGetDistGustsList @DistGuid, 0x00, 0x00, @HiGuid  -- EXEC [prcGetCustsList] 0X0, 0x0     
	 
	--SELECT * FROM [#Cust] AS [A] INNER JOIN CU000 AS B ON A.Number = B.GUID  
	 
	SELECT  
		[d].[DistGuid], [d].[Security] AS [DistSecurity], [c].[Number], [c].[Security] AS CustSecurity, [Sm].[CostGuid] 
	INTO [#CustDistTbl] 
	FROM [#DistTble] AS [d] 
		INNER JOIN [DistDistributionLines000] 	AS [Dl] ON [Dl].[DistGuid] = [d].[DistGuid] 
		INNER JOIN [#Cust] 				AS [c] 	ON [c].[Number]    = [Dl].[CustGuid] 
		INNER JOIN [vwDistributor]		AS [Ds] ON [Ds].[Guid]     = [D].[DistGuid] 
		INNER JOIN [vwDistSalesman]		AS [Sm] ON [Sm].[Guid]     = [Ds].[PrimSalesManGuid] 

	CREATE TABLE [#Result] 
	( 
		[buGuid]		[UNIQUEIDENTIFIER], 
		[CustPtr]		[UNIQUEIDENTIFIER], 
		[DistPtr]		[UNIQUEIDENTIFIER], 
		[GrPtr]			[UNIQUEIDENTIFIER], 
		[MatPtr]		[UNIQUEIDENTIFIER], 
		[mtCode] 		[NVARCHAR](256) COLLATE ARABIC_CI_AI,  
		[mtName] 		[NVARCHAR](256) COLLATE ARABIC_CI_AI,  
		[mtLatinName] 		[NVARCHAR](256) COLLATE ARABIC_CI_AI,  
		[Qty]			[FLOAT] DEFAULT 	0, 
		[Val]			[FLOAT] DEFAULT 	0, 
		[buDirection]		[INT] DEFAULT 	0, 
		[MatSecurity]		[INT] DEFAULT 	0, 
		[Security]		[INT] DEFAULT 	0, 
		[UserSecurity]		[INT] DEFAULT 	0, 
		[CustSecurity]		[INT] DEFAULT	0, 
		[DistSecurity]		[INT] DEFAULT	0, 
		[mtUnitFact] 		[FLOAT] DEFAULT 	1, 
		[mtUnitName]    	[NVARCHAR](256) COLLATE ARABIC_CI_AI, 
		[buDate]		[DATETIME], 
		[GroupGuid]		[UNIQUEIDENTIFIER] DEFAULT 0X0, 
		[CostGuid]		[UNIQUEIDENTIFIER] DEFAULT 0X0 
	) 
	CREATE TABLE [#T_Result] 
	( 
		[CustPtr]		[UNIQUEIDENTIFIER], 
		[DistPtr]		[UNIQUEIDENTIFIER], 
		[GrPtr]			[UNIQUEIDENTIFIER], 
		[MatPtr]		[UNIQUEIDENTIFIER], 
		[mtCode] 		[NVARCHAR](256) COLLATE ARABIC_CI_AI,  
		[mtName] 		[NVARCHAR](256) COLLATE ARABIC_CI_AI,  
		[mtLatinName] 		[NVARCHAR](256) COLLATE ARABIC_CI_AI,  
		[Qty]			[FLOAT] DEFAULT 	0, 
		[Val]			[FLOAT] DEFAULT 	0, 
		[mtUnitFact] 		[FLOAT] DEFAULT 	1, 
		[mtUnitName]    	[NVARCHAR](256) COLLATE ARABIC_CI_AI, 
		[StartDate]		[DATETIME], 
		[EndDate]		[DATETIME], 
		[CustCnt]		[INT], 
		[NewCnt]		[INT], 
		[buCnt]			[INT], 
		[GroupGuid]		[UNIQUEIDENTIFIER] DEFAULT 0X00 
	) 
	CREATE TABLE [#FinalResult] 
	( 
		[GrPtr]			[UNIQUEIDENTIFIER] DEFAULT 0X00, 
		[MatPtr]		[UNIQUEIDENTIFIER] DEFAULT 0X00, 
		[mtCode] 		[NVARCHAR](256) COLLATE ARABIC_CI_AI DEFAULT '',  
		[mtName] 		[NVARCHAR](256) COLLATE ARABIC_CI_AI DEFAULT '',  
		[mtLatinName] 		[NVARCHAR](256) COLLATE ARABIC_CI_AI DEFAULT '',  
		[Qty]			[FLOAT] DEFAULT 	0, 
		[Val]			[FLOAT] DEFAULT 	0, 
		[mtUnitFact] 		[FLOAT] DEFAULT 	1, 
		[mtUnitName]    	[NVARCHAR](256) COLLATE ARABIC_CI_AI DEFAULT '', 
		[StartDate]		[DATETIME], 
		[EndDate]		[DATETIME], 
		[CustCnt]		[INT], 
		[NewCnt]		[INT], 
		[buCnt]			[INT], 
		[GroupGuid]		[UNIQUEIDENTIFIER] DEFAULT 0X00, 
		[Path]			[NVARCHAR](256)	DEFAULT '', 
		[Flag]			[INT], 
		[DistPtr]		[UNIQUEIDENTIFIER] DEFAULT 0x00 
	) 
	INSERT INTO  [#MT1] 
		SELECT  
			[mt1].[mtGuid], 
			[mtCode], 
			[mtName], 
			[mtLatinName], 
			[mt].[mtSecurity], 
			CASE @UseUnit  
				WHEN 0 THEN 1 
				WHEN 1 THEN [mt1].[mtunit2Fact] 
				WHEN 2 THEN [mt1].[mtunit3Fact] 
				ELSE CASE [mt1].[mtDefUnit] 
						WHEN 1 THEN 1 
						WHEN 2 THEN [mt1].[mtunit2Fact] 
						ELSE [mt1].[mtunit3Fact] 
				     END 
			END, 
			CASE [mt1].[mtunit2Fact] WHEN 0 THEN 1 ELSE [mt1].[mtunit2Fact] END, 
			CASE [mt1].[mtunit3Fact] WHEN 0 THEN 1 ELSE [mt1].[mtunit3Fact] END, 
			CASE @UseUnit  
				WHEN 0 THEN [mt1].[mtunity] 
				WHEN 1 THEN CASE [mt1].[mtunit2Fact] WHEN 0 THEN [mt1].[mtunity] ELSE [mt1].[mtunit2] END  
				WHEN 2 THEN CASE [mt1].[mtunit3Fact] WHEN 0 THEN [mt1].[mtunity] ELSE [mt1].[mtunit3] END  
				ELSE CASE [mt1].[mtDefUnit] 
						WHEN 1 THEN [mt1].[mtunity] 
						WHEN 2 THEN [mt1].[mtunit2] 
						ELSE [mt1].[mtunit3] 
					END 
			END , 
			[mtGroup] 
		FROM  
			[#MatTbl]  AS [mt] 
			INNER JOIN [vwMt] AS [mt1] ON [mt1].[mtGuid] = mt.MatGuid 
	CREATE INDEX [mtIndex] ON [#MT1]([mtGuid]) 
	/*SELECT * FROM [dbo].[fn_bubi_Fixed] (@CurrencyGUID) 
	WHERE btBillType in (1,3) 
	*/ 
	/* 
	-- THIS TABLE NOW CONTAINS ALL BILL DETAILS  
	-- THAT ARE WITHIN THE SPECIFIED RANGE OF DATE 
	INSERT INTO #Result   
		SELECT  
			[buGUID], 
			[cu].[Number], 
			[DistGuid], 
			[mt].[mtGroup], 
			[bi].[biMatPtr], 
			[mtCode],  
			[mtName],  
			CASE [mtLatinName] WHEN '' THEN [mtName] ELSE [mtLatinName] END,  
			([biQty] + [biBonusQnt])/CASE [mt].[mtUnitFact] WHEN 0 THEN 1 ELSE [mt].[mtUnitFact] END , 
			(((( [bi].[biPrice] / CASE [bi].[biUnity] WHEN 1 THEN 1 WHEN 2 THEN [mt].[mtunit2] ELSE  [mt].[mtunit2] END ) - ((CASE [buTotal]    WHEN 0 THEN (CASE [biQty] WHEN 0 THEN 0  ELSE [biDiscount] / [biQty] END) + [biBonusDisc] ELSE ((CASE [biQty] WHEN 0 THEN 0 ELSE ([biDiscount] / [biQty]) END) + (ISNULL((SELECT Sum([diDiscount]) FROM vwDi WHERE diParent = buGUID),0) * biPrice / CASE mtUnitFact WHEN 0 THEN 1 ELSE mtUnitFact END) / buTotal) END) + (CASE biQty WHEN 0 THEN 0 ELSE (biBonusDisc / biQty) END)) + ((CASE [buTotal]    WHEN 0 THEN (CASE [biQty] WHEN 0 THEN 0  ELSE [biExtra] / [biQty] END) ELSE ((CASE [biQty] WHEN 0 THEN 0 ELSE ([biExtra] / [biQty]) END) + (ISNULL((SELECT Sum([diExtra]) FROM vwDi WHERE diParent = buGUID),0) * biPrice / CASE mtUnitFact WHEN 0 THEN 1 ELSE mtUnitFact END) / buTotal) END))) * [biQty]) + [biVat])* [FixedCurrencyFactor], 
			CASE [btIsInput] WHEN 0 THEN -1 ELSE 1 END, 
			[mt].[mtSecurity],   
			[buSecurity], 
			CASE [buIsPosted] WHEN 1 THEN [bt].[Security] ELSE [UnPostedSecurity] END, 
			[CustSecurity], 
			[DistSecurity], 
			[mt].[mtUnitFact], 
			[mtUnitName], 
			[buDate], 
		        [mtGroup]     
		FROM   
			[dbo].[fn_bubi_Fixed] (@CurrencyGUID) AS [bi] 
			INNER JOIN [#CustDistTbl] 	AS [cu] ON [cu].[Number] = [bi].[buCustPtr]  AND [cu].[CostGuid] = [bi].[buCostPtr] 
			INNER JOIN [#BillTbl] 		AS [bt] ON [bt].[Type]   = [bi].[buType] 
			INNER JOIN [#MT1] 		AS [mt] ON [mt].[mtGuid] = [bi].[biMatPtr] 
		WHERE 
			[bi].[BuDate] BETWEEN  @StartDate AND @EndDate 	--AND [buIsPosted] > 0 
			AND [BI].[btBILLTYPE] IN (1,3) -- IF BILLTYPE IS 1 THEN IT IS „»Ì⁄«  
						       --                3 THEN IT IS „— Ã⁄ „»Ì⁄« 	 
	 
	*/ 
	-- THIS TABLE NOW CONTAINS ALL BILL DETAILS  
	-- THAT ARE WITHIN THE SPECIFIED RANGE OF DATE 
	INSERT INTO #Result   
		SELECT  
			[buGUID], 
			[bi].[buCustPtr], 
			[DistGuid], 
			[mt].[mtGroup], 
			[bi].[biMatPtr], 
			[mtCode],  
			[mtName],  
			CASE [mtLatinName] WHEN '' THEN [mtName] ELSE [mtLatinName] END,  
			([biQty] + [biBonusQnt])/CASE [mt].[mtUnitFact] WHEN 0 THEN 1 ELSE [mt].[mtUnitFact] END , 
			(((( [bi].[biPrice] / CASE [bi].[biUnity] WHEN 1 THEN 1 WHEN 2 THEN [mt].[mtunit2] ELSE  [mt].[mtunit2] END ) - ((CASE [buTotal]    WHEN 0 THEN (CASE [biQty] WHEN 0 THEN 0  ELSE [biDiscount] / [biQty] END) + [biBonusDisc] ELSE ((CASE [biQty] WHEN 0 THEN 0 ELSE ([biDiscount] / [biQty]) END) + (ISNULL((SELECT Sum([diDiscount]) FROM vwDi WHERE diParent = buGUID),0) * biPrice / CASE mtUnitFact WHEN 0 THEN 1 ELSE mtUnitFact END) / buTotal) END) + (CASE biQty WHEN 0 THEN 0 ELSE (biBonusDisc / biQty) END)) + ((CASE [buTotal]    WHEN 0 THEN (CASE [biQty] WHEN 0 THEN 0  ELSE [biExtra] / [biQty] END) ELSE ((CASE [biQty] WHEN 0 THEN 0 ELSE ([biExtra] / [biQty]) END) + (ISNULL((SELECT Sum([diExtra]) FROM vwDi WHERE diParent = buGUID),0) * biPrice / CASE mtUnitFact WHEN 0 THEN 1 ELSE mtUnitFact END) / buTotal) END))) * [biQty]) + [biVat])* [FixedCurrencyFactor], 
			CASE [btIsInput] WHEN 0 THEN -1 ELSE 1 END, 
			[mt].[mtSecurity],   
			[buSecurity], 
			CASE [buIsPosted] WHEN 1 THEN [bt].[Security] ELSE [UnPostedSecurity] END, 
			[cu].[cuSecurity], 
			[DIST].[Security], 
			[mt].[mtUnitFact], 
			[mtUnitName], 
			[buDate], 
		    [mtGroup],
			[Sm].[CostGuid]     
		FROM   
			[dbo].[fn_bubi_Fixed] (@CurrencyGUID) AS [bi] 
			INNER JOIN [DistSalesman000]   AS [SM]   ON [BI].[biCostPtr] = [SM].[CostGuid] 
			INNER JOIN [DISTRIBUTOR000]    AS [D]    ON [D].[PrimSalesManGuid] = [SM].[GUID] 
			INNER JOIN [#DistTble]	       AS [DIST] ON [DIST].[DistGuid] = [D].[GUID] 
			INNER JOIN [vwCu]	       AS [cu]   ON [cu].[cuGUID] = [bi].[buCustPtr] 
			--INNER JOIN [#CustDistTbl] 	AS [cu] ON [cu].[Number] = [bi].[buCustPtr]  AND [cu].[CostGuid] = [bi].[buCostPtr] 
			INNER JOIN [#BillTbl] 		AS [bt] ON [bt].[Type]   = [bi].[buType] 
			INNER JOIN [#MT1] 		AS [mt] ON [mt].[mtGuid] = [bi].[biMatPtr] 
		WHERE 
			[bi].[BuDate] BETWEEN  @StartDate AND @EndDate 	--AND [buIsPosted] > 0 
			--AND [BI].[btBILLTYPE] IN (1,3) -- IF BILLTYPE IS 1 THEN IT IS „»Ì⁄«  
						       --                3 THEN IT IS „— Ã⁄ „»Ì⁄« 	 
	 
	/* 
	SELECT * FROM [dbo].[fn_bubi_Fixed] (@CurrencyGUID) AS [BI] 
		 WHERE [BI].[btBillType] in (1,3) AND [BI].[biMatPtr] = '09175877-F34E-4B2C-8E74-EE6EE7429B73' 
		 ORDER BY buDate,biQty 
	*/ 
		 
	CREATE CLUSTERED INDEX [rInd] ON #Result( [CustPtr], [DistPtr], [MatPtr], [buDate]) 
	/* 
	SELECT [A].[buDate],[A].[Qty],[C].[NAME]  
			FROM [#RESULT] AS [A] INNER JOIN [BU000] AS [B] ON [A].[buGUID] = [B].[GUID] 
		 	                      INNER JOIN [BT000] AS [C] ON [B].[TYPEGUID] = [C].[GUID] 
			WHERE [A].[MatPtr] = '09175877-F34E-4B2C-8E74-EE6EE7429B73' 
							 
	*/ 
	 
--	SELECT * FROM [#RESULT]	 
	EXEC prcCheckSecurity  
	INSERT INTO [#T_Result]  
		SELECT  
			[CustPtr], [DistPtr], [GrPtr], [MatPtr], mtCode, mtName, mtLatinName, SUM([Qty]*-[buDirection]),  
			SUM([Val]*-[buDirection]), [mtUnitFact], mtUnitName, StartDate, EndDate, 0, 0, 0, GroupGuid 
		FROM [#RESULT] AS r  
			INNER JOIN @PDate AS p ON [buDate] BETWEEN  StartDate AND EndDate 
		GROUP BY  [CustPtr], [DistPtr], [GrPtr], [MatPtr], [mtCode], [mtName], [mtLatinName], [mtUnitFact], [mtUnitName], [StartDate], [EndDate], [GroupGuid] 
--	SELECT * FROM [#T_RESULT]  
--	SELECT * FROM @PDate	 
	-- NOW THIS INSERT INSTRUCTION INSERTS THE DISTINCT NEW CUSTOMERS  
	-- ALONG WITH INFORMATION ABOUT THE DISTINCT MATERIALS GUID THAT THEY HAVE PURCHASED AS FIRST TIME 
	SELECT [F].[CustPtr],[F].[GrPtr] AS MatGuid, [StartDate], [EndDate], [F].MatPtr,[M].[NAME], [F].[DistPtr] 
	INTO [#NewCnt2] 
	FROM [#Result] AS [f]  
		INNER JOIN @PDate	AS p ON [buDate] BETWEEN [StartDate] AND EndDate 
		INNER JOIN [MT000]	AS [M] ON [F].[MatPtr] = [M].[GUID] 
		-- LEFT  JOIN vwbubi AS bu ON bu.buCustPtr = f.CustPtr AND bu.biMatPtr = f.MatPtr AND bu.Date < p.StartDate
	WHERE  
		--[CustPtr] NOT IN (SELECT [CustomerGUID] FROM [DistCm000] AS d2 WHERE d2.CustomerGUID = [f].[CustPtr] AND [f].[MatPtr] = [d2].[MatGuid] AND [d2].[Date] < StartDate) AND  [buDirection] = -1   
		-- [CustPtr] NOT IN ( SELECT [CustGUID] FROM BU000 AS A , BI000 AS B WHERE A.CustGUID = [f].[CustPtr] AND [f].[MatPtr] = [B].[MatGuid] AND [A].[GUID] = [B].[ParentGUID] AND [A].[Date] < StartDate ) --AND  [buDirection] = -1   
		[CustPtr] NOT IN (	SELECT [CustGUID] FROM BU000 AS bu INNER JOIN BI000 AS Bi ON Bu.Guid = bi.ParentGuid 
							INNER JOIN #BillTbl AS bt ON bt.Type = bu.TypeGuid 
							WHERE	bu.CustGUID = [f].[CustPtr] AND [f].[MatPtr] = [Bi].[MatGuid] 
									AND [bu].[Date] < p.StartDate AND [bu].[CostGuid] = [f].[CostGuid]
						 ) 

-- Select * FROm #NewCnt2 Order By Name, StartDate

	-- UP TO THIS POINT #RESULT HOLDS COMPLETE INFORMATION ABOUT BILLS DETAILS 
	-- ALONG WITH SECURTIY INFORMATION  
	-- NOW THIS INSERT INSTRUCTION INSERTS THE DISTINCT NEW CUSTOMERS COUNT  
	-- BASED ON THE DISTINCT MATERIALS GUID THAT THEY HAVE PURCHASED AS FIRST TIME 
	SELECT  
		COUNT(DISTINCT( CAST([CustPtr] AS [NVARCHAR](40)))) AS [NewCustCNT], [MatPtr] AS MatGUID, [StartDate], [EndDate] ,CASE @GroupByDistBit WHEN 1 THEN [F].[DistPtr] ELSE 0x00 END AS [DistPtr] 
	INTO [#NewCustCnt] 
	FROM [#Result] AS [f]  
		INNER JOIN   @PDate AS p ON [buDate] BETWEEN [StartDate] AND EndDate 
	WHERE  
		-- [CustPtr] NOT IN (SELECT [CustomerGUID] FROM [DistCm000] AS d2 WHERE d2.CustomerGUID = [f].[CustPtr] AND [f].[MatPtr] = [d2].[MatGuid] AND [d2].[Date] < StartDate) AND  [buDirection] = -1   
		-- [CustPtr] NOT IN ( SELECT [CustGUID] FROM BU000 AS A , BI000 AS B WHERE A.CustGUID = [f].[CustPtr] AND [f].[MatPtr] = [B].[MatGuid] AND [A].[GUID] = [B].[ParentGUID] AND [A].[Date] < StartDate ) -- AND  [buDirection] = -1   
		[CustPtr] NOT IN (	SELECT [CustGUID] FROM BU000 AS bu INNER JOIN BI000 AS Bi ON Bu.Guid = bi.ParentGuid 
							INNER JOIN #BillTbl AS bt ON bt.Type = bu.TypeGuid 
							WHERE	bu.CustGUID = [f].[CustPtr] AND [f].[MatPtr] = [Bi].[MatGuid] 
									AND [bu].[Date] < p.StartDate AND [bu].[CostGuid] = [f].[CostGuid]
						 ) 
	GROUP BY  
		CASE @GroupByDistBit WHEN 1 THEN [F].[DistPtr] ELSE 0x00 END,[MatPtr], [StartDate], [EndDate] 
--	SELECT A.*, B.NAME FROM [#NewCustCnt] AS [A] INNER JOIN [MT000] AS [B] ON [A].[MatGuid] = [B].[GUID] 
	 
	-- NOW THIS INSERT INSTRUCTION INSERTS THE DISTINCT CUSTOMERS COUNT  
	-- BASED ON THE DISTINCT MATERIALS GUID 
	SELECT  
		COUNT(DISTINCT( CAST([CustPtr] AS [NVARCHAR](40)))) AS [CustCNT], COUNT(DISTINCT( CAST([buGuid] AS [NVARCHAR](40)))) AS [buCount], [f].[MatPtr], [p].[StartDate], [p].[EndDate], CASE @GroupByDistBit WHEN 1 THEN [F].[DistPtr] ELSE 0x00 END AS [DistPtr] 
	INTO [#CustCnt] 
	FROM [#Result] AS [f]  
		INNER JOIN   @PDate AS p ON [buDate] BETWEEN  [StartDate] AND EndDate 
	--WHERE [buDirection] = -1   
	GROUP BY  
		CASE @GroupByDistBit WHEN 1 THEN [F].[DistPtr] ELSE 0x00 END, [f].[MatPtr], [StartDate], [EndDate] 
	 
	-- NOW THIS BLOCK IS FOR RETRIEVING TOTAL COUNTS OF CUSTOEMRS,NEW CUSTOMERS AND BILL COUNTS 
	-- GROUPED BY DISTRIBUTOR 
	IF @GroupByDistBit = 1 
	BEGIN 
		-- UP TO THIS POINT #RESULT HOLDS COMPLETE INFORMATION ABOUT BILLS DETAILS 
		-- ALONG WITH SECURTIY INFORMATION  
		-- NOW THIS INSERT INSTRUCTION INSERTS THE DISTINCT CUSTOMERS COUNT  
		-- BASED ON THE DISTINCT MATERIALS GUID 
		SELECT  
			COUNT(DISTINCT( CAST([CustPtr] AS [NVARCHAR](40)))) AS [CustCNT], COUNT(DISTINCT( CAST([buGuid] AS [NVARCHAR](40)))) AS [buCount], SUM([Qty]*-[buDirection]) AS [QTY], 
			SUM([Val]*-[buDirection]) AS [VAL], [StartDate], [EndDate] ,[F].[DistPtr] 
		INTO [#TEMP44] 
		FROM [#Result] AS [f]  
			INNER JOIN   @PDate AS p ON [buDate] BETWEEN  [StartDate] AND EndDate 
		--WHERE [buDirection] = -1   
		GROUP BY  
			[F].[DistPtr], [StartDate], [EndDate]		 
		-- NOW THIS INSERT INSTRUCTION INSERTS THE DISTINCT NEW CUSTOMERS COUNT  
		-- BASED ON THE DISTINCT MATERIALS GUID THAT THEY HAVE PURCHASED AS FIRST TIME 
		SELECT  
			COUNT(DISTINCT( CAST([CustPtr] AS [NVARCHAR](40)))) AS [NewCustCNT], SUM([Qty]*-[buDirection]) AS [QTY], 
			SUM([Val]*-[buDirection]) AS [VAL], [StartDate], [EndDate] ,[F].[DistPtr] 
		INTO [#TEMP45] 
		FROM [#Result] AS [f]  
			INNER JOIN   @PDate AS p ON [buDate] BETWEEN [StartDate] AND EndDate 
		WHERE  
			--[CustPtr] NOT IN (SELECT [CustomerGUID] FROM [DistCm000] AS d2 WHERE d2.CustomerGUID = [f].[CustPtr] AND [f].[MatPtr] = [d2].[MatGuid] AND [d2].[Date] < StartDate) AND  [buDirection] = -1   
			-- [CustPtr] NOT IN ( SELECT [CustGUID] FROM BU000 AS A , BI000 AS B WHERE A.CustGUID = [f].[CustPtr] AND [f].[MatPtr] = [B].[MatGuid] AND [A].[GUID] = [B].[ParentGUID] AND [A].[Date] < StartDate ) -- AND  [buDirection] = -1   
			[CustPtr] NOT IN (	SELECT [CustGUID] FROM BU000 AS bu INNER JOIN BI000 AS Bi ON Bu.Guid = bi.ParentGuid 
								INNER JOIN #BillTbl AS bt ON bt.Type = bu.TypeGuid 
								WHERE	bu.CustGUID = [f].[CustPtr] AND [f].[MatPtr] = [Bi].[MatGuid] 
										AND [bu].[Date] < p.StartDate AND [bu].[CostGuid] = [f].[CostGuid]
							 ) 
		GROUP BY  
			[F].[DistPtr], [StartDate], [EndDate]	 
		SELECT ISNULL([A].[CustCNT],0) AS [CustCnt], ISNULL([B].[NewCustCNT],0) AS [NewCnt], ISNULL([A].[buCount],0) AS [buCnt], (ISNULL([A].[QTY],0)/*+ISNULL([B].[QTY],0)*/) AS [QTY] , (ISNULL([A].[VAL],0)/*+ISNULL([B].[VAL],0)*/) AS [VAL]  ,[A].[StartDate], [A].[EndDate], [A].[DistPtr] AS [DistGuid] 
		FROM [#TEMP44] AS [A] FULL JOIN [#TEMP45] AS [B] 
			ON [A].[STARTDATE] = [B].[STARTDATE] 
			AND [A].[ENDDATE] = [B].[ENDDATE] 
			AND [A].[DISTPTR] = [B].[DISTPTR] 
		ORDER BY [A].[DistPtr] , [A].[StartDate], [B].[StartDate] 
		 
	END 
--	SELECT * FROM [#CustCnt] 
--	SELECT * FROM [#NEWCustCnt] 
	SELECT  
		ISNULL([CustCNT],0)			AS [CustCNT] , 
		ISNULL([NewCustCNT],0) 			AS [NewCustCNT], 
		ISNULL([MatPtr],[MatGUID]) 		AS [MatPtr], 
		ISNULL([buCount],0) 			AS [buCount], 
		ISNULL(cu.StartDate,Ncu.StartDate) 	AS [StartDate], 
		ISNULL(cu.EndDate,Ncu.EndDate) 		AS [EndDate], 
		ISNULL([cu].[DistPtr],0x00)		AS [DistPtr] 
	INTO [#CustCntNewCnt] 
		FROM [#NEWCustCnt] AS [Ncu]  
			FULL JOIN  [#CustCnt] AS [cu] ON [cu].[MatPtr] = [Ncu].[MatGuid] AND [cu].[StartDate] = [Ncu].[StartDate] AND [cu].[EndDate] = [Ncu].[EndDate] AND [cu].[DistPtr] = CASE @GroupByDistBit WHEN 1 THEN  [Ncu].[DistPtr] ELSE  [cu].[DistPtr] END 
	 
	 
--	SELECT DISTPTR FROM [#CustCntNewCnt] 
--	SELECT * FROM [#T_RESULT] 
	INSERT INTO [#T_Result]  
	SELECT 
		0x0, 
		[C].[DistPtr], 
		[mtGroup], 
		[c].[MatPtr], 
		[mtCode],  
		[mtName],  
		CASE [mtLatinName] WHEN '' THEN [mtName] ELSE [mtLatinName] END,  
		0, 
		0, 
		[mtUnitFact], 
		[mtUnitName], 
		[StartDate], 
		[EndDate], 
		[CustCNT], 
		[NewCustCNT], 
		[buCount], 
		[mtGroup]	 
	FROM [#CustCntNewCnt] 	AS [c]  
		INNER JOIN [#MT1] 	AS [m] ON [c].[MatPtr] = [m].[mtGuid] 
	--INNER JOIN [mt000] AS [mt] ON [mt].[Guid] = [c].[MatPtr]  
/*	 
	SELECT * FROM [#CustCntNewCnt] 
	SELECT * FROM [#T_RESULT] 
*/ 
	INSERT INTO [#FinalResult] 
		SELECT [r].[GrPtr], [r].[MatPtr], [mtCode], [mtName], [mtLatinName],  
			SUM(ISNULL([Qty],0)), SUM(ISNULL([Val],0)), 
			[mtUnitFact], 
			[mtUnitName], 
			[r].[StartDate], 
			[r].[EndDate], 
			SUM(ISNULL([CustCnt],0)), 
			SUM(ISNULL([NewCnt],0)), 
			SUM(ISNULL([buCnt],0)), 
			GroupGUID, 
			'',0, CASE @GroupByDistBit WHEN 1 THEN [r].[DistPtr] ELSE 0x00 END 
		FROM [#T_Result] AS [r]  
		GROUP BY 
			CASE @GroupByDistBit WHEN 1 THEN [r].[DistPtr] ELSE 0x00 END,  
			[r].[GrPtr], [r].[MatPtr], [mtCode], [mtName], [mtLatinName], [mtUnitFact], [mtUnitName], [r].[StartDate], [r].[EndDate], [GroupGUID] 
--	SELECT * FROM #FINALRESULT 
	-- I WILL CALL THIS BLOCK007 
	INSERT INTO @TempPDate SELECT * FROM @PDate		 
	SELECT @ROWCOUNT = COUNT(*) FROM @TempPDate 
	WHILE @ROWCOUNT > 0 
	BEGIN 
			-- THIS SELECT GET THE FIRST RANGE OF DATE 
			SELECT TOP 1 @SD = [StartDate], @ED = [EndDate] FROM @TempPDate ORDER BY [StartDate],[EndDate]					 
			SET @TEMPCOUNT = 0			 
			-- THIS SELECT STATEMENT GETS THE TOTOAL COUNT OF ALL CUSTOMERS THAT HAVE PURCHASED 
			-- MATERIALS. PLEASE NOTICE THAT THERE ARE NO GROUPING HERE 
			-- BECAUSE WE COUNT ALL THE CUSTOMERS REGARDLESS OF THE MATERIALS 
			SELECT @TEMPCOUNT = COUNT(DISTINCT( CAST([CustPtr] AS [NVARCHAR](40)))) 
			FROM [#Result] AS [f]  
				INNER JOIN   @PDate AS p ON [buDate] BETWEEN  [StartDate] AND [EndDate] 
			WHERE /*[buDirection] = -1 AND */[P].[StartDate] = @SD AND [P].[EndDate] = @ED 
			GROUP BY  [StartDate] , [EndDate]		 
			-- 0 IN THE FOLLOWING INSERT STATEMENT IS FOR NOT NEW CUSTOMERS 
			INSERT INTO @TOTALCOUNTS (TOTALCNT,TYPE,STARTDATE,ENDDATE) 
			VALUES (@TEMPCOUNT,0,@SD,@ED)			 
			SET @TEMPCOUNT = 0 
			-- THIS SELECT STATEMENT GETS THE TOTOAL COUNT OF ALL CUSTOMERS THAT HAVE PURCHASED 
			-- MATERIALS FOR THE FIRST TIME. PLEASE NOTICE THAT THERE ARE NO GROUPING HERE 
			-- BECAUSE WE COUNT ALL THE NEW CUSTOMERS REGARDLESS OF THE MATERIALS 
			SELECT 	@TEMPCOUNT = COUNT(DISTINCT( CAST([CustPtr] AS [NVARCHAR](40)))) 
			FROM [#Result] AS [f]  
				INNER JOIN   @PDate AS p ON [buDate] BETWEEN [StartDate] AND EndDate 
			WHERE  
				--[CustPtr] NOT IN (SELECT [CustomerGUID] FROM6 [DistCm000] AS d2 WHERE d2.CustomerGUID = [f].[CustPtr] AND [f].[MatPtr] = [d2].[MatGuid] AND [d2].[Date] < StartDate) AND  [buDirection] = -1   
				-- [CustPtr] NOT IN ( SELECT [CustGUID] FROM BU000 AS A , BI000 AS B WHERE A.CustGUID = [f].[CustPtr] AND [f].[MatPtr] = [B].[MatGuid] AND [A].[GUID] = [B].[ParentGUID] AND [A].[Date] < StartDate ) -- AND  [buDirection] = -1  	 
				[CustPtr] NOT IN (	SELECT [CustGUID] FROM BU000 AS bu INNER JOIN BI000 AS Bi ON Bu.Guid = bi.ParentGuid 
									INNER JOIN #BillTbl AS bt ON bt.Type = bu.TypeGuid 
									WHERE	bu.CustGUID = [f].[CustPtr] AND [f].[MatPtr] = [Bi].[MatGuid] 
											AND [bu].[Date] < p.StartDate AND [bu].[CostGuid] = [f].[CostGuid]
								 ) 
				AND [P].[StartDate] = @SD AND [P].[EndDate] = @ED 
			GROUP BY  [StartDate] , [EndDate]				 
			-- 1 IN THE FOLLOWING INSERT STATEMENT IS FOR NEW CUSTOMERSS			 
			INSERT INTO @TOTALCOUNTS (TOTALCNT,TYPE,STARTDATE,ENDDATE) 
			VALUES (@TEMPCOUNT,1,@SD,@ED)		 
			/*SELECT COUNT(DISTINCT( CAST([buGuid] AS [NVARCHAR](40)))) 
			FROM [#Result] AS [f]  
				INNER JOIN   @PDate AS p ON [buDate] BETWEEN  [StartDate] AND [EndDate] 
			WHERE [P].[StartDate] = @SD AND [P].[EndDate] = @ED 
			GROUP BY  [StartDate] , [EndDate]	*/ 
			-- THIS SELECT STATEMENT GETS THE TOTOAL BILL COUNT OF ALL CUSTOMERS THAT HAVE PURCHASED 
			-- MATERIALS. PLEASE NOTICE THAT THERE ARE NO GROUPING HERE 
			-- BECAUSE WE COUNT ALL THE CUSTOMERS REGARDLESS OF THE MATERIALS 
			SELECT @TEMPCOUNT = COUNT(DISTINCT( CAST([buGuid] AS [NVARCHAR](40)))) 
			FROM [#Result] AS [f]  
				INNER JOIN   @PDate AS p ON [buDate] BETWEEN  [StartDate] AND [EndDate] 
			WHERE /*[buDirection] = -1 AND */[P].[StartDate] = @SD AND [P].[EndDate] = @ED 
			GROUP BY  [StartDate] , [EndDate]		 
			-- 2 IN THE FOLLOWING INSERT STATEMENT IS FOR BILL COUNT 
			INSERT INTO @TOTALCOUNTS (TOTALCNT,TYPE,STARTDATE,ENDDATE) 
			VALUES (@TEMPCOUNT,2,@SD,@ED) 
			 
			DELETE FROM @TempPDate WHERE [StartDate] = @SD AND [EndDate] = @ED 
			SET	@ROWCOUNT = @ROWCOUNT - 1 
	END	 
	 
	IF @ShowGroup = 1 
	BEGIN 
		------------- 
		TRUNCATE TABLE [#NEWCustCnt] 
		TRUNCATE TABLE [#CustCnt] 
		-------------------- 
		SELECT [f].[Guid], [f].[Level], [f].[Path], [gr].[Code], [gr].[Name], CASE [LatinName] WHEN '' THEN Name ELSE  [LatinName] END AS [LatinName], [gr].[ParentGuid] 
		INTO #GrpTbl 
		FROM  fnGetGroupsOfGroupSorted(@GroupGuid,1) AS f  
		INNER JOIN gr000 AS gr ON f.Guid = gr.Guid 
		--------------- 
		SELECT @Level = MAX(Level) FROM #GrpTbl 
	 
		-- THIS SELECT STATEMENT FILLS [#Custcm] WITH THE CUSTOMERS GUID AND THE MATERIAL GUID THAT THEY HAVE  
		-- PURHCASED DURING THE RANGE OF SPECIFIED DATE. 
		-- Customer Guid , Bill Guid, Start and End Date, Purchased Material Guid and Name and its Direct Parent Guid 
		SELECT DISTINCT [CustPtr], [buGuid], [StartDate], [EndDate], [mt].[GroupGuid] AS [MatGuid], [MT].[GUID], [MT].[NAME],[F].[DistPtr] 
		INTO [#Custcm] 
		FROM [#Result] 		AS [f]  
		INNER JOIN @PDate  	AS [p]  ON [buDate] BETWEEN  [StartDate] AND [EndDate] 
		INNER JOIN [mt000]	AS [mt] ON [MatPtr] = [mt].[Guid]  
--		WHERE [buDirection] = -1  
		 
--		SELECT [C].CUSTOMERNAME, [B].[NAME] FROM [#CUSTCM] AS [A] , [MT000] AS [B] , [CU000] AS [C] WHERE [A].[GUID] = [B].[GUID] AND [A].CustPtr = [C].GUID		 
		 
		-- THIS INSUTRUCTION INSERTS THE COUNT OF CUSTOMERS  
		-- GROUPED BY THE MATERIALS GUID THAT THEY HAVE PURCHASED 
		INSERT INTO [#CustCnt]  
		SELECT 	COUNT(DISTINCT( CAST([CustPtr] AS [NVARCHAR](40)))) AS [CustCNT],  
			COUNT(DISTINCT( CAST([buGuid] AS [NVARCHAR](40))))  AS [buCount],  
			[Guid], [StartDate], [EndDate] , 
			CASE @GroupByDistBit WHEN 1 THEN [#CustCm].[DistPtr] ELSE 0x00 END 
		FROM [#Custcm] 
		GROUP BY  
			CASE @GroupByDistBit WHEN 1 THEN [#CustCm].[DistPtr] ELSE 0x00 END, 
			[Guid], [StartDate], [EndDate] 
		------------------------------ 
		 
--		SELECT * FROM [#CustCnt] 
		 
		--SELECT * FROM [#NEWCNT2]		 
		-- SALEM INTENTIALLY HAS ADDED THIS LINE BECAUASE WITHOUT IT THE COUNT OF CUSTOMERS  
		-- OF THE FIRST DIRECT PARENT GROUP IN THE GROUP TREE IS IGNORED 
		-- SO NEVER DELETE THIS INCREMENT STATEMENT 
		SET @Level = @Level + 1		 
		SET @MaxLevel = @Level	 
		WHILE @Level >= 0 
		BEGIN 
			--SELECT * FROM #Custcm WHERE Guid = '255A3426-051F-4AB6-AD0A-C9B3B82CCF91' 
			INSERT INTO #FinalResult 
				SELECT 
					[gr].[ParentGuid], [gr].[Guid], [gr].[Code], [gr].[Name] ,  
					[gr].[LatinName], SUM([Qty]), 
					SUM(Val), 1, '', 
					[f].[StartDate], [f].[EndDate], ISNULL([c].[CustCnt],0), /*[nc].[NewCustCNT]*/ISNULL([nc].[NewCustCNT],0), ISNULL([c].[buCount],0), 
					[ParentGuid], [gr].[Path], 1,CASE @GroupByDistBit WHEN 1 THEN [F].[DistPtr] ELSE 0x00 END AS [DistPtr] 
				FROM [#FinalResult]	 AS [f]  
				INNER JOIN [#GrpTbl] 	 AS [gr] ON [f].[GroupGUID] = [gr].[Guid] 
				LEFT JOIN  [#NEWCustCnt] AS [nc] ON [gr].[Guid] = [nc].[MatGuid] AND [f].[StartDate] = [nc].[StartDate] AND [f].[DistPtr] = CASE @GroupByDistBit WHEN 1 THEN  [nc].[DistPtr] ELSE [f].[DistPtr] END  
				LEFT JOIN  [#CustCnt] 	 AS [c]  ON [gr].[Guid] = [c].[MatPtr]   AND [f].[StartDate] = [c].[StartDate]  AND [f].[DistPtr] = CASE @GroupByDistBit WHEN 1 THEN  [c].[DistPtr]  ELSE [f].[DistPtr] END  
				WHERE gr.Level = @Level 
				GROUP BY  
					 CASE @GroupByDistBit WHEN 1 THEN [F].[DistPtr] ELSE 0x00 END, 
					 [gr].[Guid], [gr].[Code], [gr].[Name], [gr].[LatinName], [f].[StartDate], [f].[EndDate], 
					 [ParentGuid], [gr].[Path], ISNULL([c].[CustCnt],0), /*[nc].[NewCustCNT]*/ISNULL([nc].[NewCustCNT],0), ISNULL([c].[buCount],0) 
			 
		-------------------------						 
			-- UP TO THIS POINT [#Custcm] CONTAINS THE CUSTOEMRS GUID AND THE MATERIALS GUID THAY HAVE PURCHASED 
			-- THIS INSTRUCTION WILL INSERT THE PARENT GROUP FOR EACH MATERIAL IN TABLE [#Custcm] 
			-- SO WE CAN TRAVERSE THE MATERIAL COUNT TREE FROM LEAVES UP TO THE ROOT 
			-- PLEASE NOTICE THAT AT THE FIRST ITERATION FIELD [#Custcm].[Guid] HOLDS MATERIAL GUID 
			-- AND [#Custcm].[MatGuid] HOLD THE DIRECT PARENT GROUP GUID FOR THAT MATERIAL. 
			-- AS LOOP ITERATES, THIS INSTRUCTION WOULD PUT [#Custcm].[Guid] = [#Custcm].[MatGuid] 
			-- AND PUT THE NEW DIRECT PARENT GROUP IN [#Custcm].[MatGuid]. SO THIS MECHANISM  
			-- ALONG WITH THE CLAUSE 'WHERE gr.Level = @Level' IN THE INSERT STATEMENT FOUND IN THE BEGINNING  
			-- OF THIS LOOP EMULATES THE TRAVERSING MOVE IN THE TREE FROM THE LEAVES THAT HOLD MATERIALS GUID 
			-- AT THE FIRST ITERATION UP TO THE ROOT PASSING BY EACH DIRECT MATERIAL PARENT GROUP FOR EACH MATERIAL GROUP			 
			INSERT INTO [#Custcm] 
			SELECT [CustPtr], [buGuid], [StartDate], [EndDate], [gr].[ParentGuid], [GR].[GUID], [GR].[NAME],[A].[DistPtr] 
			FROM [#Custcm] AS [A]  
			INNER JOIN [gr000] AS [gr] ON [gr].[Guid] = [A].[MatGuid] 
			 
			-- NOW WILL COUNT THE CUSTOMERS COUNT BASED IN THE MATERIALS GROUP GUID 
			TRUNCATE TABLE [#CustCnt] 
			INSERT INTO [#CustCnt] 
				SELECT COUNT(DISTINCT( CAST([CustPtr] AS [NVARCHAR](40)))) AS [CustCNT], COUNT(DISTINCT( CAST([buGuid] AS [NVARCHAR](40)))) AS [buCount], [GUID], [StartDate], [EndDate] ,CASE @GroupByDistBit WHEN 1 THEN [#CustCm].[DistPtr] ELSE 0x00 END 
				FROM [#Custcm] 
				GROUP BY  
					CASE @GroupByDistBit WHEN 1 THEN [#CustCm].[DistPtr] ELSE 0x00 END, 
					[Guid], [StartDate], [EndDate] 
			-------------------------------- 
--			SELECT * FROM [#CUSTCM] 
			 
			-- THESE TWO INSERTION STATEMENT WORK EXACTLY AS THE TWO ABOVE DO 
			-- THE ONY DIEFFERENCE IS THAT THEY WORK ON NEW CUSTOMERS FOR THE MATERIALS 
			INSERT INTO [#NEWCNT2]  
			SELECT DISTINCT [CustPtr], [gr].[ParentGuid], [StartDate], [EndDate],[GR].[GUID], [GR].[NAME],[#NewCnt2].[DistPtr] 
			FROM [#NEWCNT2] INNER JOIN [gr000] AS [gr] ON [gr].[guid] =  [MatGuid] 
			TRUNCATE TABLE [#NEWCustCnt] 
			INSERT INTO [#NEWCustCnt]  
				SELECT COUNT(DISTINCT( CAST([CustPtr] AS [NVARCHAR](40)))) AS [NewCustCNT], [MatGuid], [StartDate], [EndDate] ,CASE @GroupByDistBit WHEN 1 THEN [F].[DistPtr] ELSE 0x00 END AS [DistPtr] 
				FROM [#NEWCNT2] AS [f]  
				--INNER JOIN [Gr000] AS [gr] ON [gr].[Guid] = [MatGuid]			 
				GROUP BY  
					CASE @GroupByDistBit WHEN 1 THEN [F].[DistPtr] ELSE 0x00 END, 
					[MatGuid], [StartDate], [EndDate] 
			------------------------------					 
			SET @Level = @Level -1			 
		END 
		UPDATE [#FinalResult] SET [Path] = (SELECT DISTINCT [f1].[Path] FROM [#FinalResult] AS [f1] WHERE f.GroupGUID = f1.MatPtr) 
		FROM [#FinalResult] AS f 
		WHERE [f].[Flag] = 0 
	END 
	 
	-- THIS TABLE CONTAINS TOW ROWS THE FIRST ONE IS TOTAL COUNT FOR THE CUSTOMERS 
	-- THE SECOND ONE IS THE TOTAL COUNT FOR THE NEW CUSTOMERS 
	SELECT * FROM @TOTALCOUNTS 
	ORDER BY [STARTDATE], [ENDDATE], [TYPE]	 
	IF @ShowGroup = 0  
		SELECT  
			[GrPtr], [MatPtr], [mtCode], [mtName], [mtLatinName], [Qty], [Val], [mtUnitName], [StartDate], [EndDate], [CustCnt], [NewCnt], [buCnt], [Flag] , CASE @GroupByDistBit WHEN 1 THEN [A].[DistPtr] ELSE 0x00 END AS [DistGuid], CASE @GroupByDistBit WHEN 1 THEN [B].[NAME] ELSE 0x00 END AS [DistName] 
		FROM [#FinalResult] AS [A] LEFT JOIN [Distributor000] AS [B] ON [A].[DistPtr] = [B].[GUID] 
		ORDER BY  
			CASE @GroupByDistBit WHEN 1 THEN [A].[DistPtr] ELSE 0x00 END, [Flag] DESC, [mtCode], [StartDate] 
	ELSE 
	BEGIN 
		SELECT  
			[GrPtr], [MatPtr], [mtCode], [mtName], [mtLatinName], [Qty], [Val], [mtUnitName], [StartDate], [EndDate], [CustCnt], [NewCnt], [buCnt], [Flag], [Path] , CASE @GroupByDistBit WHEN 1 THEN [A].[DistPtr] ELSE 0x00 END AS [DistGuid], CASE @GroupByDistBit WHEN 1 THEN [B].[NAME] ELSE 0x00 END AS [DistName] 
		FROM [#FinalResult] AS [A] LEFT JOIN [Distributor000] AS [B] ON [A].[DistPtr] = [B].[GUID] 
		ORDER BY  
			CASE @GroupByDistBit WHEN 1 THEN [A].[DistPtr] ELSE 0x00 END, 
			[Path], [Flag] DESC, [mtCode], [StartDate] 
	END 
	SELECT * FROM #SecViol 
/*
exec prcConnections_Add2 '„œÌ—'
EXECUTE [repDistSalesCoverage] '1/1/2008', '2/29/2008', '00000000-0000-0000-0000-000000000000', '00000000-0000-0000-0000-000000000000', '00000000-0000-0000-0000-000000000000', 'bf26408b-219c-44cc-9492-08b5e64f60b7', 3, '1-1-2008,1-31-2008,2-1-2008,2-29-2008', 1, 1
*/
##################################################################################
#END
