################################################################################
CREATE PROCEDURE repDistCustomersVisitsList
	@DistributorGuid	UNIQUEIDENTIFIER,
	@HierarchyGuid		UNIQUEIDENTIFIER,
	@VisitDate			DATETIME
AS
	SET NOCOUNT ON
	
	DECLARE @RouteNumber INT
	SELECT @RouteNumber = dbo.fnDistGetRouteNumOfDate(@VisitDate)

	CREATE TABLE #CustRoute	(CustGuid UNIQUEIDENTIFIER, RouteTime DATETIME)
	CREATE TABLE #DistTbl	(DistGUID UNIQUEIDENTIFIER, distSecurity INT) 
	CREATE TABLE #Result
	(
		DistGuid			UNIQUEIDENTIFIER,
		CustGuid			UNIQUEIDENTIFIER,
		TradeChannelGuid	UNIQUEIDENTIFIER,
		PayType				INT, -- 1 for cash, 0 for other
		LastSaleDate		DATETIME,
		LastSaleQuantity	FLOAT,
		LastNoSaleDate		DATETIME,
		LastNoSaleReason	UNIQUEIDENTIFIER,
		BestVisitTime		DATETIME
	)
	
	INSERT INTO #DistTbl EXEC GetDistributionsList @DistributorGuid, @HierarchyGuid
	
	-------------------------------------------------------------
	DECLARE	@CurrDistGuid	UNIQUEIDENTIFIER,
			@CostGuid		UNIQUEIDENTIFIER
	
	DECLARE @C CURSOR 
	SET @C = CURSOR FAST_FORWARD FOR SELECT DistGuid FROM #DistTbl 
	OPEN @C
	FETCH NEXT FROM @C INTO @CurrDistGuid
	WHILE @@FETCH_STATUS = 0
	BEGIN
		SELECT @CostGUID = CostGUID FROM vwDistSalesMan WHERE GUID = (SELECT PrimSalesmanGuid FROM Distributor000 WHERE Guid = @CurrDistGuid)

		TRUNCATE TABLE #CustRoute
		INSERT INTO #CustRoute EXEC prcDistGetRouteOfDistributor @CurrDistGuid, @RouteNumber

		INSERT INTO #Result
		SELECT
			@CurrDistGuid,
			0x0,
			0x0,
			0,
			'1-1-1980',
			0,
			'1-1-1980',
			0x0,
			'1-1-1980'
			
		INSERT INTO #Result
		SELECT
			@CurrDistGuid,
			cu.CustGuid,
			ISNULL(ce.TradeChannelGuid, 0x0),
			ISNULL(ct.PayTypeCashOnly, 0),
			ISNULL(bubi.buDate, '1-1-1980'),
			SUM(ISNULL((bubi.biQty * bubi.buDirection * -1), 0)),
			ISNULL(vd.Date, '1-1-1980'),
			ISNULL(vd.ObjectGuid, 0x0),
			bt.Time
		FROM #CustRoute AS cu
		LEFT JOIN DistCe000 AS ce ON ce.CustomerGuid = cu.CustGuid
		LEFT JOIN DistCt000 AS ct ON ct.Guid = ce.CustomerTypeGuid
		LEFT JOIN (SELECT * FROM vwbubi WHERE buGuid IN (SELECT bu.Guid
														 FROM bu000 AS bu
														 WHERE bu.Date = (SELECT MAX(bu2.Date) FROM bu000 AS bu2 WHERE bu2.CustGuid = bu.CustGuid AND bu2.CostGuid = @CostGuid)
															AND bu.CustGuid IN (SELECT CustGuid FROM #CustRoute)
															AND bu.CostGuid = @CostGuid)) AS bubi ON bubi.buCustPtr = cu.CustGuid
		LEFT JOIN  (SELECT
						vi.CustomerGuid,
						tr.Date,
						vd.ObjectGuid
					FROM DistTr000 AS tr
					INNER JOIN DistVi000 AS vi on tr.Guid = vi.TripGuid
					INNER JOIN DistVd000 AS vd on vi.Guid = vd.VistGuid
					WHERE vd.Type = 0 AND tr.Date = (SELECT MAX(tr1.Date)
													 FROM DistTr000 AS tr1
													 INNER JOIN DistVi000 AS vi1 on tr1.Guid = vi1.TripGuid
													 INNER JOIN DistVd000 AS vd1 on vi1.Guid = vd1.VistGuid
													 WHERE vi1.CustomerGuid = vi.CustomerGuid)) AS vd ON vd.CustomerGuid = cu.CustGuid
		INNER JOIN (
					SELECT CustGuid, Route1Time AS Time FROM DistDistributionLines000 AS l1 WHERE Route1 = @RouteNumber AND DistGuid = @CurrDistGuid
					UNION ALL
					SELECT CustGuid, Route2Time AS Time FROM DistDistributionLines000 AS l2 WHERE Route2 = @RouteNumber AND DistGuid = @CurrDistGuid
					UNION ALL
					SELECT CustGuid, Route3Time AS Time FROM DistDistributionLines000 AS l3 WHERE Route3 = @RouteNumber AND DistGuid = @CurrDistGuid
					UNION ALL
					SELECT CustGuid, Route4Time AS Time FROM DistDistributionLines000 AS l4 WHERE Route4 = @RouteNumber AND DistGuid = @CurrDistGuid
					) AS bt ON bt.CustGuid = cu.CustGuid
		GROUP BY
			cu.CustGuid,
			ce.TradeChannelGuid,
			ct.PayTypeCashOnly,
			bubi.buDate,
			vd.Date,
			vd.ObjectGuid,
			bt.Time
		
		IF (SELECT COUNT(*) FROM #Result WHERE DistGuid = @CurrDistGuid) = 1
			DELETE FROM #Result WHERE DistGuid = @CurrDistGuid
			
		FETCH NEXT FROM @C INTO @CurrDistGuid
	END
	CLOSE @C
	DEALLOCATE @C	
	-------------------------------------------------------------
	-- Final Result
	SELECT
		r.DistGuid,
		d.Name		AS DistName,
		d.LatinName	AS DistLatinName,
		r.CustGuid,
		r.TradeChannelGuid,
		ISNULL(tc.Name, '')AS TradeChannelName,
		r.PayType,
		r.LastSaleDate,
		r.LastSaleQuantity,
		r.LastNoSaleDate,
		r.LastNoSaleReason AS LastNoSaleReasonGuid,
		ISNULL(dl.Name, '')AS LastNoSaleReasonName,
		r.BestVisitTime,
		cu.Number,
		cu.CustomerName,
		cu.LatinName,
		cu.Nationality,
		cu.Address,
		cu.Phone1,
		cu.Phone2,
		cu.Fax,
		cu.Telex,
		cu.Notes,
		cu.DiscRatio,
		cu.Prefix,
		cu.Suffix,
		cu.Mobile,
		cu.Pager,
		cu.Email,
		cu.HomePage,
		cu.Country,
		cu.City,
		cu.Area,
		cu.Street,
		cu.ZipCode,
		cu.POBox,
		cu.Certificate,
		cu.Job,
		cu.JobCategory,
		cu.UserFld1,
		cu.UserFld2,
		cu.UserFld3,
		cu.UserFld4,
		cu.DateOfBirth,
		cu.Gender,
		cu.Hoppies,
		cu.DefPrice,
		cu.Barcode,
		cu.GPSX,
		cu.GPSY
	FROM    
		#Result AS r
		INNER JOIN Distributor000 AS d ON r.DistGuid = d.Guid
		LEFT JOIN vexCu AS cu ON r.CustGuid = cu.Guid
		LEFT Join DistLookup000 AS dl ON r.LastNoSaleReason = dl.Guid
		LEFT JOIN DistTch000 AS tc ON r.TradeChannelGuid = tc.Guid
	ORDER BY
		r.DistGuid,
		cu.CustomerName
		
/*
EXEC repDistDailyVisitsList 'A5DF6FE1-BFF2-46E9-B89D-14C4660A777D', 0x0, '1-1-2010'
EXEC repDistDailyVisitsList 0x0, '50FF8DB5-6F53-479B-978F-0E682A7D0269', '7-7-2010'
*/
################################################################################
#END