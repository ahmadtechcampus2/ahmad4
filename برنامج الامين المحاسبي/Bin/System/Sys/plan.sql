######################################################
CREATE FUNCTION fnGetJobOrdersAvg( 
		@MaterialGuid			UNIQUEIDENTIFIER
		,@ProductionLineGuid	UNIQUEIDENTIFIER
		,@JobOrdersCount		INT
		,@ShowJobOrderAvarageQty bit) 
	RETURNS FLOAT
AS BEGIN 

	DECLARE @result FLOAT
	SET @result = (	 
					/*SELECT CASE CASE WHEN MaxRowIndex < @JobOrdersCount THEN MaxRowIndex ELSE @JobOrdersCount END WHEN 0 THEN 0 ELSE SUM(Qty) / CASE WHEN MaxRowIndex < @JobOrdersCount THEN MaxRowIndex ELSE @JobOrdersCount END END
					FROM
					(
						SELECT SUM(Qty) Qty, MAX(RowIndex) MaxRowIndex
						FROM 
						(
							SELECT  
								ROW_NUMBER() OVER(ORDER BY Jo.StartDate DESC, Jo.Number DESC)	RowIndex 
								,SUM(Jo.PlannedProductionQty)		Qty
							   FROM JobOrder000 Jo
							   INNER JOIN Mi000 Mi ON Mi.ParentGuid = Jo.Guid
							   WHERE 
								Mi.MatGuid = @MaterialGuid
								AND Jo.ProductionLine = @ProductionLineGuid
								AND Mi.Type = 0
								-- AND ISNULL(InBillGuid, 0x0) = 0x0
							GROUP BY Jo.Number, Jo.StartDate
						)Res1
						WHERE RowIndex <= @JobOrdersCount
					)Res
					GROUP BY MaxRowIndex*/
					select  SUM(qty)  /count(*)  value from 
						(

							select  top(@JobOrdersCount)
							case @ShowJobOrderAvarageQty when 0 then ActualProductionQty  when 1 then PlannedProductionQty end as  qty
							from
								JobOrder000 Jo INNER JOIN Mi000 Mi ON Mi.ParentGuid = Jo.Guid
							where
								 Mi.Type = 0
								 and Mi.MatGuid = @MaterialGuid
								AND Jo.ProductionLine = @ProductionLineGuid
		 						order by  Jo.Number desc  ,Jo.StartDate desc 
							)	result
					 where  qty<>0
   ) 
	RETURN ISNULL(@result, 0) 
END
######################################################
CREATE PROCEDURE prcGenerateMainPlan
    @PlanDate DATETIME, 
    @FromPeriod UNIQUEIDENTIFIER, 
    @ToPeriod UNIQUEIDENTIFIER, 
    @PlGuid UNIQUEIDENTIFIER, 
    @Unit INT, 
    @PlanedQtyTolerance FLOAT, 
    @TargetQtyTolerance FLOAT, 
    @JobOrdersCount INT, 
    @QuantityAvailabilityOption INT, 
	@ParentGuid UNIQUEIDENTIFIER ,
	@ShowJobOrderAvarageQty bit
