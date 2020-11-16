CREATE    PROC [repDistActualCoverage]
	@SrcGuid	[UNIQUEIDENTIFIER],
	@StartDate	[DATETIME], 
	@EndDate	[DATETIME], 
	@HiGuid		[UNIQUEIDENTIFIER], 
	@DistGuid	[UNIQUEIDENTIFIER], 
	@CustAccGuid	[UNIQUEIDENTIFIER], 
	@ShowCustCoverage	[INT] = 0, 	-- 0 All Custs   1 CustInCoverage   2 CustOutCoverage
	@CustTypes		[UNIQUEIDENTIFIER],
	@RouteCount		[INT] 
AS 
	SET NOCOUNT ON
	DECLARE @UserId UNIQUEIDENTIFIER
	SET @UserId = dbo.fnGetCurrentUserGUID()  
---------------------------------------------------------------------------------------
	CREATE TABLE [#DistTbl] ([DistGUID] [UNIQUEIDENTIFIER],[distSecurity] [INT]) 
	INSERT INTO [#DistTbl] EXEC GetDistributionsList @DistGuid , @HiGuid
---------------------------------------------------------------------------------------
	CREATE TABLE [#BillTbl] ([Type] [UNIQUEIDENTIFIER],[Security] [INT],[ReadPriceSecurity] [INT],[UnPostedSecurity] [INT]) 
	CREATE TABLE [#EntryTbl]([Type] [UNIQUEIDENTIFIER],[Security] [INT])  
	CREATE TABLE [#CostTbl] ([Guid] [UNIQUEIDENTIFIER],[Security] [INT])     
	INSERT INTO [#BillTbl] EXEC [prcGetBillsTypesList2] @SrcGuid, @UserID     
	INSERT INTO [#EntryTbl] EXEC [prcGetEntriesTypesList] @SrcGuid, @UserID     
	INSERT INTO #CostTbl 
	SELECT co.GUID, co.Security 
	FROM 
		Co000 AS co 
		INNER JOIN DistSalesMan000 AS sm ON sm.CostGUID = co.GUID 
		INNER JOIN Distributor000 AS d ON d.PrimSalesManGUID = sm.GUID 
		INNER JOIN #DistTbl AS dt ON dt.DistGUID = d.GUID 
---------------------------------------------------------------------------------------
--  Get CustomerAccounts List
	CREATE TABLE [#Cust] 	([Guid] [UNIQUEIDENTIFIER], [Security] [INT], [cuName] [NVARCHAR](255), [AccountGuid] [UNIQUEIDENTIFIER], [Route1] [INT], [Route2] [INT],[Route3] [INT], [Route4] [INT], [DistributorGUID] [uniqueidentifier], [ExpectedCoverage] [INT], [ActualCoverage] [INT], [ActVisit] [INT], [InActVisit] [INT]) 

		DECLARE @CustomersAccGUID UNIQUEIDENTIFIER 
		SELECT @CustomersAccGUID = ISNULL(CustomersAccGUID, 0x00) FROM Distributor000 WHERE GUID = @DistGUID OR  @DistGUID = 0x00
		PRINT(@CustomersAccGUID)
		IF (@CustomersAccGUID = 0x00) 
		begin 
			PRINT('111')		
			INSERT INTO [#Cust]   
			SELECT  
				cu.cuGUID, 
				cu.cuSecurity, 
				cu.cuCustomerName,
				cuAccount, 
				[Route1], [Route2], [Route3], [Route4], 
				[DistributorGUID],
				0, 0, 0, 0 
 
			FROM  
				(SELECT GUID FROM fnGetAccountsList(@CustAccGuid, 0) GROUP BY GUID) AS ce 
				INNER JOIN vwCu AS cu ON cu.cuAccount = ce.Guid				 
				INNER JOIN DistCe000 AS di ON di.CustomerGuid = cu.cuGuid
				INNER JOIN RepSrcs AS r1 ON di.CustomerTypeGuid = r1.IdType  
				INNER JOIN RepSrcs AS r2 ON di.TradeChannelGuid = r2.IdType  
				INNER JOIN #DistTbl	AS dt ON dt.DistGuid = di.DistributorGUID
			WHERE 
				r1.idTbl = @CustTypes	
				AND  r2.idTbl = @CustTypes

		end 
		else 
		begin 
			PRINT('222')		
			INSERT INTO [#Cust] 
			SELECT 
				cu.cuGUID, 
				cu.cuSecurity, 
				cu.cuCustomerName,
				cuAccount, 
				[Route1],[Route2],[Route3],[Route4], 
				di.DistGUID ,
				0, 0, 0, 0 
			FROM 
				(SELECT GUID FROM fnGetAccountsList(@CustAccGuid, 0) GROUP BY GUID) AS ce 
				INNER JOIN vwCu AS cu ON cu.cuAccount = ce.Guid				 
				INNER JOIN DistDistributionLines000 AS di ON di.CustGUID = cu.cuGUID
				INNER JOIN #DistTbl	AS dt ON dt.DistGuid = di.DistGUID
		end 

--------------------------------------------------------------------------------------
-- Calc ExpectedCoverage
	UPDATE [#Cust]
		SET ExpectedCoverage = 	  (((DateDiff(dd, @StartDate, @EndDate) + 1) / @RouteCount) * 			( (case [Route1] WHEN 0 THEN 0 ELSE 1  end) + (case [Route2] WHEN 0 THEN 0 ELSE 1  end) + (case [Route3] WHEN 0 THEN 0 ELSE 1  end) + (case [Route4] WHEN 0 THEN 0 ELSE 1  end)))
					+ (   CASE 	WHEN (((DateDiff(dd, @StartDate, @EndDate) + 1) % @RouteCount) > ( @RouteCount / 	( (case [Route1] WHEN 0 THEN 0 ELSE 1  end) + (case [Route2] WHEN 0 THEN 0 ELSE 1  end) + (case [Route3] WHEN 0 THEN 0 ELSE 1  end) + (case [Route4] WHEN 0 THEN 0 ELSE 1  end))))
								THEN	(((DateDiff(dd, @StartDate, @EndDate) + 1) % @RouteCount) / ( @RouteCount / 	( (case [Route1] WHEN 0 THEN 0 ELSE 1  end) + (case [Route2] WHEN 0 THEN 0 ELSE 1  end) + (case [Route3] WHEN 0 THEN 0 ELSE 1  end) + (case [Route4] WHEN 0 THEN 0 ELSE 1  end))))
					     		ELSE	0
						END
					  )
--------------------------------------------------------------------------------------
-- Calc ActualCoverage
	CREATE TABLE [#CustVisits] ( [cuGuid] [UNIQUEIDENTIFIER], [Number] [INT], [viDate] DATETIME, [Type] [INT] )   -- Type = 1	For Bill    - Type = 2	For Entry - Type = 3  	For Visits
	
	INSERT INTO  [#CustVisits] 
	SELECT DISTINCT bu.buCustPtr, 0, bu.buDate, 1
	FROM [vwBu] AS bu 
	INNER JOIN [#Billtbl] 	AS bt ON bt.Type = bu.buType
	INNER JOIN [#Cust] 	AS cu ON cu.Guid = bu.buCustPtr
	WHERE bu.buDate BETWEEN @StartDate AND @EndDate

	INSERT INTO  [#CustVisits] 
	SELECT DISTINCT cu.Guid, 0, ce.ceDate, 2
	FROM [#Cust]  AS cu 
	INNER JOIN [vwCeEn] AS ce ON ce.EnAccount = cu.AccountGuid
	INNER JOIN [#Entrytbl] AS et ON et.Type = ce.ceTypeGuid
	WHERE ce.ceDate BETWEEN @StartDate AND @EndDate

	INSERT INTO  [#CustVisits] 
	SELECT  DISTINCT cu.Guid, 0, CAST (FLOOR(CAST(tr.trDate as float) - 0.5) AS DATETIME), 3 --tr.trDate , 3
	FROM [vwDistTrVi] as tr 
	INNER JOIN [#DistTbl] 	AS di ON di.DistGuid = tr.TrDistributorGUID
	INNER JOIN [#Cust] 	AS cu ON cu.Guid = tr.ViCustomerGUID
	WHERE tr.trDate BETWEEN @StartDate AND @EndDate


	CREATE TABLE [#TotalCustVisits] ( [cuGuid] [UNIQUEIDENTIFIER], [VisitTotal] [INT])   -- Type = 1	For Bill    - Type = 2	For Entry - Type = 3  	For Visits
	INSERT INTO [#TotalCustVisits] 
	SELECT V.cuGuid, COUNT(v.Totals) 
	FROM
		(	SELECT cuGuid, COUNT(ViDate) AS Totals	FROM [#CustVisits]
			GROUP BY	cuGuid, ViDate	) 	AS 	V
	GROUP BY cuGuid	


	UPDATE [#Cust] 
	SET ActualCoverage = cv.VisitTotal
	FROM 
		[#Cust] AS cu 
		INNER JOIN [#TotalCustVisits] AS cv ON cv.cuGuid = cu.Guid
--------------------------------------------------------------------------------------
-----  ActVisit	
	UPDATE [#Cust]  
	SET ActVisit = d.Totals		--COUNT 
	FROM
		[#Cust] AS cu 
		INNER JOIN 
		(SELECT cuGuid, COUNT(Totals) AS Totals FROM 
			(SELECT  cuGuid, COUNT(ViDate) AS Totals	FROM [#CustVisits]
			WHERE Type <> 3
			GROUP BY	cuGuid, ViDate	
				) AS V  GROUP BY cuGuid )   AS d ON d.cuGuid = cu.Guid
--------------------------------------------------------------------------------------
----- Calc InActVisit	
	UPDATE [#Cust]  
	SET InActVisit = ActualCoverage - ActVisit 
--------------------------------------------------------------------------------------
----- Calc No Sales Reason	√”»«» ⁄œ„ «·»Ì⁄

	CREATE TABLE [#NoSalesReason] ([cuGuid] [UNIQUEIDENTIFIER], [ObjectGuid] [UNIQUEIDENTIFIER], [Name] [NVARCHAR](200), [Count] [INT])
	INSERT INTO [#NoSalesReason]
	SELECT  cu.Guid, dl.Guid, dl.Name, COUNT(dl.Name) 
	FROM	DistTr000 AS Tr
		INNER JOIN [DistVi000] 		AS vi 	ON Vi.TripGuid = Tr.Guid
		INNER JOIN [DistVd000] 	 	AS vd	ON vd.vistGuid = vi.Guid 
		INNER JOIN [DistLookup000] 	AS dl 	ON dl.Guid = vd.ObjectGuid
		INNER JOIN [#DistTbl]	 	AS ds	ON ds.DistGuid = Tr.DistributorGuid
		INNER JOIN [#Cust]	 	AS cu  	ON cu.Guid = Vi.CustomerGuid	
	WHERE vd.Type = 0
	GROUP BY cu.Guid, dl.Guid, dl.Name

--------------   Results
IF (@ShowCustCoverage = 0)	SELECT * FROM [#Cust]	ORDER BY Guid
IF (@ShowCustCoverage = 1)	SELECT * FROM [#Cust] WHERE ActualCoverage = 0	ORDER BY Guid
IF (@ShowCustCoverage = 2)	SELECT * FROM [#Cust] WHERE ActualCoverage <> 0  ORDER BY Guid

SELECT * FROM [#NoSalesReason] ORDER BY cuGuid, ObjectGuid
SELECT DISTINCT cuGuid, viDate FROM [#CustVisits] ORDER BY cuGuid, viDate DESC

-- SELECT cuGuid, VisitTotal AS VisitTotal FROM [#TotalCustVisits] 
-- select * from #CustVisits

DROP TABLE [#DistTbl]
DROP TABLE [#BillTbl]
DROP TABLE [#EntryTbl]
DROP TABLE [#CostTbl]

DROP TABLE [#Cust]
DROP TABLE [#CustVisits]
DROP TABLE [#TotalCustVisits]



/*
EXEC [repDistActualCoverage]
'A736F4A3-0F62-41C9-BE62-2410AB12D3CF',		-- @SrcGuid	[UNIQUEIDENTIFIER],
'01-01-2006', 					-- @StartDate	[DATETIME], 
'01-31-2006',					-- @EndDate	[DATETIME], 
0x00, --'81A09B21-EE56-48A3-8264-73F38F6A9697', 	-- @HiGuid		[UNIQUEIDENTIFIER], 
0x00, 						-- @DistGuid	[UNIQUEIDENTIFIER], 
'AB9321BD-DB01-49B2-B02A-131AB9FF31EC', -- 0x00,						-- @CustAccGuid	[UNIQUEIDENTIFIER], 
0,						-- @ShowCustCoverage	[INT] = 0, 	-- 0 All Custs   1 CustInCoverage   2 CustOutCoverage
'40CD72E5-9012-443D-85B8-659789E2D316', 	-- @CustTypes		[NVARCHAR](8000),
12						-- @RouteCount		[INT] 

select * from RepSrcs
select Guid, * from ac000 where code = 

*/
