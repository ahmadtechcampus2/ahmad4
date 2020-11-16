##################################################################################
CREATE PROC repDistCustStockByVisit
	@CustGUID	uniqueidentifier,
	@GroupGUID	uniqueidentifier,
	@FromDate	datetime,
	@ToDate		datetime,
	@MatCondGUID	uniqueidentifier
AS
	SET NOCOUNT ON
	SET @GroupGUID = ISNULL(@GroupGUID, 0x00)
	-------------------------------------------
	CREATE TABLE #MatTbl([MatGUID] [UNIQUEIDENTIFIER],[mtSecurity] [INT]) 
	INSERT INTO [#MatTbl]	EXEC [prcGetMatsList] 	0X0, @GroupGUID , -1, @MatCondGUID  
	-------------------------------------------
	CREATE TABLE #Visit([Date] [datetime])
	INSERT INTO #Visit
	SELECT 
		bu.[buDate] 
	FROM 
		vwBu AS bu 
	Where 
		bu.buDate Between @FromDate AND @ToDate AND
		bu.buCustPtr = @CustGUID
	GROUP BY
		bu.buDate
	-------------------------------------------
	CREATE TABLE #Result(MatGUID uniqueidentifier, [Date] datetime, Stock float, Sales float)
	INSERT INTO #Result
	SELECT
		m.MatGUID,
		v.Date,
		0,
		0
	FROM  
		#Visit AS v 
		Cross join #MatTbl AS m
	-------------------------------------------
	UPDATE #Result
	SET 
		Stock = cm.Qty
	FROM
		#Result AS r
		INNER JOIN DistCm000 AS cm ON cm.MatGUID = r.MatGUID AND r.Date = cm.Date AND cm.CustomerGUID = @CustGUID
	-------------------------------------------
	CREATE TABLE #Sales(MatGUID uniqueidentifier, [Date] datetime, Qty float )
	INSERT INTO #Sales
	SELECT
		bi.biMatPtr AS MatGUID,
		bi.buDate	AS [Date],
		sum(bi.biQty) AS SumQty
	FROM
		#Result AS r
		INNER JOIN vwExtended_bi AS bi ON bi.biMatPtr = r.MatGUID AND r.Date = bi.buDate
	WHERE
		bi.buCustPtr = @CustGUID
	Group By 
		bi.biMatPtr, 
		bi.buDate
	-------------------------------------------
	UPDATE #Result
	SET
		Sales = bi.Qty
	FROM
		#Result AS r
		INNER JOIN #Sales AS bi ON bi.MatGUID = r.MatGUID AND r.Date = bi.Date
	-------------------------------------------
	SELECT 
		r.*,
		mt.Name,
		mt.Code
	FROM 
		#Result AS r 
		INNER JOIN MT000 AS mt on mt.GUID = r.MatGUID 
		ORDER BY 
			LEN([mt].[Code]), 
			[mt].[Code], 
			[Date]
	SELECT * FROM #Visit ORDER BY [Date]
	-------------------------------------------
	DROP TABLE #Visit
	DROP TABLE #MatTbl
	DROP TABLE #Result
	DROP TABLE #Sales
#############################
#END