AS 

    SET NOCOUNT ON  
     
    DELETE FROM MainProductionPlanDetail000 WHERE ParentGuid IN ( SELECT Guid FROM MainProductionPlanItem000 WHERE ParentGuid IN ( SELECT Guid FROM MainProductionPlan000 WHERE ParentGuid = @ParentGuid ) ) 
     
	DELETE FROM ModifiedProductionPlanDetail000 WHERE ParentGuid IN ( SELECT Guid FROM ModifiedProductionPlanItem000 WHERE ParentGuid IN ( SELECT Guid FROM ModifiedProductionPlan000 WHERE ParentGuid = @ParentGuid ) ) 
     
    DELETE FROM MainProductionPlanItem000 WHERE ParentGuid IN ( SELECT Guid FROM MainProductionPlan000 WHERE ParentGuid = @ParentGuid ) 
	 
	DELETE FROM ModifiedProductionPlanItem000 WHERE ParentGuid IN ( SELECT Guid FROM ModifiedProductionPlan000 WHERE ParentGuid = @ParentGuid ) 
	 
	DELETE FROM MainProductionPlan000 WHERE ParentGuid = @ParentGuid 
	 
	DELETE FROM ModifiedProductionPlan000 WHERE ParentGuid = @ParentGuid 
	 
	DELETE FROM ProductionPlanApproval000 WHERE ParentGuid = @ParentGuid 
      
 -- ãæÇÏ ÇáÎØÉ  
    DECLARE @PlanMats AS TABLE (MatGuid UNIQUEIDENTIFIER, PlGuid UNIQUEIDENTIFIER) -- to be pupulated  
    --NEW  
    INSERT INTO @PlanMats  
    SELECT  
  Mt.Guid  
  ,PLG.ProductionLine  
    FROM ProductionPlanGroups000 PPG 
    INNER JOIN Mt000 Mt ON Mt.Guid IN (SELECT MtGuid FROM [dbo].[fnGetMatsOfGroups](PPG.GroupGuid))  
    INNER JOIN ProductionLineGroup000 PlG ON (PlG.GroupGuid = Mt.GroupGuid OR PlG.GroupGuid IN (SELECT Guid FROM dbo.fnGetGroupParents(Mt.GroupGuid)) ) 
    WHERE PPG.PlanGuid = @ParentGuid  
      
    INSERT INTO @PlanMats  
    SELECT  
  Mt.Guid  
  ,PlG.ProductionLine 
    FROM ProductionLineGroup000 PlG  
    INNER JOIN Mt000 Mt ON Mt.Guid IN (SELECT MtGuid FROM [dbo].[fnGetMatsOfGroups](PlG.GroupGuid))  
    WHERE PlG.ProductionLine = @PlGuid  
    OR 
		( 
		ISNULL(@PlGuid, 0x0) = 0x0 
		AND 
		(SELECT COUNT(*) FROM @PlanMats) = 0 
		) 
		 
    --NEW  
 -- ÝÊÑÇÊ ÇáÎØÉ  
  
 DECLARE @Periods AS TABLE (PeriodGuid UNIQUEIDENTIFIER, Number INT, StartDate DATETIME, EndDate DATETIME)      
    INSERT INTO @Periods  
        SELECT Guid, Number, StartDate, EndDate  
        FROM bdp000  
        WHERE StartDate >= (SELECT StartDate FROM bdp000 WHERE Guid = @FromPeriod)  
            AND EndDate <= (SELECT EndDate FROM bdp000 WHERE Guid = @ToPeriod)  
              
    DECLARE @FirstPeriodGuid UNIQUEIDENTIFIER  
    DECLARE @FirstPeriodNumber INT  
 DECLARE @FirstPeriodStartDate DATETIME  
 DECLARE @FirstPeriodEndDate DATETIME  
    SELECT TOP 1 @FirstPeriodGuid = PeriodGuid  
     ,@FirstPeriodNumber = Number   
     ,@FirstPeriodStartDate = StartDate  
     ,@FirstPeriodEndDate = EndDate  
 FROM @Periods ORDER BY Number  
   
 DECLARE @PlanCreationPeriodGuid UNIQUEIDENTIFIER  
    DECLARE @PlanCreationPeriodStartDate DATETIME  
    DECLARE @PlanCreationPeriodEndDate DATETIME  
      
    SELECT TOP 1   
  @PlanCreationPeriodGuid = Guid,   
  @PlanCreationPeriodStartDate = StartDate,   
  @PlanCreationPeriodEndDate = EndDate  
    FROM bdp000 p  
    WHERE @planDate BETWEEN p.StartDate AND p.EndDate   
      
 -- ÍÏæÏ ÇáãÇÏÉ æÇáãÎÒæä ÇáÂãä  
 DECLARE @SafeStockDays FLOAT  
 SELECT @SafeStockDays = CAST(value AS FLOAT) FROM op000 WHERE name = 'ProductAvailabilitySafeStockPeriod'  
       
 DECLARE @LastPeriodEndDate DATETIME  
 DECLARE @LastPeriodNumber INT  
   
 SELECT TOP 1 @LastPeriodNumber = Number, @LastPeriodEndDate = EndDate  
 FROM @Periods ORDER BY Number DESC  
   
 DECLARE @WorkDays INT  
 SELECT @WorkDays =   
  (DATEDIFF(day, @FirstPeriodStartDate, @LastPeriodEndDate)+1)
  -(SELECT COUNT(*) FROM DistCalendar000 WHERE date BETWEEN @FirstPeriodStartDate AND @LastPeriodEndDate)  
   
 SELECT   
  pm.MatGuid,   
  mt.low LowLimit,   
  mt.high HighLimit,   
  mt.OrderLimit,   
  s.SafeStockQty  
 INTO #MatInfo  
 FROM   
  @PlanMats pm   
  INNER JOIN mt000 mt ON mt.Guid = pm.MatGuid  
  INNER JOIN -- ÇáãÎÒæä ÇáÂãä  
  (  
   SELECT   
    tmq.mtGuid MatGuid  
    ,(SUM(tmq.TargetQuantity)/@WorkDays)*@SafeStockDays SafeStockQty -- åÏÝ ãÈíÚÇÊ ÇáãÇÏÉ Öãä ÇáÝÊÑÉ ÇáãÎØØÉ  
   FROM  
    MatTargets000 tmq  
    INNER JOIN @Periods pr ON pr.PeriodGuid = tmq.bdpGuid  
   GROUP BY tmq.mtGuid  
  ) s ON s.MatGuid = pm.MatGuid  
   
   
 -- ÃåÏÇÝ ãÈíÚÇÊ ÇáãæÇÏ ÍÓÈ ÇáÝÊÑÇÊ  
  
 SELECT pm.MatGuid, pr.PeriodGuid, SUM(ISNULL(TargetQuantity, 0.0)) * @TargetQtyTolerance / 100 TargetQty  
 INTO #MatTargets  
 FROM   
  @PlanMats pm  
  CROSS JOIN @Periods Pr 
  LEFT JOIN MatTargets000 tmq ON pm.MatGuid = tmq.mtGuid AND pr.PeriodGuid = tmq.bdpGuid 
 GROUP BY pm.MatGuid, pr.PeriodGuid  
  
  
 -- ãÊæÓØ ÃæÇãÑ ÇáÊÔÛíá  
 SELECT MatGuid, PlGuid, [dbo].[fnGetJobOrdersAvg](MatGuid, PlGuid, @JobOrdersCount,@ShowJobOrderAvarageQty)JobOrdersAvg 
 INTO #JobAvg 
 FROM @PlanMats 
  
  
    DECLARE @OutBillType  [UNIQUEIDENTIFIER]      
    DECLARE @ReturnBillType  [UNIQUEIDENTIFIER]            
    DECLARE @OutTransBillType [UNIQUEIDENTIFIER]      
    DECLARE @InTransBillType [UNIQUEIDENTIFIER]    
       
    SELECT @OutBillType   = CAST([VALUE] AS UNIQUEIDENTIFIER) FROM op000 WHERE [NAME] ='JobOrderRequisitionBillType'    
    SELECT @ReturnBillType  = CAST([VALUE] AS UNIQUEIDENTIFIER) FROM op000 WHERE [NAME] ='JobOrderReturnBillType'    
    SELECT @OutTransBillType = CAST([VALUE] AS UNIQUEIDENTIFIER) FROM op000 WHERE [NAME] ='AmnJOC_TransfereOutputBillType'    
    SELECT @InTransBillType  = CAST([VALUE] AS UNIQUEIDENTIFIER) FROM op000 WHERE [NAME] ='AmnJOC_TransfereInputBillType'  
     
    DECLARE   
		@ProductionPlanInitiationDatePeriodStartDate  DATE,  
		@ProductionPlanStartPeriodStartDate           DATE  
	SELECT        
		@ProductionPlanInitiationDatePeriodStartDate	= Bdp.StartDate  
		,@ProductionPlanStartPeriodStartDate			= Bdp2.StartDate  
	FROM   
		ProductionPlan000 ProductionPlan  
		INNER JOIN Bdp000 Bdp	ON ProductionPlan.Date BETWEEN Bdp.StartDate AND Bdp.EndDate  
		INNER JOIN Bdp000 Bdp2  ON ProductionPlan.FromPeriod = Bdp2.Guid  
	WHERE ProductionPlan.Guid = @ParentGuid 
        
    SELECT pm.MatGuid, pm.PlGuid  
   -- ßãíÇÊ ãÎØØÉ = (ÇáßãíÇÊ ÇáãÎØØÉ ãä ÈÏÇíÉ ÝÊÑÉ ÊÇÑíÎ ÅäÔÇÁ ÇáÎØÉ Åáì ÈÏÇíÉ ÝÊÑÉ ÈÏÇíÉ ÇáÎØÉ + ÇáßãíÇÊ ÇáãÊÈÞíÉ ãä ÃæÇãÑ ÇáÊÔÛíá ÇáãÝÊæÍÉ ááÝÊÑÇÊ ÇáÓÇÈÞÉ áÝÊÑÉ ÅäÔÇÁ ÇáÎØÉ) * äÓÈÉ ÇÑÊíÇÈ ÇáãÎØØ  
     ,(SUM(ISNULL(PreviousPlans.PlanedQty, 0.0) + ISNULL(MaterialPlanFromOpenedJobOrders.PlanedQty, 0.0)) * @PlanedQtyTolerance / 100) PlanedQty  
     -- åÏÝ ÇáãÈíÚÇÊ = åÏÝ ÇáãÈíÚÇÊ ãä ÈÏÇíÉ ÝÊÑÉ ÅäÔÇÁ ÇáÎØÉ Åáì ÈÏÇíÉ ÝÊÑÉ ÈÏÇíÉ ÇáÎØÉ * äÓÈÉ ÇÑÊíÇÈ ÇáåÏÝ  
     ,SUM(ISNULL(MatTargets.SalesTarget *  @TargetQtyTolerance / 100	, 0.0)) TargetQty  
     -- ÈÖÇÚÉ Ãæá ÇáãÏÉ ááÝÊÑÉ ÇáÍÇáíÉ: åí ÈÖÇÚÉ Ãæá ÇáãÏÉ Ýí ÊÇÑíÎ ÈÏÇíÉ ÝÊÑÉ ÅäÔÇÁ ÇáÎØÉ  
     ,ISNULL(InitiationDatePeriodStock.Stock, 0.0) CurrentPeriodStartQty 
     -- ÈÖÇÚÉ Ãæá ÇáãÏÉ ááÝÊÑÉ ÇáãÎØØÉ= (ÈÖÇÚÉ Ãæá ÇáãÏÉ ááÝÊÑÉ ÇáÍÇáíÉ + ßãíÇÊ ÇáãÎØØÉ  - ÃåÏÇÝ ÇáãÈíÚÇÊ  ÇáãÓÌáÉ) * äÓÈÉ ÇÑÊíÇÈ ÇáåÏÝ     
     ,ISNULL(InitiationDatePeriodStock.Stock, 0.0) + (SUM(ISNULL(PreviousPlans.PlanedQty, 0.0) + ISNULL(MaterialPlanFromOpenedJobOrders.PlanedQty, 0.0)) * @PlanedQtyTolerance / 100) - SUM(ISNULL(MatTargets.SalesTarget *  @TargetQtyTolerance / 100	, 0.0)) FirstPeriodStartQty  
 INTO #FirstPeriodInfo  
 FROM   
  @PlanMats pm  
    
  		  
		INNER JOIN #JobAvg javg ON javg.MatGuid = pm.MatGuid AND javg.PlGuid = pm.PlGuid  
		LEFT JOIN  
		(  
			SELECT  
				Mt.Guid MatGuid  
				,SUM(ISNULL((Bi.Qty * CASE Bt.BillType WHEN 0 THEN 1 WHEN 3 THEN 1 WHEN 4 THEN 1 ELSE -1 END) , 0)) Stock  
			FROM   
				Mt000 Mt  
				INNER JOIN Bi000 Bi ON Mt.Guid = Bi.MatGuid  
				INNER JOIN Bu000 Bu ON Bu.Guid = Bi.ParentGuid AND Bu.Date < @ProductionPlanInitiationDatePeriodStartDate  
				INNER JOIN Bt000 Bt ON Bt.Guid = Bu.TypeGuid  
			GROUP BY   
				Mt.Guid  
		)InitiationDatePeriodStock ON pm.MatGuid = InitiationDatePeriodStock.MatGuid  
	LEFT JOIN  
	(  
		SELECT  
			Mi.MatGuid  
			,SUM(JobOrder.PlannedProductionQty - JobOrder.ActualProductionQty) PlanedQty  
		FROM   
			JobOrder000 JobOrder  
			INNER JOIN Fm000 Fm ON Fm.Guid = JobOrder.FormGuid  
			INNER JOIN Mn000 Mn ON Mn.FormGuid = Fm.Guid AND Mn.Type = 0  
			INNER JOIN Mi000 Mi ON Mi.ParentGuid = Mn.Guid AND Mi.Type = 0  
		WHERE   
			ISNULL(JobOrder.InBillGuid, 0x0) = 0x0  
			AND JobOrder.StartDate < @ProductionPlanInitiationDatePeriodStartDate  
		GROUP BY   
			Mi.MatGuid  
	)MaterialPlanFromOpenedJobOrders ON MaterialPlanFromOpenedJobOrders.MatGuid = pm.MatGuid  
	LEFT JOIN  
	(  
		  SELECT  
			MPPI.MaterialGuid  
			,SUM(MPPD.PlanedQty) PlanedQty  
		  FROM  
			MainProductionPlanItem000 MPPI  
			INNER JOIN MainProductionPlanDetail000 MPPD ON MPPD.ParentGuid = MPPI.Guid  
			INNER JOIN Bdp000 Bdp ON Bdp.Guid = MPPD.PeriodGuid  
		  WHERE   
			Bdp.StartDate >= @ProductionPlanInitiationDatePeriodStartDate  
			AND Bdp.EndDate < @ProductionPlanStartPeriodStartDate  
		  GROUP BY   
			MPPI.MaterialGuid  
	)PreviousPlans ON PreviousPlans.MaterialGuid = pm.MatGuid   
	INNER JOIN  
	(  
		SELECT  
			MatTargets.MtGuid MatGuid  
			,SUM(MatTargets.TargetQuantity) SalesTarget  
		FROM   
			MatTargets000 MatTargets  
			INNER JOIN Bdp000 Bdp ON Bdp.Guid = MatTargets.BdpGuid  
		WHERE   
			Bdp.StartDate >= @ProductionPlanInitiationDatePeriodStartDate  
			AND Bdp.EndDate < @ProductionPlanStartPeriodStartDate  
		GROUP BY   
			MatTargets.MtGuid  
	)MatTargets ON MatTargets.MatGuid = pm.MatGuid   
	INNER JOIN Mi000 Mi ON Mi.MatGuid = pm.MatGuid AND Mi.Type = 0 
    INNER JOIN Mn000 Mn ON Mn.Guid = Mi.ParentGuid AND Mn.Type = 0
	GROUP BY  
		pm.MatGuid 
		,pm.PlGuid	 
		,ISNULL(InitiationDatePeriodStock.Stock, 0.0) 
	  
	----------  
	SELECT   
		@FirstPeriodGuid PeriodGuid,   
		@FirstPeriodNumber PeriodNumber,  
		fp.MatGuid,  
		fp.PlGuid  
		,(CASE WHEN fp.FirstPeriodStartQty <= 0 THEN 0 ELSE fp.FirstPeriodStartQty END) PeriodStartQty  
		,CASE javg.JobOrdersAvg WHEN 0 THEN 0 ELSE 
		CEILING(((CASE @QuantityAvailabilityOption  
			WHEN 0 THEN 0  
			WHEN 1 THEN m.SafeStockQty  
			WHEN 2 THEN m.LowLimit  
			WHEN 3 THEN m.HighLimit  
			WHEN 4 THEN m.OrderLimit  
		 END)+tmq.TargetQty-(CASE	WHEN fp.FirstPeriodStartQty < 0 THEN 0 ELSE fp.FirstPeriodStartQty END)			  
		) / javg.JobOrdersAvg) END JobOrdersCount  
		,javg.JobOrdersAvg  
		,tmq.TargetQty  
	INTO #tmp_cte  
	FROM  
		#FirstPeriodInfo fp  
		INNER JOIN #MatTargets tmq ON tmq.MatGuid = fp.MatGuid AND @FirstPeriodGuid = tmq.PeriodGuid  
		INNER JOIN #JobAvg javg ON javg.MatGuid = fp.MatGuid AND javg.PlGuid = fp.PlGuid  
		INNER JOIN #MatInfo m ON m.MatGuid = fp.MatGuid  
	
	 
	SELECT  
		PeriodGuid, PeriodNumber, MatGuid, PlGuid  
		,PeriodStartQty  
		,(CASE WHEN JobOrdersCount < 0 THEN 0 ELSE JobOrdersCount END) JobOrdersCount  
		,(CASE WHEN JobOrdersCount < 0 THEN 0 ELSE JobOrdersCount END) * JobOrdersAvg PlanedQty  
		,(PeriodStartQty+((CASE WHEN JobOrdersCount < 0 THEN 0 ELSE JobOrdersCount END) * JobOrdersAvg)-TargetQty) PeriodEndQty  
	INTO #cte  
	FROM #tmp_cte  

	DECLARE @PeriodNumber INT  
	SET @PeriodNumber = @FirstPeriodNumber + 1  
	
	WHILE @PeriodNumber <= @lastPeriodNumber  
	BEGIN  
		SELECT   
			p.PeriodGuid,   
			p.Number PeriodNumber,  
			cte.MatGuid,  
			cte.PlGuid  
			,AVG(CASE WHEN cte.PeriodEndQty <= 0 THEN 0 ELSE cte.PeriodEndQty END) PeriodStartQty  				 
			,AVG(CASE javg.JobOrdersAvg WHEN 0 THEN 0 ELSE 
			CEILING(((CASE @QuantityAvailabilityOption  
				WHEN 0 THEN 0  
				WHEN 1 THEN m.SafeStockQty  
				WHEN 2 THEN m.LowLimit  
				WHEN 3 THEN m.HighLimit  
				WHEN 4 THEN m.OrderLimit  
			 END)+tmq.TargetQty-(CASE WHEN cte.PeriodEndQty <= 0 THEN 0 ELSE cte.PeriodEndQty END)
			) / javg.JobOrdersAvg) END) JobOrdersCount  
			,AVG(javg.JobOrdersAvg)		JobOrdersAvg 
			,AVG(tmq.TargetQty)			TargetQty 
		INTO #temp_period_cte  
		FROM								  
			#cte cte   
			INNER JOIN #MatInfo m ON m.MatGuid = cte.MatGuid   
			CROSS JOIN @Periods p  
			INNER JOIN #MatTargets tmq ON tmq.MatGuid = cte.MatGuid AND p.PeriodGuid = tmq.PeriodGuid  
			INNER JOIN #JobAvg javg ON javg.MatGuid = cte.MatGuid AND javg.PlGuid = cte.PlGuid  
		WHERE p.Number = @PeriodNumber  AND cte.PeriodNumber = @PeriodNumber - 1
		GROUP BY p.PeriodGuid 
				,p.Number 
				,cte.MatGuid 
				,cte.PlGuid 
	
		INSERT INTO #cte  
		SELECT  
			PeriodGuid, PeriodNumber, MatGuid, PlGuid  
			,PeriodStartQty  
			,(CASE WHEN JobOrdersCount < 0 THEN 0 ELSE JobOrdersCount END) JobOrdersCount  
			,(CASE WHEN JobOrdersCount < 0 THEN 0 ELSE JobOrdersCount END) * JobOrdersAvg PlanedQty  
			,(PeriodStartQty+((CASE WHEN JobOrdersCount < 0 THEN 0 ELSE JobOrdersCount END) * JobOrdersAvg)-TargetQty) PeriodEndQty  
		FROM  
			#temp_period_cte  
			       

		DROP TABLE #temp_period_cte  
		  
		SET @PeriodNumber = @PeriodNumber + 1  
	END  
		
		DECLARE @items TABLE(  
			ItemGuid UNIQUEIDENTIFIER,   
			MatGuid UNIQUEIDENTIFIER,   
			PlGuid UNIQUEIDENTIFIER  
		)  
		  
		DECLARE @MainPlanGuid UNIQUEIDENTIFIER  
		  
		 
		SET @MainPlanGuid = NEWID()  
		INSERT INTO MainProductionPlan000 (Guid, ParentGuid) VALUES(@MainPlanGuid, @ParentGuid)			  
	  
		INSERT INTO MainProductionPlanItem000  
			OUTPUT INSERTED.Guid, INSERTED.MaterialGuid, INSERTED.ProductionLineGuid INTO @items  
			SELECT   
				NEWID() Guid  
				,@MainPlanGuid  
				,d.PlGuid  
				,d.MatGuid  
				,SUM(d.PlanedQty)  
				,SUM(d.JobOrdersCount)  
				,javg.JobOrdersAvg  
				,(CASE @QuantityAvailabilityOption  
					WHEN 2 THEN LowLimit  
					WHEN 3 THEN HighLimit  
					WHEN 4 THEN OrderLimit  
					ELSE 0  
				 END)  
				,(CASE @QuantityAvailabilityOption  
					WHEN 1 THEN SafeStockQty  
					ELSE 0  
				 END)  
			FROM  
				#cte d  
				INNER JOIN #JobAvg javg ON javg.MatGuid = d.MatGuid AND javg.PlGuid = d.PlGuid  
				INNER JOIN #MatInfo m ON m.MatGuid = d.MatGuid  
			GROUP BY   
				d.PlGuid  
				,d.MatGuid  
				,javg.JobOrdersAvg  
				,(CASE @QuantityAvailabilityOption  
					WHEN 2 THEN LowLimit  
					WHEN 3 THEN HighLimit  
					WHEN 4 THEN OrderLimit  
					ELSE 0  
				 END)  
				,(CASE @QuantityAvailabilityOption  
					WHEN 1 THEN SafeStockQty  
					ELSE 0  
				 END) 	  
		 
		INSERT INTO MainProductionPlanDetail000  
			SELECT  
				NEWID()  
				,i.ItemGuid  
				,d.PeriodGuid  
				,d.PeriodStartQty  
				,d.PlanedQty  
				,d.JobOrdersCount  
				,tmq.TargetQty  
			FROM   
				#cte d  
				INNER JOIN @items i ON i.MatGuid = d.MatGuid AND i.PlGuid = d.PlGuid  
				INNER JOIN #MatTargets tmq ON tmq.MatGuid = d.MatGuid AND tmq.PeriodGuid = d.PeriodGuid  
	 
		  
		DELETE FROM @items  
		DECLARE @ModifiedPlanGuid UNIQUEIDENTIFIER		  
		SET @ModifiedPlanGuid = NEWID()  
		  
		INSERT INTO ModifiedProductionPlan000 (Guid, ParentGuid) VALUES(@ModifiedPlanGuid, @ParentGuid)		  
		  
		INSERT INTO ModifiedProductionPlanItem000 
		SELECT  
			NEWID() 
			,@ModifiedPlanGuid 
			,ProductionLineGuid 
			,MaterialGuid 
			,PlanedQty 
			,JobOrderQty 
			,JobOrderAvarage 
			,MinLimit 
			,SafeStock 
		FROM MainProductionPlanItem000 
		WHERE ParentGuid = @MainPlanGuid 
		 
		INSERT INTO ModifiedProductionPlanDetail000  
		SELECT  
			NEWID() 
			,ModPPI.Guid 
			,MPPD.PeriodGuid 
			,MPPD.FirstPeriodQty 
			,MPPD.PlanedQty 
			,MPPD.JobOrderQty 
			,MPPD.TargetQty 
		FROM 
			MainProductionPlanDetail000 MPPD 
			INNER JOIN MainProductionPlanItem000 MPPI ON MPPI.Guid = MPPD.ParentGuid 
			INNER JOIN MainProductionPlan000 MPP ON MPP.Guid = MPPI.ParentGuid 
			INNER JOIN ModifiedProductionPlan000 ModPP ON MPP.ParentGuid = ModPP.ParentGuid 
			INNER JOIN ModifiedProductionPlanItem000 ModPPI ON ModPPI.ParentGuid = ModPP.Guid AND ModPPI.MaterialGuid = MPPI.MaterialGuid AND ModPPI.ProductionLineGuid = MPPI.ProductionLineGuid 
		WHERE ModPPI.ParentGuid = @ModifiedPlanGuid 
	 
	SELECT @MainPlanGuid AS MainPlanGuid, @ModifiedPlanGuid AS ModifiedPlanGuid 
