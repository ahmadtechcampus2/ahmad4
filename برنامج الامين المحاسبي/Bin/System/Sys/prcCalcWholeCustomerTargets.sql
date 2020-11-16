######################################
CREATE PROCEDURE prcCalcWholeCustomerTargets
	@PeriodGuid		UNIQUEIDENTIFIER,
	@DistGuid		UNIQUEIDENTIFIER,
	@CustTypes		NVARCHAR(max),
	@PricePolicy	INT,
	@PriceType		INT,
	@CurGuid		UNIQUEIDENTIFIER,
	@CurVal 		FLOAT,
	@UseUnit		INT,
	@BranchGuid		UNIQUEIDENTIFIER
AS

	SET NOCOUNT ON	
	CREATE TABLE #CustTypes( [TypeGuid] [UNIQUEIDENTIFIER])
	INSERT INTO [#CustTypes] SELECT CAST( [Data] AS UNIQUEIDENTIFIER) FROM [fnTextToRows]( @CustTypes)

	CREATE TABLE #BillsDateRange(StartDate DATETIME, EndDate DATETIME)
	CREATE TABLE #CustSales(CustGuid UNIQUEIDENTIFIER, Sales FLOAT, DistSales FLOAT)

	DECLARE @EPDate DATETIME
	SELECT @EPDate = GETDATE()

	CREATE TABLE #CustTarget 
		( 	
			CustGUID 		UNIQUEIDENTIFIER, 
			cuCustomerName 	NVARCHAR(250) COLLATE ARABIC_CI_AI, 
			Target 			float, 
			BranchGUID 		UNIQUEIDENTIFIER,
			BranchName 		NVARCHAR(250) COLLATE ARABIC_CI_AI, 
			CustDistRatio	FLOAT
		)

	INSERT INTO #CustSales
	SELECT
		CustGuid,
		0,
		0
	FROM distdistributionlines000
	WHERE DistGuid = @DistGuid

	DECLARE @PeriodsMask BIGINT
	SELECT TOP 1 @PeriodsMask = PeriodsMask FROM disgeneraltarget000
								WHERE BranchGuid = @BranchGuid AND PeriodGuid = @PeriodGuid

	IF(@PeriodsMask = 0)
	BEGIN
		INSERT INTO #BillsDateRange
		(
			StartDate,
			EndDate
		)
		SELECT TOP 1
			StartDate,
			EndDate
		FROM disgeneraltarget000 AS gt
		WHERE PeriodGuid = @PeriodGuid AND BranchGuid = @BranchGuid
	END
	ELSE
	BEGIN
		INSERT INTO #BillsDateRange
		(
			StartDate,
			EndDate
		)
		SELECT
			p.StartDate,
			p.EndDate
		FROM bdp000 AS p
		INNER JOIN (SELECT TOP 1 * FROM disgeneraltarget000) AS gt ON gt.PeriodsMask & dbo.fnPowerOf2(p.Number - 1) <> 0
		WHERE gt.PeriodGuid = @PeriodGuid AND gt.BranchGuid = @BranchGuid
	END

	DECLARE @C CURSOR,
			@StartDate DATETIME,
			@EndDate DATETIME,
			@DistSales FLOAT

	SET @DistSales = 0

	SET @C = CURSOR FOR SELECT StartDate, EndDate FROM #BillsDateRange
	OPEN @C
	FETCH @C INTO @StartDate, @EndDate
	WHILE @@fetch_status = 0
	BEGIN
		UPDATE #CustSales
			SET DistSales = @DistSales + ISNULL(s.Sales, 0)
		FROM #CustSales AS cs
		INNER JOIN (SELECT bu.CustGuid, SUM(bu.Total) AS Sales FROM bu000 AS bu
										INNER JOIN distsalesman000 AS sm ON bu.CostGuid = sm.CostGuid
										INNER JOIN distributor000 AS d ON sm.Guid = d.PrimSalesmanGuid
										INNER JOIN #CustSales AS cs ON cs.CustGuid = bu.CustGuid
										WHERE d.Guid = @DistGuid
											AND bu.Date BETWEEN @StartDate AND @EndDate AND bu.Branch = @BranchGuid
										GROUP BY bu.CustGuid) AS s ON cs.CustGuid = s.CustGuid

		UPDATE #CustSales
			SET Sales = cs.Sales + ISNULL(s.Sales, 0)
		FROM #CustSales AS cs
		INNER JOIN (SELECT CustGuid, SUM(bu.Total) AS Sales FROM bu000 AS bu
										WHERE bu.Date BETWEEN @StartDate AND @EndDate AND bu.Branch = @BranchGuid
										GROUP BY CustGuid) AS s ON cs.CustGuid = s.CustGuid

		FETCH @C INTO @StartDate, @EndDate
	END
	CLOSE @C
	DEALLOCATE @C
	CREATE TABLE #CustCnt(CustGuid UNIQUEIDENTIFIER, CustCnt INT)
	INSERT INTO #CustCnt
	SELECT
		CustGuid,
		COUNT(1)
	FROM distdistributionlines000 AS dl
	GROUP BY CustGuid
	CREATE TABLE #CustPercent(CustGuid UNIQUEIDENTIFIER, CustPercent FLOAT)
	INSERT INTO #CustPercent
	SELECT
		CustGuid,
		CASE SALES WHEN 0 THEN -1 ELSE DistSales / Sales END
	FROM #CustSales

/*
	INSERT INTO #CustTarget
	SELECT	DISTINCT
		[cu].[cuGUID],
		[cu].[cuCustomerName],
		0,
		0x0	
	FROM
		[DistCe000] AS [ce]
		INNER JOIN [#CustTypes] 		AS [ct] ON [ct].[TypeGuid] = [ce].[CustomerTypeGuid]
		INNER JOIN [vwCu] 			AS [Cu] ON [cu].[CuGuid] = [ce].[CustomerGuid]
		INNER JOIN [DistDistributionLines000] 	AS [Dl] ON [Dl].[CustGuid] = [ce].[CustomerGuid]
	WHERE
		([ce].[State] = 0)	AND
		([Dl].[DistGuid] = @DistGuid OR @DistGuid = 0x0)
	ORDER BY [cu].[cuCustomerName]

	UPDATE [#CustTarget]
	SET
		[Target] = [r].[Target],
		[BranchGuid] = [r].[BranchGUID]
	FROM
		[#CustTarget] AS [cu],
		(
			SELECT
					[cm].[CustGuid],
					[cm].[BranchGUID],
					SUM ([cm].[ExpectedCustTarget] * [m].[mtPrice]) AS [Target]
			FROM
				[vbDistCustMatTarget] AS [cm] 
				INNER JOIN [dbo].[fnGetMtPricesWithSec] (@PriceType, @PricePolicy, @UseUnit, @CurGuid, @EPDate) AS m ON [m].[mtGuid] = [cm].[MatGuid] AND [cm].[PeriodGuid] = @PeriodGuid
			GROUP BY
				[cm].[CustGuid],
				[cm].[BranchGuid]
		) AS [r]
	WHERE
		[r].[CustGuid] = [cu].[CustGUID]
		
	SELECT 
			ct.*,
			br.Name	AS BranchName 
	FROM 
		[#CustTarget] AS ct
		INNER JOIN br000 AS br ON br.Guid = ct.BranchGUID
*/

	DECLARE @BranchMask	BIGINT,
			@brEnabled	INT

	SET @brEnabled = [dbo].[fnOption_get]('EnableBranches', '1')  
	SELECT @BranchMask = brBranchMask FROM vwbr WHERE brGuid = @BranchGuid  
	INSERT INTO #CustTarget 
		(
			CustGuid,
			cuCustomerName,
			Target,
			BranchGUID,
			BranchName,
			CustDistRatio
		)
	SELECT
		cu.cuGuid,
		cu.cuCustomerName,
		CASE cp.CustPercent WHEN -1 THEN SUM([cm].[ExpectedCustTarget] * [m].[mtPrice]) / cc.CustCnt
									ELSE CASE cp.CustPercent WHEN 0 THEN 0 ELSE SUM([cm].[ExpectedCustTarget] * [m].[mtPrice]) / cp.CustPercent END
							END AS [Target],
		cm.BranchGUID,
		ISNULL(br.Name, ''),
		CASE cp.CustPercent WHEN -1 THEN 1.0 / cc.CustCnt ELSE cp.CustPercent END
	FROM
		vbDistCustMatTarget	AS cm
		INNER JOIN [dbo].[fnGetMtPricesWithSec] (@PriceType, @PricePolicy, @UseUnit, @CurGuid, @EPDate) AS m ON [m].[mtGuid] = [cm].[MatGuid] AND [cm].[PeriodGuid] = @PeriodGuid
		INNER JOIN DistCe000 AS Ce ON Ce.CustomerGuid = cm.CustGuid
		INNER JOIN #CustTypes AS ct ON Ce.CustomerTypeGuid = ct.TypeGuid
		INNER JOIN vwCu	AS cu	ON cu.cuGUID = ce.CustomerGUID
		INNER JOIN #CustPercent AS cp ON cp.CustGuid = cm.CustGuid
		INNER JOIN #CustCnt AS cc ON cc.CustGuid = cm.CustGuid
		INNER JOIN [DistDistributionLines000] 	AS [Dl] ON [Dl].[CustGuid] = [ce].[CustomerGuid]
		INNER JOIN Distributor000 AS d ON d.Guid = Dl.DistGuid
		LEFT JOIN br000 AS br ON br.Guid = cm.BranchGuid
	WHERE
		([ce].[State] = 0) AND
		([Dl].[DistGuid] = @DistGuid OR @DistGuid = 0x0) AND
		((d.BranchMask & @BranchMask <> 0 AND [cm].[BranchGuid] = @BranchGuid AND @brEnabled = 1) OR (@brEnabled <> 1))
	GROUP BY
		cu.cuGuid,
		cu.cuCustomerName,
		cm.BranchGUID,
		br.Name,
		cp.CustPercent,
		cc.CustCnt
	ORDER BY 
		[cu].[cuCustomerName]

	SELECT * FROM #CustTarget 
/*
Exec prcConnections_Add2 "„œÌ—"	
EXEC [prcCalcWholeCustomerTargets] '47e64183-1b63-407c-9366-91e1e24be22b', '94aadc7b-2f84-42a2-abf3-7b9a99c9d6ab', '012621e2-db6e-489a-a9c9-335c1980c145,15f6f0bb-4277-4b1f-8811-3b984638d028,49ea02b8-4708-4928-90d5-774fec70d232,51245975-64f9-4f7e-8ff5-041160ca7f5f,68cbc157-d131-404e-8f51-1f02545068b2', 0, 128, '27392dbb-44c7-4d0d-899f-b23671c92171', 1.000000, 0
*/
####################################
#END