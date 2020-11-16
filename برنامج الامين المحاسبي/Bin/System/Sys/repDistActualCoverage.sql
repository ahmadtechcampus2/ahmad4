##################################################################
CREATE PROCEDURE repDistActualCoverage  
	@SrcGuid			[UNIQUEIDENTIFIER],      
	@StartDate			[DATETIME],       
	@EndDate			[DATETIME],       
	@HiGuid				[UNIQUEIDENTIFIER],       
	@DistGuid			[UNIQUEIDENTIFIER],       
	@CustAccGuid		[UNIQUEIDENTIFIER],       
	@ShowCustCoverage	[INT] = 0, 		-- 0 All Custs   1 CustInCoverage   2 CustOutCoverage      
	@ShowDistHi			[BIT] = 0,  
	@ShowCusts			[BIT] = 1,		-- 1 Show Custs		 - 0 Dont Show Custs 
	@GroupVisit			[BIT] = 1,		-- 1  Visits In Same Date = 1 Visit     0  All Visits In Same Date = Total Visits 
	@BillIsVisit		[BIT] = 0,		-- 1  Bill From Ameen IS Visit		0 Bill From Amn Is Not Visit 
	@CustsCT			[UNIQUEIDENTIFIER],      
	@CustsTCH			[UNIQUEIDENTIFIER],      
	@MatsTemplates		[UNIQUEIDENTIFIER], 
	@ShowDates			[INT],	      
	@CurGuid			[UNIQUEIDENTIFIER] = 0x00, 
	@ShowCustSales		[BIT] = 0	 
AS       
	SET NOCOUNT ON      
