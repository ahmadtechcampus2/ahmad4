########################################
## repDistActivities
CREATE PROC repDistActivities
	@StartDate			[DATETIME],       
	@EndDate			[DATETIME],       
	@HiGuid				[UNIQUEIDENTIFIER],       
	@DistGuid			[UNIQUEIDENTIFIER],       
	@CustAccGuid		[UNIQUEIDENTIFIER],       
	@CustsCT			[UNIQUEIDENTIFIER],      
	@CustsTCH			[UNIQUEIDENTIFIER],      
	@Activities			[UNIQUEIDENTIFIER],
	@ShowDistHi			[BIT] = 0,  
	@GroupOption		[INT],	-- 1 Detail Result,		2 Group Result By Cust,		3 Group Result By Date,		4 Group Result By Visit
	@VisitOption		[INT]		/*	Visit Option Used When @GroupOption = 1 || 4 (Detail Result OR Group Result By Visit)
										1 Show Visits Have Activities, 2 Show Visits Have not Activities, 3 All Visits			*/
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
		LEFT JOIN  [DistDistributionLines000] 	AS [Dl] ON [dl].[CustGUID]  = [cu].[GUID]     
		LEFT JOIN  [#Dists]		AS [D]	  ON [D].[DistGuid] = [dl].[DistGuid] 
		LEFT JOIN  [DistCe000] 	AS [Dc]   ON [Dc].[CustomerGuid] = [cu].[Guid]    
		INNER JOIN [RepSrcs]	AS [rCT]  ON [rCT].[IdType]  = ISNULL([Dc].[CustomerTypeGuid], 0x00) AND [rCT].[idTbl] = @CustsCT 
		INNER JOIN [RepSrcs]	AS [rTCH] ON [rTCH].[IdType] = ISNULL([Dc].[TradeChannelGuid], 0x00) AND [rTCH].[idTbl] = @CustsTCH 

	---------------------------------------------------------------------
	------ Activities List
	CREATE TABLE #ActivitiesLst([GUID]	[UNIQUEIDENTIFIER], [Name]	[NVARCHAR](100) )
	INSERT INTO #ActivitiesLst([Guid], [Name]) 
		SELECT [l].[Guid], [l].[Name] From [DistLookup000] AS [L] INNER JOIN [RepSrcs] AS [r] ON [r].[IdType] = [l].[Guid] AND [r].[idTbl] = @Activities
	---------------------------------------------------------------------
	------ 
	CREATE TABLE [#CustVisits] ( 
		[VisitGuid]		[UNIQUEIDENTIFIER], -- DEFAULT (newID()),  
		[CustGuid]		[UNIQUEIDENTIFIER],  
		[DistGuid]		[UNIQUEIDENTIFIER],  
		[ActivityGuid]	[UNIQUEIDENTIFIER],  
		[DistNotes]		[NVARCHAR](100), 
		[CustNotes]		[NVARCHAR](100), 
		[VisitDate]		[DATETIME],			 
		[VisitState]	[INT],		-- State = 1 Visit In Route  , State = 2 Visit Out Route 
		[Flag]			[INT]		-- Flag = 1     if this Cust related to this Dist  - Flag = 2 if this Cust not related to this Dist		  
	)   	 
	------- DETAIL RESULTS
	------- Visits Have Activities
	INSERT INTO  [#CustVisits]( [VisitGuid], [CustGuid], [DistGuid], [ActivityGuid], [DistNotes], [CustNotes], 
								[VisitDate], [VisitState], [Flag] )       
	SELECT -- DISTINCT -- Distinct // For Dublicate Values In DistVd000  
		[tr].[ViGuid],  
		[cu].[CustGuid], -- [CC].[Guid],  
		[tr].[TrDistributorGUID], -- [di].[DistGuid],  
		[vd].[ObjectGuid], 
		[vd].[DistNotes],
		[vd].[CustNotes],
		[dbo].[fnGetDateFromDT]([tr].[ViStartTime]),  
		[dbo].[fnDistGetCustVisitState]([tr].[TrDistributorGUID], [cu].[CustGuid], [dbo].[fnGetDateFromDT]([tr].[ViStartTime])),  
		[cu].[Flag] -- CASE ISNULL([Cu].[CustGuid], 0x00) WHEN 0x00 THEN 2 ELSE 1 END -- [cu].[Flag] 
	FROM [vwDistTrVi] AS [tr]       
		INNER JOIN [DistVd000]	AS [vd] ON [vd].[VistGuid] = [tr].[viGuid] AND [vd].[Type] = 1 /*Activities*/ 
		INNER JOIN [#ActivitiesLst] AS [al] ON [al].[Guid] = [vd].[ObjectGuid]
		INNER JOIN [#Dists] 	AS [di] ON [di].[DistGuid] = [tr].[TrDistributorGUID]      
		INNER JOIN  [#Cust] 		AS [cu] ON [Cu].[CustGuid] = [tr].[ViCustomerGUID]  AND [Cu].[DistGuid] = [Di].[DistGuid]    
		-- LEFT JOIN  [#Cust] 		AS [cu] ON [Cu].[CustGuid] = [tr].[ViCustomerGUID]  AND [Cu].[DistGuid] = [Di].[DistGuid]    
		-- INNER JOIN [cu000]		AS [cc] ON [cc].[Guid] = [tr].[ViCustomerGUID] 
	WHERE  
		[dbo].[fnGetDateFromDT]([tr].[ViStartTime]) BETWEEN @StartDate AND @EndDate     
-- Select * from [#CustVisits]

	-- Show Visits Have not Activities	
	IF (@VisitOption = 2 OR @VisitOption = 3 ) -- AND (@GroupOption = 1 OR @GroupOption = 4)
	BEGIN
		INSERT INTO  [#CustVisits]( 
			[VisitGuid],	 
			[CustGuid],	 
			[DistGuid],	 
			[ActivityGuid],	 
			[DistNotes], 	
			[CustNotes], 	
			[VisitDate],	 
			[VisitState], 
			[Flag]
		)       
		SELECT -- DISTINCT -- Distinct // For Dublicate Values In DistVd000  
			[tr].[ViGuid],  
			[cu].[CustGuid], -- [CC].[Guid],  
			[tr].[TrDistributorGUID], -- [di].[DistGuid],  
			0x00, 
			'',
			'',
			[dbo].[fnGetDateFromDT]([tr].[ViStartTime]),  
			[dbo].[fnDistGetCustVisitState]([tr].[TrDistributorGUID], [cu].[CustGuid], [dbo].[fnGetDateFromDT]([tr].[ViStartTime])),  
			[cu].[Flag] -- CASE ISNULL([Cu].[CustGuid], 0x00) WHEN 0x00 THEN 2 ELSE 1 END -- [cu].[Flag] 
		FROM [vwDistTrVi] AS [tr]       
			LEFT JOIN  [DistVd000]	AS [vd] ON [vd].[VistGuid] = [tr].[viGuid] AND [vd].[Type] = 1 /*Activities*/ 
			INNER JOIN [#Dists] 	AS [di] ON [di].[DistGuid] = [tr].[TrDistributorGUID]      
			INNER JOIN [#Cust] 		AS [cu] ON [Cu].[CustGuid] = [tr].[ViCustomerGUID]  AND [Cu].[DistGuid] = [Di].[DistGuid]    
			-- LEFT JOIN  [#Cust] 		AS [cu] ON [Cu].[CustGuid] = [tr].[ViCustomerGUID]  AND [Cu].[DistGuid] = [Di].[DistGuid]    
			-- INNER JOIN [Cu000]		AS [cc]	ON [cc].[Guid]	   = [tr].[ViCustomerGUID] 
		WHERE  
			[dbo].[fnGetDateFromDT]([tr].[ViStartTime]) BETWEEN @StartDate AND @EndDate     
			AND ISNULL([vd].[VistGuid], 0x00) = 0x00
	END

-- Select * From #CustVisits	
	---- Totals For Dist & DistHi	
	DECLARE @Level AS INT 
	SELECT @Level = MAX(Level) + 1 FROM #DistsList 
	CREATE TABLE  #TotalVisits( 
		[DistGUID]		[UNIQUEIDENTIFIER], 
		[CustGUID]		[UNIQUEIDENTIFIER], 
		[ActivityGUID]	[UNIQUEIDENTIFIER], 
		[ActivityCount]	[INT], 
		[Level]			[INT],
		[Type]			[INT] -- 1 DistHi	-- 2 Dists	-- 3 Custs  
	) 
	-- Total Vists For Cust
	INSERT INTO #TotalVisits( [DistGuid], [CustGuid], [ActivityGuid], [ActivityCount], [Level], [Type])
	SELECT 
		[DistGuid],
		[CustGuid],
		[ActivityGuid],
		COUNT(CAST([ActivityGuid] AS NVARCHAR(100))),
		@Level,
		3	-- Custs
	FROM #CustVisits
	GROUP BY 
		[DistGuid], [CustGuid], [ActivityGuid]
		
	-- IF @ShowDistHi = 1 
	BEGIN  
		WHILE @Level <> 0 
		BEGIN 
			SET @Level = @Level - 1 
			INSERT INTO #TotalVisits([DistGuid], [CustGuid], [ActivityGuid], [ActivityCount], [Level], [Type]) 
				SELECT	     
					ISNULL([ds].[HierarchyGuid], [hi].[ParentGuid]), [tv].[DistGuid], [tv].[ActivityGuid], SUM([ActivityCount]), 
					@Level, CASE ISNULL([ds].[Guid], 0x00) WHEN 0x00 THEN 1 ELSE 2 END
				FROM  
					#TotalVisits AS [tv] 
					INNER JOIN #DistsList	  AS [dl] ON [dl].[Guid] = [tv].[DistGuid] 
					LEFT  JOIN Distributor000 AS [ds] ON [ds].[Guid] = [dl].[Guid] 
					LEFT  JOIN DistHi000	  AS [hi] ON [hi].[Guid] = [dl].[Guid] 
				WHERE  
					[tv].[Level] = @Level + 1 
				GROUP BY [DistGuid], [ds].[HierarchyGuid], [hi].[ParentGuid], [tv].[ActivityGuid], [ds].[Guid] 
		END 
	END 

-- Select * from #TotalVisits ORDER BY Level
	CREATE TABLE #Result(
			[VisitGuid]			[UNIQUEIDENTIFIER] DEFAULT (0x00),   
			[ParentGuid]		[UNIQUEIDENTIFIER],  
			[Guid]				[UNIQUEIDENTIFIER],  
			[Code]				[NVARCHAR](255)	COLLATE ARABIC_CI_AI,   
			[Name]				[NVARCHAR](255)	COLLATE ARABIC_CI_AI,   
			[LatinName]			[NVARCHAR](255)	COLLATE ARABIC_CI_AI,   
			[VisitDate]			[DATETIME],
			[VisitState]		[INT],
			[Path]				[NVARCHAR](1000) COLLATE ARABIC_CI_AI,  
			[Flag]				[INT],	-- Flag = 1 Custs Related To Dist --- Flag = 2  Custs Dont Related To Dists 
			[Type]				[INT]	-- 1 DistHi	-- 2 Dists	-- 3 Custs  
	)
	CREATE TABLE #ResultDetail(
			[ParentGuid]		[UNIQUEIDENTIFIER],  
			[Guid]				[UNIQUEIDENTIFIER],  
			[ActivityDate]		[DATETIME],
			[ActivityGuid]		[UNIQUEIDENTIFIER],  
			[ActivityCount]		[INT],
			[DistNotes]			[NVARCHAR](100)	COLLATE ARABIC_CI_AI, 
			[CustNotes]			[NVARCHAR](100)	COLLATE ARABIC_CI_AI,
			[Path]				[NVARCHAR](1000) COLLATE ARABIC_CI_AI  
	)
	--====================================================================
	-- Results For Dists & DistHi
	--====================================================================
	INSERT INTO #Result( [ParentGuid], [Guid], [Code], [Name], [LatinName], [VisitDate], [VisitState], [Path], [Flag], [Type] )
	SELECT DISTINCT
		[tv].[DistGuid],
		[tv].[CustGuid],
		ISNULL([ds].[Code], [Hi].[Code]),
		ISNULL([ds].[Name], [Hi].[Name]),
		ISNULL([ds].[LatinName], [Hi].[LatinName]),
		'01-01-1980',
		0,
		[dl].[Path],
		0,
		[tv].[Type]
	FROM 	
		[#TotalVisits]	AS [tv]
		INNER JOIN [#DistsList]		AS [dl] ON [dl].[Guid] = [tv].[CustGuid]
		LEFT JOIN [Distributor000]	AS [ds] ON [ds].[Guid] = [tv].[CustGuid]
		LEFT JOIN [DistHi000]		AS [Hi] ON [Hi].[Guid] = [tv].[CustGuid]
	WHERE 
		([tv].[Type] = 1 AND @ShowDistHi = 1) OR [tv].[Type] = 2
	INSERT INTO #ResultDetail( [ParentGuid], [Guid], [ActivityDate], [ActivityGuid], [ActivityCount], [DistNotes], [CustNotes], [Path])
	SELECT 
		[r].[ParentGuid],
		[r].[Guid],
		[r].[VisitDate],	
		[tv].[ActivityGuid],
		[tv].[ActivityCount],
		'', '',
		[r].[Path]
	FROM 
		[#Result] AS [r]
		INNER JOIN [#TotalVisits] AS [tv] ON [tv].[DistGuid] = [r].[ParentGuid] AND [tv].[CustGuid] = [r].[Guid]
	--====================================================================
	-- Results For Custs
	--====================================================================
	-- Detail Results || Group Result By Visit
	IF (@GroupOption = 1 OR @GroupOption = 4) 
	BEGIN
		INSERT INTO #Result( [VisitGuid], [ParentGuid], [Guid], [Code], [Name], [LatinName], [VisitDate], [VisitState], [Path], [Flag], [Type] )
		SELECT  DISTINCT
			[cv].[VisitGuid],
			[cv].[DistGuid],
			[cv].[CustGuid],
			[ac].[Code],
			[cu].[CustomerName],
			[cu].[LatinName],
			[cv].[VisitDate],	
			[cv].[VisitState],
			[dl].[Path] + '0.9999',
			[cv].[Flag],
			3
		FROM 	
			[#CustVisits]	AS [cv]
			INNER JOIN [#DistsList]		AS [dl] ON [dl].[Guid] = [cv].[DistGuid]
			INNER JOIN [Cu000]			AS [cu] ON [cu].[Guid] = [cv].[CustGuid]
			INNER JOIN [Ac000]			AS [ac] ON [ac].[Guid] = [cu].[AccountGuid]
		WHERE 
			(@VisitOption = 1 AND cv.ActivityGuid <> 0x00)	OR	-- Visits Have Activities
			(@VisitOption = 2 AND cv.ActivityGuid = 0x00)	OR	-- Visits Have NOT Activities
			(@VisitOption = 3)									-- ALL Visits
		IF (@VisitOption <> 2)		
		BEGIN
			INSERT INTO #ResultDetail([ParentGuid], [Guid], [ActivityDate], [ActivityGuid], [ActivityCount], [DistNotes], [CustNotes], [Path])
			SELECT 
				[r].[ParentGuid],
				[r].[Guid],
				[r].[VisitDate],
				[cv].[ActivityGuid],
				1,
				[cv].[DistNotes], 
				[cv].[CustNotes],
				[r].[Path]
			FROM 
				#Result AS r
				INNER JOIN #CustVisits AS cv ON cv.VisitGuid = r.VisitGuid -- cv.DistGuid = r.ParentGuid AND cv.CustGuid = r.Guid
			WHERE 
				r.Type = 3 -- Custs Results
		END
	END
	--- Group Result By Cust
	IF @GroupOption = 2
	BEGIN
		INSERT INTO #Result( [ParentGuid], [Guid], [Code], [Name], [LatinName], [VisitDate], [VisitState], [Path], [Flag], [Type] )
		SELECT -- DISTINCT
			[cv].[DistGuid],
			[cv].[CustGuid],
			[ac].[Code],
			[cu].[CustomerName],
			[cu].[LatinName],
			'01-01-1980',	
			0,
			[dl].[Path] + '0.9999',
			0, --[cv].[Flag],
			3
		FROM 	
			[#CustVisits]	AS [cv]
			INNER JOIN [#DistsList]		AS [dl] ON [dl].[Guid] = [cv].[DistGuid]
			INNER JOIN [Cu000]			AS [cu] ON [cu].[Guid] = [cv].[CustGuid]
			INNER JOIN [Ac000]			AS [ac] ON [ac].[Guid] = [cu].[AccountGuid]
		GROUP BY 
			cv.DistGuid, cv.CustGuid, ac.Code, cu.CustomerName, cu.LatinName, dl.Path

		INSERT INTO #ResultDetail(ParentGuid, Guid, ActivityDate, ActivityGuid, ActivityCount, DistNotes, CustNotes, Path)
		SELECT 
			r.ParentGuid,
			r.Guid,
			'01-01-1980',
			cv.ActivityGuid,
			COUNT ( CAST (cv.ActivityGuid AS NVARCHAR(100)) ),
			'', '',
			r.Path 
		FROM 
			#Result AS r
			INNER JOIN #CustVisits AS cv ON cv.DistGuid = r.ParentGuid AND cv.CustGuid = r.Guid
		WHERE 
			r.Type = 3 -- Custs Results
		GROUP BY
			r.ParentGuid, r.Guid, cv.ActivityGuid, r.Path
	END
	--- Group Result By Date
	IF @GroupOption = 3
	BEGIN
		INSERT INTO #Result( [ParentGuid], [Guid], [Code], [Name], [LatinName], [VisitDate], [VisitState], [Path], [Flag], [Type] )
		SELECT -- DISTINCT
			[cv].[DistGuid],
			0x00,
			'',
			'',
			'',
			cv.VisitDate,	
			0, -- cv.VisitState
			[dl].[Path] + '0.9999',
			0, -- [cv].[Flag],
			3
		FROM 	
			[#CustVisits]	AS [cv]
			INNER JOIN [#DistsList]		AS [dl] ON [dl].[Guid] = [cv].[DistGuid]
		GROUP BY cv.DistGuid, cv.VisitDate, dl.Path 

		INSERT INTO #ResultDetail(ParentGuid, Guid, ActivityDate, ActivityGuid, ActivityCount, DistNotes, CustNotes, Path)
		SELECT 
			r.ParentGuid,
			0x00,
			r.VisitDate,
			cv.ActivityGuid,
			COUNT ( CAST(cv.ActivityGuid AS NVARCHAR(100)) ),
			'', '',
			r.Path 
		FROM 
			#Result AS r
			INNER JOIN #CustVisits AS cv ON cv.DistGuid = r.ParentGuid AND cv.VisitDate = r.VisitDate
		WHERE 
			r.Type = 3 -- Custs Results
		GROUP BY
			r.ParentGuid, r.VisitDate, cv.ActivityGuid, r.Path
	END
	-----------------------------------------------------------------------------------      
	----------  Results ---------------------------------------------------------------
	--- Main Results 
	SELECT 
		ParentGuid,	Guid, Code, Name, LatinName, VisitDate, VisitState, Path, Flag, Type
	FROM 
		[#Result] 
	WHERE 
		(@ShowDistHi = 1 AND Type = 1) OR Type = 2 OR Type = 3 
	ORDER BY 
		[Path], VisitDate, Guid
	--- Detail Result
	SELECT
		ParentGuid, Guid, ActivityDate, ActivityGuid, ActivityCount, DistNotes, CustNotes 
	FROM 
		#ResultDetail
	ORDER BY 
		Path, ActivityDate, Guid
	--- Activities List
	SELECT [Guid] AS ActivityGuid , [Name] AS ActivityName FROM [#ActivitiesLst] 
	-----------------------------------------------------------------------------------      

/*
EXEC [repDistActivities] '6/1/2008  0:0:0:0', '7/10/2008  0:0:0:0', '00000000-0000-0000-0000-000000000000', 'be916cf7-47ba-4a1a-80f2-1294f211cc5e', '00000000-0000-0000-0000-000000000000', '7f06f382-2984-4436-9ce2-2467dc9d5ae2', '46609719-1734-4ce2-8a56-ce75b3121bec', '90dd6cff-55df-4169-a2f0-bed0d664b405', 0, 1, 1 
*/
########################################
#END