######################################################
CREATE PROCEDURE RepReadyMaterialVariation
	@ProductionPlanGuid UNIQUEIDENTIFIER = 0x0
AS 
SET NOCOUNT ON 

SELECT
	 Mt.Guid       MaterialGuid
	 ,Mt.Name      MaterialName
	 ,Gr.Guid      GroupGuid
	 ,Gr.Name      GroupName
	 ,MPPD.PeriodGuid    PeriodGuid
	 ,Bdp.StartDate     PeriodStartDate
	 ,Bdp.Name          PeriodName
	 ,SUM(MPPD.PlanedQty)   MainPlanedQty
	 ,SUM(MPPD.JobOrderQty)   MainJobOrderQty
	 ,SUM(ISNULL(ModifiedPP.PlanedQty, 0))  ModifiedPlanedQty
	 ,SUM(ISNULL(ModifiedPP.JobOrderQty, 0)) ModifiedJobOrderQty
	 ,CAST(0 AS FLOAT)    PlanedQtyDiff
	 ,CAST(0 AS FLOAT)    JobOrderQtyDiff
	 ,1        Type
INTO #Result
FROM ProductionPlan000 PP
	INNER JOIN MainProductionPlan000 MPP ON MPP.ParentGuid = PP.Guid
	INNER JOIN MainProductionPlanItem000 MPPI ON MPPI.ParentGuid = MPP.Guid
	INNER JOIN MainProductionPlanDetail000 MPPD ON MPPD.ParentGuid = MPPI.Guid
	INNER JOIN Mt000 Mt ON Mt.Guid = MPPI.MaterialGuid
	INNER JOIN Gr000 Gr ON Gr.Guid = Mt.GroupGuid
	INNER JOIN Bdp000 Bdp ON MPPD.PeriodGuid = Bdp.Guid
	LEFT JOIN
	(
		 SELECT
			  MPPI.MaterialGuid
			  ,MPPD.PeriodGuid
			  ,MPPD.PlanedQty
			  ,MPPD.JobOrderQty
		 FROM ModifiedProductionPlan000 MPP
			 INNER JOIN ModifiedProductionPlanItem000 MPPI ON MPPI.ParentGuid = MPP.Guid
			 INNER JOIN ModifiedProductionPlanDetail000 MPPD ON MPPD.ParentGuid = MPPI.Guid
		 WHERE MPP.ParentGuid = @ProductionPlanGuid
		 GROUP BY MPPI.MaterialGuid
		   ,MPPD.PeriodGuid
		   ,MPPD.PlanedQty
		   ,MPPD.JobOrderQty
	) ModifiedPP ON ModifiedPP.MaterialGuid = Mt.Guid AND ModifiedPP.PeriodGuid = MPPD.PeriodGuid
WHERE PP.Guid = @ProductionPlanGuid
GROUP BY Mt.Guid
  ,Mt.Name
  ,Gr.Guid
  ,Gr.Name
  ,MPPD.PeriodGuid
  ,Bdp.StartDate
  ,Bdp.Name
  
INSERT INTO #Result
SELECT
	 MaterialGuid
	 ,MaterialName
	 ,GroupGuid
	 ,GroupName
	 ,0x0
	 ,'1-1-1980'
	 ,''
	 ,SUM(MainPlanedQty)
	 ,SUM(MainJobOrderQty)
	 ,SUM(ModifiedPlanedQty)
	 ,SUM(ModifiedJobOrderQty)
	 ,0
	 ,0
	 ,1
FROM #Result
GROUP BY MaterialGuid, MaterialName, GroupGuid, GroupName

INSERT INTO #Result
SELECT
	 GroupGuid
	 ,GroupName
	 ,GroupGuid
	 ,GroupName
	 ,PeriodGuid
	 ,PeriodStartDate
	 ,PeriodName
	 ,SUM(MainPlanedQty)
	 ,SUM(MainJobOrderQty)
	 ,SUM(ModifiedPlanedQty)
	 ,SUM(ModifiedJobOrderQty)
	 ,0
	 ,0
	 ,0
FROM #Result
GROUP BY GroupGuid, GroupName, PeriodGuid, PeriodStartDate, PeriodName

UPDATE #Result SET 
	PlanedQtyDiff = ModifiedPlanedQty - MainPlanedQty
    ,JobOrderQtyDiff = ModifiedJobOrderQty - MainJobOrderQty

SELECT DISTINCT PeriodGuid, PeriodName, PeriodStartDate
FROM #Result
WHERE PeriodGuid <> 0x0
ORDER BY PeriodStartDate

SELECT * FROM #Result ORDER BY GroupName, Type, MaterialName, PeriodStartDate
######################################################
CREATE FUNCTION fnGetVacationDays(
	 @FromPeriod UNIQUEIDENTIFIER
	,@ToPeriod UNIQUEIDENTIFIER)
	RETURNS int 
AS 
BEGIN
    DECLARE @cnt int;
	set @cnt=(select count(*) cnt FROM bdp000 b , DistCalendar000 d
	WHERE Date BETWEEN StartDate AND EndDate 
		  AND b.GUID IN (@FromPeriod,@ToPeriod))
    RETURN @cnt;
END
########################################################################
CREATE PROCEDURE RepRawMaterialVariation
	@ProductionPlanGuid  UNIQUEIDENTIFIER
AS  
SET NOCOUNT ON  
SELECT 
	 RawMt.Guid       																								MaterialGuid 
	 ,RawMt.Name      																								MaterialName 
	 ,Gr.Guid																										GroupGuid 
	 ,Gr.Name																										GroupName 
	 ,MPPD.PeriodGuid   																							PeriodGuid 
	 ,Bdp.StartDate     																							PeriodStartDate 
	 ,Bdp.Name																										PeriodName 
	 ,SUM(CASE ReadyMi.Qty WHEN 0 THEN 0 ELSE MPPD.PlanedQty * RawMi.Qty / ReadyMi.Qty END)							MainPlanedQty  
	 ,SUM(ISNULL(CASE ReadyMi.Qty WHEN 0 THEN 0 ELSE ModifiedPP.PlanedQty * RawMi.Qty / ReadyMi.Qty END, 0))		ModifiedPlanedQty 
	 ,CAST(0 AS FLOAT)																								PlanedQtyDiff 
	 ,1																												Type 
INTO #Result 
FROM ProductionPlan000 PP 
	INNER JOIN MainProductionPlan000 MPP ON MPP.ParentGuid = PP.Guid 
	INNER JOIN MainProductionPlanItem000 MPPI ON MPPI.ParentGuid = MPP.Guid 
	INNER JOIN MainProductionPlanDetail000 MPPD ON MPPD.ParentGuid = MPPI.Guid 
	INNER JOIN Mt000 ReadyMt ON ReadyMt.Guid = MPPI.MaterialGuid 
	INNER JOIN Bdp000 Bdp ON MPPD.PeriodGuid = Bdp.Guid 
	INNER JOIN Mi000 ReadyMi ON ReadyMi.MatGuid = ReadyMt.Guid AND ReadyMi.Type = 0
	INNER JOIN Mn000 Mn ON Mn.Guid = ReadyMi.ParentGuid AND Mn.Type = 0
	INNER JOIN Mi000 RawMi ON RawMi.ParentGuid = Mn.Guid AND RawMi.Type = 1
	INNER JOIN Mt000 RawMt ON RawMt.Guid = RawMi.MatGuid
	INNER JOIN Gr000 Gr ON Gr.Guid = RawMt.GroupGuid 
	LEFT JOIN 
	( 
		 SELECT 
			  MPPI.MaterialGuid 
			  ,MPPD.PeriodGuid 
			  ,MPPD.PlanedQty 
			  ,MPPD.JobOrderQty 
		 FROM ModifiedProductionPlan000 MPP 
			 INNER JOIN ModifiedProductionPlanItem000 MPPI ON MPPI.ParentGuid = MPP.Guid 
			 INNER JOIN ModifiedProductionPlanDetail000 MPPD ON MPPD.ParentGuid = MPPI.Guid 
		 WHERE MPP.ParentGuid = @ProductionPlanGuid 
		 GROUP BY MPPI.MaterialGuid 
		   ,MPPD.PeriodGuid 
		   ,MPPD.PlanedQty 
		   ,MPPD.JobOrderQty 
	) ModifiedPP ON ModifiedPP.MaterialGuid = ReadyMt.Guid AND ModifiedPP.PeriodGuid = MPPD.PeriodGuid 
WHERE PP.Guid = @ProductionPlanGuid 
GROUP BY RawMt.Guid 
  ,RawMt.Name 
  ,Gr.Guid 
  ,Gr.Name 
  ,MPPD.PeriodGuid 
  ,Bdp.StartDate 
  ,Bdp.Name 
   
INSERT INTO #Result 
SELECT 
	 MaterialGuid 
	 ,MaterialName 
	 ,GroupGuid 
	 ,GroupName 
	 ,0x0 
	 ,'1-1-1980' 
	 ,'' 
	 ,SUM(MainPlanedQty) 
	 ,SUM(ModifiedPlanedQty) 
	 ,0 
	 ,1 