-- Select * from #aa 
	CREATE TABLE [#SecViol]	( [Type]	[INT], [Cnt] [INTEGER] )   
	-----------------------------------------------------------------------------------  
	---------- Dists Informations ----------------------------------------------------- 
	CREATE TABLE [#Dists]( [DistGuid] 	[UNIQUEIDENTIFIER], [Security] 	 [INT], [HIGuid] [UNIQUEIDENTIFIER], [SalesManGuid] [UNIQUEIDENTIFIER], [SalesManSecrity] [INT], [CostGuid] [UNIQUEIDENTIFIER])  
	-- For Bills With CostGuid = 0x00  
	IF (@DistGuid = 0x00 AND @HiGuid = 0x00) 
	BEGIN 
		INSERT INTO [#Dists] ( [DistGuid], [Security], [HIGuid], [SalesManGuid], [CostGuid], [SalesManSecrity] )  
			VALUES (0x00, 1, 0x00, 0x00, 0x00, 0x00)   
	END 
	INSERT INTO [#Dists] ( [DistGuid], [Security]) EXEC [GetDistributionsList] @DistGuid, @HiGuid   
	UPDATE [d] SET	[HiGuid] = [HierarchyGUID],   
					[SalesManGuid]	  = CASE [CurrSaleMan] WHEN 1 THEN [PrimSalesmanGUID] ELSE [AssisSalesmanGUID] END, 
					[CostGuid]		  = [sm].[CostGUID],  
					[SalesManSecrity] = [sm].[Security]    
	FROM   
		[#Dists] AS [d]   
		INNER JOIN [Distributor000]	 AS [ds] ON [d].[DistGuid] = [ds].[GUID]  
		--INNER JOIN [DistSalesman000] AS [sm] ON [sm].[Guid] = CASE [CurrSaleMan] WHEN 1 THEN [PrimSalesmanGUID] ELSE [AssisSalesmanGUID] END  
		--AssisSalesmanGUID Became Unused In New Versions 
		INNER JOIN [DistSalesman000] AS [sm] ON [sm].[Guid] = [PrimSalesmanGUID]
	---- Dists HierarchyList  
	CREATE TABLE [#DistsList]( [Guid] [UNIQUEIDENTIFIER], [Type] [INT], [Level] [INT], [Path] [NVARCHAR](1000) COLLATE ARABIC_CI_AI)  
	INSERT INTO #DistsList( [Guid], [Type], [Level], [Path]) VALUES (0x00, 0, 0, '1.00')  
	INSERT INTO #DistsList( [Guid], [Type], [Level], [Path]) SELECT [Guid], [Type], [Level], [Path] FROM dbo.fnDistGetHierarchyList(0, 1) 
	-----------------------------------------------------------------------------------      
	------Report Sources Bills -------------------------------------------------------- 
	DECLARE @UserId		UNIQUEIDENTIFIER      
	SET @UserId = dbo.fnGetCurrentUserGUID()        
	CREATE TABLE [#BillTbl] ([Type] [UNIQUEIDENTIFIER], [Security] [INT], [ReadPriceSecurity] [INT], [UnPostedSecurity] [INT])       
	INSERT INTO [#BillTbl] 	EXEC [prcGetBillsTypesList2] 	@SrcGuid, @UserID    

	CREATE TABLE [#EntryTbl]( [Type] 	[UNIQUEIDENTIFIER], [Security]  	[INT])  
	INSERT INTO [#EntryTbl] EXEC [prcGetEntriesTypesList] @SrcGuid, @UserID     

	-------------------------------------------------------------------------------------      
	------ Custs List For This Report --------------------------------------------------- 
	--  Get CustomerAccounts List      
	CREATE TABLE [#Customers]      ( [GUID] [UNIQUEIDENTIFIER], [Security] [INT])          
	INSERT INTO  [#Customers] EXEC prcGetDistGustsList @DistGuid, @CustAccGuid, 0x00, @HiGuid   
	----- 
	CREATE TABLE [#Cust] 	(  
		[CustGuid] 		[UNIQUEIDENTIFIER],  
		[DistGuid] 		[UNIQUEIDENTIFIER],  
		[Security] 		[INT],  
		[Route1]		[INT],  
		[Route2]		[INT], 
		[Route3]		[INT],  
		[Route4]		[INT],  
		[ExpectedCov]	[INT],
		[Flag]			[INT] -- 1 customer related to this dist, 2 customer not related to dist
	)        
	
	INSERT INTO [#Cust]( 
		[CustGuid], 
		[DistGuid], 
		[Security], 
		[Route1], 
		[Route2], 
		[Route3], 
		[Route4], 
		[ExpectedCov],
		[Flag]
	) 
	SELECT    
		[cu].[GUID],       
		ISNULL([Dl].[DistGuid], 0x00),    
		[cu].[Security],
		ISNULL([Dl].[Route1], 0),
		ISNULL([Dl].[Route2], 0),
		ISNULL([Dl].[Route3], 0),
		ISNULL([Dl].[Route4], 0),
		0,
		1
	FROM       
		[#Customers] AS Cu       
		LEFT JOIN [DistDistributionLines000] 	AS [Dl] ON [dl].[CustGUID] = [cu].[GUID]     
		INNER JOIN [#Dists]		AS [D]	  ON [D].[DistGuid] = [dl].[DistGuid] 
		LEFT JOIN [DistCe000] 	AS [Dc]   ON [Dc].[CustomerGuid] = [cu].[Guid]    
		INNER JOIN [RepSrcs]	AS [rCT]  ON [rCT].[IdType]  = ISNULL([Dc].[CustomerTypeGuid], 0x00) AND [rCT].[idTbl] = @CustsCT 
		INNER JOIN [RepSrcs]	AS [rTCH] ON [rTCH].[IdType] = ISNULL([Dc].[TradeChannelGuid], 0x00) AND [rTCH].[idTbl] = @CustsTCH 
	WHERE (@ShowCustCoverage = 1 AND (ISNULL([Dl].[Route1], 0) <> 0 OR ISNULL([Dl].[Route2], 0) <> 0 OR ISNULL([Dl].[Route3], 0) <> 0 OR ISNULL([Dl].[Route4], 0) <> 0))
		OR (@ShowCustCoverage = 2)
		OR @ShowCustCoverage = 0

	-- Insert the customers not related to the distributor but have visits from this distributor
	--the visits generated by manual bills
	BEGIN 
		INSERT INTO [#Cust]( 
			[CustGuid], 
			[DistGuid], 
			[Security], 
			[Route1], 
			[Route2], 
			[Route3], 
			[Route4], 
			[ExpectedCov],
			[Flag]
		) 
		SELECT  DISTINCT 
			[cu].[cuGUID],       
			ISNULL( [D].[DistGuid], 0x00),    
			[cu].[cuSecurity], 
			0,  
			0,  
			0,  
			0,   
			0,
			2
		FROM       
			dbo.fnGetAcDescList(@CustAccGuid)	AS [ac] 
			INNER JOIN [vwCu] 		AS [Cu]		ON [cu].[cuAccount] = [ac].[Guid] 
			INNER JOIN [vwBu] 		AS [bu] 	ON [bu].[buCustPtr] = [cu].[cuGuid] 
			INNER JOIN [#Billtbl] 	AS [bt]		ON [bt].[Type] = [bu].[buType]      
			INNER JOIN [#Dists]		AS [D]		ON [D].[CostGuid] = [bu].[buCostPtr] 
			LEFT  JOIN [#Cust] 		AS [C]		ON [cu].[cuGuid] = [C].[CustGuid] AND [C].[DistGuid] = [D].[DistGuid] 
			LEFT  JOIN [DistCe000] 	AS [Dc]		ON [Dc].[CustomerGuid] = [cu].[cuGuid] 
			INNER JOIN [RepSrcs]	AS [rCT] 	ON rCT.IdType  = ISNULL([Dc].[CustomerTypeGuid], 0x00) AND [rCT].[idTbl]  = @CustsCT 
			INNER JOIN [RepSrcs]	AS [rTCH]	ON rTCH.IdType = ISNULL([Dc].[TradeChannelGuid], 0x00) AND [rTCH].[idTbl] = @CustsTCH 
		WHERE       
			[C].[CustGuid] IS NULL 
			AND [bu].[buDate] BETWEEN @StartDate AND @EndDate 

	--the visits generated by manual entries
	INSERT INTO [#Cust]( 
			[CustGuid], 
			[DistGuid], 
			[Security], 
			[Route1], 
			[Route2], 
			[Route3], 
			[Route4], 
			[ExpectedCov],
			[Flag]
		) 
		SELECT  DISTINCT 
			[cu].[cuGUID],       
			ISNULL( [D].[DistGuid], 0x00),    
			[cu].[cuSecurity], 
			0,  
			0,  
			0,  
			0,   
			0,
			2
		FROM       
			dbo.fnGetAcDescList(@CustAccGuid)	AS [ac] 
			INNER JOIN [vwCu] 		AS [Cu]		ON [cu].[cuAccount] = [ac].[Guid] 
			INNER JOIN [en000] 		AS [en] 	ON [en].[AccountGuid] = [cu].[cuAccount] 
			INNER JOIN [ce000]		AS [ce]		ON [ce].[Guid] = [en].[ParentGuid]
			INNER JOIN [#Entrytbl] 	AS [et]		ON [et].[Type] = [ce].[TypeGuid]      
			INNER JOIN [#Dists]		AS [D]		ON [D].[CostGuid] = [en].[CostGuid] 
			LEFT  JOIN [#Cust] 		AS [C]		ON [cu].[cuGuid] = [C].[CustGuid] AND [C].[DistGuid] = [D].[DistGuid] 
			LEFT  JOIN [DistCe000] 	AS [Dc]		ON [Dc].[CustomerGuid] = [cu].[cuGuid] 
			INNER JOIN [RepSrcs]	AS [rCT] 	ON rCT.IdType  = ISNULL([Dc].[CustomerTypeGuid], 0x00) AND [rCT].[idTbl]  = @CustsCT 
			INNER JOIN [RepSrcs]	AS [rTCH]	ON rTCH.IdType = ISNULL([Dc].[TradeChannelGuid], 0x00) AND [rTCH].[idTbl] = @CustsTCH 
		WHERE       
			[C].[CustGuid] IS NULL 
			AND [en].[Date] BETWEEN @StartDate AND @EndDate 

	END
	-------------------------------------------------------------------------------------- 
	     
	------ Calc ExpectedCoverage     ------------------------------------------------------ 
	UPDATE [#Cust] SET ExpectedCov = dbo.fnDistCalcExpectedCovBetweenDates (@StartDate, @EndDate, Route1, Route2, Route3, Route4)   
	-----------------------------------------------------------------------------------      

	------ Get Visits ----------------------------------------------------------------- 
	CREATE TABLE #TotalVisitsStates (VisitGuid UNIQUEIDENTIFIER, CustGuid UNIQUEIDENTIFIER, DistGuid UNIQUEIDENTIFIER, State INT, VisitDate DATETIME) -- State: 1 Active , 0 Inactive
	INSERT INTO #TotalVisitsStates EXEC prcDistGetVisitsState @StartDate, @EndDate, @HiGuid, @DistGuid, @BillIsVisit, @SrcGuid

	CREATE TABLE [#CustVisits] ( 
		[VisitGuid]		[UNIQUEIDENTIFIER] DEFAULT (newID()),
		[CustGuid]		[UNIQUEIDENTIFIER],  
		[DistGuid]		[UNIQUEIDENTIFIER],  
		[VisitDate]		[DATETIME],		
		[VisitState]	[INT],		-- State = 1 Effective Visit,	State = 0 Uneffective Visit	 
		[RouteState]	[INT],		-- State = 1 Visit In Route  , State = 2 Visit Out Route 
		[ObjectGuid]	[UNIQUEIDENTIFIER], -- 0x0 if the visit dosen't contain a bill
		[Flag]			[INT]
	)

	INSERT INTO  #CustVisits
		SELECT
			tv.VisitGuid,
			tv.CustGuid,
			tv.DistGuid,
			dbo.fnGetDateFromDT(tv.VisitDate),
			tv.State,
			dbo.fnDistGetCustVisitState(tv.DistGuid, tv.CustGuid, dbo.fnGetDateFromDT(tv.VisitDate)),
			Vd.ObjectGuid,
			Cu.Flag
		FROM #TotalVisitsStates AS tv
		INNER JOIN #Cust AS Cu ON Cu.CustGuid = tv.CustGuid  AND Cu.DistGuid = tv.DistGuid
		INNER JOIN DistVd000 AS Vd ON Vd.VistGuid = tv.VisitGuid AND Vd.Type = 3
		
	--UPDATE #CustVisits
	--	SET OBjectGuid = Vd.ObjectGuid
	--FROM #CustVisits AS cv
	--INNER JOIN DistVd000 AS Vd ON Vd.VistGuid = cv.VisitGuid AND Vd.Type = 3
	-- Cant Update On 3 rows with one visit that have 2 bill guid

	;WITH CTE AS(
		SELECT *,
			RN = ROW_NUMBER()OVER(PARTITION BY VisitGuid, CustGuid, DistGuid ORDER BY VisitGuid, CustGuid, DistGuid)
		FROM #CustVisits
	)
	DELETE FROM CTE WHERE RN > 1

	--SELECT * FROM #CustVisits
	-----------------------------------------------------------------------------------      
	------ Get Visits ---------------------------------------------------------------- 
	CREATE TABLE [#CustTotalVisits] (  
		[CustGuid]						[UNIQUEIDENTIFIER],  
		[DistGuid]						[UNIQUEIDENTIFIER],  
		[ExpectedVisits]				[INT],  
		[TotalVisits]					[INT],  
		[ActVisitsInRoute]				[INT], 
		[ActVisitsOutRoute]				[INT], 
		[UnActVisitsInRoute]			[INT], 
		[UnActVisitsOutRoute]			[INT], 
		[TemplateActVisitsInRoute]		[INT], 
		[TemplateActVisitsOutRoute]		[INT], 
		[Flag]							[INT]
	)      
	-- Get Visits : Total - ActVisit(InRoute - OutRoute) - UnActVisit(InRoute - OutRoute) 
	INSERT INTO #CustTotalVisits( 
		[CustGuid], 
		[DistGuid], 
		[ExpectedVisits], 
		[TotalVisits], 
		[ActVisitsInRoute], 
		[ActVisitsOutRoute], 
		[UnActVisitsInRoute], 
		[UnActVisitsOutRoute], 
		[TemplateActVisitsInRoute], 
		[TemplateActVisitsOutRoute],
		[Flag]
	) 
	SELECT 
		[cv].[CustGuid],  
		[cv].[DistGuid],  
		0, -- ExpectedCov, 
		TotalVisits				= CASE @GroupVisit WHEN 1 THEN COUNT(DISTINCT [cv].[VisitDate])	 ELSE COUNT([cv].[VisitDate])  END, 
		ActiveVisitsInRoute		= CASE @GroupVisit WHEN 1 THEN COUNT(DISTINCT	CASE [cv].[VisitState] WHEN 1 THEN (CASE [cv].[RouteState] WHEN 1 THEN cv.VisitDate ELSE NULL END) ELSE NULL END )  
														  ELSE COUNT(			CASE [cv].[VisitState] WHEN 1 THEN (CASE [cv].[RouteState] WHEN 1 THEN cv.VisitDate ELSE NULL END) ELSE NULL END ) END, 
		ActiveVisitsOutRoute	= CASE @GroupVisit WHEN 1 THEN COUNT(DISTINCT	CASE [cv].[VisitState] WHEN 1 THEN (CASE [cv].[RouteState] WHEN 2 THEN cv.VisitDate ELSE NULL END) ELSE NULL END )  
														  ELSE COUNT(			CASE [cv].[VisitState] WHEN 1 THEN (CASE [cv].[RouteState] WHEN 2 THEN cv.VisitDate ELSE NULL END) ELSE NULL END ) END, 
		UnActiveVisitsInRoute	= CASE @GroupVisit WHEN 1 THEN COUNT(DISTINCT	CASE [cv].[VisitState] WHEN 1 THEN NULL ELSE (CASE cv.RouteState WHEN 1 THEN [cv].[VisitDate] ELSE NULL END) END )  
														  ELSE COUNT(			CASE [cv].[VisitState] WHEN 1 THEN NULL ELSE (CASE cv.RouteState WHEN 1 THEN [cv].[VisitDate] ELSE NULL END) END ) END, 
		UnActiveVisitsOutRoute	= CASE @GroupVisit WHEN 1 THEN COUNT(DISTINCT	CASE [cv].[VisitState] WHEN 1 THEN NULL ELSE (CASE cv.RouteState WHEN 2 THEN [cv].[VisitDate] ELSE NULL END) END )  
														  ELSE COUNT(			CASE [cv].[VisitState] WHEN 1 THEN NULL ELSE (CASE cv.RouteState WHEN 2 THEN [cv].[VisitDate] ELSE NULL END) END ) END, 
		0, 
		0,
		cv.Flag
	FROM 
		#CustVisits AS cv 
	GROUP BY  
		[cv].[CustGuid], [cv].[DistGuid], cv.Flag

	--- Expected Visits 
	UPDATE #CustTotalVisits 
		SET [ExpectedVisits] = [cu].[ExpectedCov] 
	FROM #CustTotalVisits AS [tv] 
		INNER JOIN #Cust AS [cu] ON [cu].[CustGuid] = [tv].[CustGuid] AND [cu].[DistGuid] = [tv].[DistGuid] 

	IF @ShowCustCoverage = 2
	BEGIN
		UPDATE #CustTotalVisits
			SET [ActVisitsInRoute] = 0,
				[ActVisitsOutRoute] = 0,
				[UnActVisitsInRoute] = 0,
				[UnActVisitsOutRoute]=0
		FROM #CustTotalVisits AS tv
	END

	--Insert the customers that don't have a visit
	INSERT INTO #CustTotalVisits( 
		[CustGuid], 
		[DistGuid], 
		[ExpectedVisits], 
		[TotalVisits], 
		[ActVisitsInRoute], 
		[ActVisitsOutRoute], 
		[UnActVisitsInRoute], 
		[UnActVisitsOutRoute], 
		[TemplateActVisitsInRoute], 
		[TemplateActVisitsOutRoute],
		[Flag]
	) 
	SELECT 
		[cu].[CustGuid],  
		[cu].[DistGuid],  
		[cu].[ExpectedCov], 
		0,  
		0,  
		0,  
		0,  
		0, 
		0, 
		0, 
		[cu].[Flag] 
	FROM  
		#Cust As [cu] 
		LEFT JOIN #CustTotalVisits AS [tv] ON [tv].[CustGuid] = [cu].[CustGuid] AND [tv].[DistGuid] = [cu].[DistGuid] 
	WHERE  
		ISNULL([tv].[CustGuid], 0x00) = 0x00
	--SELECT * FROM #CustTotalVisits

	------------------------------------------------------------------------------------------------------- 
	--------  Get Active Visits For Templates & Route 	 
	DECLARE @Level INT 
	CREATE TABLE #TemplatesLst	( [Guid]	[UNIQUEIDENTIFIER], [Name]			[NVARCHAR](255) ) 
	CREATE TABLE #MatTemplates	( [MatGuid]	[UNIQUEIDENTIFIER], [GroupGuid]		[UNIQUEIDENTIFIER], [TemplateGuid]	[UNIQUEIDENTIFIER] ) 
	CREATE TABLE #TemplateVisits( [buGuid]	[UNIQUEIDENTIFIER], [TemplateGuid]	[UNIQUEIDENTIFIER], [VisitGuid]		[UNIQUEIDENTIFIER] ) 
	CREATE TABLE #TotalTemplatesVisits( 
		[CustGuid]			[UNIQUEIDENTIFIER],  
		[DistGuid]			[UNIQUEIDENTIFIER],  
		[TemplateGuid]		[UNIQUEIDENTIFIER],  
		[ActVisitsInRoute]	[INT], 
		[ActVisitsOutRoute]	[INT], 
		[Level]				[INT] 
	) 
	BEGIN 
		---- Get MatTemplates List	 
		INSERT INTO #TemplatesLst (	[Guid], [Name]) 
		SELECT  
			[Guid], [Name]  
		FROM [DistMatTemplates000]  
		Where [Guid] IN (SELECT [IdType] FROM RepSrcs WHERE [idTbl] = @MatsTemplates) OR (@MatsTemplates = 0x00) 
		INSERT INTO #MatTemplates (	[MatGuid], [GroupGuid], [TemplateGuid]) 
		SELECT  
			[MatGuid], [GroupGuid], [TemplateGuid] 
		FROM  
			fnDistGetMatTemplates(0x00) AS fn 
			INNER JOIN #TemplatesLst AS tm ON [tm].[Guid] = [fn].[TemplateGuid] 
		---- Act Visits For Each Template 
		INSERT INTO #TemplateVisits( 
			buGuid, 
			TemplateGuid, 
			VisitGuid 
		) 
		SELECT 
			[bu].[buGuid], 
			[mt].[TemplateGuid], 
			[cv].[VisitGuid] 
		FROM  
			[#CustVisits] AS [cv]  
			INNER JOIN [#Dists] AS [ds] ON [ds].[DistGuid] = [cv].[DistGuid]  
			INNER JOIN [vwbubi]	AS [bu] ON [bu].[buCostPtr] = [ds].[CostGuid] AND [bu].[buCustPtr] = [cv].[CustGuid] AND [bu].[buGuid] = [cv].[ObjectGuid] 
			INNER JOIN [#MatTemplates] AS [mt] ON [mt].[MatGuid] = [bu].[biMatPtr] 
		--WHERE cv.VisitState = 1 -- Only active visits
		GROUP BY [bu].[buGuid], [cv].[VisitGuid], [mt].[TemplateGuid] 
 --select * from #custvisits
		---- Total Visits Templates	For Custs		 
		-- Total For Each Template 
		SELECT @Level = MAX(Level) + 1 FROM #DistsList 
		INSERT INTO #TotalTemplatesVisits( 
			[CustGuid], 
			[DistGuid], 
			[TemplateGuid], 
			[ActVisitsInRoute], 
			[ActVisitsOutRoute], 
			[Level] 
		) 
		SELECT  
			[cv].[CustGuid], 
			[cv].[DistGuid], 
			[tv].[TemplateGuid],	 
			ActiveVisitsInRoute		= CASE @GroupVisit WHEN 1 THEN COUNT(DISTINCT	CASE [cv].[RouteState] WHEN 1 THEN [cv].[VisitDate] ELSE NULL END)  
															  ELSE COUNT(			CASE [cv].[RouteState] WHEN 1 THEN [cv].[VisitDate] ELSE NULL END) END, 
			ActiveVisitsOutRoute	= CASE @GroupVisit WHEN 1 THEN COUNT(DISTINCT	CASE [cv].[RouteState] WHEN 2 THEN [cv].[VisitDate] ELSE NULL END) 
															  ELSE COUNT(			CASE [cv].[RouteState] WHEN 2 THEN [cv].[VisitDate] ELSE NULL END) END, 
			@Level   
		FROM  
			#CustVisits AS cv  
			INNER JOIN #TemplateVisits AS tv ON [tv].[VisitGuid] = [cv].[VisitGuid]  
		--WHERE  
		--	[cv].[VisitState] = 1 
		GROUP BY [cv].[CustGuid], [cv].[DistGuid], [tv].[TemplateGuid] 

		-- Total For All Template 
		INSERT INTO #TotalTemplatesVisits( 
			[CustGuid], 
			[DistGuid], 
			[TemplateGuid], 
			[ActVisitsInRoute], 
			[ActVisitsOutRoute], 
			[Level] 
		) 
		SELECT  
			[cv].[CustGuid], 
			[cv].[DistGuid], 
			0x00,	 
			ActiveVisitsInRoute		= CASE @GroupVisit WHEN 1 THEN COUNT(DISTINCT	CASE [cv].[RouteState] WHEN 1 THEN [cv].[VisitDate] ELSE NULL END)  
															  ELSE COUNT(			CASE [cv].[RouteState] WHEN 1 THEN [cv].[VisitDate] ELSE NULL END) END, 
			ActiveVisitsOutRoute	= CASE @GroupVisit WHEN 1 THEN COUNT(DISTINCT	CASE [cv].[RouteState] WHEN 2 THEN [cv].[VisitDate] ELSE NULL END) 
															  ELSE COUNT(			CASE [cv].[RouteState] WHEN 2 THEN [cv].[VisitDate] ELSE NULL END) END, 
			@Level   
		FROM  
			#CustVisits AS cv  
			INNER JOIN (SELECT DISTINCT [buGuid], [VisitGuid] FROM #TemplateVisits)AS tv ON [tv].[VisitGuid] = [cv].[VisitGuid] AND [cv].[ObjectGuid] = [tv].[buGuid] 
		--WHERE [cv].[VisitState] = 1 
		GROUP BY [cv].[CustGuid], [cv].[DistGuid] 

		---- Total Visits Templates	For Dist & DistHi		 
		-- IF @ShowDistHi = 1 
		BEGIN  
			WHILE @Level <> 0 
			BEGIN 
				SET @Level = @Level - 1 
				INSERT INTO #TotalTemplatesVisits([DistGuid], [CustGuid], [TemplateGuid], [ActVisitsInRoute], [ActVisitsOutRoute], [Level]) 
				SELECT	     
					ISNULL([ds].[HierarchyGuid], [hi].[ParentGuid]), [tv].[DistGuid], [tv].[TemplateGuid], SUM([ActVisitsInRoute]), SUM([ActVisitsOutRoute]), @Level 
				FROM  
					#TotalTemplatesVisits AS [tv] 
					INNER JOIN #DistsList	  AS [dl] ON [dl].[Guid] = [tv].[DistGuid] 
					LEFT  JOIN Distributor000 AS [ds] ON [ds].[Guid] = [dl].[Guid] 
					LEFT  JOIN DistHi000	  AS [hi] ON [hi].[Guid] = [dl].[Guid] 
				WHERE  
					[tv].[Level] = @Level + 1 
				GROUP BY [DistGuid], [TemplateGuid], [ds].[HierarchyGuid], [hi].[ParentGuid] 
			END 
		END 
		--- Total TemplateVisits 
		UPDATE #CustTotalVisits 
			SET [TemplateActVisitsInRoute]  = [tv].[ActVisitsInRoute], 
				[TemplateActVisitsOutRoute] = [tv].[ActVisitsOutRoute] 
		FROM #CustTotalVisits AS [cv]  
			INNER JOIN #TotalTemplatesVisits AS [tv] ON [tv].[DistGuid] = [cv].[DistGuid] AND [tv].[CustGuid] = [cv].[CustGuid] AND [tv].[TemplateGuid] = 0x00 
	END		-- IF @ShowCustCoverage <> 2	-- DONT SHOW ONLY CUST OUT COVERAGE 
	------------------------------------------------------------------------------------ 

	--------  Get UnSales Reason 
	CREATE TABLE #UnSales( 
		[DistGUID]		UNIQUEIDENTIFIER, 
		[CustGUID]		UNIQUEIDENTIFIER, 
		[ObjectGUID]	UNIQUEIDENTIFIER, 
		[ObjectCount]	INT, 
		[Level]			INT 
	) 
	BEGIN 
		SELECT @Level = MAX(Level) + 1 FROM #DistsList 
		--- UnSalesReason For Custs 
		INSERT INTO #UnSales([DistGuid], [CustGuid], [ObjectGuid], [ObjectCount], [Level]) 
		SELECT	     
			[DistGuid], [CustGuid], vd.[ObjectGuid], CASE @GroupVisit WHEN 1 THEN COUNT(DISTINCT [VisitDate]) ELSE COUNT([VisitState]) END, @Level 
		FROM  
			#CustVisits AS cv
		INNER JOIN DistVd000 AS vd ON cv.VisitGuid = vd.VistGuid
		WHERE vd.[Type] = 0 
		GROUP BY [DistGuid], [CustGuid], vd.[ObjectGuid] 

		--- UnSalesReason For Dist & DistHi 
		-- IF @ShowDistHi = 1 
		BEGIN  
			WHILE @Level <> 0 
			BEGIN 
				SET @Level = @Level - 1 
				INSERT INTO #UnSales([DistGuid], [CustGuid], [ObjectGuid], [ObjectCount], [Level]) 
				SELECT	     
					ISNULL([ds].[HierarchyGuid], [hi].[ParentGuid]), [un].[DistGuid], [ObjectGuid], SUM([ObjectCount]), @Level 
				FROM  
					#UnSales AS [un] 
					INNER JOIN #DistsList	  AS [dl] ON [dl].[Guid] = [un].[DistGuid] 
					LEFT  JOIN Distributor000 AS [ds] ON [ds].[Guid] = [dl].[Guid] 
					LEFT  JOIN DistHi000	  AS [hi] ON [hi].[Guid] = [dl].[Guid] 
				WHERE  
					[un].[Level] = @Level + 1 
				GROUP BY [DistGuid], [ObjectGuid], [ds].[HierarchyGuid], [hi].[ParentGuid] 
			END 
		END 
	END		-- IF @ShowCustCoverage = 2	-- DONT SHOW ONLY CUST OUT COVERAGE 
	-----------------------------------------------------------------------------------  
	--------- Cust Totals Sales 
	CREATE TABLE #CustSales( 
		HiGuid		UNIQUEIDENTIFIER, 
		DistGuid	UNIQUEIDENTIFIER, 
		CustGuid	UNIQUEIDENTIFIER, 
		SalesTotal	FLOAT, 
		MatsCount	INT, 
		BillsCount	INT, 
		Type		INT,	-- 1 DistHi	-- 2 Dists	-- 3 Custs  
		Level		INT 
	) 

	IF (@ShowCustSales = 1) 
	BEGIN 
		IF (ISNULL(@CurGuid, 0x00) = 0x00) 
			SELECT @CurGuid = Guid FROM My000 WHERE Number = 1  
		------- TotalSales For Custs 
		SELECT @Level = MAX(Level) + 1 FROM #DistsList 

		SELECT ds.HIGuid, cv.DistGuid, ds.CostGuid, cv.CustGuid, 
				COUNT(bu.biMatPtr) AS MatsCount,	 
				COUNT(bu.buGuid) AS BillsCount,	 
				SUM( ([FixedBuTotal] + [FixedBuTotalExtra] - [FixedBuTotalDisc]) * (btDirection*-1) ) AS SalesTotal,
				3 AS Type,		     
				@Level AS Level
		INTO #MatCustDist
		FROM #CustVisits AS cv  
			INNER JOIN #Dists AS ds ON ds.DistGuid = cv.DistGuid
			INNER JOIN [dbo].[fnExtended_bi_Fixed](@CurGuid) AS bu ON bu.buCustPtr = cv.CustGuid AND bu.buCostPtr = ds.CostGuid
		GROUP BY ds.HIGuid, cv.DistGuid, ds.CostGuid, cv.CustGuid, cv.VisitGuid

		;WITH cte AS (
				SELECT HIGuid, DistGuid, CostGuid, CustGuid, MatsCount, BillsCount, SalesTotal, Type, LEVEL,
						row_number() OVER(PARTITION BY HIGuid, DistGuid, CostGuid, CustGuid, MatsCount, BillsCount, SalesTotal, Type, LEVEL ORDER BY CustGuid) AS [rn]
				FROM #MatCustDist
			 )DELETE cte WHERE [rn] > 1


		INSERT INTO #CustSales( HiGuid, DistGuid, CustGuid, SalesTotal, MatsCount, BillsCount, Type, Level) 
		SELECT HiGuid, DistGuid, CustGuid, SalesTotal, MatsCount, BillsCount, Type, Level FROM #MatCustDist

		------- TotalSales For Dists 	
		SET @Level = @Level - 1  
		INSERT INTO #CustSales( HiGuid, DistGuid, CustGuid, SalesTotal, MatsCount, BillsCount, Type, Level) 
		SELECT  
			ds.HiGuid,   
			cv.DistGuid, 
			0x00, 
			0, 
			COUNT(DISTINCT CAST( bu.biMatPtr AS NVARCHAR(40))),	 
			COUNT(DISTINCT CAST( bu.buGuid AS NVARCHAR(40))),	 
			2,		     
			@Level		 
		FROM	 
			#CustVisits AS cv 
			INNER JOIN #Dists AS ds ON ds.DistGuid = cv.DistGuid 
			INNER JOIN [dbo].[fnExtended_bi_Fixed](@CurGuid) AS bu ON bu.buCostPtr = ds.CostGuid AND cv.ObjectGuid =  bu.buGuid 
		GROUP BY ds.HiGuid, cv.DistGuid 
		UPDATE #CustSales SET SalesTotal = Bill.SalesTotal 
		FROM #CustSales AS cs  
			INNER JOIN  
			( 	SELECT MCD.DistGuid, SUM(MCD.SalesTotal) AS  SalesTotal 
				FROM #MatCustDist MCD
				GROUP BY MCD.DistGuid 
			) AS bill ON bill.DistGuid = cs.DistGuid 
		WHERE Type = 2 

		------- TotalSales For DistHi 
		IF @ShowDistHi = 1  
		BEGIN 
			DECLARE @C				CURSOR, 
					@CHiGuid		UNIQUEIDENTIFIER,  
					@CHiParentGuid	UNIQUEIDENTIFIER, 
					@CHiLevel		INT 
			SET @C = CURSOR FAST_FORWARD FOR SELECT Hi.Guid, Hi.ParentGuid, dl.Level FROM DistHi000 As Hi INNER JOIN #DistsList AS dl ON dl.Guid = Hi.Guid  
			OPEN @C FETCH FROM @C INTO @CHiGuid, @CHiParentGuid, @CHiLevel 
			WHILE @@FETCH_STATUS = 0 
			BEGIN  
				INSERT INTO #CustSales( HiGuid, DistGuid, CustGuid, SalesTotal, MatsCount, BillsCount, Type, Level) 
				SELECT  
					@CHiParentGuid,   
					@CHiGuid, 
					0x00, 
					0, 
					COUNT(DISTINCT CAST( bu.biMatPtr AS NVARCHAR(40))),	 
					COUNT(DISTINCT CAST( bu.buGuid   AS NVARCHAR(40))),	 
					1,		     
					@CHiLevel		 
				FROM	 
					dbo.fnGetHierarchiesList(@CHiGuid, 0) AS FnHi 
					INNER JOIN #Dists AS ds ON ds.HiGuid = FnHi.Guid 
					INNER JOIN #CustVisits AS cv ON cv.DistGuid = ds.DistGuid 
					INNER JOIN [dbo].[fnExtended_bi_Fixed] (@CurGuid) AS bu ON bu.buCostPtr = ds.CostGuid AND cv.ObjectGuid =  bu.buGuid 
				-- GROUP BY FnHi.Guid, FnHi.Level 
				UPDATE #CustSales SET SalesTotal = Bill.SalesTotal 
				FROM #CustSales AS cs  
					INNER JOIN  
					(	SELECT @CHiParentGuid AS ParentHiGuid, @CHiGuid AS HiGuid, SUM( ([FixedBuTotal] + [FixedBuTotalExtra] - [FixedBuTotalDisc]) * (btDirection*-1) ) AS  SalesTotal 
						FROM  
							dbo.fnGetHierarchiesList(@CHiGuid, 0) AS Hi 
							INNER JOIN #Dists		AS ds ON ds.HiGuid = Hi.Guid 
							INNER JOIN #CustVisits	AS cv ON cv.DistGuid = ds.DistGuid 
							INNER JOIN [dbo].[fnbu_Fixed](@CurGuid) AS bu ON bu.buCostPtr = ds.CostGuid AND cv.ObjectGuid =  bu.buGuid 
					  -- GROUP BY Hi.Guid 
					) AS bill ON bill.HiGuid = cs.DistGuid AND bill.ParentHiGuid = cs.HiGuid 
				WHERE Type = 1 AND cs.HiGuid = @CHiParentGuid AND cs.DistGuid = @CHiGuid 
				FETCH FROM @C INTO @CHiGuid, @CHiParentGuid, @CHiLevel 
			END	 
			CLOSE @C DEALLOCATE @C 
		END		-- IF @ShowDistHi = 1  
	END			-- IF (@ShowCustSales = 1) 
	-----------------------------------------------------------------------------------  
	--------- 
	CREATE TABLE [#Result](  
			[DistGuid]					[UNIQUEIDENTIFIER],  
			[ParentGuid]				[UNIQUEIDENTIFIER],  
			[Guid]						[UNIQUEIDENTIFIER],  
			[Code]						[NVARCHAR](255) COLLATE ARABIC_CI_AI,   
			[Name]						[NVARCHAR](255) COLLATE ARABIC_CI_AI,   
			[LatinName]					[NVARCHAR](255) COLLATE ARABIC_CI_AI,   
			[ExpectedVisits]			[INT],  
			[TotalVisits]				[INT],  
			[ActVisitsInRoute]			[INT], 
			[ActVisitsOutRoute]			[INT], 
			[TemplateActVisitsInRoute]	[INT], 
			[TemplateActVisitsOutRoute]	[INT], 
			[UnActVisitsInRoute]		[INT], 
			[UnActVisitsOutRoute]		[INT], 
			[Path]						[NVARCHAR](2000) COLLATE ARABIC_CI_AI,  
			[Level]						[INT],  
			[Flag]						[INT],	-- Flag = 1 Custs Related To Dist --- Flag = 2  Custs Dont Related To Dists 
			[Type]						[INT],	-- 1 DistHi	-- 2 Dists	-- 3 Custs  
			SalesTotal					FLOAT, 
			MatsCount					INT, 
			BillsCount					INT 
		)  
	--------- Custs Informations 
	INSERT INTO #Result( 
			[DistGuid],  
			[ParentGuid],  
			[Guid],  
			[Code],   
			[Name],   
			[LatinName],   
			[ExpectedVisits],  
			[TotalVisits],  
			[ActVisitsInRoute], 
			[ActVisitsOutRoute], 
			[TemplateActVisitsInRoute], 
			[TemplateActVisitsOutRoute], 
			[UnActVisitsInRoute], 
			[UnActVisitsOutRoute], 
			[Path],  
			[Level],  
			[Flag], 
			[Type],						-- 3 Custs  
			SalesTotal, 
			MatsCount, 
			BillsCount 
	) 
	SELECT  
		[dl].[Guid], -- d.HiGuid, 
		[tv].[DistGuid], 
		[cu].[Guid], 
		[ac].[Code], 
		[cu].[CustomerName], 
		[cu].[LatinName], 
		[tv].[ExpectedVisits], 
		[tv].[TotalVisits], 
		[tv].[ActVisitsInRoute], 
		[tv].[ActVisitsOutRoute], 
		[tv].[TemplateActVisitsInRoute],	 
		[tv].[TemplateActVisitsOutRoute],	 
		[tv].[UnActVisitsInRoute], 
		[tv].[UnActVisitsOutRoute], 
		[dl].[Path] + '0.9999',		-- Path 
		0,							-- Level 
		[tv].[Flag],				-- Flag 
		3,							-- Type = 3 : Custs 
		ISNULL(cs.SalesTotal, 0), 
		ISNULL(cs.MatsCount, 0), 
		ISNULL(cs.BillsCount, 0) 
	FROM  
		#CustTotalVisits		AS [tv] 
		INNER JOIN #DistsList	AS [dl] ON [dl].[Guid] = [tv].[DistGuid] 
		INNER JOIN cu000		AS [cu] ON [cu].[Guid] = [tv].[CustGuid]	 
		INNER JOIN Ac000		AS [ac] ON [ac].[Guid] = [cu].[AccountGuid] 
		LEFT JOIN #CustSales		AS cs	ON cs.DistGuid = tv.DistGuid AND cs.CustGuid = tv.CustGuid 
	--------- Dists Informations 
	INSERT INTO #Result( 
		[DistGuid],  
		[ParentGuid],  
		[Guid],  
		[Code],   
		[Name],   
		[LatinName],   
		[ExpectedVisits],  
		[TotalVisits],  
		[ActVisitsInRoute], 
		[ActVisitsOutRoute], 
		[TemplateActVisitsInRoute], 
		[TemplateActVisitsOutRoute], 
		[UnActVisitsInRoute], 
		[UnActVisitsOutRoute], 
		[Path],  
		[Level],  
		[Flag], 
		[Type],						-- 2 Dists  
		SalesTotal, 
		MatsCount, 
		BillsCount 
	) 
	SELECT  
		[R].[DistGuid], -- ISNULL(d.HierarchyGuid, 0x00), 
		ISNULL([d].[HierarchyGuid], 0x00),  
		ISNULL([d].[Guid], 0x00), 
		ISNULL([d].[Code], ''), 
		ISNULL([d].[Name], '<»œÊ‰ „—ﬂ“ ﬂ·›…>'), 
		ISNULL([d].[LatinName], '<No Cost>'), 
		SUM([R].[ExpectedVisits]), 
		SUM([R].[TotalVisits]), 
		SUM([R].[ActVisitsInRoute]), 
		SUM([R].[ActVisitsOutRoute]), 
		SUM([R].[TemplateActVisitsInRoute]), 
		SUM([R].[TemplateActVisitsOutRoute]), 
		SUM([R].[UnActVisitsInRoute]), 
		SUM([R].[UnActVisitsOutRoute]), 
		[dl].[Path],	-- Path 
		0,				-- Level 
		0,				-- Flag 
		2, -- CASE ISNULL([d].[GUID], 0x00) WHEN 0x00 THEN 1 ELSE 2 END,				-- Type = 2 : Dists 
		0, 0, 0 
	FROM  
		[#Result] AS [R] 
		LEFT JOIN [Distributor000]	AS [D]	ON [D].[Guid]  = [R].[DistGuid] 
		INNER JOIN [#DistsList]		AS [dl] ON [dl].[Guid] = ISNULL([R].[DistGuid], 0x00) 
	WHERE  
		[R].[Type] = 3   --- Custs Info 
	GROUP BY 
		[R].[DistGuid],	[d].[HierarchyGuid], [d].[Guid], [d].[Code], [d].[Name], [d].[LatinName], [dl].[Path]  
	IF @ShowDistHi = 1  
	BEGIN  
		SET @Level = 1  
		WHILE (@Level <> 0)  
		BEGIN  
			INSERT INTO  [#Result](  
					[DistGuid],  
					[ParentGuid],  
					[Guid],  
					[Code],   
					[Name],   
					[LatinName],   
					[ExpectedVisits],  
					[TotalVisits],  
					[ActVisitsInRoute], 
					[ActVisitsOutRoute], 
					[TemplateActVisitsInRoute], 
					[TemplateActVisitsOutRoute], 
					[UnActVisitsInRoute], 
					[UnActVisitsOutRoute], 
					[Path],  
					[Level],  
					[Flag], 
					[Type],						-- 1 DistHi 
					SalesTotal, 
					MatsCount, 
					BillsCount 
				)  
				SELECT  
					0x00,  -- [hi].[ParentGuid], 
					[hi].[ParentGuid],  
					[hi].[Guid],  
					[hi].[Code],  
					[hi].[Name],  
					[hi].[LatinName],  
					SUM([R].[ExpectedVisits]), 
					SUM([R].[TotalVisits]), 
					SUM([R].[ActVisitsInRoute]), 
					SUM([R].[ActVisitsOutRoute]), 
					SUM([R].[TemplateActVisitsInRoute]), 
					SUM([R].[TemplateActVisitsOutRoute]), 
					SUM([R].[UnActVisitsInRoute]), 
					SUM([R].[UnActVisitsOutRoute]), 
					[dl].[Path],	-- Path  
					@Level, --0,	-- Level			  
					0,				-- Flag 
					1,				-- Type = 1 : DistHi  
					0, 0, 0 
				FROM   
					[#Result] AS [R]  
					INNER JOIN [DistHi000]  AS [Hi] ON [Hi].[Guid] = [R].[ParentGuid]  
					INNER JOIN [#DistsList] AS [dl] ON [dl].[Guid] = [Hi].[Guid]  
				WHERE   
					[R].[Level] = @Level - 1 AND ([R].[Type] = 2 OR [R].[DistGuid] = 0x00)  
				GROUP BY   
					[hi].[ParentGuid], [hi].[Guid], [hi].[Code], [hi].[Name], [hi].[LatinName], [dl].[Path]  
				IF EXISTS (SELECT TOP 1 [ParentGuid] FROM [#Result] WHERE [Type] = 1 AND [Level] = @Level AND [ParentGuid] <> 0x00)  
					SET @Level = @Level + 1  
				ELSE  
					SET @Level = 0  
		END	-- While @Level <> 0  
	END		-- IF @ShowDistHi = 1  
	UPDATE #Result  
		SET SalesTotal = cs.SalesTotal, MatsCount = cs.MatsCount, BillsCount = cs.BillsCount 
	FROM #Result AS r  
		INNER JOIN #CustSales AS cs ON r.Type = cs.Type AND cs.DistGuid = r.Guid AND cs.HiGuid = r.ParentGuid  
	-----------------------------------------------------------------------------------      
	----------  Results ----------------------------------------------------------------	 
	--- Main Results 
	SELECT 
		[ParentGuid] AS DistGuid,  
		[Guid], 
		[Code], 
		[Name], 
		[LatinName], 
		[ExpectedVisits],  
		[TotalVisits],  
		[ActVisitsInRoute], 
		[ActVisitsOutRoute], 
		[TemplateActVisitsInRoute], 
		[TemplateActVisitsOutRoute], 
		[UnActVisitsInRoute], 
		[UnActVisitsOutRoute], 
		[Flag], 
		[Type], 
		SalesTotal, 
		MatsCount, 
		BillsCount							 
	FROM  
		#Result  
	WHERE  
		( [Type] = 1 AND @ShowDistHi = 1)	OR		-- Show DistHi 
		( [Type] = 2 )						OR		-- Show Dists 
		( ( [Type] = 3 AND @ShowCusts = 1 ) AND		-- Show Custs 
			(	@ShowCustCoverage = 0 OR			-- Show All Custs 
				( ([TotalVisits] <> 0 OR [ExpectedVisits] <> 0) AND @ShowCustCoverage = 1 ) OR	-- Show Custs In Coverage  (Custs Have Visits OR Have Expected Coverage) 
				( ([TotalVisits] = 0 AND [ExpectedVisits] = 0 ) AND @ShowCustCoverage = 2 )		-- Show Custs Out Coverage (Custs Dont Have Visits And Expected Coverage) 
			)    
		) 
	Order BY  
		Path, Guid 
	--- TemplateVisits 
	SELECT [Guid], [Name] FROM [#TemplatesLst] ORDER By [Guid]	 
	SELECT  
		[CustGuid],  
		[DistGuid],  
		[TemplateGuid],  
		[ActVisitsInRoute], 
		[ActVisitsOutRoute] 
	FROM #TotalTemplatesVisits 
	WHERE TemplateGuid <> 0x00	-- ONLY Get Detail TemplateVisits 
	ORDER BY  
		[DistGuid], [CustGuid], [TemplateGuid] 

	--- UnSales Reason 
	SELECT DISTINCT [dl].[Guid], [dl].[Name] FROM [DistLookup000] AS [dl]
	INNER JOIN DistVd000 AS vd ON [vd].[ObjectGuid] = [dl].[Guid]
	INNER JOIN [#CustVisits] AS [cv] ON vd.VistGuid = cv.VisitGuid
	WHERE vd.Type = 0

	SELECT [CustGuid], [DistGuid], [ObjectGuid], [ObjectCount] FROM [#UnSales] ORDER BY [DistGuid], [CustGuid], [ObjectGuid] 

	--- Visits Dates 
	IF (@ShowDates > 0) 
	BEGIN 
		IF @GroupVisit = 1 
			SELECT DISTINCT [CustGuid], [DistGuid], [VisitDate] FROM [#CustVisits] /*WHERE Flag = 1*/ ORDER BY [DistGuid], [CustGuid], [VisitDate] DESC 
		ELSE 
			SELECT [CustGuid], [DistGuid], [VisitDate] FROM [#CustVisits] /*WHERE Flag = 1*/ ORDER BY [DistGuid], [CustGuid], [VisitDate] DESC 
 	END 
	ELSE  
		SELECT TOP 0 [CustGuid], [DistGuid], [VisitDate] FROM [#CustVisits]  
	SELECT * FROM [#SecViol]     
	-----------------------------------------------------------------------------------      
/*     
EXEC dbo.prcConnections_Add2 '„œÌ—'    
EXEC  [repDistActualCoverage] '1266c80b-b312-40f7-9915-fff9d892e877', '7/7/2009 0:0:0.0', '7/7/2009 23:59:14.998', '00000000-0000-0000-0000-000000000000', '5d67f3f5-0721-43bc-92a0-f8e574e4c689', '00000000-0000-0000-0000-000000000000', 1, 0, 1, 0, 0, 'd994b932-4245-430d-8320-7e65fed3fb5e', '2c4cefe3-0505-4c55-a7c4-40dc3b6dd93f', '72ad56d3-8150-45fe-b9c3-5f5fa64f0d6c', 0, '00000000-0000-0000-0000-000000000000', 0
EXEC  [repDistActualCoverage] '7cf6b75a-7239-4c68-b3a9-6df03b224eb9', '6/18/2009 0:0:0.0', '6/23/2009 23:59:57.923', '00000000-0000-0000-0000-000000000000', '5d67f3f5-0721-43bc-92a0-f8e574e4c689', '00000000-0000-0000-0000-000000000000', 1, 0, 1, 0, 1, '180da4b6-2810-4987-9ab7-f10043bdc006', 'ec9ff3a2-af71-45cf-8eda-3ed26e15e12c', '31fd6ca0-331c-43b1-8a47-7bc6c6535c50', 0, '00000000-0000-0000-0000-000000000000', 0
*/ 
###########################################################
#END