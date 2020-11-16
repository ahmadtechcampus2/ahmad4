######################################################
CREATE PROCEDURE StockCapabilityReoprt
      @FromPeriodGuid	UNIQUEIDENTIFIER
	  ,@ToPeriodGuid	UNIQUEIDENTIFIER	= 0x0
      
AS 
	SET NOCOUNT ON
	DECLARE
		@FromDate	DATE,
		@ToDate		DATE,
		@Unit       INT
		
	SET @Unit = 1
	
	SELECT @Unit = ISNULL(CAST(value AS FLOAT), 1) FROM op000 WHERE name = 'ProductAvailabilityUnitBox'
	SELECT @FromDate = StartDate FROM Bdp000 WHERE Guid = @FromPeriodGuid
	SELECT @ToDate	 = EndDate	 FROM Bdp000 WHERE Guid = @ToPeriodGuid
	SELECT 
		Mt.Guid				MaterialGuid 
		,Mt.Name			MaterialName 
		,Gr.Guid			GroupGuid 
		,Gr.Name			GroupName  
		,Bdp.Guid			PeriodGuid  
		,Bdp.Name			PeriodName  
		,Bdp.StartDate		PeriodStartDate  
		,SUM(CASE	WHEN MPPI.MinLimit > (MPPD.FirstPeriodQty + MPPD.PlanedQty - MPPD.TargetQty) 
					THEN MPPI.MinLimit 
					ELSE (MPPD.FirstPeriodQty + MPPD.PlanedQty - MPPD.TargetQty)		 
			END / NULLIF(MaterialUnity.UnitFact, 0))
							PlanedQty  
		,1					Type  
	INTO  	 
		#Result  
	FROM   
		ProductionPlan000 PP  
		INNER JOIN MainProductionPlan000 MPP ON PP.Guid = MPP.ParentGuid  
		INNER JOIN MainProductionPlanItem000 MPPI ON MPP.Guid = MPPI.ParentGuid  
		INNER JOIN MainProductionPlanDetail000 MPPD ON MPPI.Guid = MPPD.ParentGuid  
		INNER JOIN Bdp000 Bdp ON MPPD.PeriodGuid = Bdp.Guid  
		INNER JOIN Mt000 Mt ON Mt.Guid = MPPI.MaterialGuid  
		INNER JOIN Gr000 Gr ON Gr.Guid = Mt.GroupGuid 
		INNER JOIN  
		( 
			  SELECT	Guid MaterialGuid 
						,CASE @Unit WHEN 0 THEN 1 WHEN 1 THEN Unit2Fact WHEN 2 THEN Unit3Fact WHEN 3 THEN CASE DefUnit WHEN 2 THEN Unit2Fact WHEN 3 THEN Unit3Fact Else 1 END END UnitFact 
			  FROM Mt000 
		)MaterialUnity ON MaterialUnity.MaterialGuid = Mt.Guid  
	WHERE   
		Bdp.StartDate >= @FromDate   
		AND Bdp.EndDate <= @ToDate  
	GROUP BY   
		Mt.Guid  
		,Mt.Name  
		,Gr.Guid  
		,Gr.Name  
		,Bdp.Guid  
		,Bdp.Name  
		,Bdp.StartDate 
		,MaterialUnity.UnitFact 
		
	INSERT INTO #Result  
	SELECT  
		R.MaterialGuid  
		,R.MaterialName  
		,R.GroupGuid  
		,R.GroupName  
		,0x0  
		,''  
		,DATEADD(dd, -1, @FromDate) 
		,ISNULL(FirstPeriodQtys.Stock, 0)  
		,1  
	FROM   
		#Result R  
		LEFT JOIN   
		(  
			  SELECT  
				Mt.Guid MaterialGuid  
				,SUM(ISNULL((Bi.Qty * CASE WHEN Bt.BillType IN(0, 3, 4) THEN 1 ELSE -1 END) , 0) 
				/ NULLIF(CASE @Unit WHEN 0 THEN 1 WHEN 1 THEN mt.Unit2fact WHEN 2 THEN mt.Unit3Fact WHEN 3 THEN CASE DefUnit WHEN 2 THEN Unit2Fact WHEN 3 THEN Unit3Fact Else 1 END END, 0) ) Stock  
			FROM   
				Mt000 Mt  
				INNER JOIN Bi000 Bi ON Mt.Guid = Bi.MatGuid  
				INNER JOIN Bu000 Bu ON Bu.Guid = Bi.ParentGuid AND Bu.Date < @FromDate  
				INNER JOIN Bt000 Bt ON Bt.Guid = Bu.TypeGuid  
			GROUP BY   
				Mt.Guid  
		)FirstPeriodQtys ON R.MaterialGuid = FirstPeriodQtys.MaterialGuid  
	GROUP BY R.MaterialGuid 
			,R.MaterialName 
			,R.GroupGuid 
			,R.GroupName 
			,FirstPeriodQtys.Stock 
		
	INSERT INTO #Result 
	SELECT  
		GroupGuid 
		,GroupName 
		,GroupGuid 
		,GroupName 
		,PeriodGuid 
		,PeriodName 
		,PeriodStartDate 
		,SUM(PlanedQty) 
		,0 
	FROM  
		#Result 
	GROUP BY  
		GroupGuid 
		,GroupName 
		,PeriodGuid 
		,PeriodName 
		,PeriodStartDate 
		
	INSERT INTO #Result 
	SELECT  
		  0x0 
		  ,'' 
		  ,0x0 
		  ,'ннннннн' 
		  ,PeriodGuid 
		  ,PeriodName 
		  ,PeriodStartDate 
		  ,SUM(PlanedQty) 
		  ,2 
	FROM #Result 
	WHERE  
		Type = 0 
	GROUP BY  
		PeriodGuid 
		,PeriodName 
		,PeriodStartDate 
		
	INSERT INTO #Result 
	SELECT 
		0x0 
		,'' 
		,0x0 
		,'ннннннн' 
		,PeriodGuid 
		,PeriodName 
		,PeriodStartDate
		,SUM(R.PlanedQty)
		,3 
	FROM  
		#Result R 
		LEFT JOIN 
		( 
			  SELECT  
					Gr.Guid 
					,PLG.ConversionFactor 
			  FROM ProductionLineGroup000 PLG 
			  INNER JOIN Gr000 Gr ON Gr.Guid IN (SELECT Guid FROM [dbo].[fnGetGroupsList](PLG.GroupGuid)) 
		)Groups ON Groups.Guid = R.GroupGuid 
	WHERE  
		Type = 0 
	GROUP BY  
		PeriodGuid 
		,PeriodName 
		,PeriodStartDate 
	SELECT  
		Bdp.Guid  
		,SUM(ISNULL(St.StorageCapacity, 0)) StorageCapacity  
	INTO   
		#PeriodsStoresCapacities  
	FROM   
		Bdp000 bdp
		CROSS JOIN st000 st
		INNER JOIN Distributor000 as Dist ON Dist.storeGuid = st.Guid
	WHERE 
		bdp.StartDate between @FromDate AND @ToDate
		AND bdp.EndDate between @FromDate AND @ToDate
		AND (st.IsActive = 0
		OR st.IsActive = 1 AND EXISTS(select * from bu000 AS bu where storeGuid = st.Guid AND bu.Date between bdp.StartDate AND bdp.EndDate))
	Group by  
		Bdp.Guid
	INSERT INTO   
		#PeriodsStoresCapacities  
	SELECT  
		0x0
		,SUM(ISNULL(St.StorageCapacity, 0)) StorageCapacity  
	FROM   
		Bdp000 bdp
		CROSS JOIN st000 st
		INNER JOIN Distributor000 as Dist ON Dist.storeGuid = st.Guid
	WHERE 
		Bdp.EndDate < @FromDate  
		AND (st.IsActive = 0
		OR st.IsActive = 1 AND EXISTS(select * from bu000 AS bu where storeGuid = st.Guid AND bu.Date between bdp.StartDate AND bdp.EndDate))