FROM #Result 
GROUP BY MaterialGuid, MaterialName, GroupGuid, GroupName 
INSERT INTO #Result 
SELECT 
	 GroupGuid 
	 ,GroupName 
	 ,GroupGuid 
	 ,GroupName 
	 ,PeriodGuid 
	 ,PeriodStartDate 
	 ,PeriodName 
	 ,SUM(MainPlanedQty) 
	 ,SUM(ModifiedPlanedQty) 
	 ,0 
	 ,0 
FROM #Result 
GROUP BY GroupGuid, GroupName, PeriodGuid, PeriodStartDate, PeriodName 

INSERT INTO #Result 
SELECT 
	 0x0
	 ,'ííííííííííííííííííí'
	 ,0x0
	 ,'ííííííííííííííííííí'
	 ,PeriodGuid 
	 ,PeriodStartDate
	 ,PeriodName
	 ,SUM(MainPlanedQty) 
	 ,SUM(ModifiedPlanedQty) 
	 ,0 
	 ,2
FROM #Result 
WHERE Type = 0
GROUP BY PeriodGuid, PeriodStartDate, PeriodName 

UPDATE #Result SET  
	PlanedQtyDiff = ModifiedPlanedQty - MainPlanedQty 
SELECT DISTINCT PeriodGuid, PeriodName, PeriodStartDate 
FROM #Result 
WHERE PeriodGuid <> 0x0 
ORDER BY PeriodStartDate 
SELECT * FROM #Result ORDER BY GroupName, Type, MaterialName, PeriodStartDate 
######################################################
CREATE PROCEDURE RepPlanImplementationVariation
	@ProductionPlanGuid		UNIQUEIDENTIFIER = 0x0   
	,@FormGuid				UNIQUEIDENTIFIER = 0x0   
	,@GroupGuid				UNIQUEIDENTIFIER = 0x0   
	,@ProductionLineGuid	UNIQUEIDENTIFIER = 0x0   
	,@FromPeriodGuid		UNIQUEIDENTIFIER = 0x0   
	,@ToPeriodGuid			UNIQUEIDENTIFIER = 0x0   
	,@ShowMaterials			INT = 1   
	,@ShowJobOrdersNo		INT = 1   
	,@ShowProductionLines	INT = 1   
	,@ShowPeriodsDetails	INT = 1 
	,@ShowRatioOfAchievedPlan INT = 1  
AS    
	SET NOCOUNT ON  
	DECLARE @ProductionPlanUnit INT  
	SELECT @ProductionPlanUnit = Unit FROM ProductionPlan000 WHERE Guid = @ProductionPlanGuid   
	IF(ISNULL(@ProductionPlanGuid, 0x0) = 0x0)  
		SET @ProductionPlanUnit = 0  
	
	IF(ISNULL(@ProductionPlanGuid, 0x0) <> 0x0)  
	BEGIN  
		SELECT	@FromPeriodGuid = FromPeriod  
				,@ToPeriodGuid	= ToPeriod  
		FROM ProductionPlan000  
		WHERE Guid = @ProductionPlanGuid  
	END 
	
	DECLARE 
		@FromDate DATE,
		@ToDate  DATE   
	
	SELECT @FromDate = StartDate FROM Bdp000 WHERE Guid = @FromPeriodGuid   
	SELECT @ToDate	 = EndDate	 FROM Bdp000 WHERE Guid = @ToPeriodGuid   
	

	SELECT   
	   Mt.Guid			MaterialGuid   
	  ,Mt.Name			MaterialName   
	  ,Gr.Guid			GroupGuid   
	  ,Gr.Name			GroupName   
	  ,Pl.Guid			ProductionLineGuid   
	  ,Pl.Name			ProductionLineName   
	  ,Bdp.Guid			PeriodGuid   
	  ,Bdp.Name			PeriodName   
	  ,Bdp.StartDate    PeriodStartDate   
	  ,ISNULL(SUM(MPPD.PlanedQty / MaterialUnity.UnitFact), 0.0)                PlanedQty   
	  ,ISNULL(SUM(MPPD.JobOrderQty), 0.0)										PlanedJobOrdersQty   
	  ,ISNULL(JobOrders.ActiveProductionQty / MaterialUnity.UnitFact, 0.0)      ActiveProductionQty   
	  ,ISNULL(JobOrders.FinishedProductionQty / MaterialUnity.UnitFact, 0.0)    FinishedProductionQty    
	  ,ISNULL(JobOrders.JobOrdersNumber, 0)										JobOrdersNumber 
	  ,ISNULL(JobOrders.ActiveJobOrdersNumber, 0)								ActiveJobOrdersNumber 
	  ,ISNULL(JobOrders.FinishedJobOrdersNumber, 0)								FinishedJobOrdersNumber 
	  ,CAST(0 AS FLOAT) TotalProductionQty   
	  ,CAST(0 AS FLOAT) ProductionQtyDiff   
	  ,CAST(0 AS FLOAT)	JobOrdersNumberDiff
	  ,CAST(0 AS FLOAT) RatioOFAchievedPlan
	  ,1                Type   
	INTO #Result   
	FROM 
		ProductionPlan000 PP   
		INNER JOIN MainProductionPlan000 MPP ON MPP.ParentGuid = PP.Guid   
		INNER JOIN MainProductionPlanItem000 MPPI ON MPPI.ParentGuid = MPP.Guid   
		INNER JOIN MainProductionPlanDetail000 MPPD ON MPPD.ParentGuid = MPPI.Guid   
		INNER JOIN Mt000 Mt ON Mt.Guid = MPPI.MaterialGuid   
		INNER JOIN Gr000 Gr ON Gr.Guid = Mt.GroupGuid   
		INNER JOIN Bdp000 Bdp ON MPPD.PeriodGuid = Bdp.Guid   
		INNER JOIN ProductionLine000 Pl ON Pl.Guid = MPPI.ProductionLineGuid  
		INNER JOIN   
		(  
			SELECT 
			  Guid MaterialGuid  
			  ,CASE @ProductionPlanUnit WHEN 0 THEN 1 WHEN 1 THEN CASE Unit2Fact WHEN 0 THEN 1 ELSE Unit2Fact END WHEN 2 THEN CASE Unit3Fact WHEN 0 THEN 1 ELSE Unit3Fact END WHEN 3 THEN CASE DefUnit WHEN 1 THEN 1 WHEN 2 THEN CASE Unit2Fact WHEN 0 THEN 1 ELSE Unit2Fact END WHEN 3 THEN CASE Unit3Fact WHEN 0 THEN 1 ELSE Unit3Fact END END END UnitFact  
			  FROM Mt000  
		)MaterialUnity ON MaterialUnity.MaterialGuid = Mt.Guid  
		LEFT JOIN    
		(   
			 SELECT    
				  Jo.ProductionLine   
				  ,Mi.MatGuid   
				  ,Bdp.Guid				PeriodGuid  
				  ,COUNT(Jo.Guid)	JobOrdersNumber 
				  ,SUM(CASE ISNULL(Jo.InBillGuid, 0x0) WHEN 0x0 THEN 1 ELSE 0 END) ActiveJobOrdersNumber   
				  ,SUM(CASE ISNULL(Jo.InBillGuid, 0x0) WHEN 0x0 THEN 0 ELSE 1 END) FinishedJobOrdersNumber   
				  ,SUM(CASE ISNULL(Jo.InBillGuid, 0x0) WHEN 0x0 THEN Jo.PlannedProductionQty ELSE 0 END) ActiveProductionQty   
				  ,SUM(CASE ISNULL(Jo.InBillGuid, 0x0) WHEN 0x0 THEN 0 ELSE Jo.ActualProductionQty END) FinishedProductionQty   
			 FROM JobOrder000 Jo   
				 INNER JOIN Mn000 Mn ON Mn.FormGuid = Jo.FormGuid AND Mn.Type = 0   
				 INNER JOIN Mi000 Mi ON Mi.ParentGuid = Mn.Guid AND Mi.Type = 0  
				 INNER JOIN Bdp000 Bdp ON (Jo.StartDate BETWEEN Bdp.StartDate AND Bdp.EndDate)   
			 WHERE (ISNULL(@FormGuid, 0x0) = 0x0 OR Jo.FormGuid = @FormGuid)   
				AND (ISNULL(@ProductionLineGuid, 0x0) = 0x0 OR Jo.ProductionLine = @ProductionLineGuid)   
				AND Jo.StartDate BETWEEN @FromDate AND @ToDate  
			 GROUP BY Jo.ProductionLine   
			   ,Mi.MatGuid   
			   ,Bdp.Guid  
		)JobOrders ON JobOrders.MatGuid = Mt.Guid AND JobOrders.ProductionLine = MPPI.ProductionLineGuid AND JobOrders.PeriodGuid = Bdp.Guid  
	WHERE 
		(ISNULL(@ProductionPlanGuid, 0x0) = 0x0 OR PP.Guid = @ProductionPlanGuid)   
		AND (ISNULL(@ProductionLineGuid, 0x0) = 0x0 OR MPPI.ProductionLineGuid = @ProductionLineGuid)   
		AND Bdp.StartDate >= @FromDate AND Bdp.EndDate <= @ToDate   
		AND (ISNULL(@GroupGuid, 0x0) = 0x0 OR Gr.Guid IN (SELECT Guid FROM dbo.fnGetGroupsOfGroup(@GroupGuid)))  
		AND (ISNULL(@FormGuid, 0x0) = 0x0 OR Mt.GUID IN (SELECT Mi.MatGuid FROM MI000 Mi INNER JOIN MN000 Mn ON Mi.ParentGUID = Mn.GUID AND Mn.Type = 0 WHERE Mn.FormGUID = @FormGuid AND Mi.Type = 0) )  
	GROUP BY 
	   Mt.Guid   
	  ,Mt.Name   
	  ,Gr.Guid   
	  ,Gr.Name   
	  ,Pl.Guid   
	  ,Pl.Name   
	  ,Bdp.Guid   
	  ,Bdp.Name   
	  ,Bdp.StartDate   
	  ,JobOrders.ActiveProductionQty   
	  ,JobOrders.FinishedProductionQty 
	  ,JobOrders.JobOrdersNumber   
	  ,JobOrders.ActiveJobOrdersNumber 
	  ,JobOrders.FinishedJobOrdersNumber 
	  ,MaterialUnity.UnitFact  
	    
	INSERT INTO #Result   
	SELECT    
		 MaterialGuid   
		 ,MaterialName   
		 ,GroupGuid   
		 ,GroupName   
		 ,ProductionLineGuid   
		 ,ProductionLineName   
		 ,0x0   
		 ,''   
		 ,'1-1-1980'   
		 ,SUM(PlanedQty)   
		 ,SUM(PlanedJobOrdersQty)
		 ,SUM(ActiveProductionQty)   
		 ,SUM(FinishedProductionQty) 
		 ,SUM(JobOrdersNumber)   
		 ,SUM(ActiveJobOrdersNumber)   
		 ,SUM(FinishedJobOrdersNumber) 
		 ,0
		 ,0   
		 ,0   
		 ,0
		 ,1   
	FROM #Result   
	GROUP BY 
		MaterialGuid   
	  ,MaterialName   
	  ,GroupGuid   
	  ,GroupName   
	  ,ProductionLineGuid   
	  ,ProductionLineName   
	
	INSERT INTO #Result   
	SELECT    
		 GroupGuid   
		 ,GroupName   
		 ,GroupGuid   
		 ,GroupName   
		 ,0x0   
		 ,''   
		 ,PeriodGuid   
		 ,PeriodName   
		 ,PeriodStartDate   
		 ,SUM(PlanedQty)   
		 ,SUM(PlanedJobOrdersQty)
		 ,SUM(ActiveProductionQty)   
		 ,SUM(FinishedProductionQty) 
		 ,SUM(JobOrdersNumber)   
		 ,SUM(ActiveJobOrdersNumber)   
		 ,SUM(FinishedJobOrdersNumber)
		 ,0
		 ,0   
		 ,0   
		 ,0
		 ,0   
	FROM #Result   
	GROUP BY 
		GroupGuid   
	  ,GroupName   
	  ,PeriodGuid   
	  ,PeriodName   
	  ,PeriodStartDate   
	
	UPDATE #Result SET 
		TotalProductionQty  = ActiveProductionQty + FinishedProductionQty,
		ProductionQtyDiff	= PlanedQty - TotalProductionQty,
		JobOrdersNumberDiff	= PlanedJobOrdersQty - JobOrdersNumber,
   		RatioOfAchievedPlan = (CASE PlanedQty WHEN 0 THEN 0 ELSE (FinishedProductionQty / PlanedQty) * 100 END) 

	DELETE FROM #Result 
	WHERE 
		(@ShowMaterials = 0 AND Type = 1)
		OR(@ShowPeriodsDetails = 0 AND ISNULL(PeriodGuid, 0x0) <> 0x0)
	
	SELECT DISTINCT 
		PeriodGuid, PeriodName, PeriodStartDate   
	FROM 
		#Result 
	WHERE 
		PeriodGuid <> 0x0   
	ORDER BY 
		PeriodStartDate   
	
	IF(@ShowProductionLines = 1)   
	 SELECT * FROM #Result 
	 ORDER BY 
		GroupName, Type, ProductionLineName , MaterialName, PeriodStartDate    
	ELSE   
	 SELECT    
		  MaterialGuid   
		  ,MaterialName   
		  ,GroupGuid   
		  ,GroupName   
		  ,0x0			ProductionLineGuid  
		  ,''			ProductionLineName  
		  ,PeriodGuid   
		  ,PeriodName   
		  ,PeriodStartDate   
		  ,SUM(PlanedQty)		PlanedQty  
		  ,SUM(PlanedJobOrdersQty) PlanedJobOrdersQty
		  ,SUM(ActiveProductionQty)	ActiveProductionQty  
		  ,SUM(FinishedProductionQty)		FinishedProductionQty 
		  ,SUM(JobOrdersNumber)			JobOrdersNumber  
		  ,SUM(ActiveJobOrdersNumber)	ActiveJobOrdersNumber 
		  ,SUM(FinishedJobOrdersNumber)		FinishedJobOrdersNumber 
		  ,SUM(ActiveProductionQty) + SUM(FinishedProductionQty) TotalProductionQty   
		  ,SUM(PlanedQty) - ( SUM(ActiveProductionQty) + SUM(FinishedProductionQty) )ProductionQtyDiff   
		  ,SUM(JobOrdersNumberDiff)	  JobOrdersNumberDiff
		 ,(CASE SUM(PlanedQty) WHEN 0 THEN 0 ELSE (SUM(FinishedProductionQty) / SUM(PlanedQty))* 100 END)    RatioOFAchievedPlan   
		  ,Type   
	 FROM #Result    
	 GROUP BY 
		MaterialGuid   
	   ,MaterialName   
	   ,GroupGuid   
	   ,GroupName   
	   ,PeriodGuid   
	   ,PeriodName   
	   ,PeriodStartDate   
	   ,Type   
	 ORDER BY 
		GroupName, Type, MaterialName, PeriodStartDate 
