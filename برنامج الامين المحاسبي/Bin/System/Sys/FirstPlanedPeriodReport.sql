######################################################
CREATE PROCEDURE FirstPlanedPeriodReport
      @ProductionPlanGuid UNIQUEIDENTIFIER
	 
      
AS    
      SET NOCOUNT ON   
      DECLARE    
            @ProductionPlanInitiationDatePeriodStartDate	DATE,   
            @ProductionPlanStartPeriodStartDate				DATE, 
            @ProductionPlanUnit								INT,
            @ProductionLineGuid								UNIQUEIDENTIFIER
      SELECT         
            @ProductionPlanInitiationDatePeriodStartDate    = Bdp.StartDate   
            ,@ProductionPlanStartPeriodStartDate            = Bdp2.StartDate   
            ,@ProductionPlanUnit                            = ProductionPlan.Unit 
            ,@ProductionLineGuid							= ProductionPlan.ProductionLineGuid
      FROM    
            ProductionPlan000 ProductionPlan   
            INNER JOIN Bdp000 Bdp   ON ProductionPlan.Date BETWEEN Bdp.StartDate AND Bdp.EndDate   
            INNER JOIN Bdp000 Bdp2  ON ProductionPlan.FromPeriod = Bdp2.Guid   
      WHERE ProductionPlan.Guid = @ProductionPlanGuid  

      SELECT    
            Mt.Guid  MaterialGuid
			,MT.Code                                                                                                                                                                                             MaterialCode   
            ,Mt.Name                                                                                                                                                                                                                                                                                        MaterialName   
            ,Gr.Guid                                                                                                                                                                                                                                                                                        GroupGuid   
            ,Gr.Name GroupName 
			,Gr.Code                                                                                                                                                                                                                                                                                        GroupCode   
            ,ISNULL(InitiationDatePeriodStock.Stock, 0.0) / MaterialUnity.UnitFact                                                                                                                                                                                                                                FirstPeriodQty   
            ,(ISNULL(PreviousPlans.PlanedQty, 0.0) + ISNULL(MaterialPlanFromOpenedJobOrders.PlanedQty, 0.0)) * PP.PlanedQtyTolerance / (100    * MaterialUnity.UnitFact)                                                                               PlanedQty   
            ,ISNULL(MatTargets.SalesTarget *  PP.TargetQtyTolerance / 100     , 0.0) / MaterialUnity.UnitFact                                                                                                                                                                    TargetQty   
            ,CAST(0 AS FLOAT)																																									PlannedPeriodQty   
            ,1                                                                                                                                                                                                                                                                                                    Type   
      INTO    
            #Result   
      FROM    
            ProductionPlan000 PP   
            INNER JOIN MainProductionPlan000 MPP ON MPP.ParentGuid = PP.Guid   
            INNER JOIN MainProductionPlanItem000 MPPI ON MPPI.ParentGuid = MPP.Guid   
            INNER JOIN Mt000 Mt ON Mt.Guid = MPPI.MaterialGuid   
            INNER JOIN Gr000 Gr ON Gr.Guid = Mt.GroupGuid 
            INNER JOIN  
            ( 
                  SELECT Guid MaterialGuid 
                              ,CASE @ProductionPlanUnit WHEN 0 THEN 1 WHEN 1 THEN CASE Unit2Fact WHEN 0 THEN 1 ELSE Unit2Fact END WHEN 2 THEN CASE Unit3Fact WHEN 0 THEN 1 ELSE Unit3Fact END WHEN 3 THEN CASE DefUnit WHEN 1 THEN 1 WHEN 2 THEN CASE Unit2Fact WHEN 0 THEN 1 ELSE Unit2Fact END WHEN 3 THEN CASE Unit3Fact WHEN 0 THEN 1 ELSE Unit3Fact END END END UnitFact 
                  FROM Mt000 
            )MaterialUnity ON MaterialUnity.MaterialGuid = Mt.Guid 
            LEFT JOIN   
            (   
                  SELECT   
                        Mt.Guid MatGuid   
                       -- ,SUM(ISNULL((Bi.Qty * CASE Bt.BillType WHEN 0 THEN 1 WHEN 3 THEN 1 WHEN 4 THEN 1 ELSE -1 END) , 0)) Stock  
					   ,SUM(ISNULL((Bi.Qty * CASE Bt.bIsInput WHEN 0 THEN -1 ELSE 1 END) , 0))  Stock 
                  FROM    
                        Mt000 Mt   
                        INNER JOIN Bi000 Bi ON Mt.Guid = Bi.MatGuid   
                        INNER JOIN Bu000 Bu ON Bu.Guid = Bi.ParentGuid AND Bu.Date < @ProductionPlanInitiationDatePeriodStartDate   
                        INNER JOIN Bt000 Bt ON Bt.Guid = Bu.TypeGuid   
                  GROUP BY    
                        Mt.Guid   
            )InitiationDatePeriodStock ON Mt.Guid = InitiationDatePeriodStock.MatGuid   
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
      )MaterialPlanFromOpenedJobOrders ON MaterialPlanFromOpenedJobOrders.MatGuid = Mt.Guid   
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
                  Bdp.StartDate > @ProductionPlanInitiationDatePeriodStartDate   
                  AND Bdp.EndDate < @ProductionPlanStartPeriodStartDate   
              GROUP BY    
                  MPPI.MaterialGuid   
      )PreviousPlans ON PreviousPlans.MaterialGuid = Mt.Guid   
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
      )MatTargets ON MatTargets.MatGuid = Mt.Guid   
      INNER JOIN Mi000 Mi ON Mi.MatGuid = Mt.Guid AND Mi.Type = 0
      INNER JOIN Mn000 Mn ON Mn.Guid = Mi.ParentGuid AND Mn.Type = 0
      WHERE    
            PP.Guid = @ProductionPlanGuid 
              
      GROUP BY    
            Mt.Guid 
			,MT.Code  
            ,Mt.Name  
            ,MaterialUnity.UnitFact  
            ,ISNULL(InitiationDatePeriodStock.Stock, 0.0)   
            ,Gr.Guid   
            ,Gr.Name 
			,Gr.Code  
            ,PP.PlanedQtyTolerance   
            ,MPPI.SafeStock   
            ,MPPI.MinLimit   
            ,MatTargets.SalesTarget  
            ,PP.TargetQtyTolerance  
            ,ISNULL(PreviousPlans.PlanedQty, 0.0)  
            ,ISNULL(MaterialPlanFromOpenedJobOrders.PlanedQty, 0.0)  
            ,PP.PlanedQtyTolerance  
           
      INSERT INTO    
            #Result   
      SELECT   
            GroupGuid 
			,0  
            ,GroupName   
            ,GroupGuid  
            ,GroupName  
			,GroupCode 
            ,SUM(FirstPeriodQty)   
            ,SUM(PlanedQty)   
            ,SUM(TargetQty)   
            ,SUM(PlannedPeriodQty)   
            ,0   
      FROM    
            #Result   
      GROUP BY    
            GroupGuid   
            ,GroupName
			,GroupCode   
               
      INSERT INTO    
            #Result   
      SELECT    
            0x0 
			,0  
            ,''   
            ,0x0   
            ,'ннннннннн' 
			,0
            ,SUM(FirstPeriodQty)   
            ,SUM(PlanedQty)   
            ,SUM(TargetQty)   
            ,SUM(PlannedPeriodQty)   
            ,2   
      FROM    
            #Result   
      WHERE    
            Type = 0   
      GROUP BY    
            GroupGuid   
            ,GroupName
			,GroupCode   
      UPDATE #Result    
      SET    
            PlannedPeriodQty = FirstPeriodQty + PlanedQty - TargetQty   
      WHERE    
            (FirstPeriodQty + PlanedQty - TargetQty) > PlannedPeriodQty   
      SELECT * FROM #Result   
      ORDER BY GroupName, Type, MaterialCode

######################################################
#END