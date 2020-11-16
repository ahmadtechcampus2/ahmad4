#########################################################################
CREATE PROC repLC
	@ParentLC		UNIQUEIDENTIFIER,
	@ChildLC		UNIQUEIDENTIFIER,
	@LCAcc			UNIQUEIDENTIFIER,	
	@CustGuid		UNIQUEIDENTIFIER,	
	@MatGuid		UNIQUEIDENTIFIER,	
	@GroupGuid		UNIQUEIDENTIFIER,					
	@Status			INT, --	ALL = 0, OPEND = 1, CLOSED = 2, EMPTY = 3, EXPENSEONLY = 4, BILLONLY = 5
	@DateType		INT,
	@FromDate		DATETIME,
	@ToDate			DATETIME,
	@ShowFlag		INT,	-- ID_SCHILDLC = 1, ID_SPARENTLC = 2, ID_SLCCURYEAR = 4, ID_SLCPREVYEARS = 8, ID_SLCDDETAILS = 16, 
							-- ID_SEXPENSEDETAILS = 32, ID_SVALUEDETAILS = 64
	@OrderTypeGuid 	UNIQUEIDENTIFIER = 0x0	

AS
BEGIN
	SET NOCOUNT ON;
		
	
	DECLARE @Lang [INT] = [dbo].[fnConnections_getLanguage]() 

	CREATE TABLE #Result
	(
		[ID]				[INT] IDENTITY( 1, 1),
		[Guid]				UNIQUEIDENTIFIER,
		[ParentGuid]		UNIQUEIDENTIFIER,
		[Code]				NVARCHAR(250),	
		[Name]				NVARCHAR(250),
		[LName]				NVARCHAR(250),				
		[Level]				INT,
		[Path]				[NVARCHAR](max) COLLATE ARABIC_CI_AI,
		[Qty]				INT,
		[Price]				FLOAT,
		[Value]				FLOAT,
		[Disc]				FLOAT,
		[Extra]				FLOAT,
		[TotalPrice]		[FLOAT],
		[UnityName]			VARCHAR(255),
		[CustGuid]			UNIQUEIDENTIFIER,
		[BillGuid]			UNIQUEIDENTIFIER,
		[MatGuid]			UNIQUEIDENTIFIER,
		[Expenses]			FLOAT,
		[Type]				INT,
		[CloseDate]			DATETIME,
		[ExpectedCloseDate] DATETIME,
		[Status]			INT,
		[OpenDate]			DATETIME,
		[BiGuid]       UNIQUEIDENTIFIER
	)

	CREATE TABLE #MatTbl( [MatGUID] [UNIQUEIDENTIFIER], [mtSecurity] [INT]) 
	INSERT INTO #MatTbl	EXEC [prcGetMatsList] @MatGUID, @GroupGUID 

	CREATE TABLE #LCTbl ([lcGuid] [UNIQUEIDENTIFIER], [ParentGuid] [UNIQUEIDENTIFIER], [lcSecurity] [INT])
	INSERT INTO #LCTbl 
	SELECT [fn].[GUID], [fn].[ParentGUID], [fn].[Security] 
	  FROM [dbo].[fnGetLCChildList](@ChildLC, @ParentLC, @LCAcc) AS [fn]
		   LEFT JOIN LCRelatedExpense000 AS [ex] ON [ex].[LCGUID] = [fn].[GUID]
	 WHERE (@ShowFlag & 4 <> 0 AND ISNULL([ex].[IsTransfared],0) = 0) OR (@ShowFlag & 8 <> 0 AND [ex].[IsTransfared] = 1) 

	CREATE TABLE #LCMain ([GUID] [UNIQUEIDENTIFIER], [Level] [INT], [Path] [NVARCHAR](max) COLLATE ARABIC_CI_AI)
	INSERT INTO #LCMain SELECT * FROM [dbo].[fnGetChildLCsOfLCSorted]( @ParentLC, 1);

	CREATE TABLE #LC 
	(
		[GUID]			[UNIQUEIDENTIFIER],
		[ParentGUID]	[UNIQUEIDENTIFIER],
		[Code]			[NVARCHAR](250), 
		[Name]			[NVARCHAR](250), 
		[LatinName]		[NVARCHAR](250), 
		[CloseDate]		[DATETIME], 
		[ExpCloseDate]	[DATETIME], 
		[State]			[INT], 
		[BillCount]		[INT], 
		[ExpenseCount]	[INT],
		[OpenDate]		[DATETIME]
	)
	
	INSERT  INTO #LC 
	SELECT  DISTINCT [lc].[GUID],
			[lc].[ParentGUID],
			[lc].[Code],
			[lc].[Name],
			[lc].[LatinName],
			CASE [lc].[State] WHEN 0 THEN [lc].[CloseDate] END,
			[lc].[ExpCloseDate],
			[lc].[State],
			COUNT([bu].[GUID]) OVER (PARTITION BY [lc].[GUID]) billCount,
			COUNT([en].[GUID]) OVER (PARTITION BY [lc].[GUID]) + COUNT([exBu].[GUID]) OVER (PARTITION BY [lc].[GUID]) expenseCount,
			[lc].[OpenDate]
	  FROM 
			LC000 [lc] INNER JOIN #LCMain [lcMain] ON [lc].[ParentGUID] = [lcMain].[GUID]
			LEFT JOIN en000 [en] ON [lc].[GUID] = [en].[LCGUID]
			LEFT JOIN bu000 [bu] ON [lc].[GUID] = [bu].[LCGUID] and [bu].[LCType] = 1
			LEFT JOIN bu000 [exBu] ON [lc].[GUID] = [exBu].[LCGUID] and [exBu].[LCType] = 2
	  WHERE 
			(ISNULL(@ChildLC, 0x0) = 0x0 OR [lc].[GUID] = @ChildLC) AND
			(ISNULL(@LCAcc, 0x0) = 0x0 OR [lc].[AccountGUID] = @LCAcc) AND
			(@Status = 0 OR @Status > 2 OR 
			(@Status = 1 AND [lc].[State] = 1) OR
			(@Status = 2 AND [lc].[State] = 0)) AND
			((@FromDate IS NULL AND @ToDate IS NULL) OR
			(@DateType = 0 AND [OpenDate] BETWEEN @FromDate and @ToDate) OR
			(@DateType = 1 AND  [lc].[State] = 0 AND [CloseDate] BETWEEN @FromDate and @ToDate) OR
			(@DateType = 2 AND [ExpCloseDate] BETWEEN @FromDate and @ToDate))

	DELETE #LC 
	WHERE 
		(@Status = 3 AND (ISNULL(BillCount,0) <> 0 OR ISNULL(ExpenseCount,0) <> 0)) OR
		(@Status = 4 AND (ISNULL(ExpenseCount,0) = 0 OR ISNULL(BillCount,0) <> 0)) OR
		(@Status = 5 AND (ISNULL(BillCount,0) = 0 OR ISNULL(ExpenseCount,0) <> 0))

	---------------------------------------------------------------------------------------
	IF(@ShowFlag & 16 = 0)	
	BEGIN
		INSERT INTO #Result (Guid, ParentGuid, Code, [Name], [LName], Level, [Path], [type], CloseDate, ExpectedCloseDate, Status, OpenDate, [Expenses], [BillGuid], [MatGuid])
		SELECT [lc].[GUID],
			   [lc].[ParentGUID],
			   [lc].[Code],
			   [lc].[Name],
			   [lc].[LatinName], 
			   [lcm].[Level] + 1,
			   [lcm].[Path],
			   1,
			   lc.CloseDate,
			   ExpCloseDate,
			   [State],
			   lc.[OpenDate],
			   NetValue,
			   0x0,
			   0x0
		  FROM #LC lc INNER JOIN #LCMain lcm ON [lcm].[GUID] = [lc].[ParentGUID]
				CROSS APPLY (SELECT SUM(NetValue * CurrencyVal) AS NetValue FROM fnGetLCExpenses([lc].[Guid]) WHERE ISNULL([ExpenseDistMethod],0x0) <> 0x0) AS [fn]
		 ORDER BY [lc].[Code]
	 END
	-----------------------------------------------------------------------------------------
	CREATE TABLE #ExpensesList		--«·‰›ﬁ« 
	(
		[ExpName]			NVARCHAR(250),	
		[buGuid]			UNIQUEIDENTIFIER,
		[matGuid]			UNIQUEIDENTIFIER,
		[expenseDistMethod]	UNIQUEIDENTIFIER,
		[LCExp]				FLOAT,
		[LCGuid]			UNIQUEIDENTIFIER,
		[biGuid]		    UNIQUEIDENTIFIER
	)

		INSERT INTO #ExpensesList
		SELECT 
			CASE @Lang WHEN 0 THEN [ex].[Name] ELSE (CASE [ex].[LatinName] WHEN N'' THEN [ex].[Name] ELSE [ex].[LatinName] END) END, 
			[fn].[buGuid],							
			[fn].[matGuid],			
			[fn].[expenseDistMethod],	
			[fn].[LCExtra] - [fn].[LCDisc],			
			[fn].[LCGuid],
			[fn].[biGUID]
		FROM #LC [lc] CROSS APPLY (SELECT * FROM fnLC_CalcBillItemsDiscExtra([lc].[Guid])) AS [fn]
			INNER JOIN LCExpenses000 [ex] ON [ex].[Guid] = [fn].[expenseDistMethod]
	
	-----------------------------------------------------------------------------------------	
	CREATE TABLE #BillItems			-- «·›Ê« Ì—
	(
		[Guid]			UNIQUEIDENTIFIER,
		[ParentGuid]	UNIQUEIDENTIFIER,
		[Level]			INT,
		[Qty]			INT,
		[Price]			FLOAT,
		[Value]			FLOAT,
		[Disc]			FLOAT,
		[Extra]			FLOAT,
		[UnityName]		VARCHAR(255),
		[CustGuid]		UNIQUEIDENTIFIER,
		[BillGuid]		UNIQUEIDENTIFIER,
		[MatGuid]		UNIQUEIDENTIFIER
	)

	INSERT INTO #BillItems (Guid, [ParentGuid], CustGuid, BillGuid, MatGuid, Qty, Price, Value, Disc, Extra, UnityName)
	SELECT  bi.biGUID,
			bi.buLCGUID,
			bi.buCustPtr,
			bi.buGUID,
			bi.biMatPtr,
			bi.biBillQty,
			bi.biPrice, 
			(bi.biPrice * bi.biBillQty) value,
			(bi.biUnitDiscount * bi.biBillQty) disc,
			(bi.biUnitExtra * bi.biBillQty) extra,
			CASE bi.biUnity WHEN 1 THEN bi.mtUnityName WHEN 2 THEN bi.MtUnit2 WHEN 3 THEN bi.MtUnit3 END AS UnityName
	  FROM  vwExtended_bi bi INNER JOIN #LC LC ON bi.buLCGUID = LC.GUID
			INNER JOIN #MatTbl mt ON bi.biMatPtr = mt.MatGUID
	 WHERE	buLCType = 1 
			AND (ISNULL(@CustGuid, 0x0) = 0x0 OR bi.buCustPtr = @CustGuid) 

	IF(@ShowFlag & 16 <> 0)		--≈ŸÂ«—  ›«’Ì· «·«⁄ „«œ« 
	BEGIN	
		INSERT INTO #Result ([Guid], [ParentGuid], CustGuid, BillGuid, MatGuid,  Qty, Price, Value, Disc, Extra, UnityName, [Expenses], [type], [Status],
							 [Code], [Name], [LName], [CloseDate], [ExpectedCloseDate], [OpenDate], [BiGuid])
		SELECT  [lc].[GUID],
				[lc].[ParentGUID],
				[b].[CustGuid],
				[b].[BillGuid],
				[b].[matguid], 
				SUM([b].[Qty]),
				SUM([b].[Price]), 
				SUM([b].[Value]),
				SUM([b].[Disc]),
				SUM([b].[Extra]),
				[b].[UnityName],
				[ex].[LCExp],
				5, 
				[lc].[State],
				[lc].[Code],
				[lc].[Name],
				[lc].[LatinName], 
				[lc].[CloseDate], 
				[lc].[ExpCloseDate], 
				[lc].[OpenDate],
				[b].Guid
		  FROM  #BillItems [b] 
				INNER JOIN #LC [lc] ON [lc].[GUID] = [b].[ParentGuid]
				INNER JOIN (SELECT SUM([LCExp]) [LCExp], [LCGuid], [buGuid], [matGUID], [biGuid] FROM #ExpensesList GROUP BY [LCGuid], [buGuid], [matGUID], [biGuid])[ex] ON ([ex].[LCGuid] = [lc].[Guid] AND [ex].[buGuid] = [b].[BillGuid] AND [ex].[matGUID] = [b].[matguid] AND [ex].[biGuid] = [b].[Guid])  
		  GROUP BY [lc].[GUID],	[lc].[ParentGUID], [b].[BillGuid], [b].[CustGuid], [b].[matguid], [b].[UnityName], [ex].[LCExp], [lc].[Code], [lc].[Name], [lc].[LatinName], 
				[lc].[CloseDate], [lc].[ExpCloseDate], [lc].[OpenDate], [lc].[State], [b].Guid

		UPDATE #Result
		   SET [TotalPrice] = Value + Extra - Disc
	END

	-----------------------------------------------------------------------------------------
	IF(@ShowFlag & 16 = 0)
	BEGIN
		UPDATE r 
		   SET Value = [sv], Disc =  [sd], Extra = [se], [TotalPrice] = [sv] + [se] - [sd] 
		FROM #Result r INNER JOIN
			(SELECT ParentGuid, SUM(Value) sv, SUM(Disc) sd, SUM(Extra) se 
			FROM #BillItems  GROUP BY [ParentGuid]) [b] ON [r].[GUID] = [b].[ParentGuid]

		UPDATE #ExpensesList
		   SET [buGuid] = 0x0, [matGUID] = 0x0 
	END
	-----------------------------------------------------------------------------------------
	IF  @ShowFlag & 2 <> 0 --≈ŸÂ«— «·„” ‰œ«  «·—∆Ì”Ì…
	BEGIN
		WITH CTE_LCMain  ([Guid], [ParentGuid], [Code], [Name], [LName], [Level], [type], [Status], [Value], [Disc], [Extra], [Expenses], [TotalPrice])
		AS(
			SELECT [lcm].[GUID],
				   [lcm].[ParentGUID],
				   [lcm].[Code],
				   [lcm].[Name],
				   [lcm].[LatinName], 
				   [fn].[Level],
				   0,
				   -1,
				   SUM(Value),
				   SUM(Disc),
				   SUM(Extra),
				   SUM(Expenses),
				   SUM(TotalPrice)
			  FROM #Result [r] INNER JOIN LCMain000 [lcm] ON [lcm].[GUID] = [r].[ParentGuid] INNER JOIN #LCMain [fn] ON [fn].[GUID] = [lcm].[GUID]
		     GROUP BY [lcm].[GUID], [lcm].[ParentGUID], [lcm].[Code], [lcm].[Name], [lcm].[LatinName], [fn].[Level]--, [fn].[Path]
			 UNION ALL
			SELECT [lcm].[GUID],
				   [lcm].[ParentGUID],
				   [lcm].[Code],
				   [lcm].[Name],
				   [lcm].[LatinName], 
				   [fn].[Level],
				   0,
				   -1,
				   Value,
				   Disc,
				   Extra,
				   Expenses,
			      TotalPrice
			  FROM LCMain000 [lcm] INNER JOIN CTE_LCMain [cte] ON [cte].[ParentGUID] = [lcm].[Guid] 
		      INNER JOIN #LCMain [fn] ON [fn].[GUID] = [lcm].[GUID]
		) 
		INSERT INTO #Result ([Guid], [ParentGuid], [Code], [Name], [LName], [Level], [type], [Status], [Value], [Disc], [Extra], [Expenses], [TotalPrice], [BillGuid], [MatGuid])
		SELECT [GUID],
			   [ParentGUID],
			   [Code],
			   [Name],
			   [LName],
			   [Level],
			   0,
			   -1,
			   SUM(Value),
			   SUM(Disc),
			   SUM(Extra),
			   SUM(Expenses),
			   SUM(TotalPrice),
			   0x0,
			   0x0
		  FROM CTE_LCMain
		 GROUP BY [GUID], [ParentGuid], [Code], [Name], [LName], [Level]
	END
	-----------------------------------------------------------------------------------------

	IF(@ShowFlag & 32 <> 0 AND EXISTS(SELECT TOP 1* FROM LCExpenses000) )		-- ›’Ì· «·‰›ﬁ« 
	BEGIN

		DECLARE @SQLQuery		NVARCHAR(MAX)
		DECLARE @PivotColumns	NVARCHAR(MAX)

		CREATE TABLE #Exptemp ( LCExp		FLOAT, 
								ExpLCGuid	UNIQUEIDENTIFIER, 
								ExpName		NVARCHAR(250), 
								ExpBuGuid	UNIQUEIDENTIFIER,  
								ExpMtGuid	UNIQUEIDENTIFIER,
								ExpBiGuid	UNIQUEIDENTIFIER)

		 
		SELECT 
			@PivotColumns = COALESCE(@PivotColumns + ',','') + QUOTENAME(Name)	--Get Rows Names To Convert To Columns
		FROM 
			( SELECT DISTINCT Name 
			  FROM LCExpenses000 ) AS PivotExample
		 
		INSERT INTO #Exptemp
		SELECT 
			SUM(LCExp)			 AS LCExp, 
			LCGuid               AS ExpLCGuid, 
			ExpName, 
			ISNULL(BuGuid, 0x0)  AS ExpBuGuid,
			ISNULL(matGuid, 0x0) AS ExpMtGuid,
			CASE WHEN (@ShowFlag & 16 <> 0 AND @ShowFlag & 2 = 0 ) THEN  ISNULL(biGuid, 0x0) ELSE 0x0 END AS ExpBiGuid
		FROM 
			#ExpensesList
		GROUP BY 
			LCGuid, 
			BuGuid, 
			matGuid, 
			ExpName,
			CASE WHEN (@ShowFlag & 16 <> 0 AND @ShowFlag & 2 = 0) THEN ISNULL(biGuid, 0x0) ELSE 0x0 END

		IF [dbo].[fnObjectExists]('##LCExpensesConvertRowsToColumns') <> 0
			DROP TABLE ##LCExpensesConvertRowsToColumns

		-- Convert Rows To Columns
		SET  @SQLQuery = N' SELECT ExpLCGuid, ExpBuGuid, ExpMtGuid, ExpBiGuid, ' + @PivotColumns + 
						   'INTO ##LCExpensesConvertRowsToColumns
							FROM #Exptemp fn 
							PIVOT(  Sum(LCExp)
							FOR ExpName in( ' + @PivotColumns + ')) AS P'
		EXEC sp_executesql @SQLQuery 


		SELECT * 
		INTO 
			#Result2
		FROM 
			#result r 
			LEFT JOIN ##LCExpensesConvertRowsToColumns t ON [r].[Guid]     = [t].[ExpLCGuid] 
														AND [r].[BillGuid] = [t].[ExpBuGuid] 
														AND [r].[MatGuid]  = [t].[ExpMtGuid] 
														AND (((@ShowFlag & 16 <> 0  OR @ShowFlag & 2 = 0) AND [r].[BiGuid]  = [t].[ExpBiGuid] ) 
															 OR @ShowFlag & 16 = 0 OR @ShowFlag & 2 <> 0) 
		IF [dbo].[fnObjectExists]('##LCExpensesConvertRowsToColumns') <> 0
			DROP TABLE ##LCExpensesConvertRowsToColumns

		DROP TABLE  #Exptemp



		IF(@ShowFlag & 2 <> 0)		--≈ŸÂ«— «·«⁄ „«œ«  «·—∆Ì”Ì…
		BEGIN				 
			DECLARE @cnt	  INT = (SELECT MAX([Number]) FROM LCExpenses000)
			DECLARE @colName  NVARCHAR(250)
			DECLARE @maxlevel INT = (SELECT MAX([Level]) FROM #Result2) + 1
			DECLARE @level	  INT = @maxlevel

			WHILE (@cnt > 0)		--Update tree with new values
			BEGIN
				SET @level = @maxlevel
				SELECT @colName = Name From LCExpenses000 WHERE Number = @cnt
				
				------- Update lc incase of expenses only
				SET @SQLQuery = N'UPDATE R SET [' + @colName + '] =  NetValue
					FROM #Result2 R INNER JOIN #LC lc ON [lc].[GUID] = R.[Guid]
					CROSS APPLY (SELECT NetValue, ExpenseName FROM fnGetLCExpenses([lc].[Guid]) WHERE ISNULL([ExpenseDistMethod],0x0) <> 0x0) AS [fn] 
					WHERE '''+@colName+''' = fn.[ExpenseName] AND [lc].[BillCount] = 0'
				EXEC sp_executesql @SQLQuery

				--update expenses details in hierarchy
				WHILE @Level >= 0 
				BEGIN
					SET @SQLQuery = N'UPDATE #Result2 SET [' + @colName + '] =  sumEx
								 FROM (SELECT [ParentGuid], SUM(ISNULL( [' + @colName + '],0)) AS sumEx FROM #Result2 GROUP BY [ParentGuid]) r2 
								 WHERE r2.[ParentGuid] = #Result2.[Guid]'
					EXEC sp_executesql @SQLQuery
					SET @level = @level - 1
				END		
				SET @cnt = @cnt - 1
			END
		END
		SELECT r.*, 
			CASE @Lang WHEN 0 THEN [r].[Name] ELSE (CASE [r].[LName] WHEN N'' THEN [r].[Name] ELSE [r].[LName] END) END + '-' + [r].[Code] AS [CodeName], 
			CASE WHEN @Lang <> 0 AND ISNULL([cu].[LatinName], '') <> '' THEN [cu].[LatinName] ELSE [cu].[CustomerName] END AS [CustomerName],
			CASE WHEN @Lang <> 0 AND ISNULL([bu].[btLatinName], '') <> '' THEN [bu].[btLatinName] ELSE [bu].[btName] END + ': ' + CAST([bu].[buNumber] AS NVARCHAR(10)) AS [btName], 
			[mt].[mtCode]  + '-' + CASE WHEN @Lang <> 0 AND ISNULL([mt].[mtLatinName], '') <> '' THEN [mt].[mtLatinName] ELSE [mt].[mtName] END  AS [mtName],
			[bu].[buDate],
			CASE WHEN @Lang <> 0 AND ISNULL([lcm].[LatinName], '') <> '' THEN [lcm].[LatinName] ELSE [lcm].[Name] END + '-' + [lcm].[Code] AS [LCMainName],
			[r].[TotalPrice] + [r].[Expenses] AS [Total],
			[lcm].[GUID] AS [LCMainGuid],
			CASE WHEN @Lang <> 0 AND ISNULL([orp].orderLatinName, '') <> '' THEN [orp].orderLatinName ELSE [orp].orderName END + ': ' + CAST([orp].orderNumber AS NVARCHAR(10)) AS [OrderType]
		FROM #Result2 r
		LEFT JOIN LCMain000 lcm ON lcm.GUID =r.[ParentGuid]
		LEFT JOIN cu000 cu ON r.CustGuid = cu.[GUID]
		LEFT JOIN vwbu bu ON r.BillGuid = bu.buGUID	
		LEFT JOIN vwmt mt ON r.MatGuid = mt.mtGUID
		LEFT JOIN vwOrderBuBiPosted orp ON r.biGuid = orp.orderPostedBiGuid 
		WHERE @OrderTypeGuid = orp.orderGuid OR @OrderTypeGuid = 0x0
		ORDER BY [Path], [type], r.Code, cu.CustomerName, bu.buNumber, mt.mtCode
	END
	ELSE 
	BEGIN	
		SELECT  r.*, 
			CASE @Lang WHEN 0 THEN [r].[Name] ELSE (CASE [r].[LName] WHEN N'' THEN [r].[Name] ELSE [r].[LName] END) END + '-' + [r].[Code] AS [CodeName], 
			CASE WHEN @Lang <> 0 AND ISNULL([cu].[LatinName], '') <> '' THEN [cu].[LatinName] ELSE [cu].[CustomerName] END AS [CustomerName],
			CASE WHEN @Lang <> 0 AND ISNULL([bu].[btLatinName], '') <> '' THEN [bu].[btLatinName] ELSE [bu].[btName] END + ': ' + CAST([bu].[buNumber] AS NVARCHAR(10)) AS [btName], 
			[mt].[mtCode] + '-' + (CASE WHEN @Lang <> 0 AND ISNULL([mt].[mtLatinName], '') <> '' THEN [mt].[mtLatinName] ELSE [mt].[mtName] END) AS [mtName],
			[bu].[buDate],
			CASE WHEN @Lang <> 0 AND ISNULL([lcm].[LatinName], '') <> '' THEN [lcm].[LatinName] ELSE [lcm].[Name] END + '-' + [lcm].[Code] AS [LCMainName],
			[r].[TotalPrice] + [r].[Expenses] AS [Total],
			[lcm].[GUID] AS [LCMainGuid],
			CASE WHEN @Lang <> 0 AND ISNULL([orp].orderLatinName, '') <> '' THEN [orp].orderLatinName ELSE [orp].orderName END + ': ' + CAST([orp].orderNumber AS NVARCHAR(10)) AS [OrderType]
		FROM #Result r
		LEFT JOIN LCMain000 lcm ON lcm.GUID = r.[ParentGuid]
		LEFT JOIN cu000 cu ON r.CustGuid = cu.[GUID]
		LEFT JOIN vwbu bu ON r.BillGuid = bu.buGUID	
		LEFT JOIN vwmt mt ON r.MatGuid = mt.mtGUID
		LEFT JOIN vwOrderBuBiPosted orp ON r.biGuid = orp.orderPostedBiGuid 
		WHERE @OrderTypeGuid = orp.orderGuid OR @OrderTypeGuid = 0x0
		ORDER BY [Path], [type], r.Code,cu.CustomerName, bu.buNumber, mt.mtCode ,[orp].orderNumber
	END
END
#########################################################################
CREATE FUNCTION fnGetLCMainList(@LCMainGUID [UNIQUEIDENTIFIER])
	RETURNS @Result TABLE([GUID] [UNIQUEIDENTIFIER])
AS BEGIN
	DECLARE @FatherBuf TABLE([GUID] [UNIQUEIDENTIFIER], [LEVEL] [INT])
	DECLARE @Continue [INT]
	SET @LCMainGUID = ISNULL(@LCMainGUID, 0x0)
	IF @LCMainGUID = 0x0
	BEGIN
		INSERT INTO @Result SELECT [GUID] FROM [LCMain000]
		RETURN
	END
	DECLARE @LEVEL [INT]
	SET @LEVEL = 0
	INSERT INTO @FatherBuf SELECT [GUID], @LEVEL FROM [LCMain000] WHERE [GUID] = @LCMainGUID
	SET @Continue = 1
	WHILE @Continue <> 0
	BEGIN
		SET @LEVEL = @LEVEL + 1
		INSERT INTO @FatherBuf
			SELECT [lc].[GUID], @LEVEL
			FROM [LCMain000] AS [lc] INNER JOIN @FatherBuf AS [fb] ON [lc].[ParentGUID] = [fb].[GUID]
			WHERE [fb].[Level] = @LEVEL - 1
		SET @Continue = @@ROWCOUNT
	END
	INSERT INTO @Result SELECT [GUID] FROM @FatherBuf
	RETURN
END
#########################################################################
CREATE FUNCTION fnGetLCChildList
      (@LCGuid UNIQUEIDENTIFIER, @LCMainGuid UNIQUEIDENTIFIER, @LCAccGuid UNIQUEIDENTIFIER) RETURNS TABLE 
AS
RETURN
      SELECT [lc].[GUID], [lc].[ParentGUID], [lc].[Security]
      FROM LC000 AS [lc] 
		   INNER JOIN [dbo].[fnGetLCMainList](@LCMainGuid) AS [lcm] ON [lcm].[GUID] = [lc].[ParentGUID]
      WHERE (ISNULL(@LCGuid, 0x0) = 0x0 OR [lc].[GUID] = @LCGuid) AND (ISNULL(@LCAccGuid, 0x0) = 0x0 OR [lc].[AccountGUID] = @LCAccGuid);
#########################################################################
CREATE PROC repOrderLC
	@ChildLC		UNIQUEIDENTIFIER,
	@CustGuid		UNIQUEIDENTIFIER,	
	@MatGuid		UNIQUEIDENTIFIER,	
	@GroupGuid		UNIQUEIDENTIFIER,					
	@ShowFlag		INT,	-- ID_SCHILDLC = 1, ID_SPARENTLC = 2, ID_SLCCURYEAR = 4, ID_SLCPREVYEARS = 8, ID_SLCDDETAILS = 16, 
							-- ID_SEXPENSEDETAILS = 32, ID_SVALUEDETAILS = 64
	@OrderTypeGuid 	UNIQUEIDENTIFIER = 0x0

AS
BEGIN
	SET NOCOUNT ON;


	EXEC repLc  0x0, @ChildLC,0x0,@CustGuid,@MatGuid,@GroupGuid,0,0,NULL,NULL,@ShowFlag,@OrderTypeGuid


END
#########################################################################
#END