######################################################
CREATE PROCEDURE RepProductionLinesCapacity
	 @ProductionLine	UNIQUEIDENTIFIER
	 ,@FromPeriodGuid	UNIQUEIDENTIFIER
     ,@ToPeriodGuid		UNIQUEIDENTIFIER
AS  
SET NOCOUNT ON 

DECLARE @FromDate	DATETIME
DECLARE @ToDate		DATETIME

SELECT @FromDate = StartDate FROM Bdp000 WHERE Guid = @FromPeriodGuid
SELECT @ToDate = EndDate FROM Bdp000 WHERE Guid = @ToPeriodGuid

SELECT  
	 Pl.Guid																													ProductionLineGuid 
	 ,Pl.Name																													ProductionLineName 
	 ,Bdp.Guid              																									PeriodGuid 
	 ,Bdp.Name              																									PeriodName 
	 ,Bdp.StartDate         																									PeriodStartDate 
	 ,ISNULL(PeriodJobOrders.JobOrdersNumber, 0)																				JobOrdersNumber 
	 ,((DATEDIFF(dd, Bdp.StartDate, Bdp.EndDate) + 1 - ISNULL(PeriodWorkingDays.VacationDaysCount, 0)) * Pl.ProductionCapacity)	ProductionLineProductionCapacity 
	 ,ISNULL(PeriodJobOrders.ActualProductionQty, 0)																			ProductionLineUsedProductionCapacity 
	 ,CAST(0.0 AS FLOAT)																										UsedCapacityAverage 
	 ,0																															PeriodWorkingDays
	 ,1																															Type
INTO #Result
FROM Bdp000 Bdp
	CROSS JOIN ProductionLine000 Pl
	LEFT JOIN  
	( 
		 SELECT  
			  Bdp.Guid PeriodGuid 
			  ,SUM(1)  VacationDaysCount 
		 FROM Bdp000 Bdp 
			INNER JOIN DistCalendar000 DC ON DC.Date BETWEEN Bdp.StartDate AND Bdp.EndDate 
		 GROUP BY Bdp.Guid, Bdp.StartDate, Bdp.EndDate 
	)PeriodWorkingDays ON PeriodWorkingDays.PeriodGuid = Bdp.Guid
	LEFT JOIN
	(
		SELECT 
			Bdp.Guid											PeriodGuid
			,Jo.ProductionLine									ProductionLine
			,SUM(1)												JobOrdersNumber
			,SUM(PlG.ConversionFactor * Jo.ActualProductionQty) ActualProductionQty
		FROM JobOrder000 Jo
		INNER JOIN Mi000 Mi ON Mi.ParentGuid = Jo.Guid AND Mi.Type = 0
		INNER JOIN Mt000 Mt ON Mt.Guid = Mi.MatGuid
		INNER JOIN ProductionLineGroup000 PlG ON Jo.ProductionLine = PLG.ProductionLine AND Mt.GroupGuid IN (SELECT Guid FROM dbo.fnGetGroupsList(PLG.GroupGuid)) 
		INNER JOIN Bdp000 Bdp ON Jo.StartDate BETWEEN Bdp.StartDate AND Bdp.EndDate
		GROUP BY Bdp.Guid
				,Jo.ProductionLine
	)PeriodJobOrders ON PeriodJobOrders.PeriodGuid = Bdp.Guid AND PeriodJobOrders.ProductionLine = Pl.Guid
	WHERE	(ISNULL(@ProductionLine, 0x0) = 0x0 OR Pl.Guid = @ProductionLine)
		AND	(Bdp.StartDate BETWEEN @FromDate AND @ToDate)
		AND (Bdp.EndDate BETWEEN @FromDate AND @ToDate)
	
INSERT INTO #Result 
SELECT 
	 ProductionLineGuid 
	 ,ProductionLineName 
	 ,0x0 
	 ,'' 
	 ,'1-1-1980' 
	 ,SUM(JobOrdersNumber) 
	 ,SUM(ProductionLineProductionCapacity) 
	 ,SUM(ProductionLineUsedProductionCapacity) 
	 ,0
	 ,0
	 ,1
FROM #Result 
GROUP BY ProductionLineGuid 
  ,ProductionLineName 

INSERT INTO #Result 
SELECT 
	 0x0 
	 ,'ííííííííííííííí' 
	 ,PeriodGuid 
	 ,PeriodName 
	 ,PeriodStartDate 
	 ,SUM(JobOrdersNumber) 
	 ,SUM(ProductionLineProductionCapacity) 
	 ,SUM(ProductionLineUsedProductionCapacity) 
	 ,0
	 ,0
	 ,1
FROM #Result 
GROUP BY PeriodGuid 
  ,PeriodName 
  ,PeriodStartDate 
 
UPDATE #Result SET UsedCapacityAverage = CASE ProductionLineProductionCapacity WHEN 0 THEN 0 ELSE ProductionLineUsedProductionCapacity * 100 / ProductionLineProductionCapacity END

INSERT INTO #Result 
SELECT 
	 0x0 
	 ,'' 
	 ,r.PeriodGuid 
	 ,r.PeriodName 
	 ,r.PeriodStartDate 
	 ,0
	 ,0
	 ,0
	 ,0
	 ,ISNULL((DATEDIFF(dd, Bdp.StartDate, Bdp.EndDate) + 1 - ISNULL(PeriodWorkingDays.VacationDaysCount, 0)), 0)
	 ,0
FROM #Result r 
LEFT JOIN Bdp000 Bdp ON Bdp.Guid = r.PeriodGuid
LEFT JOIN  
	( 
		 SELECT  
			  Bdp.Guid PeriodGuid 
			  ,SUM(1)  VacationDaysCount 
		 FROM Bdp000 Bdp 
			INNER JOIN DistCalendar000 DC ON DC.Date BETWEEN Bdp.StartDate AND Bdp.EndDate 
		 GROUP BY Bdp.Guid
	)PeriodWorkingDays ON PeriodWorkingDays.PeriodGuid = r.PeriodGuid
GROUP BY r.PeriodGuid 
		,r.PeriodName 
		,r.PeriodStartDate 
		,Bdp.StartDate
		,Bdp.EndDate
		,PeriodWorkingDays.VacationDaysCount

SELECT * FROM #Result ORDER BY Type, ProductionLineName, PeriodStartDate
######################################################
CREATE PROCEDURE PrcCheckProductionPlanGroupsAndPeriods
	@Guid					UNIQUEIDENTIFIER
	,@ProductionLineGuid	UNIQUEIDENTIFIER
	,@FromDate				DATE
	,@ToDate				DATE
	--,@s int
AS 
	SET NOCOUNT ON  
	
	SELECT PPG.GroupGuid  Guid
	INTO #Groups
	FROM ProductionPlan000 PP 
	INNER JOIN Bdp000 StartPeriod ON StartPeriod.Guid = PP.FromPeriod 
	INNER JOIN Bdp000 EndPeriod ON EndPeriod.Guid = PP.ToPeriod  
	LEFT JOIN ProductionPlanGroups000 PPG ON PP.Guid = PPG.PlanGuid
	WHERE (
			(@FromDate BETWEEN StartPeriod.StartDate AND EndPeriod.EndDate) 
			OR 
			(@ToDate BETWEEN StartPeriod.StartDate AND EndPeriod.EndDate) 
			OR 
			(StartPeriod.StartDate BETWEEN @FromDate AND @ToDate) 
			OR 
			(EndPeriod.EndDate BETWEEN @FromDate AND @ToDate) 
		)
		AND PP.Guid <> @Guid
	
	INSERT INTO #Groups	
	SELECT PLG.GroupGuid FROM ProductionPlan000 PP 
	INNER JOIN Bdp000 StartPeriod ON StartPeriod.Guid = PP.FromPeriod 
	INNER JOIN Bdp000 EndPeriod ON EndPeriod.Guid = PP.ToPeriod  
	LEFT JOIN ProductionLine000 Pl ON Pl.Guid = PP.ProductionLineGuid
	LEFT JOIN ProductionLineGroup000 PLG ON PLG.ProductionLine = Pl.Guid
	WHERE (
			(@FromDate BETWEEN StartPeriod.StartDate AND EndPeriod.EndDate) 
			OR 
			(@ToDate BETWEEN StartPeriod.StartDate AND EndPeriod.EndDate) 
			OR 
			(StartPeriod.StartDate BETWEEN @FromDate AND @ToDate) 
			OR 
			(EndPeriod.EndDate BETWEEN @FromDate AND @ToDate) 
		)
		AND PP.Guid <> @Guid
		
	IF(ISNULL(@ProductionLineGuid, 0x0) <> 0x0)
	BEGIN
		SELECT 
			G.Guid 
		FROM ProductionLineGroup000 PLG
		INNER JOIN #Groups G ON PLG.GroupGuid = G.Guid
		WHERE PLG.ProductionLine = @ProductionLineGuid
	END
	ELSE
	BEGIN
		SELECT 
			G.Guid
		FROM ProductionPlanGroups000 PPG
		INNER JOIN #Groups G ON G.Guid = PPG.GroupGuid
		WHERE PPG.PlanGuid = @Guid
	END
######################################################
CREATE PROCEDURE GetPlanPeriods
    @PlanGuid	UNIQUEIDENTIFIER,
    @IsMain		INT
AS
	SET NOCOUNT ON 
	
	IF(@IsMain = 1)
		SELECT 
			Bdp.Guid
			,Bdp.Name
		FROM 
		MainProductionPlan000 MPP
		INNER JOIN MainProductionPlanItem000 MPPI ON MPPI.ParentGuid = MPP.Guid
		INNER JOIN MainProductionPlanDetail000 MPPD ON MPPD.ParentGuid = MPPI.Guid
		INNER JOIN Bdp000 Bdp ON Bdp.Guid = MPPD.PeriodGuid
		WHERE MPP.ParentGuid = @PlanGuid
		GROUP BY
			Bdp.Guid
			,Bdp.Name
			,Bdp.StartDate
		ORDER BY Bdp.StartDate
		
	ELSE
		SELECT 
			Bdp.Guid
			,Bdp.Name
		FROM 
		ModifiedProductionPlan000 MPP
		INNER JOIN ModifiedProductionPlanItem000 MPPI ON MPPI.ParentGuid = MPP.Guid
		INNER JOIN ModifiedProductionPlanDetail000 MPPD ON MPPD.ParentGuid = MPPI.Guid
		INNER JOIN Bdp000 Bdp ON Bdp.Guid = MPPD.PeriodGuid
		WHERE MPP.ParentGuid = @PlanGuid
		GROUP BY
			Bdp.Guid
			,Bdp.Name
			,Bdp.StartDate
		ORDER BY Bdp.StartDate
