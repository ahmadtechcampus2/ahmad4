########################################
## prcDistGetCustMatOfDistributor
CREATE PROCEDURE prcDistGetCustMatOfDistributor
		@PalmUserName nvarchar(250)      
AS	
	SET NOCOUNT ON      

	DECLARE @DistributorGUID as uniqueidentifier
	DECLARE @UseShelfShare 		BIT
	DECLARE @UseStockOfCust 	BIT
	DECLARE @UseCustLastPrice 	BIT
	DECLARE @ExportAllCustDetail 	BIT

	SELECT @DistributorGUID = GUID, @UseCustLastPrice = UseCustLastPrice, @UseShelfShare = UseShelfShare, @UseStockOfCust = UseStockOfCust, @ExportAllCustDetail = ExportAllCustDetailFlag 
	FROM vwDistributor WHERE PalmUserName = @PalmUserName

	CREATE TABLE #CmTbl(  
		MatId		Int,  
		CustId		int,  
		MatIndex	int,  
		CustIndex	int,  
		Target		float,  
		Stock		float,
		LastPrice	float
	)  
	--------------------------------------------------
	CREATE TABLE #CustLastDate(CustGUID uniqueidentifier, LastVisit datetime) 
	--------------------------------------------------
	INSERT INTO #CustLastDate 
	SELECT 
		[CustomerGUID], 
		Max([Date]) 
	FROM 
		DistCm000 AS cm 
		INNER JOIN PalmGUID AS pg ON pg.GUID = cm.CustomerGUID 
		INNER JOIN PalmCustTbl AS c ON c.ID = pg.Number 
	GROUP BY 
		CustomerGUID 
	--------------------------------------------------
	INSERT INTO #CmTbl  
	SELECT  
		m.Id AS MatID,  
		c.Id AS CustID,
		MatIndex,  
		c.[Index] AS CustIndex,  
		0,  
		0,
		0
	FROM  
		PalmMatTbl AS m 
		Cross join PalmCustTbl AS c 	
	WHERE 
		(c.InRoute = 1 AND @ExportAllCustDetail = 0) OR ( @ExportAllCustDetail = 1)
	--SELECT * FROM #CmTbl
	----------------------------------------------------------------  
	CREATE TABLE #StockTbl(  
		GUID		uniqueidentifier,  
		MatGUID		uniqueidentifier,  
		CustGUID	uniqueidentifier,  
		MatId		int,  
		CustId		int,  
		Date		datetime,  
		Target		float,  
		Stock		float  
	)  
	---- Stock Of Cust --------------------------------------------
	IF (@UseStockOfCust <> 0)
	BEGIN
		INSERT INTO #StockTbl 
		SELECT  
			cm.GUID,  
			cm.MatGUID,  
			cm.CustomerGUID,  
			r.MatId,  
			r.CustId,  
			Max(Date),  
			0,  
			0  
		FROM  
			#CmTbl AS r  
			INNER JOIN PalmGUID AS pg1 ON pg1.Number = r.MatId  
			INNER JOIN PalmGUID AS pg2 ON pg2.Number = r.CustId  
			INNER JOIN DistCm000 AS cm ON cm.MatGUID = pg1.GUID AND cm.CustomerGUID = pg2.GUID  
			INNER JOIN #CustLastDate AS ld ON ld.CustGUID = cm.CustomerGUID AND cm.Date = ld.LastVisit 
		GROUP BY   
			cm.GUID,  
			cm.MatGUID,  
			cm.CustomerGUID,  
			r.MatId,  
			r.CustId  
		UPDATE #StockTbl  
		SET  
			Stock = cm.Qty + cm.Target 
		FROM  
			#StockTbl stk, DistCm000 AS cm  
		WHERE  
			stk.GUID = cm.GUID  
		UPDATE #CmTbl 
		SET  
			Stock = stk.Stock  
		FROM  
			#StockTbl stk, #CmTbl AS cm  
		WHERE  
			stk.MatId = cm.MatId AND stk.CustId = cm.CustId  
	END
	----------------------------------------------------------------  
	 
	CREATE TABLE #CgTbl(  
		GroupId		Int,  
		CustId		int,  
		GroupIndex	int,  
		CustIndex	int,  
		GroupGUID	uniqueidentifier,  
		CustomerGUID	uniqueidentifier,  
		Visibility	float  
	)  
	----------------------------------------------------------------  
	IF (@UseShelfShare <> 0)
	BEGIN
		DELETE #CustLastDate 
		INSERT INTO #CustLastDate 
		SELECT 
			[CustomerGUID], 
			Max([Date]) 
		FROM 
			DistCg000 AS cm 
			INNER JOIN PalmGUID AS pg ON pg.GUID = cm.CustomerGUID 
			INNER JOIN PalmCustTbl AS c ON c.ID = pg.Number 
		GROUP BY 
			CustomerGUID 
		INSERT INTO #CgTbl  
		SELECT  
			g.Id AS GroupID,  
			c.Id AS CustID,  
			g.[Index] AS GroupIndex,  
			c.[Index] AS CustIndex,  
			0x0,  
			0x0,  
			0  
		FROM  
			PalmGroupTbl AS g  
			Cross join PalmCustTbl AS c  
		WHERE 
			c.InRoute = 1 
		 
		UPDATE #CgTbl SET 
			GroupGUID = pg.GUID 
		FROM 
			PalmGUID AS pg, #CgTbl AS cg 
		WHERE  
			pg.Number = cg.GroupId  
		UPDATE #CgTbl SET   
			CustomerGUID = pg.GUID  
		FROM  
			PalmGUID AS pg, #CgTbl AS cg  
		WHERE  
			pg.Number = cg.CustId  
		UPDATE #CgTbl SET  
			Visibility = cg.Visibility  
		FROM  
			#CgTbl AS cgt 
			INNER JOIN DistCg000 AS cg ON cgt.GroupGUID = cg.GroupGUID AND cgt.CustomerGUID = cg.CustomerGUID 
			INNER JOIN #CustLastDate AS ld ON ld.CustGUID = cg.CustomerGUID AND cg.Date = ld.LastVisit 
	END
	---- CustLastPrice ------------------------------------------------------
	IF (@UseCustLastPrice <> 0)
	BEGIN
		CREATE TABLE #LastBill (CustGUID uniqueidentifier, MatGUID uniqueidentifier, LastDate datetime, Price float)
		INSERT INTO #LastBill
		SELECT
			bi.bucustPtr,
			bi.biMatptr,
			max(bi.buDate) AS LastDate,
			0
		FROM
			vwExtended_Bi AS bi
			INNER JOIN PalmGUID AS pg ON pg.GUID = bi.buCustPtr
			INNER JOIN PalmCustTbl AS c ON c.ID = pg.Number
			INNER JOIN PalmGUID AS pg2 ON pg2.GUID = bi.biMatPtr
			INNER JOIN PalmMatTbl AS m ON m.ID = pg2.Number
		WHERE 
			btaffectCustPrice = 1
		GROUP BY
			buCustPtr,
			biMatptr
		
		UPDATE #LastBill
		SET
			Price = biUnitPrice
		FROM
			#LastBill AS lb
			INNER JOIN vwExtended_Bi AS bi ON bi.buCustPtr = lb.CustGUID AND bi.biMatPtr = lb.MatGUID AND bi.buDate = lb.LastDate
		
		UPDATE #CmTbl SET LastPrice = Price
		FROM			
			#LastBill AS lb
			INNER JOIN PalmGUID AS pg ON pg.GUID = lb.CustGUID
			INNER JOIN PalmGUID AS pg2 ON pg2.GUID = lb.MatGUID
			INNER JOIN #CmTbl as cm ON pg.Number = cm.CustId AND pg2.Number = cm.MatId 
	END
	-- Results	----------- 
	-- 1 ------------------
	SELECT  
		cm.*  
	FROM  
		#CmTbl AS cm 
		INNER JOIN PalmMatTbl AS pm ON pm.ID = cm.MatId 
		INNER JOIN PalmGroupTbl AS pg ON pg.ID = pm.GroupID	 
	--WHERE 
	--	cm.Stock <> 0 
	ORDER BY  
		CustID ASC , pg.ParentID ASC, pm.GroupID ASC 
	-- 2 ------------------
	SELECT   
		cg.GroupId,  
		cg.CustId,  
		cg.GroupIndex,  
		cg.CustIndex,  
		cg.Visibility  
	FROM  
		#CgTbl AS cg 
		INNER JOIN PalmGroupTbl AS pg ON pg.ID = cg.GroupID 
	ORDER BY cg.CustId ASC, cg.GroupIndex ASC
/*
prcConnections_Add2 '„œÌ—'
EXEC prcDistGetCustMatOfDistributor 'Palm'
*/
#############################
#END
