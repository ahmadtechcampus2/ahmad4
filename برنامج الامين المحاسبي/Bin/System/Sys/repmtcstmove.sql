###########################################################################
CREATE PROCEDURE repMatMoveByCust
	@StartDate AS [DateTime] ,            
	@EndDate AS [DateTime] ,             
	@Src AS [UNIQUEIDENTIFIER] , 
	@AccGUID AS [UNIQUEIDENTIFIER] , 
	@GroupGUID AS [UNIQUEIDENTIFIER] , 
	@StoreGUID AS [UNIQUEIDENTIFIER] , 
	@IncludeSubStores AS [INT],
	@CostGUID AS [UNIQUEIDENTIFIER] , 
	@ShowQty AS [INT], 
	@ShowGroup AS [INT], 
	@ShowBonus AS [INT], 
	@ShowVal AS [INT], 
	@AddBonusToQty AS [INT], 
	@AddDiscToVal AS [INT], 
	@AddTaxToVal AS [INT],
   	@InOut AS [INT], 
	@CurPtr AS [UNIQUEIDENTIFIER] , 
   	@CurVal AS [FLOAT],             
	@AccLevel AS [INT],             
	@MatLevel AS [INT] = 0,             
	@UseUnit AS [INT],
	@Posted	AS [INT],
	@ClassPtr AS [NVARCHAR] (256),
	@ShowMat [INT] = 1,
	@MatCondGuid [UNIQUEIDENTIFIER] = 0x00,
	@CustCondGuid [UNIQUEIDENTIFIER] = 0x00,
	@CustGUID  AS [UNIQUEIDENTIFIER] = 0x0
