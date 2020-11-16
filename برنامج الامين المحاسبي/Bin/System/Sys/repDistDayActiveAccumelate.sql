##############################################
CREATE PROCEDURE repDayActiveAccumelate 
	@HiGuid 			[UNIQUEIDENTIFIER], 
	@PeriodGuid			[UNIQUEIDENTIFIER], 
	@EndDate			[DATETIME], 
	@MatGuid			[UNIQUEIDENTIFIER], 
	@CurrencyGuid			[UNIQUEIDENTIFIER], 
	@UseUnit			[INT] = 3, 
	@ShowMat			[INT] = 1, 
	@ShowHi				[INT] = 0, 
	@ShowGrp			[INT] = 0, 
	@CostDep			[INT] = 1, 
	@DiscAcc			[INT] = 0, 
	@CalcVisitByBill	[INT] = 0,
	@GroupVisit			[INT] = 0,	-- 1  Visits In Same Date = 1 Visit     0  All Visits In Same Date <> 1 Visit 
	@BillVisit			[INT] = 0	-- 1  Bill From Ameen IS Visit		0 Bill From Amn Is Not Visit   
AS 
	SET NOCOUNT ON 
	DECLARE @GrGuid 	[UNIQUEIDENTIFIER] 
	DECLARE @StartDate 	[DATETIME],@PeriodEndDate 	[DATETIME], @DayDif	[INT] , @DayNum [INT]
	DECLARE @MaxLevel 	[INT] 
  
	CREATE TABLE 	[#T] ( [PeriodGUID]   [UNIQUEIDENTIFIER], [StartDate]	[DATETIME], [EndDate] 	[DATETIME] )  
	INSERT INTO 	[#T] ( [PeriodGUID], [StartDate], [EndDate] ) SELECT [GUID], [StartDate], [EndDate]  FROM [vwPeriods] WHERE @PeriodGUID = 0X00 OR GUID = @PeriodGUID  
	SELECT @StartDate = StartDate,@PeriodEndDate = EndDate FROM #T
	SET @DayNum = DATEDIFF(d, @StartDate,@PeriodEndDate) + 1 - (SELECT COUNT(*) FROM DistCalendar000 WHERE ([date] BETWEEN @StartDate AND @PeriodEndDate) AND (STATE = 1)) 	  
	SET @DayDif = DATEDIFF(d, @StartDate, @EndDate) + 1  - (SELECT COUNT(*) FROM DistCalendar000 WHERE ([date] BETWEEN @StartDate AND @EndDate) AND (STATE = 1)) 	  
	IF @DayDif = 0 
		SET @DayDif = 1	

	CREATE TABLE [#DistTble]	( [DistGuid] 	[UNIQUEIDENTIFIER], [Security] 	 [INT], [HIGuid] [UNIQUEIDENTIFIER], [SalesmanGUID] [UNIQUEIDENTIFIER], [CostSalesmanGUID] [UNIQUEIDENTIFIER], [Name] [NVARCHAR](255) COLLATE ARABIC_CI_AI DEFAULT '', [SalesSecurity] [INT] DEFAULT 0 )	 
	CREATE TABLE [#SecViol]		( [Type] 	[INT], 		    [Cnt]  	 [INT] ) 
	CREATE TABLE [#Cust] 		( [Number] 	[UNIQUEIDENTIFIER], [Security]   [INT] )  
	CREATE TABLE [#MatTbl]		( [MatGUID] 	[UNIQUEIDENTIFIER], [mtSecurity] [INT] ) 
	CREATE TABLE [#BillTbl]		( [Type] 	[UNIQUEIDENTIFIER], [Security] 	 [INT], [ReadPriceSecurity] [INT], [UnPostedSecurity] [INT] )      
	CREATE TABLE [#RESULT] 
	(     
		[DistPtr]			[UNIQUEIDENTIFIER],  
		[SalesManPtr]			[UNIQUEIDENTIFIER],     
		[Name]				[NVARCHAR](255) COLLATE ARABIC_CI_AI DEFAULT '', 
		[Security]			[INT] 	DEFAULT 0, 
		[btSecurity]			[INT] 	DEFAULT 0, 
		[BuTotal]			[FLOAT] DEFAULT 0,      
		[BuDirection]			[INT] 	DEFAULT 0, 
		[Target]			[FLOAT] DEFAULT 0, 
		[VistCount]			[FLOAT] DEFAULT 0,	 
		[ActiveVistCount]		[FLOAT] DEFAULT 0,	 
		[FLAG]				[INT] 	DEFAULT 0, 
		[Path]				[NVARCHAR](300) 	DEFAULT '', 
		[hiGuid]			[UNIQUEIDENTIFIER] DEFAULT 0X00, 
		[Level]				[INT] 	DEFAULT 0, 
		[IsHi]				[BIT]	DEFAULT 0 
	) 
	CREATE TABLE [#T_RESULT] 
	( 
		[DistPtr]			[UNIQUEIDENTIFIER],     
		[CustPtr]			[UNIQUEIDENTIFIER],     
		[Security]			[INT] DEFAULT 0,   
		[MatSecurity]			[INT] DEFAULT 0, 
		[buGuid]			[UNIQUEIDENTIFIER], 
		[MatGuid]			[UNIQUEIDENTIFIER],  
		[Qty]				[FLOAT] DEFAULT 0,      
		[TargetQty]			[FLOAT] DEFAULT 0, 
		[BuDirection]			[INT] 	DEFAULT 0, 
		[Level]				[INT] 	DEFAULT 0, 
		[mtCode]			[NVARCHAR](255) COLLATE ARABIC_CI_AI DEFAULT '', 
		[mtName]			[NVARCHAR](255) COLLATE ARABIC_CI_AI DEFAULT '', 
		[mtLatinName]			[NVARCHAR](255) COLLATE ARABIC_CI_AI DEFAULT '', 
		[GrpGuid]			[UNIQUEIDENTIFIER], 
		[HiLevel]			[INT] 	DEFAULT 0, 
		[HiGuid]			[UNIQUEIDENTIFIER] DEFAULT 0X00 
	) 
	CREATE TABLE [#T_NewMatRESULT]  
	( 
		[DistPtr]			[UNIQUEIDENTIFIER],     
		[CustNumNEW]			[INT] DEFAULT 0, 
		[CustNum]			[INT] DEFAULT 0, 
		[CustNumBye]			[INT] DEFAULT 0, 
		[Level]				[INT] DEFAULT 0 
	)  
	CREATE TABLE [#MT1] 
	( 
		[mtGuid]			[UNIQUEIDENTIFIER], 
		[mtSecurity]			[INT], 
		[mtUnitFact]			[FLOAT] DEFAULT 1, 
		[mtGroup]			[UNIQUEIDENTIFIER], 
		[mtCode]			[NVARCHAR](255) COLLATE ARABIC_CI_AI DEFAULT '', 
		[mtName]			[NVARCHAR](255) COLLATE ARABIC_CI_AI DEFAULT '', 
		[mtLatinName]			[NVARCHAR](255) COLLATE ARABIC_CI_AI DEFAULT '' 
	) 
		 
	INSERT INTO [#DistTble] ( [DistGuid], [Security] )	EXEC [GetDistributionsList] 0x0, @HiGuid  
	UPDATE [d] SET [HIGuid] = [HierarchyGUID], [SalesmanGUID] = [PrimSalesmanGUID] FROM [#DistTble] AS [d] INNER JOIN [Distributor000] AS [d2] ON [d].[DistGuid] = [d2].[GUID] 
	UPDATE [d] SET [CostSalesmanGUID] = [d2].[CostGuid], [Name] = [d2].[Name], [SalesSecurity] = [d2].[Security] FROM [#DistTble] AS [d] INNER JOIN [dbo].[DistSalesman000] AS [d2] ON [d2].[Guid] = [d].[SalesmanGUID] 
	INSERT INTO [#Cust] 	EXEC [prcGetCustsList] 0X0, 0X0	 
	INSERT INTO [#BillTbl] 	EXEC [prcGetBillsTypesList2] 0x0, 0x0  
	INSERT INTO [#MatTbl] 	EXEC [prcGetMatsList] 0X0, 0X0, 0 
	CREATE CLUSTERED INDEX [btIndex] ON [#BillTbl] ( [Type] ) 
	IF ( (@ShowMat = 1) OR (@ShowGrp = 1) OR (@MatGuid <> 0X0) ) 
	BEGIN 
		INSERT INTO  [#MT1] 
			SELECT  
				[mt1].[mtGuid], 
				[mt].[mtSecurity], 
				CASE @UseUnit  
					WHEN 0 THEN 1 
					WHEN 1 THEN CASE [mt1].[mtunit2Fact] WHEN 0 THEN 1 ELSE [mt1].[mtunit2Fact] END
					WHEN 2 THEN CASE [mt1].[mtunit3Fact] WHEN 0 THEN 1 ELSE [mt1].[mtunit3Fact] END
					ELSE CASE [mt1].[mtDefUnit] 
							WHEN 1 THEN 1 
							WHEN 2 THEN CASE [mt1].[mtunit2Fact] WHEN 0 THEN 1 ELSE [mt1].[mtunit2Fact] END
							ELSE CASE [mt1].[mtunit3Fact] WHEN 0 THEN 1 ELSE [mt1].[mtunit3Fact] END
						END 
				END , 
				[mtGroup], 
				[mtCode], 
				[mtName], 
				[mtLatinName] 
			FROM  
				[#MatTbl]  AS [mt] 
				INNER JOIN [vwMt] AS [mt1] ON [mt1].[mtGuid] = [mt].[MatGuid] 
	END 
	CREATE CLUSTERED INDEX [inddest] ON [#DistTble] ( [DistGuid] )  

	EXEC prcCheckSecurity @Result = '#DistTble' 

	SELECT DISTINCT 
			[c].[Number] AS [CustGuid],  
			CASE @CostDep WHEN 1 THEN 0X00 ELSE [c].[Number] END AS [Number], 
			CASE @CostDep WHEN 1 THEN 0 ELSE [c].[Security] END AS [CustSecurity],
			[d].[DistGuid], [hiGuid], [SalesmanGUID], [CostSalesmanGUID], [Name] 
	INTO [#Cust2]  
	FROM  [#CUST]  AS c 
	INNER JOIN [DistCe000] 			AS ce ON ce.CustomerGuid = c.Number 
	INNER JOIN DistDistributionLines000 	AS Dl ON Dl.CustGuid = ce.CustomerGuid 
	INNER JOIN [#DistTble] 			AS d  ON d.DistGuid  = Dl.DistGUID 

	EXEC prcCheckSecurity @Result = '#Cust2' 

	CREATE CLUSTERED INDEX [custiNE] 	ON [#Cust2] ( [Number], [DistGuid], [CostSalesManGUID] ) 
	CREATE CLUSTERED INDEX [mtInd] 		ON [#MT1]   ( [mtGuid] ) 
	   
	IF (@CostDep = 0) 
	BEGIN 
		SELECT 	CASE @CalcVisitByBill WHEN 1 THEN CAST (COUNT(DISTINCT CAST ([buGuid] AS [NVARCHAR](40))) AS [FLOAT])/@DayDif  ELSE 0 END AS [CustCnt], 
			[buSecurity], 
			CASE [buIsPosted] WHEN 1 THEN [bt].[Security] ELSE [UnPostedSecurity] END AS [btSecurity],
			SUM(((([biUnitPrice] + (@DiscAcc * (-[biUnitDiscount] + [biUnitExtra]))) * [biQty]) ) * [FixedCurrencyFactor]) AS [FixedBuTotal],
			[btDirection], [buCustPtr]   
		INTO [#RES1]  
		FROM [fnExtended_bi_Fixed] ( @CurrencyGuid ) AS bi 
		INNER JOIN [#BillTbl] AS [bt] ON [bt].[Type] = [bi].[buType] 
		WHERE 	([buDate] BETWEEN @StartDate AND @EndDate)  AND (btbilltype in (1,3))
		GROUP BY [buSecurity], [bt].[Security], [btDirection], [buCustPtr], [buIsPosted], [UnPostedSecurity]  
		INSERT INTO [#RESULT] ( [DistPtr], [SalesManPtr], [Name], [Security], [btSecurity], [BuTotal], [BuDirection], [FLAG], [hiGuid], [VistCount], [ActiveVistCount]) 
			SELECT	DISTINCT 
				[c].[DistGuid], [SalesmanGUID], [c].[Name], [buSecurity], [btSecurity], [FixedBuTotal], [btDirection], 1, [hiGuid], [bi].[CustCnt], [bi].[CustCnt] 
			FROM [#RES1] AS bi 
			INNER JOIN [#CUST2]  AS c ON  [c].[Number] = [bi].[buCustPtr]    
	END 
	ELSE 
	BEGIN 
		SELECT 	CASE @CalcVisitByBill WHEN 1 THEN CAST (COUNT(DISTINCT CAST ([buGuid] AS NVARCHAR(40))) AS [FLOAT])/@DayDif  ELSE 0 END AS [CustCnt],
			[buSecurity],
			CASE [buIsPosted] WHEN 1 THEN [bt].[Security] ELSE [UnPostedSecurity] END AS [btSecurity],
			SUM(((([biUnitPrice] + (@DiscAcc * (- [biUnitDiscount] + [biUnitExtra]))) * [biQty]) )* [FixedCurrencyFactor])AS [FixedBuTotal],
			[btDirection], [biCostPtr]   
		INTO [#RES2]  
		FROM [fnExtended_bi_Fixed] (@CurrencyGuid) AS bi 
		INNER JOIN [#BillTbl] AS [bt] ON [bt].[Type] = [bi].[buType] 
		WHERE 
			([buDate] BETWEEN @StartDate AND @EndDate)  AND (btbilltype in (1,3))
		GROUP BY [buSecurity], [bt].[Security], [btDirection] ,[biCostPtr], [buIsPosted], [UnPostedSecurity]  
		 
		INSERT INTO [#RESULT] ( [DistPtr], [SalesManPtr], [Name], [Security], [btSecurity], [BuTotal], [BuDirection], [FLAG], [hiGuid], [VistCount], [ActiveVistCount]) 
			SELECT DISTINCT
				[c].[DistGuid], [SalesmanGUID], [c].[Name], [buSecurity], [btSecurity], [FixedBuTotal], [btDirection], 1, [hiGuid], [bi].[CustCnt], [bi].[CustCnt] 
			FROM   
				[#RES2] AS [bi] 
				INNER JOIN [#CUST2]  AS c ON [c].[CostSalesmanGUID] = [bi].[biCostPtr] 
	END 
	-- Target 
	UPDATE [res] SET Target = [dbo].[fnCurrency_fix] ( GeneralTargetVal, d.CurGuid, d.CurVal, @CurrencyGuid, NULL ) 
	FROM [#Result] AS res 
	INNER JOIN [vwDistDistributorTarget] 	AS [d]	ON [res].[DistPtr]  = [d].[DistGuid]
	INNER JOIN [#T] 			AS [t] 	ON [d].[PeriodGUID] = [t].[PeriodGUID] 
	INNER JOIN [#DistTble] 			AS [d2] ON [d].[DistGUID]   = [d2].[DistGuid] 

/*
	INSERT INTO [#RESULT] ( [DistPtr], [SalesManPtr], [Name], [Target], [hiGuid] ) 
		SELECT  [d].[DistGUID], [SalesmanGUID], [d2].[Name], [dbo].[fnCurrency_fix](GeneralTargetVal, d.CurGuid, d.CurVal, @CurrencyGuid, NULL), [hiGuid] 
	FROM [DistDistributorTarget000] AS d  
	INNER JOIN [#T] 	AS [t] 	ON [d].[PeriodGUID] = [t].[PeriodGUID] 
	INNER JOIN [#DistTble] 	AS [d2] ON [d].[DistGUID]   = [d2].[DistGuid] 
*/
	-----------General Target 

	INSERT INTO [#RESULT] ( [DistPtr], [Target] ) 
		SELECT  0X00, ISNULL(SUM([dbo].[fnCurrency_fix] ( [GeneralTargetVal], [CurGuid], [CurVal], @CurrencyGuid, NULL)), 0)  
		FROM [vwDistDistributorTarget] WHERE [PeriodGuid] = @PeriodGuid 
	 
	--VSITS 
	IF @CalcVisitByBill = 0 
	BEGIN 
/*
		INSERT INTO [#RESULT] ( [DistPtr], [SalesManPtr], [Name], [VistCount], [ActiveVistCount], [hiGuid] ) 
			SELECT  [DistGuid], [SalesmanGUID], [d].[Name], 
			-- CAST(COUNT (DISTINCT CAST( [ViGuid] AS [NVARCHAR](40))) AS [FLOAT]) / @DayDif,    	-- „⁄œ· «·“Ì«—«  «·ÌÊ„Ì
			CAST ( COUNT(DISTINCT CAST([ViGuid] AS NVARCHAR(40))) + ( SELECT COUNT(DISTINCT [BuDate]) FROM vwbu AS bu WHERE bu.buCostPtr = d.CostSalesmanGUID AND buDate BETWEEN @StartDate AND @EndDate AND buDate NOT IN ( SELECT [dbo].[fnGetDateFromDT]([StartTime]) FROM DistVi000 AS t WHERE t.CustomerGuid = bu.buCustPtr)  ) AS FLOAT ) / @DayDif,	-- „⁄œ· «·“Ì«—«  «·ÌÊ„Ì
			CAST(SUM([viState]) AS [FLOAT]) / @DayDif, 						-- „⁄œ· «·“Ì«—«  «·›⁄«·… «·ÌÊ„Ì
			[hiGuid]	 
			FROM [#DistTble] 	AS	 [d] 
			INNER JOIN [vwDistTrvi] AS 	 [vi] 	ON [vi].[trDistributorGuid] = [d].[DistGuid] 
			WHERE  [dbo].[fnGetDateFromDT]([trDate]) BETWEEN @StartDate AND @EndDate 
			GROUP BY [DistGuid], [SalesmanGUID], [d].[Name], [hiGuid], [CostSalesmanGUID]
		
		UPDATE r SET 	ActiveVistCount = ( SELECT CAST(COUNT(DISTINCT [BuDate]) AS FLOAT) / @DayDif FROM vwbu AS bu WHERE [bu].[buCostPtr] = [d].[CostSalesmanGUID] AND buDate BETWEEN @StartDate AND @EndDate )
		FROM [#Result] AS r INNER JOIN [#DistTble] AS d ON r.DistPtr = d.DistGuid
		UPDATE r SET VistCount = CASE   WHEN VistCount > ActiveVistCount THEN VistCount ELSE ActiveVistCount END
		FROM [#Result] AS r INNER JOIN [#DistTble] AS d ON r.DistPtr = d.DistGuid

		-- UPDATE r SET 	VistCount = (CAST ( COUNT( DISTINCT CAST([ViGuid] AS NVARCHAR(40))) + ( SELECT COUNT(DISTINCT [BuDate]) FROM vwbu AS bu WHERE bu.buCostPtr = d.CostSalesmanGUID AND buDate BETWEEN @StartDate AND @EndDate AND buDate NOT IN ( SELECT [dbo].[fnGetDateFromDT]([StartTime]) FROM DistVi000 AS t WHERE t.CustomerGuid = bu.buCustPtr)  ) AS FLOAT ) / @DayDif)	-- „⁄œ· «·“Ì«—«  «·ÌÊ„Ì

		UPDATE r SET 	VistCount = CAST (  ( SELECT COUNT(CAST([ViGuid] AS [NVARCHAR](40))) FROM [vwDistTrvi] AS [vi] WHERE [vi].[trDistributorGuid] = [d].[DistGuid] AND [dbo].[fnGetDateFromDT]([trDate]) BETWEEN @StartDate AND @EndDate ) 
					   	  + ( SELECT COUNT(DISTINCT [BuDate]) FROM vwbu AS bu WHERE bu.buCostPtr = d.CostSalesmanGUID AND buDate BETWEEN @StartDate AND @EndDate AND buDate NOT IN ( SELECT [dbo].[fnGetDateFromDT]([StartTime]) FROM DistVi000 AS t WHERE t.CustomerGuid = bu.buCustPtr) ) 
						 AS FLOAT) / @DayDif
		FROM [#Result] 		AS 	[r]
		INNER JOIN [#DistTble] 	AS	[d] 	ON [d].[DistGuid] = [r].[DistPtr]

		UPDATE r SET 	ActiveVistCount = ( SELECT CAST(COUNT(DISTINCT [BuDate]) AS FLOAT) / @DayDif FROM vwbu AS bu WHERE [bu].[buCostPtr] = [d].[CostSalesmanGUID] AND buDate BETWEEN @StartDate AND @EndDate )
		FROM [#Result] AS r INNER JOIN [#DistTble] AS d ON r.DistPtr = d.DistGuid

		UPDATE r SET VistCount = CASE   WHEN VistCount > ActiveVistCount THEN VistCount ELSE ActiveVistCount END
		FROM [#Result] AS r INNER JOIN [#DistTble] AS d ON r.DistPtr = d.DistGuid
*/
		CREATE TABLE [#Visits] ( [CustGuid] [UNIQUEIDENTIFIER], [DistGuid] [UNIQUEIDENTIFIER], [viDate] [DATETIME], [Type] [INT])   	-- Type = 1	For Bill    - Type = 2	For Entry - Type = 3  	For Visits     
		INSERT INTO  [#Visits]    -- All Visits  Type =  3 
		SELECT  [cu].[number], di.DistGuid,  [dbo].[fnGetDateFromDT]([tr].[ViStartTime]), 3 
		FROM [vwDistTrVi] AS [tr]      
			INNER JOIN [#DistTble] 	AS [di] ON [di].[DistGuid] = [tr].[TrDistributorGUID] 
			INNER JOIN [#Cust] 	AS [cu] ON [Cu].[number] = [tr].[ViCustomerGUID] 
		WHERE 	[dbo].[fnGetDateFromDT]( [tr].[ViStartTime]) BETWEEN @StartDate AND @EndDate 
		IF @BillVisit = 1
		BEGIN
			INSERT INTO  [#Visits] 
			SELECT bu.buCustPtr, [di].[DistGuid], buDate, 3
			FROM [#DistTble] as [di] inner join vwbu AS bu ON 	Di.[CostSalesmanGUID] = bu.buCostPtr
			WHERE buDate BETWEEN @StartDate AND @EndDate
			AND  buGuid  not in 
				( SELECT objectGuid FROM DistVd000 AS vd INNER JOIN DistVi000 AS vi ON vd.vistGuid = vi.Guid
				  WHERE [dbo].[fnGetDateFromDT]([StartTime])BETWEEN @StartDate AND @EndDate 
				  AND Type = 3
				)
		END		
		INSERT INTO  [#Visits]     -- Actvie Visit   Type = 1 
		SELECT bu.buCustPtr, [di].[DistGuid], bu.buDate, 1  
	 	FROM [vwBu] AS bu      
			INNER JOIN [#Cust] 	AS cu ON Cu.number = bu.buCustPtr     
			INNER JOIN [#DistTble] AS Di ON Di.[CostSalesmanGUID] = bu.buCostPtr   
			LEFT JOIN  DistVd000 	AS Vd ON Vd.ObjectGuid = bu.buGuid 
		WHERE 	( bu.buDate BETWEEN @StartDate AND @EndDate )  AND 
			( ISNULL(Vd.ObjectGuid, 0x00) <> 0x00 OR @BillVisit = 1 ) 
		SELECT DistGuid, COUNT(viDate) AS Total
		INTO #TotalVi
		FROM [#Visits]
		WHERE type = 3
		GROUP BY DistGuid
		--SELECT * FROM #TotalVi

		SELECT DistGuid, COUNT( viDate) AS Total
		INTO #ActiveVi
		FROM [#Visits]
		WHERE type = 1
		GROUP BY DistGuid
		--SELECT * FROM #ActiveVi
 
		UPDATE r 
		SET VistCount = CAST(Total AS FLOAT) / @DayDif
		FROM [#Result] AS r INNER JOIN #TotalVi AS vi
		ON r.DistPtr = vi.DistGuid

		UPDATE r 
		SET ActiveVistCount = CAST(Total AS FLOAT) / @DayDif
		FROM [#Result] AS r INNER JOIN #ActiveVi AS vi
		ON r.DistPtr = vi.DistGuid
	END
	 
	EXEC prcCheckSecurity
	 
	IF ((@ShowMat = 1) OR (@ShowGrp = 1) OR (@MatGuid <> 0X0) ) 
	BEGIN 
		INSERT INTO [#T_RESULT] 
			SELECT  DISTINCT
				-- [cu].[DistGuid], 
				-- CASE @CostDep WHEN 0 THEN [cu].[CustGuid] ELSE 0x00 END,   --  [cu].[Number], 
				ds.DistGuid,
				[cu].[CustGuid], 
				[buSecurity], 
				[mtSecurity],      
				[buGUID], 
				[mt].[mtGuid], 
				[bi].[biQty]/[mtUnitFact], 
				0,    -- Target
				[buDirection], 
				0, 
				[mt].[mtCode], 
				[mt].[mtName], 
				[mt].[mtLatinName], 
				[mt].[mtGroup], 
				0, 
				[cu].[hiGuid] 
			FROM   
				[vwbubi] AS bi 
				INNER JOIN #DistTble 	AS Ds	ON ds.CostSalesmanGUID = bi.biCostPtr
--				INNER JOIN [#CUST2]  	AS [cu] ON ( [cu].[CustGuid] = [bi].[buCustPtr] AND @CostDep = 0 ) OR ( [cu].[CostSalesmanGUID] = [bi].[biCostPtr] AND @CostDep = 1 )  
--  				INNER JOIN [#CUST2]  	AS [cu] ON ([cu].[CustGuid] = [bi].[buCustPtr]) AND ( [cu].[CostSalesmanGUID] = [bi].[biCostPtr] OR @CostDep = 0 )  
  				LEFT JOIN  [#CUST2]  	AS [cu] ON [cu].[CustGuid] = [bi].[buCustPtr] AND [cu].[CostSalesmanGUID] = [bi].[biCostPtr]   
				INNER JOIN [#BillTbl] 	AS [bt] ON bt.Type = bi.buType 
				INNER JOIN [#MT1] 	AS [mt] ON mt.mtGuid = bi.biMatPtr 
			WHERE 
				([bi].[BuDate] BETWEEN  @StartDate AND @EndDate)  AND (btbilltype in (1,3))

-- Select * From #T_Result

		INSERT INTO [#T_RESULT] ( [DistPtr], [MatGuid], [TargetQty], [MatSecurity], [mtCode], [mtName], [mtLatinName], [GrpGuid], [hiGuid] )  
			-- SELECT [d].[DistGuid], [mt].[mtGuid], SUM([dt].[CustTarget]/[mtUnitFact]), [mtSecurity], [mt].[mtCode], [mt].[mtName], [mt].[mtLatinName], [mt].[mtGroup], [d].[hiGuid] 
			SELECT [d].[DistGuid], [mt].[mtGuid], (SUM([dt].[CustTarget]/[mtUnitFact]) * @DayDif) / @DayNum, [mtSecurity], [mt].[mtCode], [mt].[mtName], [mt].[mtLatinName], [mt].[mtGroup], [d].[hiGuid] 
			FROM [#Cust2] 	    AS [d]  
			-- INNER JOIN [vwBubi] AS [bu] ON ( [d].[Number] = [bu].[buCustPtr] AND @CostDep = 0 ) OR ( [d].[CostSalesmanGUID] = [bu].[biCostPtr] AND @CostDep = 1 )  
			-- INNER JOIN [DistCustMatTarget000] AS [dt] ON [bu].[buCustPtr] = [dt].[CustGuid] AND [dt].PeriodGuid = @PeriodGuid  AND [bu].[biMatPtr] = [dt].[MatGuid]  -- [d].[Number] = [dt].[CustGuid]  
			INNER JOIN [vwDistCustMatTarget] AS [dt] ON [d].[CustGuid] = [dt].[CustGuid]   -- [d].[Number] = [dt].[CustGuid]  
			INNER JOIN [#MT1]   AS [mt] ON [mt].[mtGuid] = [dt].[MatGuid]  
			WHERE [PeriodGuid] = @PeriodGuid 
			GROUP BY [d].[DistGuid], [mt].[mtGuid], [mtSecurity], [mt].[mtCode], [mt].[mtName], [mt].[mtLatinName], [mt].[mtGroup], [d].[hiGuid] 

		CREATE INDEX [tresult] ON [#T_RESULT] ([MatGuid]) 
		EXEC [prcCheckSecurity]  @result = '#T_Result' 
		IF (@ShowGrp = 1) 
		BEGIN 
			INSERT INTO [#T_Result]([DistPtr],[CustPtr],[MatGuid],[Qty],[TargetQty],[BuDirection],[Level],[mtCode],[mtName],[mtLatinName],[GrpGuid],[HiGuid]) 
			SELECT [DistPtr],[CustPtr],[gr].[Guid],SUM([Qty] * [BuDirection]),SUM([TargetQty]),-3,[Level],[gr].[Code],[gr].[Name],[gr].[LatinName],[gr].[ParentGuid],[r].[HiGuid] 
			FROM [#T_Result] AS [r] INNER JOIN [gr000] AS [gr] ON [gr].[Guid] = [r].[GrpGuid] 
			GROUP BY [DistPtr],[CustPtr],[gr].[Guid],[Level],[gr].[Code],[gr].[Name],[gr].[LatinName],[gr].[ParentGuid],[r].[HiGuid] 
			DELETE [#T_Result] WHERE [BuDirection] <> -3 
			UPDATE [#T_Result] SET [BuDirection] = 1  
		END  
		SELECT DISTINCT [gr].[Guid],[gr].[Code],[gr].[Name],[gr].[ParentGuid],[LEVEL],LEFT([PATH],18) AS [PATH]  
		INTO [#GrpLevel] 
		FROM [fnGetGroupsOfGroupSorted](0x0,1) AS [f]  
		INNER JOIN [gr000] AS [gr] ON [gr].[Guid] = [f].[Guid]  
		-- 
		INSERT INTO [#T_RESULT] ( [DistPtr], [MatGuid], [mtCode], [mtName], [mtLatinName], [GrpGuid] )  
		SELECT DISTINCT 	  0X00,      [MatGuid], [mtCode], [mtName], [mtLatinName], [GrpGuid] 
		FROM [#T_RESULT] AS [r]  
	END 
	IF (@MatGuid <> 0X0) 
	BEGIN 
		-- SELECT DISTINCT [Number] AS [CustPtr] 
		SELECT DISTINCT [CustGuid] AS [CustPtr] 
		INTO [#CU2] FROM [#CUST2]  AS [d]  
		WHERE d.CustGuid IN ( SELECT CustomerGuid FROM DistCM000 WHERE [DATE] > @StartDate AND MatGuid = @MatGuid ) 
			
		SELECT DistPtr, t.CustPtr 
		INTO [#TT] 
		FROM [#T_Result] AS [t] 
		WHERE 		MatGuid = @MatGuid
			 -- AND 	[CustPtr] NOT IN ( SELECT [CustPtr] FROM [#CU2] ) 
		GROUP BY DistPtr, t.CustPtr 
		HAVING SUM(Qty*-BuDirection) > 0

		-- INSERT [#T_NewMatRESULT] ( [DistPtr], [CustNumNEW] ) SELECT [DistPtr], COUNT(*) FROM [#TT] GROUP BY [DistPtr] -- «·“»«∆‰ «· Ì «‘ — 
		SELECT DISTINCT [DistGuid], [cu].[CustGuid] AS Number, [bi].[buDate] 
		INTO #TT1	 
		FROM   
			fn_bubi_Fixed( @CurrencyGuid) AS bi 
			INNER JOIN #CUST2  	AS cu ON [cu].[CustGuid] = [bi].[buCustPtr]  
			INNER JOIN #BillTbl 	AS bt ON bt.Type   = bi.buType 
		WHERE 
			bi.biMatPtr = @MatGuid 
		INSERT [#T_NewMatRESULT] ( [DistPtr], [CustNumNEW] ) SELECT [DistGuid], COUNT(*) FROM [#TT1] WHERE buDate BETWEEN @StartDate AND @EndDate GROUP BY [DistGuid] -- «·“»«∆‰ «· Ì «‘ — 
		-- SELECT DISTINCT [DistGuid], [Number] INTO [#TT2] FROM [#TT1] WHERE [buDate] BETWEEN @StartDate AND @EndDate 
		SELECT DISTINCT [DistGuid], [Number] INTO [#TT2] FROM [#TT1] 
			WHERE 	[buDate] BETWEEN @StartDate AND @EndDate AND 
				[Number] NOT IN ( SELECT DISTINCT CustomerGuid FROM DistCm000 WHERE [DATE] < @StartDate AND MatGuid = @MatGuid )  AND
				[Number] NOT IN ( SELECT DISTINCT Number FROM [#TT1] WHERE [buDate] < @StartDate )
		SELECT DISTINCT [DistGuid], [Number] INTO [#TT3] FROM [#TT1]  WHERE buDate BETWEEN @StartDate AND @EndDate  -- ⁄œœ «·“»«∆‰
		INSERT INTO [#TT3]
			SELECT DISTINCT Dl.[DistGuid], ce.[CustomerGuid]
			FROM DistCm000 AS Cm 
				INNER JOIN DistCe000 			AS Ce ON Ce.CustomerGuid = Cm.CustomerGuid
				INNER JOIN DistDistributionLines000 	AS Dl ON Dl.CustGuid = ce.CustomerGuid 

		WHERE 	Cm.Date > @StartDate
			 AND ce.CustomerGuid NOT IN (SELECT Number FROM [#TT3])

		INSERT [#T_NewMatRESULT] ( [DistPtr], [CustNumBye] )	SELECT [DistGuid], COUNT(*) FROM [#TT2] GROUP BY DistGuid  -- «·“»«∆‰ «·ÃœÌœ…
		INSERT [#T_NewMatRESULT] ( [DistPtr], [CustNum]    ) 	SELECT [DistGuid], COUNT(*) FROM [#TT3] GROUP BY DistGuid  -- ⁄œœ «·“»«∆‰ 
	END  
	IF @ShowHi = 1 
	BEGIN 
		SELECT [f].[guid], [f].[path], [f].[Level], [hi].[ParentGuid], [HI].[Name] INTO [#HI] FROM [dbo].[fnGetHierarchyList](@HiGuid,1) AS [f] INNER JOIN [DistHi000] AS [hi] ON [f].[Guid] = [hi].[Guid] ORDER BY Level DESC
		INSERT INTO [#RESULT] ( [DistPtr], [Name], [BuTotal], [BuDirection], [Target], [VistCount], [ActiveVistCount], [Path], [hiGuid], [Level], [IsHi] ) 
		SELECT [hi].[Guid], [hi].[Name], SUM([BuTotal]*-[BuDirection]), -1, SUM([Target]), 
		 SUM(DISTINCT [VistCount])/COUNT(DISTINCT CAST([DistPtr] AS NVARCHAR(40))), SUM(DISTINCT [ActiveVistCount])/COUNT(DISTINCT CAST ([DistPtr] AS NVARCHAR(40))), 
		-- SUM([VistCount])/COUNT(CAST([DistPtr] AS NVARCHAR(40))), SUM([ActiveVistCount])/COUNT(CAST ([DistPtr] AS NVARCHAR(40))), 
		[hi].[Path], [hi].[ParentGuid], [hi].[Level], 1 
		FROM [#RESULT] AS [r]  
			INNER JOIN [#HI] AS [hi] ON [hi].[Guid] = [r].[HiGuid] 
		GROUP BY [hi].[Guid], [hi].[Name], [HI].[Path], [hi].[ParentGuid], [hi].[Level] 

		UPDATE [r] SET [Path] = [hi].[Path]  
		FROM [#RESULT] AS [r]  
			INNER JOIN [#HI] AS [hi] ON [hi].[Guid] = [r].[hiGuid] 
		WHERE [r].[Path] = '' 

		IF ( (@ShowMat = 1) OR (@ShowGrp = 1) ) 
		BEGIN 
			INSERT INTO [#T_RESULT]	( [DistPtr], [MatGuid], [Qty], [TargetQty], [BuDirection], [Level], [mtCode], [mtName], [mtLatinName], [GrpGuid], [HiLevel], [HiGuid] ) 
				SELECT [hi].[Guid], [MatGuid], SUM([Qty] * -[BuDirection]), SUM([TargetQty]), -1, [r].[Level], [mtCode], [mtName], [mtLatinName], [GrpGuid], [hi].[Level], [hi].[ParentGuid] 
			FROM [#T_RESULT] AS [r]  
			INNER JOIN [#HI] AS [hi] ON [hi].[Guid] = [r].[HiGuid] 
			GROUP BY [hi].[Guid], [MatGuid], [r].[Level], [mtCode], [mtName], [mtLatinName], [GrpGuid], [hi].[Level], [hi].[ParentGuid]	 
		END 
		IF (@MatGuid <> 0X0) 
		BEGIN
			INSERT INTO [#T_NewMatRESULT] ( [DistPtr], [CustNumNEW], [CustNum], [CustNumBye], [Level] ) 
				SELECT	[hi].[Guid], SUM([CustNumNEW]), SUM([CustNum]), SUM([CustNumBye]), [hi].[Level]	 
				FROM [#T_NewMatRESULT] AS [r] 
					INNER JOIN [vwDistributor] 	AS [d] 	ON [r].[DistPtr] = [d].[GUID] 
					INNER JOIN [#HI] 			AS [hi] ON [hi].[Guid] 	 = [d].[HierarchyGUID] 
				GROUP BY [hi].[Guid],[hi].[Level]				 
		END
		SELECT @MaxLevel = MAX([Level]) FROM [#HI] 
		WHILE @MaxLevel > 0 
		BEGIN 
			INSERT INTO [#RESULT] ( [DistPtr], [Name], [BuTotal], [BuDirection], [Target], [VistCount], [ActiveVistCount], [Path], [hiGuid], [Level], [IsHi] ) 
			SELECT [hi].[Guid], [hi].[Name], SUM([BuTotal]*-[BuDirection]), -1, SUM([Target]), AVG([VistCount]), AVG([ActiveVistCount]), [hi].[Path], [d].[ParentGUID], [hi].[Level], 1 
			FROM [#RESULT] AS [r] 
				INNER JOIN [vwDistHi] 	AS [d] 	ON [r].[DistPtr] = [d].[GUID] 
				INNER JOIN [#HI] 		AS [hi] ON [hi].[Guid] 	 = [d].[ParentGUID] 
			WHERE [r].[Level] = @MaxLevel 
			GROUP BY [hi].[Guid], [hi].[Name], [HI].[Path], [d].[ParentGUID], [hi].[Level] 
			 
			IF ((@ShowMat = 1) OR (@ShowGrp = 1)) 
			BEGIN 
				INSERT INTO [#T_RESULT]	( [DistPtr], [MatGuid], [Qty], [TargetQty], [BuDirection], [Level], [mtCode], [mtName], [mtLatinName], [GrpGuid], [HiLevel], [HiGuid] ) 
					SELECT [hi].[Guid], [MatGuid] ,SUM([Qty] * -[BuDirection]), SUM([TargetQty]), -1, [r].[Level], [mtCode], [mtName], [mtLatinName], [GrpGuid], [hi].[Level], [hi].[ParentGuid] 
					FROM [#T_RESULT] AS [r]  
					INNER JOIN [#HI] AS [hi] ON [hi].[Guid] = [r].[HiGuid] 
					WHERE [r].[HiLevel] = @MaxLevel 
					GROUP BY [hi].[Guid], [MatGuid], [r].[Level], [mtCode], [mtName], [mtLatinName], [GrpGuid], [hi].[Level], [hi].[ParentGuid]	 
			END 
			IF (@MatGuid <> 0X0) 
			INSERT INTO [#T_NewMatRESULT] ( [DistPtr], [CustNumNEW], [CustNum], [CustNumBye], [Level] )  
				SELECT [hi].[Guid], SUM([CustNumNEW]), SUM([CustNum]), SUM([CustNumBye]), [hi].[Level]	 
				FROM [#T_NewMatRESULT] 			AS [r] 
					INNER JOIN [vwDistHi]  	AS [d]	ON [r].[DistPtr] = [d].[GUID] 
					INNER JOIN [#HI] 		AS [hi]	ON [hi].[Guid]   = [d].[ParentGUID] 
				GROUP BY [hi].[Guid], [hi].[Level]		 
			SET @MaxLevel = @MaxLevel - 1 
		END 	
	END 
	SELECT 	[DistPtr], [Name] AS [DistName], SUM([BuTotal]*-[BuDirection]) AS [Sales], SUM([Target]) AS [Target], 
		-- SUM([VistCount]) AS [VistCount], SUM([ActiveVistCount]) AS [EffVistCount], [IsHi]	 
		 MAX([VistCount]) AS [VistCount], MAX([ActiveVistCount]) AS [EffVistCount], [IsHi]	
	FROM [#RESULT] AS [r]  
	GROUP BY [DistPtr], [Name], [r].[Path], [IsHi] 
	ORDER BY [r].[Path], [IsHi] DESC  

	IF ( (@ShowMat = 1) OR (@ShowGrp = 1) ) 
	BEGIN 
		IF (@ShowGrp = 1) 
		BEGIN 
			DELETE [#GrpLevel] WHERE [Guid] IN ( SELECT [MatGuid] FROM [#T_RESULT]) AND [LEVEL] > 0 
			UPDATE [t] SET [GrpGuid] = [MatGuid] FROM [#T_RESULT] AS [t] INNER JOIN [#GrpLevel] AS [g] ON [MatGuid] = [G].[Guid] 
		END 
		SELECT * FROM [#GrpLevel] WHERE [LEVEL] <= 1 ORDER BY [Path] 
		 
		SELECT    [DistPtr], [mtName] AS [Name], [mtLatinName] AS [LatinName], [MatGuid], SUM([r].[Qty]*-[BuDirection]) AS [Qty], SUM([TargetQty]) AS [TargetQty], [Path] 
		FROM [#T_RESULT] 	AS [r]  
		INNER JOIN [#GrpLevel] 	AS [g] ON [g].[GUID] = [r].[GrpGuid] 
		GROUP BY [DistPtr], [Path], [mtName], [mtLatinName], [MatGuid] 
		ORDER BY [DistPtr], [Path], [mtName] 
	END 
		 
	IF (@MatGuid <> 0X0) 
		SELECT [DistPtr], SUM([CustNumNEW]) AS [CustNumNew], SUM([CustNum]) AS [CustCount], SUM([CustNumBye]) AS [CustCountBye]
		FROM [#T_NewMatRESULT] GROUP BY [DistPtr] 
	 
	SELECT * FROM [#SecViol] 
	SELECT @StartDate AS [StartDate]
	
	

/* 
prcConnections_add2 '„œÌ—' 
exec repDayActiveAccumelate 0x00, 'BC2D0EBC-9940-432B-BA60-A5E0A99E8516', '05-01-2006', 0x00, 'FF84EF20-BEE0-4398-9B99-1970DE830C43', 0, 1, 0, 0, 1, 1, 0  

EXECUTE [repDayActiveAccumelate] '00000000-0000-0000-0000-000000000000', 'e09d370b-8ddc-4d5b-a010-b67c7bd9efdf', '5/31/2011 0:0:0.0', '00000000-0000-0000-0000-000000000000', 'e77c44de-b391-4d00-aea0-f739756732c9', 3, 0, 0, 0, 1, 0, -1, 0, 1

*/
########################################
#END