######################################################
CREATE PROCEDURE GetPlanItems
    @PlanGuid     UNIQUEIDENTIFIER, 
    @PeriodGuid UNIQUEIDENTIFIER, 
    @IsMain       INT 
AS 
      SET NOCOUNT ON  
       
      DECLARE @SafeStockDays FLOAT  
      SELECT @SafeStockDays = CAST(value AS FLOAT) FROM op000 WHERE name = 'ProductAvailabilitySafeStockPeriod'  
      
      DECLARE @ProductionPlanUnit   INT
      SELECT @ProductionPlanUnit = Unit FROM ProductionPlan000 WHERE Guid = @PlanGuid
      
      IF(ISNULL(@PeriodGuid, 0x0) <> 0x0) 
       
            IF(@IsMain = 1) 
                  SELECT  
                        MPPI.Guid                                                                                                                     Guid 
                        ,Pl.Code + '-' + Pl.Name                                                                                                      ProductionLineName 
                        ,Mt.Code + '-' + Mt.Name                                                                                                      MaterialName 
                        ,MPPD.FirstPeriodQty / MaterialUnity.UnitFact                                                                                 FirstPeriodQty 
                        ,MPPD.PlanedQty         / MaterialUnity.UnitFact                                                                              PlanedQty 
                        ,MPPD.JobOrderQty                                                                                                             JobOrderQty 
                        ,MPPD.TargetQty / MaterialUnity.UnitFact                                                                                      TargetQty 
                        ,MPPI.JobOrderAvarage / MaterialUnity.UnitFact                                                                                JobOrderAverage 
                        ,CASE PP.QuantityAvailabilityOption  
                              WHEN 0 THEN 0 
                              WHEN 1 THEN CASE (DATEDIFF(DAY, Bdp.StartDate, Bdp.EndDate) + 1 - (SELECT COUNT(*) FROM DistCalendar000 WHERE Date BETWEEN Bdp.StartDate AND Bdp.EndDate)) 
                                                      WHEN 0 THEN 0 
                                                      ELSE MPPD.TargetQty * @SafeStockDays / (DATEDIFF(DAY, Bdp.StartDate, Bdp.EndDate) + 1 - (SELECT COUNT(*) FROM DistCalendar000 WHERE Date BETWEEN Bdp.StartDate AND Bdp.EndDate))  
                                                END 
                              WHEN 2 THEN Mt.Low        
                              WHEN 3 THEN Mt.OrderLimit  
                              ELSE Mt.High  
                        END   / MaterialUnity.UnitFact																									MatLimit 
                        ,MaterialUnity.UnitFact																											MaterialUnity
                  FROM  
                  MainProductionPlan000 MPP 
                  INNER JOIN ProductionPlan000 PP ON PP.Guid = MPP.ParentGuid 
                  INNER JOIN MainProductionPlanItem000 MPPI ON MPPI.ParentGuid = MPP.Guid 
                  INNER JOIN MainProductionPlanDetail000 MPPD ON MPPD.ParentGuid = MPPI.Guid 
                  INNER JOIN Bdp000 Bdp ON Bdp.Guid = MPPD.PeriodGuid 
                  INNER JOIN Mt000 Mt ON Mt.Guid = MPPI.MaterialGuid 
                  INNER JOIN ProductionLine000 Pl ON Pl.Guid = MPPI.ProductionLineGuid 
                  INNER JOIN 
                  (
                        SELECT Guid MaterialGuid
                                    ,CASE @ProductionPlanUnit WHEN 0 THEN 1 WHEN 1 THEN CASE Unit2Fact WHEN 0 THEN 1 ELSE Unit2Fact END WHEN 2 THEN CASE Unit3Fact WHEN 0 THEN 1 ELSE Unit3Fact END WHEN 3 THEN CASE DefUnit WHEN 1 THEN 1 WHEN 2 THEN CASE Unit2Fact WHEN 0 THEN 1 ELSE Unit2Fact END WHEN 3 THEN CASE Unit3Fact WHEN 0 THEN 1 ELSE Unit3Fact END END END UnitFact
                        FROM Mt000
                  )MaterialUnity ON MaterialUnity.MaterialGuid = Mt.Guid
                  WHERE MPP.ParentGuid = @PlanGuid 
                        AND MPPD.PeriodGuid = @PeriodGuid 
                  ORDER BY Mt.Code + '-' + Mt.Name 
             
            ELSE 
                  SELECT  
                        MPPI.Guid																																				Guid 
                        ,Pl.Code + '-' + Pl.Name																																ProductionLineName 
                        ,Mt.Code + '-' + Mt.Name																																MaterialName 
                        ,MPPD.FirstPeriodQty/ MaterialUnity.UnitFact																											FirstPeriodQty 
                        ,MPPD.PlanedQty/ MaterialUnity.UnitFact                                                                                                                 PlanedQty 
                        ,MPPD.JobOrderQty																																		JobOrderQty 
                        ,MPPD.TargetQty/ MaterialUnity.UnitFact                                                                                                                 TargetQty 
                        ,MPPI.JobOrderAvarage/ MaterialUnity.UnitFact																											JobOrderAverage 
                        ,CASE PP.QuantityAvailabilityOption 
                              WHEN 0 THEN 0 
                              WHEN 1 THEN CASE (DATEDIFF(DAY, Bdp.StartDate, Bdp.EndDate) + 1 - (SELECT COUNT(*) FROM DistCalendar000 WHERE Date BETWEEN Bdp.StartDate AND Bdp.EndDate)) 
                                                      WHEN 0 THEN 0 
                                                      ELSE MPPD.TargetQty * @SafeStockDays / (DATEDIFF(DAY, Bdp.StartDate, Bdp.EndDate) + 1 - (SELECT COUNT(*) FROM DistCalendar000 WHERE Date BETWEEN Bdp.StartDate AND Bdp.EndDate))  
                                                END 
                               
                              WHEN 2 THEN Mt.Low  
                              WHEN 3 THEN Mt.OrderLimit  
                              ELSE Mt.High  
                        END   / MaterialUnity.UnitFact                                                                                                                          MatLimit 
                        ,MaterialUnity.UnitFact																																	MaterialUnity
                  FROM  
                  ModifiedProductionPlan000 MPP 
                  INNER JOIN ProductionPlan000 PP ON PP.Guid = MPP.ParentGuid 
                  INNER JOIN ModifiedProductionPlanItem000 MPPI ON MPPI.ParentGuid = MPP.Guid 
                  INNER JOIN ModifiedProductionPlanDetail000 MPPD ON MPPD.ParentGuid = MPPI.Guid 
                  INNER JOIN Bdp000 Bdp ON Bdp.Guid = MPPD.PeriodGuid 
                  INNER JOIN Mt000 Mt ON Mt.Guid = MPPI.MaterialGuid 
                  INNER JOIN ProductionLine000 Pl ON Pl.Guid = MPPI.ProductionLineGuid 
                  INNER JOIN 
                  (
                        SELECT Guid MaterialGuid
                                    ,CASE @ProductionPlanUnit WHEN 0 THEN 1 WHEN 1 THEN CASE Unit2Fact WHEN 0 THEN 1 ELSE Unit2Fact END WHEN 2 THEN CASE Unit3Fact WHEN 0 THEN 1 ELSE Unit3Fact END WHEN 3 THEN CASE DefUnit WHEN 1 THEN 1 WHEN 2 THEN CASE Unit2Fact WHEN 0 THEN 1 ELSE Unit2Fact END WHEN 3 THEN CASE Unit3Fact WHEN 0 THEN 1 ELSE Unit3Fact END END END UnitFact
                        FROM Mt000
                  )MaterialUnity ON MaterialUnity.MaterialGuid = Mt.Guid
                  WHERE MPP.ParentGuid = @PlanGuid 
                        AND MPPD.PeriodGuid = @PeriodGuid 
                  ORDER BY Mt.Code + '-' + Mt.Name    
       
      ELSE 
            IF(@IsMain = 1) 
       
                  SELECT  
                        CAST(0x0 AS UNIQUEIDENTIFIER) AS                                                                                                 [Guid] 
                        ,Pl.Code + '-' + Pl.Name                                                                                                            ProductionLineName 
                        ,Mt.Code + '-' + Mt.Name                                                                                                            MaterialName 
                        ,SUM(MPPD.FirstPeriodQty/ MaterialUnity.UnitFact)                                                                                                           FirstPeriodQty 
                        ,SUM(MPPD.PlanedQty/ MaterialUnity.UnitFact)                                                                                                                PlanedQty 
                        ,SUM(MPPD.JobOrderQty)                                                                                                              JobOrderQty 
                        ,SUM(MPPD.TargetQty/ MaterialUnity.UnitFact)                                                                                                                TargetQty 
                        ,AVG(MPPI.JobOrderAvarage/ MaterialUnity.UnitFact)                                                                                                          JobOrderAverage 
                        ,AVG( 
                              CASE PP.QuantityAvailabilityOption 
                                    WHEN 0 THEN 0 
                                    WHEN 1 THEN CASE (DATEDIFF(DAY, Bdp.StartDate, Bdp.EndDate) + 1 - Bdp.VacationsDaysNumber)  
                                                            WHEN 0 THEN 0  
                                                            ELSE MPPD.TargetQty * @SafeStockDays / (DATEDIFF(DAY, Bdp.StartDate, Bdp.EndDate) + 1 - Bdp.VacationsDaysNumber)  
                                                      END 
                                     
                                    WHEN 2 THEN Mt.Low  
                                    WHEN 3 THEN Mt.OrderLimit  
                                    ELSE Mt.High  
                              END / MaterialUnity.UnitFact
                              )                                                                                                                                         MatLimit 
                         ,AVG(MaterialUnity.UnitFact)																													MaterialUnity
                  FROM  
                  MainProductionPlan000 MPP 
                  INNER JOIN ProductionPlan000 PP ON PP.Guid = MPP.ParentGuid 
                  INNER JOIN MainProductionPlanItem000 MPPI ON MPPI.ParentGuid = MPP.Guid 
                  INNER JOIN MainProductionPlanDetail000 MPPD ON MPPD.ParentGuid = MPPI.Guid 
                  LEFT JOIN 
                  ( 
                        SELECT Bdp.Guid, Bdp.StartDate, Bdp.EndDate, (SELECT COUNT(*) FROM DistCalendar000 WHERE Date BETWEEN Bdp.StartDate AND Bdp.EndDate) VacationsDaysNumber 
                        FROM Bdp000 Bdp 
                  )Bdp ON Bdp.Guid = MPPD.PeriodGuid 
                  INNER JOIN Mt000 Mt ON Mt.Guid = MPPI.MaterialGuid 
                  INNER JOIN ProductionLine000 Pl ON Pl.Guid = MPPI.ProductionLineGuid 
                  INNER JOIN 
                  (
                        SELECT Guid MaterialGuid
                                    ,CASE @ProductionPlanUnit WHEN 0 THEN 1 WHEN 1 THEN CASE Unit2Fact WHEN 0 THEN 1 ELSE Unit2Fact END WHEN 2 THEN CASE Unit3Fact WHEN 0 THEN 1 ELSE Unit3Fact END WHEN 3 THEN CASE DefUnit WHEN 1 THEN 1 WHEN 2 THEN CASE Unit2Fact WHEN 0 THEN 1 ELSE Unit2Fact END WHEN 3 THEN CASE Unit3Fact WHEN 0 THEN 1 ELSE Unit3Fact END END END UnitFact
                        FROM Mt000
                  )MaterialUnity ON MaterialUnity.MaterialGuid = Mt.Guid
                  WHERE MPP.ParentGuid = @PlanGuid 
                  GROUP BY 
                        Pl.Code 
                        ,Pl.Name 
                        ,Mt.Code 
                        ,Mt.Name 
                  ORDER BY Mt.Code + '-' + Mt.Name 
             
            ELSE 
                  SELECT  
                        CAST(0x0 AS UNIQUEIDENTIFIER) AS                                                                                                 [Guid] 
                        ,Pl.Code + '-' + Pl.Name                                                                                                            ProductionLineName 
                        ,Mt.Code + '-' + Mt.Name                                                                                                            MaterialName 
                        ,SUM(MPPD.FirstPeriodQty/ MaterialUnity.UnitFact)                                                                                                           FirstPeriodQty 
                        ,SUM(MPPD.PlanedQty/ MaterialUnity.UnitFact)                                                                                                                PlanedQty 
                        ,SUM(MPPD.JobOrderQty)                                                                                                              JobOrderQty 
                        ,SUM(MPPD.TargetQty/ MaterialUnity.UnitFact)                                                                                                                TargetQty 
                        ,AVG(MPPI.JobOrderAvarage/ MaterialUnity.UnitFact)                                                                                                          JobOrderAverage 
                        ,AVG( 
                              CASE PP.QuantityAvailabilityOption 
                                    WHEN 0 THEN 0 
                                    WHEN 1 THEN CASE (DATEDIFF(DAY, Bdp.StartDate, Bdp.EndDate) + 1 - Bdp.VacationsDaysNumber)  
                                                            WHEN 0 THEN 0  
                                                            ELSE MPPD.TargetQty * @SafeStockDays / (DATEDIFF(DAY, Bdp.StartDate, Bdp.EndDate) + 1 - Bdp.VacationsDaysNumber)  
                                                      END 
                                     
                                    WHEN 2 THEN Mt.Low  
                                    WHEN 3 THEN Mt.OrderLimit  
                                    ELSE Mt.High  
                              END / MaterialUnity.UnitFact
                              )                                                                                                                                         MatLimit 
                        ,AVG(MaterialUnity.UnitFact)																													MaterialUnity
                  FROM  
                  ModifiedProductionPlan000 MPP 
                  INNER JOIN ProductionPlan000 PP ON PP.Guid = MPP.ParentGuid 
                  INNER JOIN ModifiedProductionPlanItem000 MPPI ON MPPI.ParentGuid = MPP.Guid 
                  INNER JOIN ModifiedProductionPlanDetail000 MPPD ON MPPD.ParentGuid = MPPI.Guid 
                  LEFT JOIN 
                  ( 
                        SELECT Bdp.Guid, Bdp.StartDate, Bdp.EndDate, (SELECT COUNT(*) FROM DistCalendar000 WHERE Date BETWEEN Bdp.StartDate AND Bdp.EndDate) VacationsDaysNumber 
                        FROM Bdp000 Bdp 
                  )Bdp ON Bdp.Guid = MPPD.PeriodGuid 
                  INNER JOIN Mt000 Mt ON Mt.Guid = MPPI.MaterialGuid 
                  INNER JOIN ProductionLine000 Pl ON Pl.Guid = MPPI.ProductionLineGuid 
                  INNER JOIN 
                  (
                        SELECT Guid MaterialGuid
                                    ,CASE @ProductionPlanUnit WHEN 0 THEN 1 WHEN 1 THEN CASE Unit2Fact WHEN 0 THEN 1 ELSE Unit2Fact END WHEN 2 THEN CASE Unit3Fact WHEN 0 THEN 1 ELSE Unit3Fact END WHEN 3 THEN CASE DefUnit WHEN 1 THEN 1 WHEN 2 THEN CASE Unit2Fact WHEN 0 THEN 1 ELSE Unit2Fact END WHEN 3 THEN CASE Unit3Fact WHEN 0 THEN 1 ELSE Unit3Fact END END END UnitFact
                        FROM Mt000
                  )MaterialUnity ON MaterialUnity.MaterialGuid = Mt.Guid
                  WHERE MPP.ParentGuid = @PlanGuid 
                  GROUP BY 
                        Pl.Code 
                        ,Pl.Name 
                        ,Mt.Code 
                        ,Mt.Name 
                  ORDER BY Mt.Code + '-' + Mt.Name