AS          
	SET NOCOUNT ON 
	DECLARE @GUIDZero AS [UNIQUEIDENTIFIER],@Sql NVARCHAR(max) 
	SET @GUIDZero = 0x0  
	DECLARE @aSort	INT = 1
	----------------------------  
	CREATE TABLE [#SecViol]([Type] [INT], [Cnt] [INT])  
	----------------------------  
	CREATE TABLE [#Cust] ( [Number] [UNIQUEIDENTIFIER], [Sec] [INT])  
	INSERT INTO [#Cust] EXEC [prcGetCustsList]  @CustGUID, @AccGUID, @CustCondGuid  
	 
	-------Bill Resource ---------------------------------------------------------  
	CREATE TABLE [#Src] ( [Type] [UNIQUEIDENTIFIER] , [Sec] [INT], [ReadPrice] [INT], [UnPostedSec][INT]) 
	INSERT INTO [#Src] EXEC [prcGetBillsTypesList2] @Src  
	-------------------------------------------------------------------  
	CREATE TABLE #Account_Tbl ( [GUID] [UNIQUEIDENTIFIER],[cuGUID] [UNIQUEIDENTIFIER] , [Level] [INT] , [Path] [NVARCHAR] (max),[acSecurity] [INT], [Code] [NVARCHAR](256) COLLATE ARABIC_CI_AI,[Name] [NVARCHAR](256) COLLATE ARABIC_CI_AI,[LatinName] [NVARCHAR](256) COLLATE ARABIC_CI_AI,NSons INT)  
	INSERT INTO [#Account_Tbl] 
		SELECT   
			[fn].[GUID],  
			0x00, 
			[fn].[Level],   
			[fn].[Path], 
			[ac].[Security], 
			[ac].[Code],[ac].[Name],[ac].[LatinName],AC.NSons
		FROM   
			[dbo].[fnGetAccountsList]( @AccGUID, @aSort) AS [Fn]  
			INNER JOIN [ac000] AS [ac] ON [ac].[Guid] = [fn].[GUID] 
			-- LEFT JOIN (SELECT [AccountGuid],[cu2].[GUID] FROM [cu000] AS [cu2]  
			-- INNER JOIN [#Cust] AS [cust] ON [cust].[Number] = [cu2].[GUID]) AS [cu] ON [cu].[AccountGuid] = [fn].[GUID] 
		WHERE	 
			[ac].[Type] = 1 
			 
	UPDATE [#Account_Tbl] 
	SET  
		[cuGUID] = [cu].[Guid] 
	FROM 	 
		[#Account_Tbl] [ac]  
		INNER JOIN  
		(	SELECT  
				[AccountGuid], 
				[cu2].[GUID]  
			FROM  
				[cu000] AS [cu2]  
				INNER JOIN [#Cust] AS [cust] ON [cust].[Number] = [cu2].[GUID] 
		) AS [cu] ON [cu].[AccountGuid] = [ac].[GUID] 
	IF @CustCondGuid <> 0X00 
		DELETE [#Account_Tbl] WHERE [cuGUID] = 0X00 AND NSons = 0
	IF @AccGUID IN (SELECT [GUID] FROM [AC000] WHERE [TYPE] = 4) 
	BEGIN 
		UPDATE #Account_Tbl SET [Level] = [Level] - 1 
		DELETE a FROM #Account_Tbl a where path = (SELECT MIN(PATH) FROM #Account_Tbl b GROUP BY [GUID] HAVING COUNT(*) > 1 and b.[GUID] = a.[GUID] ) 
	END 
	--CREATE CLUSTERED INDEX 	IINDF ON #Account_Tbl([GUID]) 
	-------Mat Table----------------------------------------------------------  
	CREATE TABLE [#MatTbl]( [mtNumber] [UNIQUEIDENTIFIER] , [mtSecurity] [INT])    
	INSERT INTO [#MatTbl] EXEC [prcGetMatsList]  NULL, @GroupGUID,-1,@MatCondGuid 
	
	DECLARE @GRTbl TABLE( [GUID] [UNIQUEIDENTIFIER] , [Level] [INT],[Path] NVARCHAR(max))  
	INSERT INTO @GRTbl SELECT [GUID], [Level],path FROM [dbo].[fnGetGroupsOfGroupSorted]( @GroupGUID, 0)  
	-------Store Table----------------------------------------------------------  
	DECLARE @StoreTbl TABLE( [Number] [UNIQUEIDENTIFIER] )    
	IF ( @IncludeSubStores <> 0 OR  ISNULL( @StoreGUID, 0x0) = 0x0 ) 
		INSERT INTO @StoreTbl SELECT [Guid] FROM [fnGetStoresList]( @StoreGUID) 
	ELSE 
		INSERT INTO @StoreTbl SELECT @StoreGUID 
	------Cost Table----------------------------------------------------------  
	DECLARE @CostTbl TABLE( [Number] [UNIQUEIDENTIFIER] )  
	INSERT INTO @CostTbl SELECT [Guid] FROM [fnGetCostsList]( @CostGUID) 
	IF @CostGUID = @GUIDZero  
		INSERT INTO @CostTbl VALUES( @GUIDZero)  
	-------------------#Result------------------------------------------------ 
	CREATE TABLE [#Result](
				[Acc]			[UNIQUEIDENTIFIER],
				[CuPtr]			[UNIQUEIDENTIFIER],
				[CuName]		[NVARCHAR](MAX),
				[MatPtr]		[UNIQUEIDENTIFIER] , 
				[GRPtr]			[UNIQUEIDENTIFIER] , 
				[Qty]			[FLOAT], 
				[Bonus]			[FLOAT], 
				[VAL]			[FLOAT], 
				[DiscExtra]		[FLOAT],
				[Tax]			[FLOAT],
				[mtSecurity]	[INT], 
				[AccSecurity]	[INT], 
				[Security]		[INT], 
				[UserSecurity]  [INT])
	------------------------------Colect Tabels 
	INSERT INTO [#Result] 
	SELECT 
		[AcTbl].[GUID],--( CASE [Bill].[BuCustPtr] WHEN @GUIDZero THEN [Bill].[BuCustAcc] ELSE [cu].[cuAccount] END), 
		[b].[CuPtr],
		[b].CuName,
		[B].[biMatPtr], 
		[B].[mtGroup], 
		[B].[Qty], 
		[B].[Bonus], 
		[B].[Val], 
		[B].[DiscExtra],
		[B].[Tax],
		[B].[mtSecurity], 
		ISNULL( [acSecurity], 0), 
		B.[buSecurity], 
		ASec 
	FROM 
		(SELECT 
			CASE [Bill].[BuCustPtr] WHEN @GUIDZero THEN [Bill].[BuCustAcc] ELSE [cu].[AccountGuid] END as cuAcc, 
			[Bill].buCustPtr AS [CuPtr],
			[cu].[CustomerName] AS [CuName],
			[Bill].[biMatPtr], 
			[Bill].[mtGroup], 
			SUM(CASE @UseUnit 
				WHEN 0 THEN ( [biQty] + [biBonusQnt] * @AddBonusToQty) * @ShowQty 
				WHEN 1 THEN ( [biQty2] + [biBonusQnt] * @AddBonusToQty/CASE WHEN [Bill].[mtUnit2Fact] = 0 THEN 1 ELSE [Bill].[mtUnit2Fact] END) * @ShowQty 
				WHEN 2 THEN ( [biQty3] + [biBonusQnt] * @AddBonusToQty/CASE WHEN [Bill].[mtUnit3Fact] = 0 THEN 1 ELSE [Bill].[mtUnit3Fact] END) * @ShowQty 
				WHEN 3 THEN ( [biQty] + [biBonusQnt] * @AddBonusToQty) * @ShowQty/ CASE [mtDefUnitFact] WHEN 0 THEN 1 ELSE [mtDefUnitFact] END 
				END * CASE @InOut WHEN 0 THEN 1 WHEN 1 THEN [btDirection] WHEN 2 THEN (-[btDirection]) END) as Qty, 
			SUM([biBonusQnt] * @ShowBonus  
				* CASE @InOut WHEN 0 THEN 1 WHEN 1 THEN [btDirection] WHEN 2 THEN (-[btDirection]) END  
				/CASE @UseUnit 
					WHEN 0 THEN 1 
					WHEN 1 THEN CASE WHEN [Bill].[mtUnit2Fact] = 0 THEN 1 ELSE [Bill].[mtUnit2Fact] END 
					WHEN 2 THEN CASE WHEN [Bill].[mtUnit3Fact] = 0 THEN 1 ELSE [Bill].[mtUnit3Fact] END   
					ELSE CASE [Bill].[mtDefUnitFact] WHEN 0 THEN 1 ELSE [Bill].[mtDefUnitFact] END  
				END) AS Bonus, 
			SUM(@ShowVal * (CASE WHEN [ReadPrice] >= [BuSecurity] THEN [biQty] * [FixedBiUnitPrice]
																		+ (@AddDiscToVal * [biQty] * ([FixedBiUnitExtra] - [FixedBiUnitDiscount]))
																		+ (@AddTaxToVal * [FixedBiVAT])
																	ELSE 0 END)
			             * CASE @InOut WHEN 0 THEN 1 WHEN 1 THEN [btDirection] WHEN 2 THEN (-[btDirection]) END) [Val],
			SUM(CASE WHEN [ReadPrice] >= [BuSecurity] THEN 
											[biQty] * ([FixedBiUnitExtra] - [FixedBiUnitDiscount])							
									      ELSE 0 END
			             * CASE @InOut WHEN 0 THEN 1 WHEN 1 THEN [btDirection] WHEN 2 THEN (-[btDirection]) END) [DiscExtra],
			SUM(CASE WHEN [ReadPrice] >= [BuSecurity] THEN [FixedBiVAT] ELSE 0 END
			             * CASE @InOut WHEN 0 THEN 1 WHEN 1 THEN [btDirection] WHEN 2 THEN (-[btDirection]) END) [Tax],
			[Bill].[mtSecurity], 
			 
			[Bill].[buSecurity], 
			CASE [Bill].[buIsPosted] WHEN 1 THEN [Src].[Sec] ELSE [Src].[UnPostedSec] END AS ASec 
		FROM 
			( [dbo].[fnExtended_Bi_Fixed]( @CurPtr) AS [bill] 
			INNER JOIN [#Src] AS [Src] ON [Bill].[buType] = [Src].[Type] 
			INNER JOIN [#MatTbl] AS [mt] ON [Bill].[biMatPtr] = [mt].[mtNumber]  
			INNER JOIN @CostTbl AS [Co] ON [Bill].[BiCostPtr] = [Co].[Number]  
			INNER JOIN @StoreTbl AS [St] ON [Bill].[BiStorePtr] = [St].[Number]  
			LEFT JOIN [cu000] AS [cu] ON [cu].[GUID] = [Bill].[BuCustPtr]
			LEFT join [#Cust] AS cust on cust.Number=cu.GUID)
		WHERE 
			[Bill].[buDate] between @StartDate AND @EndDate  
			AND ( @ClassPtr = '' OR @ClassPtr = [Bill].[biClassPtr]) 
			AND (  ( @Posted = -1)  OR (  [Bill].[buIsPosted] = @Posted )  ) 
		GROUP BY 
			CASE [Bill].[BuCustPtr] WHEN @GUIDZero THEN [Bill].[BuCustAcc] ELSE [cu].[AccountGuid] END, 
			[Bill].[biMatPtr], 
			[Bill].[mtGroup], 
			[Bill].[mtSecurity], 
			[Bill].[buSecurity], 
			cust.Number,
			[Bill].[buCustPtr],
			[cu].[CustomerName],
			CASE [Bill].[buIsPosted] WHEN 1 THEN [Src].[Sec] ELSE [Src].[UnPostedSec] END) as [B] 
		RIGHT JOIN #Account_Tbl AS [AcTbl] ON cuAcc = [AcTbl].[GUID] 
		
	----------------------------------------------------------------------------------------------------------- 
	EXEC [prcCheckSecurity] 
	----------------------------------------------------------------------------------------------------------- 
	------ First Result Table and Total Result Table-----------------------------------------------------------  
	CREATE TABLE #ResultTbl (  
			[AccPtr]	[UNIQUEIDENTIFIER] , 
			[CuPtr]		[UNIQUEIDENTIFIER],
			[CuName]	[NVARCHAR](MAX),
			[Path]		[NVARCHAR] (4000), 
			[MatPtr]	[UNIQUEIDENTIFIER] ,  
			[GRPtr]		[UNIQUEIDENTIFIER] ,  
			[Qty]		[FLOAT],  
			[Bonus]		[FLOAT],  
			[Val]		[FLOAT],
			[DiscExtra] [FLOAT],
			[Tax]		[FLOAT],  
			[Lv]		[INT], 
			[flg]		[BIT] DEFAULT 0)  
	------ End Result Table Collected by Level---------------------------------  
	INSERT INTO #ResultTbl 
	SELECT 
		[Res].[Acc], 
		[res].[CuPtr], 
		[res].[CuName],
		[AcTbl].[Path], 
		[Res].[MatPtr],  
		[Res].[GRPtr],  
		SUM( [Res].[Qty]),  
		SUM( [Res].[Bonus]),  
		SUM( [Res].[VAL]), 
		SUM( [Res].[DiscExtra]),
		SUM( [Res].[Tax]),
		0 ,1 
	FROM  
		[#Result] AS [Res]  
		INNER JOIN @GRTbl       AS [GRTbl] ON [GRTbl].[GUID] = [Res].[GRPtr] 
		INNER JOIN #Account_Tbl AS [AcTbl] ON [AcTbl].[GUID] = [Res].[Acc]
	GROUP BY  
		[Res].[Acc],  
		[AcTbl].[Path],  
		[Res].[MatPtr],  
		[Res].[GRPtr],
		[res].[CuPtr],
		[Res].[CuName]
	---------------------------------------- 
	IF @ShowGroup = 1  
	BEGIN 
		INSERT INTO #ResultTbl 
		SELECT 
			[RS].[AccPtr], 
			[RS].[CuPtr], 
			[RS].[CuName],
			[RS].[Path], 
			NULL , 
			[RS].[GRPtr], 
			SUM( [Qty]),  
			SUM( [Bonus]),  
			SUM( [Val]), 
			SUM( [DiscExtra]),
			SUM( [Tax]),
			Lv + 1, 
			flg 
		FROM  
			#ResultTbl AS [RS]  
		GROUP BY 
			[Lv], 
			[RS].[AccPtr], 
			[RS].[Path], 
			[RS].[GRPtr], 
			flg,
			[RS].[CuPtr], 
			[RS].[CuName]
		--------------------------------------- 
			declare @Level int
			select @Level = max(lv) from  #ResultTbl where [MatPtr] is NULL 
			declare @cnt INT 
			set @cnt = 1
			while (@cnt > 0)
			begin
				INSERT INTO #ResultTbl 
				SELECT 
					[RS].[AccPtr], 
					[RS].[CuPtr], 
					[RS].[CuName],
					[RS].[Path], 
					NULL , 
					gr.ParentGUID, 
					SUM( [Qty]),  
					SUM( [Bonus]),  
					SUM( [Val]), 
					SUM( [DiscExtra]),
					SUM( [Tax]),
					Lv + 1, 
					flg 
				FROM  
					#ResultTbl AS [RS] inner join gr000 gr ON gr.guid = [RS].[GRPtr] where Lv = @Level and gr.ParentGUID <> 0x00
				GROUP BY 
					[Lv], 
					[RS].[AccPtr], 
					[RS].[Path], 
					gr.ParentGUID, 
					flg,
					[RS].[CuPtr], 
					[RS].[CuName]
				SET @cnt = @@ROWCOUNT
				SET @Level = @Level + 1
			end	
			IF @ShowMat = 0 
			BEGIN 
				DELETE #ResultTbl WHERE [Lv] = 0
				UPDATE #ResultTbl SET [Lv] = [Lv] - 1 
			END 
	END  
	------------------------------------------------------------------  
	INSERT INTO #ResultTbl 
	SELECT 
		[AcTbl].[GUID], 
		NULL, 
		'',
		[AcTbl].[Path], 
		[RS].MatPtr, 
		[RS].[GRPtr], 
		SUM([Qty]), 
		SUM([Bonus]), 
		SUM([Val]), 
		SUM([DiscExtra]),
		SUM([Tax]),
		[acTbl].[Level], 
		0  
	FROM 
		[#Account_Tbl] AS [AcTbl] 
		CROSS APPLY dbo.fnGetAccountsList([AcTbl].Guid, 0) AS fn
		JOIN #ResultTbl AS [RS] ON fn.Guid = RS.AccPtr 
	WHERE
		(@AccLevel = 0 OR [acTbl].[Level] < @AccLevel)
		AND AcTbl.GUID NOT IN (SELECt AccPtr FROm #ResultTbl)
	GROUP BY 
		[AcTbl].[GUID], 
		[acTbl].[Level], 
		[AcTbl].[Path],  
		[RS].[GRPtr],
		[RS].[MatPtr]

		
	-------------------------------------------------------------------
	CREATE TABLE #FinalResult ( 
			[NUM]				INT IDENTITY(1,1),
			[AccPtr]			[UNIQUEIDENTIFIER], 
			[ParentPtr]			[UNIQUEIDENTIFIER],
			[CuPtr]				[UNIQUEIDENTIFIER],
			[acNameCode]		[NVARCHAR](MAX)     ,
			[Path]				[NVARCHAR] (4000), 
			[MatPtr]			[UNIQUEIDENTIFIER],  
			[GRPtr]				[UNIQUEIDENTIFIER], 
			[Ptr]				[UNIQUEIDENTIFIER],
			[MatCode]			[NVARCHAR](MAX),
			[MatName]			[NVARCHAR](MAX),
			[MatLatinName]		[NVARCHAR](MAX),
			[MatUnit]			[NVARCHAR](MAX),
			[GrCode]			[NVARCHAR](MAX),
			[GrName]			[NVARCHAR](MAX),
			[GrLatinName]		[NVARCHAR](MAX),
			[GrLevel]			[INT],
			[Qty]				[FLOAT],  
			[Bonus]				[FLOAT],  
			[Val]				[FLOAT],
			[DiscExtra]			[FLOAT],
			[Tax]				[FLOAT],   
			[flg]				[BIT] DEFAULT 0,
			[Diffptr]			[UNIQUEIDENTIFIER] ,
			[CustomerName]		[NVARCHAR](MAX)) 
			
	INSERT INTO [#FinalResult]
	SELECT  
			[AccPtr],
			[ac].[ParentGUID],
			[Res].[CuPtr],
			[acTbl].[Code] +'-' + [acTbl].[Name] ,
			[Res].[Path],  
			ISNULL([Res].[MatPtr], 0x0)  ,  
			ISNULL([Res].[GRPtr], 0x0) , 
			ISNULL( [Res].[MatPtr], [Res].[GRPtr]),
			ISNULL([Mt].[mtCode], '') ,  
			ISNULL([Mt].[mtName], ''),  
			ISNULL([Mt].[mtLatinName], '') ,  
			CASE @UseUnit  
				WHEN 0 THEN ISNULL([Mt].[mtUnity], '')
				WHEN 1 THEN ISNULL([Mt].[mtUnit2] , '')
				WHEN 2 THEN ISNULL([Mt].[mtUnit3] , '')
				WHEN 3 THEN ISNULL([Mt].[mtDefUnitName] , '')
				END , 
			ISNULL([gr].[grCode], '') ,  
			ISNULL([gr].[grName], '') ,  
			ISNULL([gr].[grLatinName], '') , 
			[GrLevel].[Level] ,
			SUM( [Qty]) AS [Qty],  
			SUM( [Bonus]) AS [Bonus],  
			SUM( [Val]) AS [Val],
			SUM( [DiscExtra]) AS [DiscExtra],
			SUM( [Tax]) AS [Tax]  ,
			flg,
			NEWID(),
			res.CuName		
	FROM  
			#ResultTbl AS [Res]  
			INNER JOIN #Account_Tbl  AS [acTbl]   ON [Res].[AccPtr] = [acTbl].[GUID]  
			INNER JOIN @GRTbl        AS [GrLevel] ON [GrLevel].[GUID] = [Res].[GRPtr]  
			LEFT JOIN [vwGr]         AS [Gr]	  ON [Gr].[grGUID] = [Res].[GRPtr]
			LEFT JOIN [vwMT]         AS [Mt]	  ON [Mt].[mtGUID] = [Res].[MatPtr]
			LEFT JOIN [ac000]        AS [ac]	  ON [Res].[AccPtr] = [ac].[GUID]
	WHERE  
			( @AccLevel = 0 OR [acTbl].[Level] < @AccLevel)  
			AND ( @ShowGroup = 1 OR [Res].[MatPtr] IS NOT NULL)  
			AND [Qty] IS NOT NULL  
			AND ( @MatLevel = 0 OR ([Res].[MatPtr] IS NOT NULL AND [GrLevel].[Level] + 1 <  @MatLevel) OR ( [Res].[MatPtr] IS NULL AND [GrLevel].[Level] <  @MatLevel))
	GROUP BY  
			[AccPtr], [ac].[ParentGUID],  [Res].[CuPtr] , [acTbl].[Name], [acTbl].[Code], 
			[Res].[Path],  
			[Res].[MatPtr],
			[Res].[GRPtr],
			[Mt].[mtCode],  
			[Mt].[mtName],  
			[Mt].[mtLatinName],
			[GrLevel].[Level],
			[gr].[grCode],
			[gr].[grName],
			[gr].[grLatinName],
			[flg],
			[Res].[CuName],
			CASE @UseUnit  
				WHEN 0 THEN ISNULL([Mt].[mtUnity], '')
				WHEN 1 THEN ISNULL([Mt].[mtUnit2], '') 
				WHEN 2 THEN ISNULL([Mt].[mtUnit3] , '')
				WHEN 3 THEN ISNULL([Mt].[mtDefUnitName], '') 
			END
	ORDER BY  
			[acTbl].[Code], ISNULL([Mt].[mtCode], [grCode])

	--------------------------------------------------------------------------------
	-- update for primary 
	UPDATE FR
		SET FR.ParentPtr= ff.Diffptr
		FROM #FinalResult AS FR
		INNER JOIN #FinalResult AS FF ON FR.ParentPtr=ff.AccPtr
		WHERE (ff.AccPtr IS NOT NULL OR ff.AccPtr = fr.AccPtr) 

	IF (( @CustGUID=0x0 or  @AccGUID=0x0 ))
	BEGIN
		SELECT * FROM #FinalResult
		ORDER BY [NUM]
	END

	ELSE 
	BEGIN
		SELECT 
			[AccPtr], 
			[ParentPtr],
			[CuPtr],
			[acNameCode],
			[Diffptr],
			[Path],  
			[MatPtr],  
			[GRPtr], 
			[Ptr],
			[MatCode],  
			[MatName],  
			[MatLatinName],  
			[MatUnit], 
			[GrCode],  
			[GrName],  
			[GrLatinName], 
			[GrLevel],
			[Qty],  
			[Bonus],  
			[Val],
			[DiscExtra],
			[Tax]  ,
			[flg],
			[CustomerName]
		FROM #FinalResult AS  fr
		INNER JOIN [#Cust] CU ON CU.[Number]=fr.[CuPtr]
		ORDER BY [NUM]
	END
		-------------------------------- 
		 
	SELECT * FROM #SecViol 
		 
	SET NOCOUNT OFF

###########################################################################
#END
