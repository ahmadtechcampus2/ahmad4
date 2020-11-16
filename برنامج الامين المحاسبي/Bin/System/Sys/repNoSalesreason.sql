#########################################################
###### repNoSalesreason
CREATE PROCEDURE repNoSalesreason
	@StartDate	[DATETIME], 
	@EndDate	[DATETIME], 
	@HiGuid		[UNIQUEIDENTIFIER], 
	@DistGuid	[UNIQUEIDENTIFIER], 
	@GroupVisit	[INT] = 1,	-- 1  Visits In Same Date = 1 Visit     0  All Visits In Same Date <> 1 Visit 
	@BillVisit	[INT] = 0,	-- 0  Bill From Ameen IS Visit		1 Bill From Amn Is Not Visit 
	@NoSalesRes [UNIQUEIDENTIFIER] = 0x0 
AS 
	SET NOCOUNT ON 
	CREATE TABLE [#DistTble] ( [DistGuid]	[UNIQUEIDENTIFIER], [Security] 	[INT] ) 
	CREATE TABLE [#SecViol]	 ( [Type] 	[INT], 		    [Cnt] 	[INT] )  
	CREATE TABLE [#Cust] 	 ( [CustGuid]	[UNIQUEIDENTIFIER], [Security] 	[INT] ) 
	 
	INSERT INTO  [#Cust] EXEC prcGetDistGustsList @DistGuid, 0x00, 0x00, @HiGuid  
-- select * from #Cust 
	INSERT INTO [#DistTble] EXEC GetDistributionsList @DistGuid,@HiGuid 
	SELECT 	[d1].[DistGuid], [d1].[Security] AS [DistSecurity], 
		[sa].[Guid] AS [SalesManGuid], [sa].[Security] AS [SalesManSecurity], [sa].[Name] AS [SalesManName],	 
		[sa].[CostGuid] 
	INTO [#DistSales] 
	FROM [#DistTble] AS [d1]  
		INNER JOIN [vwDistributor] AS [d2] ON [d1].[DistGuid] = [d2].[Guid] 
		INNER JOIN [vwDistSalesman] AS [Sa] ON [Sa].[Guid] = [PrimSalesmanGUID] --CASE [CurrSaleMan] WHEN 1 THEN [PrimSalesmanGUID] ELSE [AssisSalesmanGUID] END 
	EXEC [prcCheckSecurity] @Result = '#DistSales' 
-- Select * From #DistSales 

	--Get the list of Visits (Active And Inactive)
	CREATE TABLE #TotalVisitsStates (VisitGuid UNIQUEIDENTIFIER, CustGuid UNIQUEIDENTIFIER, DistGuid UNIQUEIDENTIFIER, State INT, VisitDate DATETIME) -- State: 1 Active , 0 Inactive
	INSERT INTO #TotalVisitsStates EXEC prcDistGetVisitsState @StartDate, @EndDate, @HiGuid, @DistGuid, @BillVisit, 0x0

	--Create 2 tables to filter the active and the inactive visits of each of the distributors
	CREATE TABLE #TotalActiveVisits (DistGuid UNIQUEIDENTIFIER, Total INT)
	CREATE TABLE #TotalInActiveVisits (DistGuid UNIQUEIDENTIFIER, Total INT)
	IF @GroupVisit = 0
	BEGIN
		INSERT INTO #TotalActiveVisits
			SELECT DistGuid, COUNT(1) FROM #TotalVisitsStates
			WHERE State = 1
			GROUP BY DistGuid
	
		INSERT INTO #TotalInActiveVisits
			SELECT DistGuid, COUNT(0) FROM #TotalVisitsStates
			WHERE State = 0
			GROUP BY DistGuid
	END
	ELSE
	BEGIN
		INSERT INTO #TotalActiveVisits
			SELECT r.DistGuid, COUNT(1) FROM 
				(SELECT DISTINCT DistGuid, CustGuid, dbo.fnGetDateFromDT(VisitDate) AS date
				 FROM #TotalVisitsStates
				 WHERE State = 1) AS r
			GROUP BY DistGuid
	
		INSERT INTO #TotalInActiveVisits
			SELECT r.DistGuid, COUNT(0) FROM 
				(SELECT DISTINCT DistGuid, CustGuid, dbo.fnGetDateFromDT(VisitDate) AS date
				 FROM #TotalVisitsStates
				 WHERE State = 0) AS r
			GROUP BY DistGuid
	END
	CREATE TABLE #TotalDistVisits (DistGuid UNIQUEIDENTIFIER, VisitTotal INT, ActVisitTotal INT, InActVisitTotal INT) 
	INSERT INTO #TotalDistVisits
		SELECT
			Ac.DistGuid,
			0,
			Ac.Total,
			Ic.Total
		FROM #TotalActiveVisits AS Ac
		LEFT JOIN #TotalInActiveVisits AS Ic ON Ic.DistGuid = Ac.DistGuid

	UPDATE #TotalDistVisits SET VisitTotal = ActVisitTotal + InActVisitTotal
	
-------------------------------------------------------------------------------------------- 
----- Calc No Sales Reason	√”»«» ⁄œ„ «·»Ì⁄      
	CREATE TABLE [#NoSalesReason] ( [CustGuid] [UNIQUEIDENTIFIER], [DistGuid] [UNIQUEIDENTIFIER], [ObjectGuid] [UNIQUEIDENTIFIER], [Name] [NVARCHAR](200) COLLATE Arabic_CI_AI , [Count] [INT] )      
	INSERT INTO  [#NoSalesReason]      
		SELECT   
			[Cu].[Guid], [Ds].[DistGuid], [dl].[Guid], [dl].[Name], COUNT( DISTINCT CAST([dl].[Guid] AS NVARCHAR(40)))       
		FROM [vwDistTrvi] AS [tr]  
			INNER JOIN [#DistSales] 	 AS [ds] ON [ds].[DistGuid] = [TrDistributorGUID] 
			INNER JOIN [DistVd000]  	 AS [vd] ON [vd].[VistGuid] = [tr].[viGuid] 
			INNER JOIN [dbo].[DistLookup000] AS [dl] ON [dl].[Guid] = [vd].[ObjectGuid] 
			INNER JOIN [cu000]	    	 AS [cu] ON [Cu].[Guid] = [tr].[ViCustomerGuid]  
		WHERE   
			[dbo].[fnGetDateFromDT]([ViStartTime]) BETWEEN @StartDate AND @EndDate 
		        AND [dl].[Type] = 0 
		GROUP BY  
			[Cu].[Guid], [Ds].[DistGuid], [dl].[Guid], [dl].[Name], VistGuid      
------------------------------------------------------------------------------------------- 
-----------------  Results  
	SELECT  
		[SalesManGuid], 
		[SalesManName],  
		ds.[DistGuid], 
		ISNULL(InActVisitTotal, 0) AS [UnAffectiveVisitCount], -- ISNULL(VisitTotal, 0) - ISNULL(ActVisitTotal, 0) AS [UnAffectiveVisitCount], 
		ISNULL(ActVisitTotal, 0) AS [VisitEffectCount]	 
	FROM  [#DistSales] 	AS [ds]  
		INNER JOIN [#TotalDistVisits]	AS [tv] ON [tv].[DistGuid] = [ds].[DistGuid]  
	ORDER BY [SalesManName], Ds.[DistGuid] 
------------------- 
	SELECT  
		DistGuid, Name AS UnSalesReason, SUM([Count]) AS viCount 
	FROM  
		[#NoSalesReason] AS NSR 
		INNER JOIN [RepSrcs]	AS [rCT]  ON [rCT].[IdType]  = ISNULL([NSR].[ObjectGuid], 0x00) AND [rCT].[idTbl] = @NoSalesRes   
	GROUP BY  
		DistGuid, Name, ObjectGuid  
	ORDER By  
		DistGuid, ObjectGuid 
	SELECT * FROM [#SecViol] 
/* 
EXEC prcConnections_Add2 '„œÌ—' 
EXEC [repNoSalesreason] '6/30/2009', '7/1/2009', '00000000-0000-0000-0000-000000000000', '00000000-0000-0000-0000-000000000000', 1, 1
*/
######################################################### 
CREATE PROCEDURE repNoSalesreasonDet
	@StartDate	[DATETIME],  
	@EndDate	[DATETIME],  
	@HiGuid		[UNIQUEIDENTIFIER] = 0x0,  
	@DistGuid	[UNIQUEIDENTIFIER] = 0x0, 
	@NoSalesRes [UNIQUEIDENTIFIER] = 0x0 
AS 
	SET NOCOUNT ON 
	CREATE TABLE [#DistTble] ( [DistGuid]	[UNIQUEIDENTIFIER], [Security] 	[INT] ) 
	CREATE TABLE [#DistSales](  [DistGuid]	[UNIQUEIDENTIFIER], [DistSecurity] 	[INT],  
				                [SalesManGuid] [UNIQUEIDENTIFIER], [SalesManSecurity] [INT],   
								[SalesManName] [NVARCHAR](255)	COLLATE ARABIC_CI_AI) 
	INSERT INTO [#DistSales] ([DistGuid] , [DistSecurity]) EXEC GetDistributionsList @DistGuid,@HiGuid 
	
	CREATE TABLE [#Cust] 	 ( [CustGuid]	[UNIQUEIDENTIFIER], [Security] 	[INT] ) 
	INSERT INTO  [#Cust] EXEC prcGetDistGustsList @DistGuid, 0x00, 0x00, @HiGuid  
	
	UPDATE [#DistSales]  
	SET  [SalesManGuid] = [sa].[Guid], [SalesManSecurity] = [sa].[Security], [SalesManName]=[sa].[Name] 
	FROM [#DistSales] AS ds  
		INNER JOIN [vwDistributor] AS d ON [ds].[DistGuid]=[d].[Guid] 
		INNER JOIN [vwDistSalesman] AS [sa] ON [sa].[Guid]=[PrimSalesmanGUID]	   
	CREATE TABLE #Result ( 
						  Guid  [UNIQUEIDENTIFIER] ,  
						  Name [NVARCHAR](255)	COLLATE ARABIC_CI_AI, 
						  [VisitGuid]   [UNIQUEIDENTIFIER], 
						  [VisitDate]			[DATETIME], 
						  [NoSalesRes] [NVARCHAR](100) COLLATE Arabic_CI_AI DEFAULT '', 
						  [CustNotes] [NVARCHAR](100) COLLATE Arabic_CI_AI  DEFAULT '', 
						  [DistNotes] [NVARCHAR](100) COLLATE Arabic_CI_AI  DEFAULT '', 
						  [Type]      [int], -- 1 For Dist 2 For Cust 
					      [flag]	  [int], -- 1 For Dist And Cust In Rout , 2 For Cust Out Rout
						  [Path]				[NVARCHAR](1000) COLLATE ARABIC_CI_AI   
						  ) 
	INSERT INTO #Result   -- Insert Dists  
	SELECT  DISTINCT DistGuid, SalesManName, 0x0, '1-1-1980', ' ',  ' ', ' ', 1 , 1, hl.Path 
	FROM [#DistSales] AS ds INNER JOIN vwdisttrvi AS vi ON ds.DistGuid = vi.TrdistributorGuid 
		INNER JOIN DistVd000 AS vd ON vd.vistGuid = vi.viGuid 
		INNER JOIN [dbo].[fnDistGetHierarchyList](0, 1) AS hl ON ds.DistGuid = hl.Guid 
		INNER JOIN [RepSrcs] AS [rCT]  ON [rCT].[IdType]  = ISNULL([vd].[ObjectGuid], 0x00) AND [rCT].[idTbl] = @NoSalesRes   
	WHERE [dbo].[fnGetDateFromDT](vi.vistarttime) BETWEEN @StartDate AND @EndDate  
		  AND vd.Type = 0 
	INSERT INTO #Result  -- Insert Custs 
	SELECT  vi.viCustomerGuid, cu.CustomerName, vi.viguid, vi.viStartTime, lu.Name, Vd.CustNotes, Vd.DistNotes, 2, CASE ISNULL(dl.CustGuid, 0x0) WHEN 0x0 THEN 2 ELSE 1 END, hl.Path 
	FROM   vwdisttrvi AS vi  
	INNER JOIN distvd000 AS vd ON vi.ViGuid = vd.VistGuid 
	INNER JOIN distlookup000 AS lu ON vd.ObjectGuid = lu.Guid 
	INNER JOIN Cu000 AS cu ON cu.guid = vi.viCustomerGuid
	LEFT  JOIN [distdistributionlines000] AS dl ON dl.CustGuid = vi.viCustomerGuid AND dl.DistGuid = vi.TrdistributorGuid
	INNER JOIN [dbo].[fnDistGetHierarchyList](0, 1) AS hl ON vi.trDistributorGuid = hl.Guid 
	INNER JOIN [RepSrcs]	AS [rCT]  ON [rCT].[IdType]  = ISNULL([lu].[Guid], 0x00) AND [rCT].[idTbl] = @NoSalesRes   
    WHERE [dbo].[fnGetDateFromDT](vi.vistarttime) BETWEEN @StartDate AND @EndDate  
		  AND lu.type = 0   
		  AND (vi.trDistributorGuid = @DistGuid OR @DistGuid = 0x0) 
SELECT * FROM #Result 
ORDER BY path, type, VisitDate
######################################################### 
#END