-- CALCULATING DISTRIBUTION CARS STOCK CAPABILITY		
	INSERT INTO #Result  
	SELECT  
		0x0  
		,''  
		,0x0  
		,'ннннннн'  
		,R.PeriodGuid  
		,R.PeriodName  
		,R.PeriodStartDate  
		,ISNULL(PSC.StorageCapacity, 0) 
		,4  
	FROM   
		#Result R  
		LEFT JOIN #PeriodsStoresCapacities PSC ON R.PeriodGuid = PSC.Guid  
	WHERE R.Type = 3 AND ISNULL(R.PeriodGuid, 0x0) <> 0x0 
	
	INSERT INTO #Result  
	SELECT  
		0x0  
		,''  
		,0x0  
		,'ннннннн'  
		,0x0  
		,''  
		,DATEADD(dd, -1, @FromDate) 
		,ISNULL(SUM(ISNULL(PSC.StorageCapacity, 0)), 0)  
		,4 
	FROM   
		#PeriodsStoresCapacities PSC  
		LEFT JOIN Bdp000 Bdp ON Bdp.Guid = PSC.Guid  
	WHERE   
		PSC.guid = 0x0
		
-- CALCULATE COMPANY STORES STOCK CAPABILITY
	DELETE FROM #PeriodsStoresCapacities 
	INSERT INTO #PeriodsStoresCapacities   
	SELECT   
		St.PeriodGuid 
		,SUM(ISNULL(St.StorageCapacity, 0))   
	FROM    
	( 
		SELECT St.Guid						StoreGuid 
				,Bdp.Guid					PeriodGuid					 
				,AVG(St.StorageCapacity)	StorageCapacity 
		FROM St000 St   
		CROSS JOIN Bdp000 Bdp 
		WHERE 
			bdp.StartDate between @FromDate AND @ToDate
			AND bdp.EndDate between @FromDate AND @ToDate
			AND (st.IsActive = 0
			OR st.IsActive = 1 AND EXISTS(select * from bu000 AS bu where storeGuid = st.Guid AND bu.Date between bdp.StartDate AND bdp.EndDate))
		GROUP BY St.Guid 
				,Bdp.Guid 
	)St 
	WHERE    
		St.StoreGuid NOT IN (SELECT StoreGuid FROM Distributor000)   
	GROUP BY    
		St.PeriodGuid 

	INSERT INTO   
		#PeriodsStoresCapacities  
	SELECT  
		0x0
		,SUM(ISNULL(St.StorageCapacity, 0)) StorageCapacity  
	FROM   
		Bdp000 bdp
		CROSS JOIN st000 st
	WHERE 
		Bdp.EndDate < @FromDate  
		AND (st.IsActive = 0
		OR st.IsActive = 1 AND EXISTS(select * from bu000 AS bu where storeGuid = st.Guid AND bu.Date between bdp.StartDate AND bdp.EndDate))
		AND st.Guid NOT IN (SELECT StoreGuid FROM Distributor000)

	
	INSERT INTO #Result 
	SELECT 
		0x0 
		,'' 
		,0x0 
		,'ннннннн' 
		,R.PeriodGuid 
		,R.PeriodName 
		,R.PeriodStartDate 
		,ISNULL(PSC.StorageCapacity, 0)
		,5 
	FROM  
		#Result R 
		LEFT JOIN #PeriodsStoresCapacities PSC ON R.PeriodGuid = PSC.Guid 
	WHERE R.Type = 4 AND ISNULL(R.PeriodGuid, 0x0) <> 0x0

	INSERT INTO #Result  
	SELECT  
		0x0  
		,''  
		,0x0  
		,'ннннннн'  
		,0x0  
		,''  
		,DATEADD(dd, -1, @FromDate) 
		,ISNULL(SUM(ISNULL(PSC.StorageCapacity, 0)), 0)  
		,5  
	FROM #PeriodsStoresCapacities PSC  
	Left JOIN Bdp000 Bdp ON Bdp.Guid = PSC.Guid  
	WHERE PSC.Guid = 0x0
		
	
	INSERT INTO #Result 
	SELECT 
		0x0 
		,'' 
		,0x0 
		,'ннннннн' 
		,PeriodGuid 
		,PeriodName 
		,PeriodStartDate 
		,ISNULL(SUM(ISNULL(PlanedQty, 0)), 0) 
		,6 
	FROM  
		#Result R 
	WHERE  
		R.Type IN (4, 5) 
	GROUP BY  
		PeriodGuid, PeriodName, PeriodStartDate 
	
	DELETE FROM #PeriodsStoresCapacities 
	
	INSERT INTO #Result 
	SELECT  
		0x0 
		,'' 
		,0x0 
		,'ннннннн' 
		,R3.PeriodGuid 
		,R3.PeriodName 
		,R3.PeriodStartDate 
		,CASE ISNULL(R5.PlanedQty, 0) WHEN 0 THEN 0 ELSE (ISNULL(R3.PlanedQty, 0) - ISNULL(R4.PlanedQty, 0)) * 100 / ISNULL(R5.PlanedQty, 0) END 
		,7 
	FROM #Result R3
	INNER JOIN #Result R4 ON R4.Type = 4 AND R3.PeriodGuid = R4.PeriodGuid 
	INNER JOIN #Result R5 ON R5.Type = 5 AND R3.PeriodGuid = R5.PeriodGuid 
	WHERE R3.Type = 3
	
	INSERT INTO #Result
	SELECT 
		0x0
		,''
		,0x0
		,''
		,PeriodGuid
		,PeriodName
		,PeriodStartDate
		,0
		,-1
	FROM #Result
	GROUP BY PeriodGuid
			,PeriodName
			,PeriodStartDate
	
	SELECT * FROM #Result WHERE Type <> 2 ORDER BY GroupName, Type, MaterialName, PeriodStartDate
######################################################
#END
