############################################################
CREATE PROCEDURE repCustMoveByBill
	@StartDate AS [DATETIME],    
	@EndDate AS [DATETIME],    
	@Src AS [UNIQUEIDENTIFIER],    
	@Acc AS [UNIQUEIDENTIFIER],    
	@Gr AS [UNIQUEIDENTIFIER],    
	@Store AS [UNIQUEIDENTIFIER],    
	@Cost AS [UNIQUEIDENTIFIER], 
	@CustGUID	[UNIQUEIDENTIFIER],   
   	@CurPtr AS [UNIQUEIDENTIFIER],    
	@AccLevel AS [INT],    
	@CollectByMcBillType [INT],    
	@MergeExtraVal [INT],
	@Posted	AS [INT],
	@ShowCustBalance AS [BIT] = 0,
	@ShowEmptyType [BIT] = 0	
AS    
	SET NOCOUNT ON

	CREATE TABLE [#SecViol]([Type] [INT], [Cnt] [INT])   
	CREATE TABLE [#Result](    
			[Acc] [UNIQUEIDENTIFIER],     
			[BillType] [UNIQUEIDENTIFIER],     
			[buNumber] [INT],     
			[Price] [FLOAT],   
			[Security] [INT],   
			[mtSecurity] [INT],   
			[CustSecurity] [INT],   
			[AccSecurity] [INT],   
			[userSecurity] [INT],  
			[CustGuid] [UNIQUEIDENTIFIER])   
	-------Bill Resource ---------------------------------------------------------     
	CREATE TABLE [#Src]([Type] [UNIQUEIDENTIFIER], [Sec] [INT], [ReadPrice] [INT], [UnPostedSec] [INT])
	INSERT INTO [#Src] EXEC [prcGetBillsTypesList2] @Src     
	-------------------------------------------------------------------     
	CREATE TABLE [#Account_Tbl]([GUID] [UNIQUEIDENTIFIER], [Level] [INT], [Path] [NVARCHAR](MAX), [AccSecurity] [INT])     
	INSERT INTO [#Account_Tbl]      
		SELECT      
			[fn].[GUID],      
			[fn].[Level],      
			[fn].[Path],   
			[Acc].[acSecurity]   
		FROM      
			[dbo].[fnGetAccountsList]( @Acc, 1) AS [Fn]   
			INNER JOIN [vwAc] AS [Acc] ON [Fn].[GUID] = [Acc].[acGUID] 
	IF @Acc IN (SELECT [GUID] FROM [AC000] WHERE [TYPE] = 4)
	BEGIN
		UPDATE #Account_Tbl SET [Level] = [Level] - 1
		DELETE a FROM #Account_Tbl a where path = (SELECT MIN(PATH) FROM #Account_Tbl b GROUP BY [GUID] HAVING COUNT(*) > 1 and b.[GUID] = a.[GUID] )
	END  
	-------------------------------------------------------------------------  
	EXEC [prcCheckSecurity] @result = '#Account_Tbl'     
	-------Mat Table----------------------------------------------------------     
	CREATE TABLE [#MatTbl]([mtNumber] [UNIQUEIDENTIFIER], [mtSecurity] [INT])       
	INSERT INTO [#MatTbl] EXEC [prcGetMatsList] NULL, @Gr      
	-------Store Table----------------------------------------------------------     
	DECLARE @StoreTbl TABLE([Number] [UNIQUEIDENTIFIER])       
	INSERT INTO @StoreTbl SELECT [Guid] FROM [fnGetStoresList]( @Store)       
	IF ISNULL( @Store,0x0) = 0x0     
		INSERT INTO @StoreTbl VALUES( 0x0)      
	------Cost Table----------------------------------------------------------     
	DECLARE @CostTbl TABLE([Number] [UNIQUEIDENTIFIER])     
	INSERT INTO @CostTbl SELECT [Guid] FROM [fnGetCostsList]( @Cost)       
	IF ISNULL( @Cost, 0x0) = 0x0     
		INSERT INTO @CostTbl VALUES( 0x0)      

	--//////////////////////////////////////////////////////////     
	INSERT INTO [#Result]   
	SELECT   
		[AcTbl].[GUID] ,   
		[Bill].[buType],   
		[buNumber] AS [buNumber],   
		CASE WHEN [Src].[ReadPrice] >= [Bill].[buSecurity] THEN 1 ELSE 0 END * CASE @MergeExtraVal WHEN 0 THEN [FixedBiTotal] ELSE [bill].[biBillQty] * [bill].[FixedBiPrice] END AS [VAL],   
		[bill].[buSecurity] AS [buSecurity],   
		[bill].[mtSecurity] AS [mtSecurity],   
		ISNULL( [cu].[cuSecurity], 0),   
		[AcTbl].[AccSecurity],  
		CASE [Bill].[buIsPosted] WHEN 1 THEN [Src].[Sec] ELSE [Src].[UnPostedSec] END,
		ISNULL( [cu].[cuGuid] , 0x0)  		
	FROM     
		[vwCu] AS [cu]   
		RIGHT JOIN [dbo].[fnExtended_Bi_Fixed]( @CurPtr) AS [bill] ON [Bill].[BuCustPtr] = [cu].[cuGuid]  
		INNER JOIN [#MatTbl] AS [mt] ON [Bill].[biMatPtr] = [mt].[mtNumber]     
		INNER JOIN [#Src] AS [Src] ON [Bill].[buType] = [Src].[Type]     
		INNER JOIN @CostTbl AS [Co] ON [Bill].[BiCostPtr] = [Co].[Number]     
		INNER JOIN @StoreTbl AS [St] ON [Bill].[BiStorePtr] = [St].[Number]     
		INNER JOIN [#Account_Tbl] AS [AcTbl] ON [AcTbl].[GUID] = (CASE ISNULL( [Bill].[BuCustPtr], 0x0) WHEN 0x0 THEN [Bill].[BuCustAcc] ELSE [cu].[cuAccount] END)  
	WHERE  
		[bill].[buDate] between @StartDate AND @EndDate     
		AND (  ( @Posted > 2) 
			OR ( @Posted = 1 AND [bill].[buIsPosted] = 1 )
			OR ( @Posted = 2 AND [bill].[buIsPosted] = 0 )  )		
		AND([cu].[cuGuid] = CASE WHEN ISNULL(@CustGUID, 0x0) <> 0x0 THEN @CustGUID ELSE [cu].[cuGuid] END)
		
			------------------------------------------------------------------ 
	EXEC [prcCheckSecurity]  
	------------------------------------------------------------------   
	------ First Result Table and Total Result Table-----------------------------------------------------------   
	CREATE TABLE #ResultTbl (     
			[AccPtr] [UNIQUEIDENTIFIER], 
			[CustomerGUID] [UNIQUEIDENTIFIER],      
			[Path] [NVARCHAR](4000),     
			[BillType] [UNIQUEIDENTIFIER],     
			[CountMove] [FLOAT],     
			[Val] [FLOAT],  
			[acParent] [UNIQUEIDENTIFIER],  
			[Lv] [INT],
			[Type] [BIT] DEFAULT 0) -- Type 1 ->  Main Account, 0 -> Sub Account

	--DECLARE @TotalResultTbl TABLE(     
	--		[BillType] [NVARCHAR](40),    
	--		[CountMove] [FLOAT],    
	--		[Val] [FLOAT])     
	------ End Result Table Collected by Level---------------------------------     

	INSERT INTO #ResultTbl     
	SELECT     
		[Res].[Acc], 
		[Res].CustGuid,  
		[AcTbl].[Path],   
		[Res].[BillType],   
		COUNT(Distinct([Res].[buNumber])) AS [CountMove],   
		SUM([Res].[Price]) AS [Price],  
		[ac].[acParent],  
		0 AS [Level],
		0 AS [Type]
	FROM     
		[#Result] AS [Res] 
		INNER JOIN [#Account_Tbl] AS [AcTbl] ON [Res].[Acc] = [AcTbl].[GUID]  
		INNER JOIN [vwAc] AS [ac] ON [AcTbl].[GUID] = [ac].[acGuid]  
	GROUP BY     
		[Res].CustGuid,
		[Res].[Acc],		     
		[AcTbl].[Path],     
		[Res].[BillType],  
		[ac].[acParent],  
		[AcTbl].[Level] 

	-- calc total result     
	--INSERT INTO @TotalResultTbl     
	--	SELECT      
	--		CASE @CollectByMcBillType      
	--			WHEN 0 THEN CAST( [BillType]  AS [NVARCHAR](40))     
	--			ELSE CAST( [BT].[btBillType] AS [NVARCHAR](40)) END,    
	--		SUM( CASE WHEN [Type] = 0 THEN [CountMove] ELSE 0 END) [CountMove],     
	--		SUM( CASE WHEN [Type] = 0 THEN [Val] ELSE 0 END) AS [Val]     
	--	FROM     
	--		#ResultTbl AS [Res] INNER JOIN [vwBt] AS [BT]      
	--		ON [Res].[BillType] = [BT].[btGUID]    
	--	GROUP BY    
	--		CASE @CollectByMcBillType    
	--			WHEN 0 THEN CAST( [BillType]  AS [NVARCHAR](40))     
	--			ELSE CAST( [BT].[btBillType] AS [NVARCHAR](40)) END    
	--------------------------------------------------------------------     
	DECLARE @Continue [INT], @Lv [INT]      
	SET @Continue = 1      
	SET @Lv = 0      
	WHILE @Continue <> 0    
	BEGIN      
		SET @Lv = @Lv + 1      

		INSERT INTO #ResultTbl   
		SELECT      
			[AcTbl].[GUID],  
			0x0,
			[AcTbl].[Path],  
			[Res].[BillType],      
			SUM([Res].[CountMove]) AS [CountMove],     
			SUM([Res].[Val]) AS [Val],  
			[ac].[acParent],  
			@Lv,
			CASE [Level] WHEN 0 THEN 1 ELSE 0 END 
		FROM      
			[#Account_Tbl] AS [AcTbl] 
			INNER JOIN #ResultTbl AS [Res] ON [AcTbl].[GUID] = [Res].[acParent]  
			INNER JOIN [vwAc] AS [ac] ON [AcTbl].[GUID] = [ac].[acGuid]  
		WHERE  
			[Lv] = @Lv - 1      
		GROUP BY   
		    [AcTbl].[GUID],  
			[AcTbl].[Path],  
			[Res].[BillType],      
			[ac].[acParent],
			[Level]

		SET @Continue = @@ROWCOUNT       
	END	      

 	IF @ShowEmptyType = 0
	BEGIN 
		SELECT 
			CASE @CollectByMcBillType      
				WHEN 0 THEN CAST([BillType]  AS [NVARCHAR](40))     
				ELSE CAST([BT].[btBillType] AS [NVARCHAR](40)) 
			END AS [BillType]
		FROM 
			#ResultTbl AS [Res]
			INNER JOIN [vwBt] AS [BT] ON [Res].[BillType] = [BT].[btGUID]
		GROUP BY 
			CASE @CollectByMcBillType      
				WHEN 0 THEN CAST( [BillType]  AS [NVARCHAR](40))     
				ELSE CAST( [BT].[btBillType] AS [NVARCHAR](40)) 
			END
	END 
	
	IF NOT EXISTS(SELECT * FROM #ResultTbl WHERE [Type] != 0)
	BEGIN 
		UPDATE #ResultTbl SET [Type] = 1
	END 
				
	SELECT     
		[AccPtr] AS [AccGUID],     
		-- [Res].[Path],
		[Acc].[acCode] AS [AccCode],     
		[Acc].[acName] AS [AccName],     
		SUM (CASE WHEN ISNULL( [Cu].[GUID], 0x0) <> 0x0 THEN  [Cu].Debit -Cu.Credit
			ELSE [Acc].[acDebit]- [Acc].[acCredit]  
		END) AS [AccBalance], 
		[Acc].[acLatinName] AS [AccLatinName],     
		ISNULL([Cu].[GUID], 0x0) AS [CustGUID],
		CASE @CollectByMcBillType
			WHEN 0 THEN CAST([BillType] AS [NVARCHAR](40))     
			ELSE CAST([BT].[btBillType] AS [NVARCHAR](40)) 
		END AS [BillType],     
		SUM([CountMove]) [CountMove],     
		SUM([Val]) AS [Val],
		[acCurrencyptr] AS [AccCurrencyGUID],
		[acCurrencyVal] AS [AccCurrencyVal],
		ISNULL(res.acParent, 0x0) AS ParentAccountGUID,
		res.Type AS bMain,
		ISNULL ([CustomerName],'') AS CustomerName,
		ISNULL ([LatinName],'') AS LatinName,
		CASE ISNULL([Cu].[GUID], 0x0) WHEN 0x0 THEN  AccPtr ELSE [Cu].[GUID] END AS RecGUID 

	FROM      
		#ResultTbl AS [Res]      
		INNER JOIN [#Account_Tbl] AS [acTbl] ON [Res].[AccPtr] = [acTbl].[GUID]     
		INNER JOIN [vwBt] AS [BT] ON [Res].[BillType] = [BT].[btGUID]     
		INNER JOIN [vwAc] AS [Acc] ON [Res].[AccPtr] = [Acc].[acGuid]     
		left JOIN [vbCu] AS [Cu] ON [cu].GUID = [Res].CustomerGUID
	WHERE     
		(@AccLevel = 0 OR [acTbl].[Level] < @AccLevel)			
	GROUP BY		
		[AccPtr],		     
		[Res].[Path],     
		[Acc].[acCode],     
		[Acc].[acName],     
		[Acc].[acLatinName],
		[Cu].[GUID], 
		CASE @CollectByMcBillType      
			WHEN 0 THEN CAST( [BillType]  AS [NVARCHAR](40))     
			ELSE CAST( [BT].[btBillType] AS [NVARCHAR](40)) 
		END,
		[acCurrencyptr],
		[acCurrencyVal],
		res.acParent,
		res.Type,
		[CustomerName],
		[LatinName],
		CASE ISNULL([Cu].[GUID], 0x0) WHEN 0x0 THEN  AccPtr ELSE [Cu].[GUID] END 
	ORDER BY      
		[Res].[Path], [Acc].[acCode], [Acc].[acName]

	SELECT * FROM [#SecViol]
############################################################
#END