######################################################
CREATE PROCEDURE ProductionPlanReport
    @Guid		UNIQUEIDENTIFIER 
    ,@IsMain	INT = 1
AS
    SET NOCOUNT ON
    
    DECLARE @ProductionPlanUnit INT
    
    SELECT  @ProductionPlanUnit = Unit
	FROM ProductionPlan000 
	WHERE Guid = @Guid 
    
    CREATE TABLE #Result(
		MaterialGuid		UNIQUEIDENTIFIER
		,MaterialName		NVARCHAR(250) COLLATE ARABIC_CI_AI
		,GroupGuid			UNIQUEIDENTIFIER
		,GroupName			NVARCHAR(250) COLLATE ARABIC_CI_AI
		,ProductionLineGuid	UNIQUEIDENTIFIER
		,ProductionLineName	NVARCHAR(250) COLLATE ARABIC_CI_AI
		,PeriodGuid			UNIQUEIDENTIFIER
		,PeriodName			NVARCHAR(250) COLLATE ARABIC_CI_AI
		,PeriodStartDate	DATE
		,FirstPeriodQty		FLOAT
		,PlanedQty			FLOAT
		,JobOrderQty		FLOAT
		,TotalAvailable		FLOAT
		,TargetQty			FLOAT
		,LatPeriodQty		FLOAT
		,JobOrderAverage	FLOAT
		,MatLimit			FLOAT
		,SafeStock			FLOAT
		,RowType			INT
		,RowOrder			INT
    )
    
    IF(@IsMain = 1)
    BEGIN
		INSERT INTO #Result
		SELECT 
			Mt.Guid																	MaterialGuid
			,Mt.Name																MaterialName
			,Gr.Guid																GroupGuid
			,Gr.Name																GroupName
			,Pl.Guid																ProductionLineGuid
			,Pl.Name																ProductionLineName
			,Bdp.Guid																PeriodGuid
			,Bdp.Name																PeriodName
			,Bdp.StartDate															PeriodStartDate
			,SUM(MPPD.FirstPeriodQty / MaterialUnity.UnitFact)												FirstPeriodQty
			,SUM(MPPD.PlanedQty / MaterialUnity.UnitFact)													PlanedQty
			,SUM(MPPD.JobOrderQty)													JobOrderQty
			,CAST(0 AS FLOAT)														TotalAvailable
			,SUM(MPPD.TargetQty / MaterialUnity.UnitFact)													TargetQty
			,CAST(0 AS FLOAT)														LatPeriodQty
			,MPPI.JobOrderAvarage / MaterialUnity.UnitFact													JobOrderAverage
			,MPPI.MinLimit / MaterialUnity.UnitFact															MatLimit
			,MPPI.SafeStock / MaterialUnity.UnitFact															SafeStock
			,0																		RowType
			,0																		RowOrder
		FROM ProductionPlan000 PP
		INNER JOIN MainProductionPlan000 MPP ON PP.Guid = MPP.ParentGuid
		INNER JOIN MainProductionPlanItem000 MPPI ON MPP.Guid = MPPI.ParentGuid
		INNER JOIN MainProductionPlanDetail000 MPPD ON MPPI.Guid = MPPD.ParentGuid
		INNER JOIN Bdp000 Bdp ON Bdp.Guid = MPPD.PeriodGuid
		INNER JOIN Mt000 Mt ON Mt.Guid = MPPI.MaterialGuid
		INNER JOIN Gr000 Gr ON Gr.Guid = Mt.GroupGuid
		INNER JOIN ProductionLine000 Pl ON Pl.Guid = MPPI.ProductionLineGuid
		INNER JOIN 
        (
              SELECT Guid MaterialGuid
                          ,CASE @ProductionPlanUnit WHEN 0 THEN 1 WHEN 1 THEN CASE Unit2Fact WHEN 0 THEN 1 ELSE Unit2Fact END WHEN 2 THEN CASE Unit3Fact WHEN 0 THEN 1 ELSE Unit3Fact END WHEN 3 THEN CASE DefUnit WHEN 1 THEN 1 WHEN 2 THEN CASE Unit2Fact WHEN 0 THEN 1 ELSE Unit2Fact END WHEN 3 THEN CASE Unit3Fact WHEN 0 THEN 1 ELSE Unit3Fact END END END UnitFact
              FROM Mt000
        )MaterialUnity ON MaterialUnity.MaterialGuid = Mt.Guid
		WHERE PP.Guid = @Guid
		GROUP BY Mt.Guid
				,Mt.Name
				,Gr.Guid
				,Gr.Name
				,Pl.Guid
				,Pl.Name
				,Bdp.Guid
				,Bdp.Name
				,Bdp.StartDate
				,MPPI.JobOrderAvarage
				,MPPI.MinLimit
				,MPPI.SafeStock
				,MaterialUnity.UnitFact
	END
	ELSE
	BEGIN
		INSERT INTO #Result
		SELECT 
			Mt.Guid																	MaterialGuid
			,Mt.Name																MaterialName
			,Gr.Guid																GroupGuid
			,Gr.Name																GroupName
			,Pl.Guid																ProductionLineGuid
			,Pl.Name																ProductionLineName
			,Bdp.Guid																PeriodGuid
			,Bdp.Name																PeriodName
			,Bdp.StartDate															PeriodStartDate
			,SUM(MPPD.FirstPeriodQty / MaterialUnity.UnitFact)												FirstPeriodQty
			,SUM(MPPD.PlanedQty / MaterialUnity.UnitFact)													PlanedQty
			,SUM(MPPD.JobOrderQty)													JobOrderQty
			,CAST(0 AS FLOAT)														TotalAvailable
			,SUM(MPPD.TargetQty / MaterialUnity.UnitFact)													TargetQty
			,CAST(0 AS FLOAT)														LatPeriodQty
			,MPPI.JobOrderAvarage / MaterialUnity.UnitFact													JobOrderAverage
			,MPPI.MinLimit / MaterialUnity.UnitFact															MatLimit
			,MPPI.SafeStock / MaterialUnity.UnitFact															SafeStock
			,0																		RowType
			,0																		RowOrder
		FROM ProductionPlan000 PP
		INNER JOIN ModifiedProductionPlan000 MPP ON PP.Guid = MPP.ParentGuid
		INNER JOIN ModifiedProductionPlanItem000 MPPI ON MPP.Guid = MPPI.ParentGuid
		INNER JOIN ModifiedProductionPlanDetail000 MPPD ON MPPI.Guid = MPPD.ParentGuid
		INNER JOIN Bdp000 Bdp ON Bdp.Guid = MPPD.PeriodGuid
		INNER JOIN Mt000 Mt ON Mt.Guid = MPPI.MaterialGuid
		INNER JOIN Gr000 Gr ON Gr.Guid = Mt.GroupGuid
		INNER JOIN ProductionLine000 Pl ON Pl.Guid = MPPI.ProductionLineGuid
		INNER JOIN 
        (
              SELECT Guid MaterialGuid
                          ,CASE @ProductionPlanUnit WHEN 0 THEN 1 WHEN 1 THEN CASE Unit2Fact WHEN 0 THEN 1 ELSE Unit2Fact END WHEN 2 THEN CASE Unit3Fact WHEN 0 THEN 1 ELSE Unit3Fact END WHEN 3 THEN CASE DefUnit WHEN 1 THEN 1 WHEN 2 THEN CASE Unit2Fact WHEN 0 THEN 1 ELSE Unit2Fact END WHEN 3 THEN CASE Unit3Fact WHEN 0 THEN 1 ELSE Unit3Fact END END END UnitFact
              FROM Mt000
        )MaterialUnity ON MaterialUnity.MaterialGuid = Mt.Guid
		WHERE PP.Guid = @Guid
		GROUP BY Mt.Guid
				,Mt.Name
				,Gr.Guid
				,Gr.Name
				,Pl.Guid
				,Pl.Name
				,Bdp.Guid
				,Bdp.Name
				,Bdp.StartDate
				,MPPI.JobOrderAvarage
				,MPPI.MinLimit
				,MPPI.SafeStock	
				,MaterialUnity.UnitFact
	END
			
	
			
	INSERT INTO #Result
	SELECT
		MaterialGuid
		,MaterialName
		,GroupGuid
		,GroupName
		,ProductionLineGuid
		,ProductionLineName
		,0x0
		,''
		,'1-1-1980'
		,SUM(FirstPeriodQty)
		,SUM(PlanedQty)
		,SUM(JobOrderQty)
		,CAST(0 AS FLOAT)
		,SUM(TargetQty)
		,CAST(0 AS FLOAT)
		,AVG(JobOrderAverage)
		,AVG(MatLimit)
		,AVG(SafeStock)
		,1
		,0
	FROM #Result
	GROUP BY MaterialGuid
			,MaterialName
			,GroupGuid
			,GroupName
			,ProductionLineGuid
			,ProductionLineName
			
	INSERT INTO #Result
	SELECT
		0x0
		,''
		,GroupGuid
		,GroupName
		,ProductionLineGuid
		,ProductionLineName
		,PeriodGuid
		,PeriodName
		,PeriodStartDate
		,SUM(FirstPeriodQty)
		,SUM(PlanedQty)
		,SUM(JobOrderQty)
		,CAST(0 AS FLOAT)
		,SUM(TargetQty)
		,CAST(0 AS FLOAT)
		,SUM(JobOrderAverage)
		,SUM(MatLimit)
		,SUM(SafeStock)
		,2
		,0
	FROM #Result
	GROUP BY GroupGuid
			,GroupName
			,ProductionLineGuid
			,ProductionLineName
			,PeriodGuid
			,PeriodName
			,PeriodStartDate
			
	INSERT INTO #Result
	SELECT
		0x0
		,''
		,0x0
		,'íííííííííííííííí'
		,0x0
		,''
		,PeriodGuid
		,PeriodName
		,PeriodStartDate
		,SUM(FirstPeriodQty)
		,SUM(PlanedQty)
		,SUM(JobOrderQty)
		,CAST(0 AS FLOAT)
		,SUM(TargetQty)
		,CAST(0 AS FLOAT)
		,SUM(JobOrderAverage)
		,SUM(MatLimit)
		,SUM(SafeStock)
		,RowType
		,1
	FROM #Result
	WHERE RowType IN (0, 1)
	GROUP BY PeriodGuid
			,PeriodName
			,PeriodStartDate
			,RowType
			
			
	INSERT INTO #Result
	SELECT
		0x0
		,''
		,0x0
		,'íííííííííííííííí'
		,0x0
		,''
		,PeriodGuid
		,PeriodName
		,PeriodStartDate
		,0
		,SUM(CASE Unit2Fact WHEN 0 THEN 0 ELSE PlanedQty / Unit2Fact END)
		,0
		,0
		,0
		,0
		,0
		,0
		,0
		,RowType
		,2
	FROM #Result R
	INNER JOIN Mt000 Mt ON Mt.Guid = R.MaterialGuid 
	WHERE R.RowType IN (0, 1)
	GROUP BY PeriodGuid
			,PeriodName
			,PeriodStartDate
			,RowType
			
	INSERT INTO #Result
	SELECT
		0x0
		,''
		,0x0
		,'íííííííííííííííí'
		,0x0
		,''
		,PeriodGuid
		,PeriodName
		,PeriodStartDate
		,0
		,SUM(CASE Unit3Fact WHEN 0 THEN 0 ELSE PlanedQty / PlG.ConversionFactor END)
		,0
		,0
		,0
		,0
		,0
		,0
		,0
		,RowType
		,3
	FROM #Result R
	INNER JOIN ProductionLineGroup000 PlG ON (PlG.GroupGuid = R.GroupGuid OR PlG.GroupGuid IN (SELECT Guid FROM dbo.fnGetGroupParents(R.GroupGuid)) )
	INNER JOIN Mt000 Mt ON Mt.Guid = R.MaterialGuid 
	WHERE R.RowType IN (0, 1)	
	GROUP BY PeriodGuid
			,PeriodName
			,PeriodStartDate
			,RowType
	
	
	UPDATE #Result SET TotalAvailable = ISNULL(FirstPeriodQty, 0) + ISNULL(PlanedQty, 0)
	UPDATE #Result SET LatPeriodQty = ISNULL(TotalAvailable, 0) - ISNULL(TargetQty, 0)
	
	INSERT INTO #Result
	SELECT
		0x0
		,''
		,0x0
		,''
		,0x0
		,''
		,PeriodGuid
		,PeriodName
		,PeriodStartDate
		,0
		,0
		,0
		,0
		,0
		,0
		,0
		,0
		,0
		,0
		,-1
	FROM #Result
	WHERE ISNULL(PeriodGuid, 0x0) <> 0x0
	GROUP BY PeriodGuid
			,PeriodName
			,PeriodStartDate
			
	SELECT * 
	FROM #Result
	ORDER BY 
			RowOrder
			,GroupName
			,ProductionLineName
			,MaterialName
			,PeriodStartDate
	
	DROP TABLE #Result
