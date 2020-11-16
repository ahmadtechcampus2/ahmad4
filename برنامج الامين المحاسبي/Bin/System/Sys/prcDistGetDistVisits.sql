########################################
## prcDistGetDistVisits
CREATE PROC prcDistGetDistVisits
	@DistGuid		UNIQUEIDENTIFIER,
	@StartDate		DATETIME,
	@EndDate		DATETIME,
	@StartRoute		INT,
	@EndRoute		INT
AS
	SET NOCOUNT ON
	DECLARE @CustChart INT
	SELECT @CustChart = Value FROM op000 WHERE NAme = 'DistCfg_CustChart'
	
	DECLARE @CostGuid	UNIQUEIDENTIFIER
	SELECT @CostGuid = ISNULL(S.CostGuid, 0x0)
	FROM 
		Distributor000 AS D
		INNER JOIN DistSalesMan000	AS S ON S.Guid = D.PrimSalesManGUID	
	WHERE D.Guid = @DistGuid	
----------------------------------------------------------------------
-------------  GetDistVisits	From DistVi
	CREATE TABLE #Visits
		(
			TrGuid		UNIQUEIDENTIFIER,
			TrDate		DATETIME,
			ViNumber	INT,	
			ViGuid		UNIQUEIDENTIFIER,	
			ViDate		DATETIME,
			CustGuid	UNIQUEIDENTIFIER,
			ViState		INT
		)
	INSERT INTO #Visits
		(
			TrGuid,
			TrDate,
			ViNumber,	
			ViGuid,
			ViDate,	
			CustGuid,
			ViState
		)
	SELECT 
			TrGuid,
			TrDate,
			ViNumber,
			ViGuid,
			dbo.fnGetDateFromDT(ViStartTime),
			ViCustomerGuid,
			ViState
	FROM 
		vwDistTrVi	AS tr
		INNER JOIN DistDistributionLines000 AS l ON l.CustGuid = tr.ViCustomerGuid
	WHERE 	
		Tr.TrDistributorGuid = @DistGuid	AND
		Tr.ViStartTime BETWEEN @StartDate AND @EndDate	AND
		(l.Route1 = @StartRoute OR l.Route2 = @StartRoute OR l.Route3 = @StartRoute OR l.Route4 = @StartRoute)

-- Select * FROM #Visits
---------------------------------------------
--------   GetDistCusts 
	DECLARE @S_Route	INT,
			@S_Date		DATETIME
	SET @S_Route = @StartRoute
	SET @S_Date = @StartDate	 
	CREATE TABLE #DistCustRoutes ( CustGuid	UNIQUEIDENTIFIER, Route	INT, Date DATETIME, Flag INT )  
	-- Ã·» “»«∆‰ «·Œÿ «·„Õœœ	-- Flag = 1
	WHILE (@S_Route <= @EndRoute)
	BEGIN
		INSERT INTO #DistCustRoutes ( CustGuid, Route, Date, Flag )		
			SELECT CustomerGuid, @S_Route, @S_Date, 1 FROM dbo.fnDistGetRouteOfDistributor( @DistGuid, @S_Route)
		
		SET @S_Route = @S_Route + 1
		SET @S_Date = @S_Date + 1
	END
