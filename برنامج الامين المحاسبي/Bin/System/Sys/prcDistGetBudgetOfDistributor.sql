########################################
## prcDistGetBudgetOfDistributor
CREATE PROCEDURE prcDistGetBudgetOfDistributor
		@PalmUserName NVARCHAR(250)    
AS    
	SET NOCOUNT ON    
	    
	DECLARE @DistributorGUID uniqueidentifier
	DECLARE @SalesManGUID uniqueidentifier
	DECLARE @CostGUID uniqueidentifier
	declare @CurMonthlyPeriod uniqueidentifier
	declare @StartDate datetime
	declare @EndDate datetime

	SET @CurMonthlyPeriod = 0x0

	SELECT @DistributorGUID = GUID, @SalesManGUID = PrimSalesManGUID FROM Distributor000 WHERE PalmUserName = @PalmUserName
	SELECT @CostGUID = CostGUID FROM DistSalesMan000 WHERE GUID = @SalesManGUID
	SELECT @CurMonthlyPeriod = ISNULL(CAST(Value AS uniqueidentifier), 0x0) FROM Op000 WHERE Name = 'DistCfg_Coverage_CurMonthlyPeriod'
	SELECT @StartDate = StartDate, @EndDate = EndDate FROM BDP000 WHERE GUID = @CurMonthlyPeriod

	CREATE TABLE #CustType(GUID uniqueidentifier)
	INSERT INTO #CustType 
		SELECT DISTINCT CustomerTypeGUID FROM DistCe000 AS Ce INNER JOIN DistDistributionLines000 AS li ON Ce.CustomerGuid = li.CustGuid
		WHERE DistGUID = @DistributorGUID
	INSERT INTO #CustType 
		SELECT DISTINCT TradeChannelGUID FROM DistCe000 AS Ce INNER JOIN DistDistributionLines000 AS li ON Ce.CustomerGuid = li.CustGuid
		WHERE DistGUID = @DistributorGUID

	CREATE TABLE #Prom (GUID uniqueidentifier, Budget float, Consumed float)
	INSERT INTO #Prom
	SELECT
		DISTINCT
		pr.GUID,
		pb.Qty,
		0
	FROM
		DistPromotions000 AS pr
		INNER JOIN DistPromotionsBudget000 AS pb ON pb.ParentGUID = pr.GUID
		INNER JOIN DistPromotionsCustType000 AS pct ON pct.ParentGUID = pr.GUID
		INNER JOIN #CustType AS ct ON ct.GUID = pct.CustTypeGUID
	WHERE
		pb.DistributorGUID = @DistributorGUID AND
		(pr.FDate Between @StartDate AND @EndDate OR 
		pr.LDate Between @StartDate AND @EndDate)
	
	CREATE TABLE #Consumed(GUID uniqueidentifier, Value float)
	INSERT INTO #Consumed
	SELECT
		pr.GUID,
		Sum(bi.bibillBonusQnt) AS Qty
	FROM
		vwExtended_Bi AS bi
		INNER JOIN DistPromotionsDetail000 AS pd ON pd.MatGUID = bi.biMatPtr AND pd.Type = 1
		INNER JOIN #prom AS pr ON pr.GUID = pd.ParentGUID
	GROUP BY
		pr.GUID

	INSERT INTO #Consumed
	SELECT
		pr.GUID,
		Sum(bi.biQty) AS Qty
	FROM
		vwExtended_Bi AS bi
		INNER JOIN DistPromotionsDetail000 AS pd ON pd.MatGUID = bi.biMatPtr AND pd.Type = 0
		INNER JOIN #prom AS pr ON pr.GUID = pd.ParentGUID
	WHERE
		bi.biDiscount > 0
	GROUP BY
		pr.GUID

	UPDATE #Prom SET Consumed = c.Value
	FROM
		#Prom AS p, #Consumed AS c
	WHERE
		c.GUID = p.GUID

	SELECT 
		1			AS Type,
		0			AS ObjectId,
		pr.Name		AS Name,
		Budget		AS Budget,
		Consumed	AS UsedOld,
		0			AS UsedTrip
	FROM 
		#Prom AS p
		INNER JOIN DistPromotions000 AS pr ON pr.GUID = p.GUID


#############################
#END