######################################################
CREATE PROCEDURE PrcCommitModifiedPlanChanges 
	@ProductionPlanGuid	UNIQUEIDENTIFIER
AS 
	DECLARE @MainPlanGuid UNIQUEIDENTIFIER
	DECLARE @ModifiedPlanGuid UNIQUEIDENTIFIER
	
	SELECT @MainPlanGuid = Guid FROM MainProductionPlan000 WHERE ParentGuid = @ProductionPlanGuid
	SELECT @ModifiedPlanGuid = Guid FROM ModifiedProductionPlan000 WHERE ParentGuid = @ProductionPlanGuid
	
	DELETE FROM MainProductionPlanDetail000
	WHERE ParentGuid IN ( SELECT Guid FROM MainProductionPlanItem000 WHERE ParentGuid = @MainPlanGuid)
	
	DELETE FROM MainProductionPlanItem000 WHERE ParentGuid = @MainPlanGuid
	
	INSERT INTO MainProductionPlanItem000
		SELECT 
			NEWID()
			,@MainPlanGuid
			,ProductionLineGuid
			,MaterialGuid
			,PlanedQty
			,JobOrderQty
			,JobOrderAvarage
			,MinLimit
			,SafeStock
		FROM ModifiedProductionPlanItem000
		WHERE ParentGuid = @ModifiedPlanGuid
	
		INSERT INTO MainProductionPlanDetail000 
		SELECT 
			NEWID()
			,MainPPI.Guid
			,MPPD.PeriodGuid
			,MPPD.FirstPeriodQty
			,MPPD.PlanedQty
			,MPPD.JobOrderQty
			,MPPD.TargetQty
		FROM 
			ModifiedProductionPlanDetail000 MPPD
			INNER JOIN ModifiedProductionPlanItem000 MPPI ON MPPI.Guid = MPPD.ParentGuid
			INNER JOIN ModifiedProductionPlan000 MPP ON MPP.Guid = MPPI.ParentGuid
			INNER JOIN MainProductionPlan000 MainPP ON MPP.ParentGuid = MainPP.ParentGuid
			INNER JOIN MainProductionPlanItem000 MainPPI ON MainPPI.ParentGuid = MainPP.Guid AND MainPPI.MaterialGuid = MPPI.MaterialGuid AND MainPPI.ProductionLineGuid = MPPI.ProductionLineGuid
		WHERE 
			MPP.ParentGuid = @ProductionPlanGuid

	DELETE FROM ProductionPlanApproval000 WHERE ParentGuid = @ProductionPlanGuid
######################################################
CREATE PROCEDURE RepDistributePlansOverPeriods
	@ProductionPlan  UNIQUEIDENTIFIER = 0x0  
	,@Group			 UNIQUEIDENTIFIER = 0x0  
	,@ProductionLine UNIQUEIDENTIFIER = 0x0  
	,@FromPeriodGuid UNIQUEIDENTIFIER = 0x0  
	,@ToPeriodGuid   UNIQUEIDENTIFIER = 0x0
AS   
SET NOCOUNT ON  
--Language
DECLARE @Language bit
SET @Language = (SELECT dbo.fnConnections_GetLanguage()) 
--Date Filter
DECLARE @FromDate DATETIME 
DECLARE @ToDate DATETIME 
--Group Filter
DECLARE @GrpTbl TABLE ([guid] UNIQUEIDENTIFIER, Code nvarchar(100),Name nvarchar(100))
INSERT INTO @GrpTbl ([guid]) values (0x0)
INSERT INTO @GrpTbl 
SELECT grp.[GUID]
	, grp.Code
	, CASE @Language WHEN 0 THEN grp.Name ELSE CASE grp.LatinName WHEN N'' THEN grp.Name ELSE grp.LatinName END	END  
FROM dbo.fnGetGroupsList(@Group) grplst 
INNER JOIN gr000 grp ON grplst.[GUID] = grp.[GUID]
------------------------------------------------------------
--select * from @GrpTbl

IF(ISNULL(@ProductionPlan, 0x0) <> 0x0) 
BEGIN 
	SELECT 
		@FromDate = FromPeriod.StartDate 
		,@ToDate = ToPeriod.EndDate 
	FROM ProductionPlan000 PP 
	INNER JOIN Bdp000 FromPeriod ON PP.FromPeriod = FromPeriod.Guid 
	INNER JOIN Bdp000 ToPeriod ON PP.ToPeriod = ToPeriod.Guid 
	WHERE PP.Guid = @ProductionPlan
END 
ELSE 
BEGIN 
	SELECT @FromDate = StartDate FROM Bdp000 WHERE Guid = @FromPeriodGuid 
	SELECT @ToDate = EndDate FROM Bdp000 WHERE Guid = @ToPeriodGuid 
END 

SELECT DISTINCT
	Period.GUID PeriodGuid 
	, Period.Name PeriodName
	, Period.StartDate PeriodStartDate
	, MtGr.grGUID GroupGuid
	, MtGr.grName GroupName
	, PPlan.Code PlanCode
	, 1 [Type]
INTO #Result
FROM ProductionPlan000 PPlan
	INNER JOIN MainProductionPlan000 MainPlan ON MainPlan.ParentGuid = PPlan.Guid
	INNER JOIN MainProductionPlanItem000 PlanItems ON PlanItems.ParentGuid = MainPlan.Guid
	INNER JOIN ProductionLine000 PLine ON PLine.Guid = PlanItems.ProductionLineGuid 
	INNER JOIN vwMtGr MtGr ON MtGr.mtGUID = PlanItems.MaterialGuid
	INNER JOIN @GrpTbl Gr ON  Gr.guid = MtGr.grGUID
	INNER JOIN Bdp000 FromBdp ON FromBdp.Guid = PPlan.FromPeriod  
	INNER JOIN Bdp000 ToBdp ON ToBdp.Guid = PPlan.ToPeriod  
	INNER JOIN Bdp000 Period ON Period.StartDate >= FromBdp.StartDate AND Period.EndDate <= ToBdp.EndDate 
WHERE (ISNULL(@ProductionPlan, 0x0) = 0x0 OR PPlan.Guid = @ProductionPlan)   
	AND (ISNULL(@ProductionLine, 0x0) = 0x0 OR PlanItems.ProductionLineGuid = @ProductionLine)  
	AND(
			(Period.StartDate BETWEEN @FromDate AND @ToDate) 
			OR 
			(Period.EndDate BETWEEN @FromDate AND @ToDate)
		)
ORDER BY
		MtGr.grName 
		, Period.Name


INSERT INTO #Result 
SELECT 
	PeriodGuid  
	,PeriodName  
	,PeriodStartDate 
	,0x0 
	,'' 
	,'' 
	,0 
FROM #Result 
GROUP BY PeriodGuid  
		,PeriodName  
		,PeriodStartDate 
	
DECLARE @PeriodGuid UNIQUEIDENTIFIER	

SELECT @PeriodGuid = PeriodGuid FROM #Result

INSERT INTO #Result
SELECT 
	Period.Guid  
	,Period.Name  
	,Period.StartDate
	,R.GroupGuid  
	,R.GroupName  
	,''  
	,R.Type 
FROM #Result R
INNER JOIN Bdp000 Period ON (Period.StartDate BETWEEN @FromDate AND @ToDate) AND Period.Guid NOT IN (SELECT PeriodGuid FROM #Result)
WHERE R.PeriodGuid = @PeriodGuid
		
IF((SELECT COUNT(*) FROM #Result) = 0)
	INSERT INTO #Result  
	SELECT  
		Guid   
		,Name   
		,StartDate  
		,0x0  
		,''  
		,''  
		,0  
	FROM Bdp000  
	WHERE 
			StartDate BETWEEN @FromDate AND @ToDate
		AND EndDate BETWEEN @FromDate AND @ToDate

SELECT * FROM #Result ORDER BY Type, GroupName, PeriodStartDate

######################################################
CREATE Function GetPeriodWorkingDaysNumber(	@PeriodGuid uniqueidentifier)
RETURNS INT
AS
Begin

	DECLARE
		@FromDate							DATE,
		@ToDate								DATE,
		@FirstPeriodDate					DATE,
		@PeriodVacationsNumber				INT = 0,
		@PeriodDaysNumber					INT,
		@ActualWorkingDaysBeforePeriod		INT

	SELECT    
		@FromDate = StartDate,    
		@ToDate = EndDate   
	FROM    
		Bdp000   
	WHERE    
		Guid = @PeriodGuid   
	
	SELECT 
		@PeriodVacationsNumber = SUM(1)   
	FROM 
		DistCalendar000   
	WHERE 
		Date BETWEEN @FromDate AND @ToDate   
	
	SET @PeriodVacationsNumber = ISNULL(@PeriodVacationsNumber, 0)  
	SET @PeriodDaysNumber = DATEDIFF(dd, @FromDate, @ToDate) + 1   
	SET @ActualWorkingDaysBeforePeriod = @PeriodDaysNumber - @PeriodVacationsNumber

	RETURN CASE WHEN @ActualWorkingDaysBeforePeriod > 0 THEN @ActualWorkingDaysBeforePeriod ELSE 0 END 
END
######################################################
#END