-- Select * FROm #DistCustRoutes
	-- Ã·» «·“»«∆‰ ÷„‰ «·› —… «·„Õœœ… Ê«·€Ì—  «»⁄… ··Œÿ «·„Õœœ   -- Flag = 2
	INSERT INTO #DistCustRoutes ( CustGuid, Route, Date, Flag )		
		SELECT DISTINCT	bu.buCustPtr, ISNULL(L.Route1, -1), bu.buDate, 2
		FROM 
			vwbu	AS bu
			LEFT JOIN DistDistributionLines000 AS L ON L.CustGuid = bu.buCustPtr AND L.DistGuid = @DistGuid
			LEFT JOIN #DistCustRoutes AS cu on cu.CustGuid = bu.buCustPtr  AND cu.Date = bu.buDate
		WHERE	cu.CustGuid IS NULL			AND
				bu.buCostPtr = @CostGuid	AND  bu.buCostPtr <> 0x0	AND
				bu.buDate BETWEEN @StartDate AND @EndDate

	INSERT INTO #DistCustRoutes ( CustGuid, Route, Date, Flag )		
		SELECT DISTINCT	vCu.cuGuid, ISNULL(L.Route1, -1), ce.ceDate, 2
		FROM 
			vwCeEn	AS ce
			INNER JOIN vwER_EntriesPays_PYType AS Er On Er.ErEntryGuid = Ce.CeGuid
			INNER JOIN vwCu		AS vCu ON vCu.cuAccount = Ce.enAccount
			LEFT JOIN DistDistributionLines000 AS L ON L.CustGuid = vCu.cuGuid AND L.DistGuid = @DistGuid
			LEFT JOIN #DistCustRoutes AS cu on cu.CustGuid = vCu.cuGuid AND cu.Date = ce.ceDate
		WHERE	cu.CustGuid IS NULL			AND
				ce.enCostPoint = @CostGuid	AND	ce.enCostPoint <> 0x0	AND
				ce.ceDate BETWEEN @StartDate AND @EndDate
	-- Ã·» «·“»«∆‰ «· Ì ·Â« “Ì«—«  Ê«·€Ì—  «»⁄… ·Œÿ «·„Õœœ  - Flag = 2
	INSERT INTO #DistCustRoutes ( CustGuid, Route, Date, Flag )		
		SELECT DISTINCT	vi.CustGuid, ISNULL(L.Route1, -1), vi.viDate, 2
		FROM 
			#Visits AS vi
			LEFT JOIN DistDistributionLines000 AS L ON L.CustGuid = vi.CustGuid AND L.DistGuid = @DistGuid
			LEFT JOIN #DistCustRoutes AS cu on cu.CustGuid = vi.CustGuid AND cu.Date = vi.viDate
		WHERE	cu.CustGuid IS NULL			AND
				vi.viDate BETWEEN @StartDate AND @EndDate

	----------------------------
	CREATE TABLE [#SecViol]	( [Type] 	[INT], 		    [Cnt]	[INT] )     
	CREATE TABLE #Cust 
		( 
			CustGuid 		UNIQUEIDENTIFIER, 
			CustName  		NVARCHAR(255) COLLATE ARABIC_CI_AI,
			CustLatinName  	NVARCHAR(255) COLLATE ARABIC_CI_AI,
			Area 			NVARCHAR(255) COLLATE ARABIC_CI_AI,
			Street			NVARCHAR(255) COLLATE ARABIC_CI_AI,
			CTName			NVARCHAR(255) COLLATE ARABIC_CI_AI,
			CTLatinName		NVARCHAR(255) COLLATE ARABIC_CI_AI,
			TChName			NVARCHAR(255) COLLATE ARABIC_CI_AI,
			TChLatinName	NVARCHAR(255) COLLATE ARABIC_CI_AI,
			Security		INT,
			Route			INT,
			Date			DATETIME,
			Flag			INT,	-- Flag = 1 “»Ê‰ ÷„‰ „Ã«· «·Œÿ «·„Õœœ    -- Flag = 2 “»Ê‰ Œ«—Ã „Ã«· «·Œÿ «·„Õœœ
			buNumber		INT,
			buTotal			FLOAT,
			ceNumber		INT,
			ceTotal			FLOAT,
			State			INT
		)	

	INSERT INTO #Cust
		(
			CustGuid, 
			CustName,
			CustLatinName,
			Area,
			Street,
			CTName,
			CTLatinName,
			TChName,
			TChLatinName,
			Security,
			Route,
			Date,
			Flag,
			buNumber,
			buTotal,
			ceNumber,
			ceTotal,
			State
		)
	SELECT 
			Cu.CuGuid,
			Cu.CuCustomerName,
			Cu.CuLatinName,
			(CASE @CustChart WHEN 0 THEN Cu.CuArea 		ELSE ISNULL(Gac.Name, '') END ) AS [cuArea], 
			(CASE @CustChart WHEN 0 THEN Cu.CuStreet 	ELSE ISNULL(Pac.Name, '') END ) AS [cuStreet],  
			ISNULL(Ce.CtName, ''),	
			ISNULL(Ce.CtLatinName, ''),
			ISNULL(Ce.TChName, ''),
			ISNULL(Ce.TChLatinName, ''),		
			Cu.CuSecurity,
			Cr.Route,
			Cr.Date,
			Cr.Flag,
			0,
			0,
			0,	
			0,
			0			
	FROM	
		vwCu	AS Cu
		INNER JOIN #DistCustRoutes	AS Cr ON Cr.CustGuid = Cu.CuGuid
		LEFT JOIN vwDistCe 	AS Ce  ON Ce.CuGuid = Cu.CuGuid
		LEFT JOIN ac000  	AS ac  ON ac.Guid = Cu.CuAccount AND @CustChart <> 0
		LEFT JOIN ac000		AS Pac ON Pac.Guid = ac.ParentGuid AND @CustChart <> 0
		LEFT JOIN ac000 	AS Gac ON Gac.Guid = Pac.ParentGuid	AND @CustChart <> 0

	EXEC [prcCheckSecurity] @Result = '#Cust'
----------------------------------------------------------------------
	--- CREATE TABLE CustBills (CustGuid UNIQUEIDENTIFIER, buDate DATETIME, Totals FLOAT, Numbers NVARCHAR(100))
	UPDATE Cu 
		SET		buNumber = bu.buNumber ,
				buTotal = bu.buTotal,
				State = CASE Cu.Flag WHEN 2 THEN 2											-- 2 “Ì«—… ›⁄«·… „‰ Œ«—Ã «·Œÿ
									 ELSE (CASE bu.buDate WHEN Cu.Date THEN 1 ELSE 2 END )	-- 1  “Ì«—… ›⁄«·… „‰ «·Œÿ    
						END	
																		
	FROM 
		#Cust	AS Cu
		INNER JOIN vwbu AS bu ON Cu.CustGuid = bu.buCustPtr AND Cu.Date = bu.buDate
	WHERE	bu.buDirection = -1	AND
			bu.buDate BETWEEN @StartDate AND @EndDate

	UPDATE Cu 
		SET		ceNumber = ce.ceNumber ,
				ceTotal = ce.enCredit,	
				State = CASE Cu.Flag WHEN 2 THEN 2											-- 2 “Ì«—… ›⁄«·… „‰ Œ«—Ã «·Œÿ
									 ELSE (CASE ce.ceDate WHEN Cu.Date THEN 1 ELSE 2 END )	-- 1  “Ì«—… ›⁄«·… „‰ «·Œÿ    
						END	
	FROM 
		#Cust	AS Cu
		INNER JOIN vwCu		AS vCu ON vCu.cuGuid = Cu.CustGuid
		INNER JOIN vwCeEn	AS Ce ON vCu.cuAccount = Ce.enAccount AND Cu.Date = Ce.CeDate
		INNER JOIN vwER_EntriesPays_PYType AS Er On Er.ErEntryGuid = Ce.CeGuid
	WHERE 
		ce.enCostPoint = @CostGuid	AND
		Ce.CeDate BETWEEN @StartDate AND @EndDate 	
-- SELECT * From #Cust

----------------------------------------------------------------------
-------------  GetUnSales
	CREATE TABLE #UnSales
		(
			VisitGuid		UNIQUEIDENTIFIER,
			UnSalesGuid		UNIQUEIDENTIFIER,
			UnSalesNumber	INT,
			UnSalesName		NVARCHAR(255) COLLATE ARABIC_CI_AI
		)
	INSERT INTO #UnSales
		(
			VisitGuid,	
			UnSalesGuid,
			UnSalesNumber,
			UnSalesName
		)
	SELECT	
		Vi.ViGuid,
		L.Guid,
		L.Number,
		L.Name
	FROM
		DistVd000 AS Vd
		INNER JOIN #Visits AS Vi ON Vi.ViGuid = Vd.VistGuid
		INNER JOIN DistLookup000 AS L ON L.Guid = Vd.ObjectGuid
	--WHERE 
	--	Vd.Type = 0

-- Select * from #UnSales	
	SELECT	DISTINCT
			ISNULL(TrGuid, 0x0)	AS TripGuid ,
			ISNULL(ViGuid, 0x0)	AS VisitGuid,
			ISNULL(TrDate, '01-01-1980') AS TripDate,
			ISNULL(ViDate, '01-01-1980') AS VisitDate,
			-- ISNULL(ViState, Cu.State)	AS VisitState,
			VisitState = CASE Cu.State	WHEN 0 THEN CASE ISNULL(U.VisitGuid, 0x0) WHEN 0x0 THEN 0 ELSE 2+cu.Flag END	-- Flag = 3 “Ì«—… €Ì— ›⁄«·… „‰ «·Œÿ   -- Flag = 4 “Ì«—… €Ì— ›⁄«·… „‰ Œ«—Ã «·Œÿ
										ELSE Cu.State																	-- Flag = 1 “Ì«—… ›⁄«·… „‰ «·Œÿ		-- Flag = 2 “Ì«—… ›⁄«·… „‰ Œ«—Ã «·Œÿ
						 END,																							-- Flag = 0 »œÊ‰ “ŸÌ«—… „‰ «·Œÿ
 			Route,
			Date,
			Cu.CustGuid, 
			CustName,
			CustLatinName,
			Area,
			Street,
			CTName,
			CTLatinName,
			TChName,
			TChLatinName,
			buNumber,
			buTotal,
			ceNumber,
			ceTotal
	FROM 
		#Cust	AS Cu		
		LEFT JOIN #Visits	AS V ON Cu.CustGuid = V.CustGuid AND Cu.Date = V.ViDate
		LEFT JOIN #UnSales	AS U ON U.VisitGuid = V.ViGuid
	ORDER BY Date, Route, Area, Street 

	Select * from #UnSales	ORDER BY VisitGUID, UnSalesNumber

	DROP TABLE #DistCustRoutes 
	DROP TABLE #SecViol
	DROP TABLE #Cust
	DROP TABLE #Visits
	DROP TABLE #UnSales

/*
EXEC prcDistGetDistVisits 'A7CAF171-CB49-4D17-9D95-06BDDBBDD23B' , '9-17-2006', '9-17-2006', 1, 1
Select * From Distributor000
*/

#############################
#END
