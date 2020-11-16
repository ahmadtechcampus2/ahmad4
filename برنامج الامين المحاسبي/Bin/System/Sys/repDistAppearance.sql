########################################
CREATE PROC repDistAppearance
	@StartDate			[DATETIME],       
	@EndDate			[DATETIME],       
	@HiGuid				[UNIQUEIDENTIFIER],       
	@DistGuid			[UNIQUEIDENTIFIER],       
	@CustAccGuid		[UNIQUEIDENTIFIER],       
	@CustsCT			[UNIQUEIDENTIFIER],      
	@CustsTCH			[UNIQUEIDENTIFIER],      
	@Templates			[UNIQUEIDENTIFIER],
	@Companies			[UNIQUEIDENTIFIER],
	@ShowDistDetail		[BIT] = 0,  
	@ShowDistHi			[SMALLINT] = 0,	-- 0 DONT ShowDistHi , 1 Show DistHi , 2 Show DistHi Detail
	@VisitOption		[INT]			-- 1 Show Visits Have ShelfShare, 2 Show Visits Have not ShelfShare, 3 All Visits			*/
AS
	SET NOCOUNT ON
 -- Select * from #aa
	-----------------------------------------------------------------------------------  
	---------- Dists Informations ----------------------------------------------------- 
	CREATE TABLE [#Dists]( [DistGuid] 	[UNIQUEIDENTIFIER], [Security] 	 [INT], [HiGuid] [UNIQUEIDENTIFIER])  
	INSERT INTO [#Dists] ( [DistGuid], [Security]) EXEC [GetDistributionsList] @DistGuid, @HiGuid   
	UPDATE [d] SET	[HiGuid] = [HierarchyGUID]
	FROM   
		[#Dists] AS [d]
		INNER JOIN [Distributor000]	 AS [ds] ON [d].[DistGuid] = [ds].[GUID]  
	---- Dists HierarchyList  
	CREATE TABLE [#DistsList]( [Guid] [UNIQUEIDENTIFIER], [Type] [INT], [Level] [INT], [Path] [NVARCHAR](1000) COLLATE ARABIC_CI_AI)  
	INSERT INTO #DistsList( [Guid], [Type], [Level], [Path]) VALUES (0x00, 0, 0, '1.00')  
	INSERT INTO #DistsList( [Guid], [Type], [Level], [Path]) SELECT [Guid], [Type], [Level], [Path] FROM [dbo].[fnDistGetHierarchyList](0, 1) 
	-------------------------------------------------------------------------------------      
	------ Custs List For This Report --------------------------------------------------- 
	--  Get CustomerAccounts List      
	CREATE TABLE [#Customers]   ( [GUID] [UNIQUEIDENTIFIER], [Security] [INT])          
	INSERT INTO  [#Customers]	EXEC prcGetDistGustsList @DistGuid, @CustAccGuid, 0x00, @HiGuid   
	----- 
	CREATE TABLE [#Cust] 	(  
		[CustGuid] 		[UNIQUEIDENTIFIER],  
		[DistGuid] 		[UNIQUEIDENTIFIER],  
		[Security] 		[INT],  
		[Route1]		[INT],  
		[Route2]		[INT], 
		[Route3]		[INT],  
		[Route4]		[INT],  
		[Flag]			[INT]	-- Flag = 1 Custs Related To Dist --- Flag = 2  Custs Dont Related To Dist 
	)        
	INSERT INTO [#Cust]( [CustGuid], [DistGuid], [Security], [Route1], [Route2], [Route3], [Route4], [Flag] ) 
	SELECT    
		[cu].[GUID],       
		ISNULL([Dl].[DistGuid], 0x00),    
		[cu].[Security],       
		ISNULL([Dl].[Route1], 0),  
		ISNULL([Dl].[Route2], 0),  
		ISNULL([Dl].[Route3], 0),  
		ISNULL([Dl].[Route4], 0), 
		CASE ISNULL([Dl].[DistGuid], 0x00) WHEN 0x00 THEN 2	ELSE 1 END -- Flag = 1 Custs Related To Dist  
	FROM       
		[#Customers] AS Cu       
		LEFT JOIN [DistDistributionLines000] 	AS [Dl] ON [dl].[CustGUID]  = [cu].[GUID]     
		LEFT JOIN [#Dists]		AS [D]	  ON [D].[DistGuid] = [dl].[DistGuid] 
		LEFT JOIN [DistCe000] 	AS [Dc]   ON [Dc].[CustomerGuid] = [cu].[Guid]    
		INNER JOIN [RepSrcs]	AS [rCT]  ON [rCT].[IdType]  = ISNULL([Dc].[CustomerTypeGuid], 0x00) AND [rCT].[idTbl] = @CustsCT 
		INNER JOIN [RepSrcs]	AS [rTCH] ON [rTCH].[IdType] = ISNULL([Dc].[TradeChannelGuid], 0x00) AND [rTCH].[idTbl] = @CustsTCH 
	---------------------------------------------------------------------
	------ Companies List
	CREATE TABLE #CompaniesLst([GUID]	[UNIQUEIDENTIFIER], [Name]	[NVARCHAR](100) )
	INSERT INTO #CompaniesLst([Guid], [Name]) 
		SELECT [c].[Guid], [c].[Name] From [DistCompanies000] AS [c] INNER JOIN [RepSrcs] AS [r] ON [r].[IdType] = [c].[Guid] AND [r].[idTbl] = @Companies
	---------------------------------------------------------------------
	------ Templates List
	CREATE TABLE #TemplatesLst([GUID]	[UNIQUEIDENTIFIER], [Name]	[NVARCHAR](100), [GroupGUID]	[UNIQUEIDENTIFIER] )
	INSERT INTO #TemplatesLst([Guid], [Name], [GroupGuid]) 
		SELECT [t].[Guid], [t].[Name], t.GroupGuid From [DistMatTemplates000] AS [t] INNER JOIN [RepSrcs] AS [r] ON [r].[IdType] = [t].[Guid] AND [r].[idTbl] = @Templates
	---------------------------------------------------------------------
	------ Visibility 
	CREATE TABLE #Visibility(
		[VisitGUID]		[UNIQUEIDENTIFIER], 
		[DistGUID]		[UNIQUEIDENTIFIER], 
		[CustGUID]		[UNIQUEIDENTIFIER], 
		[GroupGUID]		[UNIQUEIDENTIFIER], 
		[TemplateGUID]	[UNIQUEIDENTIFIER], 
		[CompanyGUID]	[UNIQUEIDENTIFIER],   
		[VisitDate]		[DATETIME],			 
		[VisitState]	[INT],		-- State = 1 Visit In Route  , State = 2 Visit Out Route 
		[Flag]			[INT],		-- Flag = 1     if this Cust related to this Dist  - Flag = 2 if this Cust not related to this Dist		  
		[Visibility]	[INT]	
	)
	------- Visits Have ShelfShare
	IF (@VisitOption = 1 OR @VisitOption = 3)
	BEGIN
		INSERT INTO #Visibility( 
			[VisitGUID], 
			[DistGUID], 
			[CustGUID], 
			[GroupGUID], 
			[TemplateGUID], 
			[CompanyGUID], 
			[VisitDate], 
			[VisitState], 
			[Flag], 
			[Visibility] 
		)
		SELECT 
			cg.VisitGuid,
			tr.TrDistributorGUID,  -- cu.DistGuid,
			cu.CustGuid,
			tl.GroupGuid,
			tl.Guid,
			cl.Guid,
			[dbo].[fnGetDateFromDT]([tr].[ViStartTime]),  
			[dbo].[fnDistGetCustVisitState]([tr].[TrDistributorGUID], [cu].[CustGuid], [dbo].[fnGetDateFromDT]([tr].[ViStartTime])),  
			[cu].[Flag], 
			cg.Visibility		
		FROM 
			DistCg000				 AS cg
			INNER JOIN vwDistTrVi	 AS tr ON tr.viGuid = cg.VisitGuid 
			INNER JOIN #Dists        AS di ON di.DistGuid = tr.TrDistributorGUID
			INNER JOIN #Cust 		 AS cu ON Cu.CustGuid = cg.CustomerGuid AND Cu.DistGuid = Di.DistGuid    
			INNER JOIN #TemplatesLst AS tl ON tl.GroupGuid = cg.GroupGuid
			INNER JOIN #CompaniesLst AS cl ON cl.Guid = cg.CompanyGuid
		WHERE 
			[dbo].[fnGetDateFromDT]([tr].[ViStartTime]) BETWEEN @StartDate AND @EndDate     
	END
	------- Visits Have Not ShelfShare
	IF (@VisitOption = 2 OR @VisitOption = 3)
	BEGIN
		INSERT INTO #Visibility( 
			[VisitGUID], 
			[DistGUID], 
			[CustGUID], 
			[GroupGUID], 
			[TemplateGUID], 
			[CompanyGUID], 
			[VisitDate], 
			[VisitState], 
			[Flag], 
			[Visibility] 
		)
		SELECT 
			tr.viGuid,
			tr.TrDistributorGUID,  -- cu.DistGuid,
			cu.CustGuid,
			0x00,		-- GroupGuid
			0x00,		-- TemplateGuid
			0x00,		-- CompanyGuid
			[dbo].[fnGetDateFromDT]([tr].[ViStartTime]),  
			[dbo].[fnDistGetCustVisitState]([tr].[TrDistributorGUID], [cu].[CustGuid], [dbo].[fnGetDateFromDT]([tr].[ViStartTime])),  
			[cu].[Flag], 
			0		
		FROM 
			vwDistTrVi	 AS tr 
			LEFT JOIN DistCg000	 AS cg ON tr.viGuid = cg.VisitGuid 
			INNER JOIN #Dists        AS di ON di.DistGuid = tr.TrDistributorGUID
			INNER JOIN #Cust 		 AS cu ON Cu.CustGuid = tr.viCustomerGuid --AND Cu.DistGuid = Di.DistGuid    
			LEFT JOIN #TemplatesLst AS tl ON tl.GroupGuid = cg.GroupGuid
			LEFT JOIN #CompaniesLst AS cl ON cl.Guid = cg.CompanyGuid
		WHERE  
			[dbo].[fnGetDateFromDT]([tr].[ViStartTime]) BETWEEN @StartDate AND @EndDate     
			AND cg.VisitGuid IS NULL
	END	
--Select * From #Visibility
	---------------------------------------------------------------------
	------ 
	CREATE TABLE #Result(
		VisitGuid	UNIQUEIDENTIFIER,
		ParentGuid	UNIQUEIDENTIFIER,
		Guid		UNIQUEIDENTIFIER,
		Code		NVARCHAR(100) COLLATE ARABIC_CI_AI,
		Name		NVARCHAR(100) COLLATE ARABIC_CI_AI,
		LatinName	NVARCHAR(100) COLLATE ARABIC_CI_AI,
		VisitDate	DATETIME,
		VisitState	INT,
		Path		NVARCHAR(1000) COLLATE ARABIC_CI_AI,  
		Flag		INT,	-- Flag = 1 Custs Related To Dist --- Flag = 2  Custs Dont Related To Dists 
		Level		INT,
		Type		INT		-- 1 DistHi	-- 2 Dists	-- 3 Custs  
	)
	CREATE TABLE #ResultDetail(
			[VisitGuid]		[UNIQUEIDENTIFIER],  
			[ParentGuid]	[UNIQUEIDENTIFIER],  
			[Guid]			[UNIQUEIDENTIFIER],  
			[CompanyGuid]	[UNIQUEIDENTIFIER],  
			[CompanyName]	[NVARCHAR](100) COLLATE ARABIC_CI_AI,
			[TemplateGuid]	[UNIQUEIDENTIFIER],  
			[Visibility]	[INT]
	)
	---- Cust Results
	DECLARE @Level		AS INT, 
			@MaxLevel	AS INT 
	SELECT @Level = MAX(Level)+1, @MaxLevel = MAX(Level)+1 FROM #DistsList 
	INSERT INTO #Result ( VisitGuid, ParentGuid, Guid, Code, Name, LatinName, VisitDate, VisitState, Path, Flag, Level, Type )
	SELECT DISTINCT
		VisitGuid,
		DistGuid,
		CustGuid,
		ac.Code,
		ac.Name,
		ac.LatinName,
		VisitDate,
		VisitState,
		dl.Path + '0.9999',
		Flag,
		@Level,
		3		--Custs Results
	FROM 
		#Visibility	AS vs
		INNER JOIN [#DistsList]		AS [dl] ON [dl].[Guid] = [vs].[DistGuid]
		INNER JOIN [Cu000]			AS [cu] ON [cu].[Guid] = [vs].[CustGuid]
		INNER JOIN [Ac000]			AS [ac] ON [ac].[Guid] = [cu].[AccountGuid]
	-- WHERE Visibility <> 0	
	INSERT INTO #ResultDetail( VisitGuid, ParentGuid, Guid, CompanyGuid, CompanyName, TemplateGuid, Visibility)
	SELECT 
		r.VisitGuid,
		r.ParentGuid,
		r.Guid,
		vs.CompanyGuid,
		cl.Name,
		vs.TemplateGuid,
		vs.Visibility
	FROM 
		#Result AS r
		INNER JOIN #Visibility AS vs ON vs.VisitGuid = r.VisitGuid 
		INNER JOIN #CompaniesLst AS cl ON cl.Guid = vs.CompanyGuid 
	WHERE Type = 3	-- AND vs.Visibility <> 0 -- Cust Detail Results

	---- Dist & DistHi Results 
	WHILE @Level <> 0 -- AND 1 = 2
	BEGIN
		SET @Level = @Level - 1 
		INSERT INTO #Result ( VisitGuid, ParentGuid, Guid, Code, Name, LatinName, VisitDate, VisitState, Path, Flag, Level, Type )
		SELECT 
			0x00,
			ISNULL([ds].[HierarchyGuid], [hi].[ParentGuid]),
			r.ParentGuid,
			ISNULL(ds.Code, hi.Code),	
			ISNULL(ds.Name, hi.Name),	
			ISNULL(ds.LatinName, hi.LatinName),
			'01-01-1980',
			0,
			dl.Path,
			0,
			@Level,
			CASE ISNULL([ds].[Guid], 0x00) WHEN 0x00 THEN 1 ELSE 2 END
		FROM 
			#Result AS r
			INNER JOIN [#DistsList]		AS [dl] ON [dl].[Guid] = [r].[ParentGuid]
			LEFT  JOIN Distributor000   AS [ds] ON [ds].[Guid] = [dl].[Guid] 
			LEFT  JOIN DistHi000	    AS [hi] ON [hi].[Guid] = [dl].[Guid] AND @ShowDistHi <> 0
		Where r.Level = @Level + 1 
		GROUP BY [ds].[HierarchyGuid], [hi].[ParentGuid], r.ParentGuid, ds.Code, hi.Code, ds.Name, hi.Name, ds.LatinName, hi.LatinName, dl.Path, ds.Guid	
		----- Show Detail For Dist AND DistHi
		IF (@ShowDistDetail = 1 AND @Level = @MaxLevel-1) OR (@ShowDistHi > 1 AND @Level < @MaxLevel-1)
		BEGIN
			INSERT INTO #ResultDetail( VisitGuid, ParentGuid, Guid, CompanyGuid, CompanyName, TemplateGuid, Visibility)
			SELECT 
				0x00, 
				ISNULL([ds].[HierarchyGuid], [hi].[ParentGuid]),
				r.ParentGuid,
				rd.CompanyGuid,
				cl.Name,
				rd.TemplateGuid,
				SUM(rd.Visibility)
				-- r.Path
			FROM 
				#Result AS r
				INNER JOIN #ResultDetail	AS rd ON rd.Guid = r.Guid AND rd.ParentGuid = r.ParentGuid AND rd.VisitGuid = r.VisitGuid
				INNER JOIN #DistsList		AS dl ON dl.Guid = r.ParentGuid
     			INNER JOIN #CompaniesLst	AS cl ON cl.Guid = rd.CompanyGuid 
				LEFT  JOIN Distributor000   AS ds ON ds.Guid = dl.Guid 
				LEFT  JOIN DistHi000	    AS hi ON hi.Guid = dl.Guid AND @ShowDistHi <> 0
			WHERE r.Level = @Level+1
			GROUP BY ds.HierarchyGuid, hi.ParentGuid, r.ParentGuid, rd.CompanyGuid, cl.Name, rd.TemplateGuid -- , r.Path
			HAVING SUM(rd.visibility) > 0
		END -- IF @ShowDetail
	END -- WHILE
	---------------------------------------------------------------------------------------
	--------- REPORT RESULTS
	--- Main Results
	SELECT 
		VisitGuid, ParentGuid, Guid, Code, Name, LatinName, VisitDate, VisitState, Flag, Type 
	FROM 
		#Result 
	WHERE 
		(Type = 1 AND @ShowDistHi > 0) OR Type = 2 OR Type = 3
	ORDER BY 
		Path, Guid, VisitDate
	--- Detail Results
	SELECT 
		VisitGuid, ParentGuid, Guid, CompanyGuid, CompanyName, TemplateGuid, Visibility			 
	FROM 
		#ResultDetail 
	ORDER BY 
		Guid, CompanyGuid
	--- Templates List
	SELECT Guid, Name, GroupGuid FROM #TemplatesLst ORDER BY Guid
	--- Companies List
	SELECT Guid, Name FROM #CompaniesLst ORDER BY Guid
	---------------------------------------------------------------------------------------
/*
EXEC prcConnections_add2 '„œÌ—'
EXEC [repDistAppearance] '1/1/2008  0:0:0:0', '7/21/2008  0:0:0:0', '00000000-0000-0000-0000-000000000000', '00000000-0000-0000-0000-000000000000', '00000000-0000-0000-0000-000000000000', '33e462ba-9b32-4578-abfa-3fbda8ee1bd6', 'd774a849-9ec9-4ab7-a186-7b120cefa864', '4f59abfb-acba-47e1-90b6-d77e41aba508', 'f67617ab-3eb6-4c42-8e99-fe3ffca1026f', 0, 0, 2 
*/
#############################
#END