##################################################################
CREATE PROCEDURE ReadyMaterialAvalability 
	@GroupGuid			UNIQUEIDENTIFIER  = 0x0   
    ,@ProductionLine    UNIQUEIDENTIFIER  = 0x0   
    ,@GroupLevel		INT                           = 1   
    ,@PeriodGuid		UNIQUEIDENTIFIER  = 0x0   
    ,@Unit              INT                           = 1   
    ,@ShowOptions		INT = 255 
 
AS    
	SET NOCOUNT ON   
	DECLARE   
		@ShowMaterialsDetails					bit = 0   
		,@ShowFirstPeriodDetails				bit = 0   
		,@ShowTargetDetails						bit = 0   
		,@ShowShippingDetails					bit = 0   
		,@ShowSalesDetails						bit = 0   
		,@ShowStockDetails						bit = 0   
		,@ShowAvailableAfterTargetDetails		bit = 0   
		,@ShowStockAvailabilityPeriodDetails	bit = 0   
		,@ShowRequiredShippingDetails			bit = 0  
	SET @ShowMaterialsDetails	= CASE @ShowOptions & 1  WHEN 1  THEN 1  ELSE 0 END    
	SET @ShowFirstPeriodDetails	= CASE @ShowOptions & 2  WHEN 2  THEN 2  ELSE 0 END    
	SET @ShowTargetDetails		= CASE @ShowOptions & 4  WHEN 4  THEN 4  ELSE 0 END    
	SET @ShowShippingDetails	= CASE @ShowOptions & 8  WHEN 8  THEN 8  ELSE 0 END    
	SET @ShowSalesDetails		= CASE @ShowOptions & 16 WHEN 16 THEN 16 ELSE 0 END    
	SET @ShowStockDetails		= CASE @ShowOptions & 32 WHEN 32 THEN 32 ELSE 0 END    
	SET @ShowAvailableAfterTargetDetails	= CASE @ShowOptions & 64  WHEN 64  THEN 64  ELSE 0 END    
	SET @ShowStockAvailabilityPeriodDetails = CASE @ShowOptions & 128 WHEN 128 THEN 128 ELSE 0 END    
	SET @ShowRequiredShippingDetails = CASE @ShowOptions & 256 WHEN 256 THEN 256 ELSE 0 END    

	DECLARE    
		@FromDate                       DATE,   
		@ToDate                         DATE,   
		@MainStoreGuid                  UNIQUEIDENTIFIER,   
		@ReservationStoreGuid           UNIQUEIDENTIFIER,   
		@MainStoreName                  VARCHAR(255),   
		@ReservationStoreName           VARCHAR(255),   
		@PeriodVacationsNumber          INT,   
		@ActualWorkingDaysBeforePeriod	INT,   
		@PeriodDaysNumber               INT,   
		@FirstPeriodDate                DATE,   
		@SafeStockPeriod                FLOAT,
		@TotalStores                    FLOAT,
		@Taregt							FLOAT,
		@ActualWorkingDays				INT


	SELECT    
		@FromDate = StartDate,    
		@ToDate = EndDate   
	FROM    
		Bdp000   
	WHERE    
		Guid = @PeriodGuid   
	SET @PeriodVacationsNumber = 0   
	SELECT @PeriodVacationsNumber = SUM(1)   
	FROM DistCalendar000   
	WHERE Date BETWEEN @FromDate AND @ToDate   
	SET @PeriodVacationsNumber = ISNULL(@PeriodVacationsNumber, 0)  
	SET @PeriodDaysNumber = DATEDIFF(dd, @FromDate, @ToDate) + 1   
	SELECT @FirstPeriodDate = CONVERT(DATE, Value, 103) FROM op000 WHERE Name = 'AmnCfg_FPDate'   
	SET @ActualWorkingDaysBeforePeriod = (DATEDIFF(dd, @FromDate, GETDATE()) + 1) - (SELECT ISNULL(SUM(1), 0) FROM DistCalendar000 WHERE Date BETWEEN @FromDate AND GETDATE())
	IF(GETDATE() > @ToDate)
		SET @ActualWorkingDaysBeforePeriod = DATEDIFF(dd, @FromDate, @ToDate) + 1  - (SELECT ISNULL(SUM(1), 0) FROM DistCalendar000 WHERE Date BETWEEN @FromDate AND @ToDate)
	IF(@ActualWorkingDaysBeforePeriod < 0)
		SET @ActualWorkingDaysBeforePeriod = 0

	SET @ActualWorkingDays = @PeriodDaysNumber - @PeriodVacationsNumber

	SELECT @SafeStockPeriod = CAST(Value AS FLOAT) FROM Op000 WHERE Name = 'ProductAvailabilitySafeStockPeriod'   
	SELECT    
		  @MainStoreGuid = St.Guid   
		  ,@MainStoreName = St.Name   
	FROM    
		Op000 OP    
		INNER JOIN St000 St ON St.Guid = CAST(Value AS UNIQUEIDENTIFIER)   
	WHERE    
		Op.Name = 'ProductAvailabilityMainStore'   
	SELECT    
		  @ReservationStoreGuid = St.Guid   
		  ,@ReservationStoreName = St.Name   
	FROM    
		Op000 Op   
		INNER JOIN St000 St ON St.Guid = CAST(Value AS UNIQUEIDENTIFIER)    
	WHERE    
		Op.Name = 'ProductAvailabilityReservationStore'   
	SELECT Guid    
	INTO #MainStoreStores   
	FROM dbo.fnGetStoresList(@MainStoreGuid)   
	SELECT SUBSTRING(Name, LEN(Name), 1) Number, CAST(Value AS UNIQUEIDENTIFIER) Guid   
	INTO #CenterStoreStores   
	FROM Op000   
	WHERE Name LIKE 'ProductAvailabilityCenterStoresGuid%'   
	SELECT CAST(Value AS UNIQUEIDENTIFIER) Guid   
	INTO #SalesBillSrcs   
	FROM Op000    
	WHERE Name LIKE 'ProductAvailabilitySalesBillSrcsGuid%'   
	SELECT CAST(Value AS UNIQUEIDENTIFIER) Guid   
	INTO #ShippingBillSrcs   
	FROM Op000    
	WHERE Name LIKE 'ProductAvailabilityShippingBillSrcsGuid%'   
	SELECT CAST(Value AS UNIQUEIDENTIFIER) Guid   
	INTO #DecayedBillSrcs   
	FROM Op000    
	WHERE Name LIKE 'ProductAvailabilityDecayedBillSrcsGuid%'   
	DECLARE @MaxLevel INT   
	DECLARE @MinLevel INT   
	SELECT    
		  Gr.Guid   
		  ,Gr.ParentGuid   
		  ,Grp.Level   
		  ,Grp.Path   
	INTO    
		#Groups   
	FROM    
		fnGetGroupsOfGroupSorted(0x0, 1) Grp   
		INNER JOIN Gr000 Gr ON Gr.Guid = Grp.Guid   
	DELETE FROM #Groups   
	WHERE    
		  (   
				ISNULL(@GroupGuid, 0x0) <> 0x0   
				AND    
				Guid NOT IN (SELECT Guid FROM fnGetGroupsList(@GroupGuid))   
		  )   
		  OR   
		  (   
				ISNULL(@ProductionLine, 0x0) <> 0x0   
				AND    
				Guid NOT IN (     SELECT Gr.Guid   
										FROM ProductionLine000 Pl   
										INNER JOIN ProductionLineGroup000 Plg ON Pl.Guid = Plg.ProductionLine   
										INNER JOIN Gr000 Gr ON Gr.Guid IN (SELECT Guid FROM fnGetGroupsList(Plg.GroupGuid))   
										WHERE Pl.Guid = @ProductionLine   
								  )   
		  )   
	SELECT @MinLevel = MIN(Level) FROM #Groups   
	UPDATE #Groups SET Level = Level + 1 - @MinLevel   
	DELETE FROM #Groups WHERE Level > @GroupLevel   
	SET @MaxLevel = 0   
	SELECT @MaxLevel = MAX(Level) FROM #Groups   
	  
	SELECT   
		  Mt.mtGuid		MaterialGuid   
		  ,Mt.mtName	MaterialName   
		  ,Gr.Guid		GroupGuid   
		  ,Gr.Name		GroupName   
		  ,Groups.Path  Path   
	INTO    
		#Materials   
	FROM
		vwMt Mt
		INNER JOIN 
		(
			SELECT DISTINCT mtGuid From MatTargets000
		) AS Targets ON Targets.mtGuid = Mt.mtGuid
		INNER JOIN vwMi mi ON mi.miMatGuid = mt.[mtGuid]
		INNER JOIN    
		(   
			  SELECT Guid, Path FROM #Groups WHERE Guid NOT IN ( SELECT ParentGuid FROM #Groups )   
		) AS Groups ON (Groups.Guid = Mt.mtGroup OR Groups.Guid IN (SELECT Guid FROM dbo.fnGetGroupParents(Mt.mtGroup)))  
		INNER JOIN Gr000 Gr ON Gr.Guid = Groups.Guid  
	GROUP BY    
		Mt.mtGuid   
		,Mt.mtName   
		,Gr.Guid   
		,Gr.Name   
		,Groups.Path  
	  
	SELECT   
		Mt.MaterialGuid																						MaterialGuid   
		,Mt.MaterialName																					MaterialName   
		,Mt.GroupGuid																						GroupGuid   
		,Mt.GroupName																						GroupName   
		,@MainStoreName																						ColName   
		,1																									ColOrder   
		,-2																									ColSubOrder   
		,Mt.Path																							Path   
		,1																									Type   
		--,SUM(ISNULL((Bi.Qty * CASE Bt.BillType WHEN 0 THEN 1 WHEN 3 THEN 1 WHEN 4 THEN 1 ELSE -1 END) , 0))	Value 
		,SUM(ISNULL((Bi.Qty * CASE Bt.bIsInput WHEN 0 THEN -1 ELSE 1 END) , 0)) Value  
	INTO    
		#Result   
	FROM    
		St000 St   
		INNER JOIN #MainStoreStores MainStoreStores ON MainStoreStores.Guid = St.Guid   
		INNER JOIN Bi000 Bi ON Bi.StoreGuid = St.Guid   
		INNER JOIN Bu000 Bu ON Bu.Guid = Bi.ParentGuid   
		INNER JOIN Bt000 Bt ON Bt.Guid = Bu.TypeGuid   
		INNER JOIN #Materials Mt ON Mt.MaterialGuid = Bi.MatGuid   
	WHERE    
		Bu.Date < @FromDate   
	GROUP BY    
		Mt.MaterialGuid   
		,Mt.MaterialName   
		,Mt.GroupGuid   
		,Mt.GroupName   
		,Mt.Path   
		  
	INSERT INTO #Result   
	SELECT    
		Mt.MaterialGuid   
		,Mt.MaterialName   
		,Mt.GroupGuid   
		,Mt.GroupName   
		,@ReservationStoreName   
		,1   
		,-1   
		,Mt.Path   
		,1   
		--,SUM(ISNULL((Bi.Qty * CASE Bt.BillType WHEN 0 THEN 1 WHEN 3 THEN 1 WHEN 4 THEN 1 ELSE -1 END) , 0))  
		,SUM(ISNULL((Bi.Qty * CASE Bt.bIsInput WHEN 0 THEN -1 ELSE 1 END) , 0))  
	FROM    
		St000 St   
		INNER JOIN Bi000 Bi ON Bi.StoreGuid = St.Guid   
		INNER JOIN Bu000 Bu ON Bu.Guid = Bi.ParentGuid   
		INNER JOIN Bt000 Bt ON Bt.Guid = Bu.TypeGuid   
		INNER JOIN #Materials Mt ON Mt.MaterialGuid = Bi.MatGuid   
	WHERE    
		Bu.Date < @FromDate   
		AND St.Guid = @ReservationStoreGuid   
	GROUP BY    
		Mt.MaterialGuid   
		,Mt.MaterialName   
		,Mt.GroupGuid   
		,Mt.GroupName   
		,Mt.Path   
	INSERT INTO #Result              
	SELECT    
		Mt.MaterialGuid   
		,Mt.MaterialName   
		,Mt.GroupGuid   
		,Mt.GroupName   
		,St.Name   
		,1   
		,CenterStoreStores.Number   
		,Mt.Path   
		,1   
		--,SUM(ISNULL((Bi.Qty * CASE Bt.BillType WHEN 0 THEN 1 WHEN 3 THEN 1 WHEN 4 THEN 1 ELSE -1 END) , 0)) 
		,SUM(ISNULL((Bi.Qty * CASE Bt.bIsInput WHEN 0 THEN -1 ELSE 1 END) , 0))   
	FROM    
		St000 St   
		INNER JOIN #CenterStoreStores CenterStoreStores ON CenterStoreStores.Guid = St.Guid   
		INNER JOIN Bi000 Bi ON Bi.StoreGuid = St.Guid   
		INNER JOIN Bu000 Bu ON Bu.Guid = Bi.ParentGuid   
		INNER JOIN Bt000 Bt ON Bt.Guid = Bu.TypeGuid   
		INNER JOIN #Materials Mt ON Mt.MaterialGuid = Bi.MatGuid   
	WHERE    
		Bu.Date < @FromDate   
	GROUP BY    
		Mt.MaterialGuid   
		,Mt.MaterialName   
		,Mt.GroupGuid   
		,Mt.GroupName   
		,Mt.Path   
		,St.Name   
		,CenterStoreStores.Number   
         
	INSERT INTO #Result   
	SELECT    
		Mt.MaterialGuid   
		,Mt.MaterialName   
		,Mt.GroupGuid   
		,Mt.GroupName   
		,''   
		,2   
		,0   
		,Mt.Path   
		,1   
		,SUM(Bi.Qty)   
	FROM    
		JobOrder000 Jo   
		INNER JOIN Bu000 Bu ON Bu.Guid = Jo.InBillGuid   
		INNER JOIN Bi000 Bi ON Bi.ParentGuid = Bu.Guid   
		INNER JOIN #Materials Mt ON Mt.MaterialGuid = Bi.MatGuid   
		INNER JOIN #MainStoreStores MainStoreStores ON MainStoreStores.Guid = Bi.StoreGuid   
	WHERE    
		Bu.Date BETWEEN @FromDate AND @ToDate   
	GROUP BY    
		Mt.MaterialGuid   
		,Mt.MaterialName   
		,Mt.GroupGuid   
		,Mt.GroupName   
		,Mt.Path   
		  
	INSERT INTO #Result   
	SELECT    
		MaterialGuid   
		,MaterialName   
		,GroupGuid   
		,GroupName   
		,''   
		,3   
		,0   
		,Path   
		,1   
		,SUM(Value)   
	FROM    
		#Result   
	GROUP BY    
		MaterialGuid   
		,MaterialName   
		,GroupGuid   
		,GroupName   
		,Path   
	INSERT INTO #Result   
	SELECT   
		Mt.MaterialGuid   
		,Mt.MaterialName   
		,Mt.GroupGuid   
		,Mt.GroupName   
		,St.Name   
		,4   
		,0   
		,Mt.Path   
		,1   
		,ISNULL(SUM(ISNULL(MatTargets.TargetQuantity, 0)), 0)   
	FROM    
		#Materials Mt   
		INNER JOIN MatTargets000 MatTargets ON Mt.MaterialGuid = MatTargets.MtGuid   
		INNER JOIN St000 St ON St.Guid = MatTargets.StGuid   
		INNER JOIN #CenterStoreStores Css ON St.Guid = Css.Guid   
	WHERE    
		MatTargets.BdpGuid = @PeriodGuid   
	GROUP BY    
		Mt.MaterialGuid   
		,Mt.MaterialName   
		,Mt.GroupGuid   
		,Mt.GroupName   
		,Mt.Path   
		,St.Name   
		  
	INSERT INTO #Result   
	SELECT   
		Mt.MaterialGuid   
		,Mt.MaterialName   
		,Mt.GroupGuid   
		,Mt.GroupName   
		,''   
		,5   
		,0   
		,Mt.Path   
		,1   
		,ISNULL(R3.Value, 0) - ISNULL(R4.Value, 0)   
	FROM    
		#Materials Mt   
		LEFT JOIN #Result R3 ON Mt.MaterialGuid = R3.MaterialGuid AND R3.ColOrder = 3   
		LEFT JOIN   
		(   
			  SELECT    
					MaterialGuid      MaterialGuid   
					,Sum(Value)       Value   
			  FROM #Result   
			  WHERE ColOrder = 4   
			  GROUP BY MaterialGuid   
		)R4 ON Mt.MaterialGuid = R4.MaterialGuid   
	  
	INSERT INTO #Result   
	SELECT   
		Mt.MaterialGuid   
		,Mt.MaterialName   
		,Mt.GroupGuid   
		,Mt.GroupName   
		,St.Name   
		,6   
		,Css.Number   
		,Mt.Path   
		,1   
		,ISNULL(SUM(ISNULL((Bi.Qty * CASE Bt.BillType WHEN 0 THEN 1 WHEN 3 THEN 1 WHEN 4 THEN 1 ELSE -1 END) , 0)), 0)   
	FROM    
		#Materials Mt   
		INNER JOIN Bi000 Bi ON Mt.MaterialGuid = Bi.MatGuid   
		INNER JOIN Bu000 Bu ON Bu.Guid = Bi.ParentGuid   
		INNER JOIN Bt000 Bt ON Bt.Guid = Bu.TypeGuid   
		INNER JOIN St000 St ON St.Guid = Bi.StoreGuid   
		INNER JOIN #CenterStoreStores Css ON St.Guid = Css.Guid   
	WHERE    
		Bt.Guid IN (SELECT Guid FROM #ShippingBillSrcs)   
		AND Bu.Date BETWEEN @FromDate AND @ToDate   
	GROUP BY    
		Mt.MaterialGuid   
		,Mt.MaterialName   
		,Mt.GroupGuid   
		,Mt.GroupName   
		,Mt.Path   
		,St.Name   
		,Css.Number   
	  
	INSERT INTO #Result   
	SELECT   
		Mt.MaterialGuid   
		,Mt.MaterialName   
		,Mt.GroupGuid   
		,Mt.GroupName   
		,St.Name   
		,7   
		,Css.Number   
		,Mt.Path   
		,1   
		,ISNULL(SUM(ISNULL((Bi.Qty * CASE WHEN Bt.BillType IN(0, 3, 4)THEN -1 ELSE 1 END) , 0)), 0) 
	FROM    
		#Materials Mt   
		INNER JOIN Bi000 Bi ON Mt.MaterialGuid = Bi.MatGuid   
		INNER JOIN Bu000 Bu ON Bu.Guid = Bi.ParentGuid   
		INNER JOIN Bt000 Bt ON Bt.Guid = Bu.TypeGuid   
		INNER JOIN St000 St ON St.Guid = Bi.StoreGuid   
		INNER JOIN #CenterStoreStores Css ON St.Guid = Css.Guid   
	WHERE    
		(Bt.Guid IN (SELECT Guid FROM #SalesBillSrcs) OR Bt.Guid IN(SELECT Guid FROM #DecayedBillSrcs))
		AND Bu.Date BETWEEN @FromDate AND @ToDate   
	GROUP BY    
		Mt.MaterialGuid   
		,Mt.MaterialName   
		,Mt.GroupGuid   
		,Mt.GroupName   
		,Mt.Path   
		,St.Name   
		,Css.Number   
		  
	INSERT INTO #Result   
	SELECT   
		Mt.MaterialGuid   
		,Mt.MaterialName   
		,Mt.GroupGuid   
		,Mt.GroupName   
		,@MainStoreName   
		,8   
		,-2   
		,Mt.Path   
		,1   
		,MaterialStock.Stock
		
	FROM    
		#Materials Mt
		LEFT JOIN
		(  
			SELECT  
				Mt.Guid MatGuid  
				,SUM(ISNULL((Bi.Qty * CASE WHEN Bt.BillType IN(0, 3, 4) THEN 1 ELSE -1 END), 0)) Stock  
			FROM   
				Mt000 Mt  
				INNER JOIN Bi000 Bi ON Mt.Guid = Bi.MatGuid  
				INNER JOIN Bu000 Bu ON Bu.Guid = Bi.ParentGuid
				INNER JOIN Bt000 Bt ON Bt.Guid = Bu.TypeGuid
			WHERE 
				Bi.StoreGuid IN (SELECT Guid FROM #MainStoreStores)
				And Bu.Date Between @FirstPeriodDate AND @ToDate
			GROUP BY   
				Mt.Guid  
		)MaterialStock ON MaterialStock.MatGuid = Mt.MaterialGuid
		
	INSERT INTO #Result   
	SELECT   
		Mt.MaterialGuid   
		,Mt.MaterialName   
		,Mt.GroupGuid   
		,Mt.GroupName   
		,@ReservationStoreName
		,8   
		,-1   
		,Mt.Path   
		,1   
		,MaterialStock.Stock
	FROM    
		#Materials Mt
		LEFT JOIN
		(  
			SELECT  
				Mt.Guid MatGuid  
				,SUM(ISNULL((Bi.Qty * CASE WHEN Bt.BillType IN (0, 3, 4) THEN 1 ELSE -1 END) , 0)) Stock  
			FROM   
				Mt000 Mt  
				INNER JOIN Bi000 Bi ON Mt.Guid = Bi.MatGuid  
				INNER JOIN Bu000 Bu ON Bu.Guid = Bi.ParentGuid
				INNER JOIN Bt000 Bt ON Bt.Guid = Bu.TypeGuid
			WHERE 
				Bi.StoreGuid = @ReservationStoreGuid
				And Bu.Date Between @FirstPeriodDate AND @ToDate
			GROUP BY   
				Mt.Guid  
		)MaterialStock ON MaterialStock.MatGuid = Mt.MaterialGuid
		
	INSERT INTO #Result   
	SELECT   
		CenterStoreStoresMaterials.MaterialGuid   
		,CenterStoreStoresMaterials.MaterialName   
		,CenterStoreStoresMaterials.GroupGuid   
		,CenterStoreStoresMaterials.GroupName   
		,St.Name   
		,8   
		,CenterStoreStoresMaterials.StoreOrderNumber   
		,CenterStoreStoresMaterials.Path   
		,1   
		,MaterialStock.Stock
	FROM    
		St000 St   
		INNER JOIN   
		(   
			  SELECT    
					Css.Guid                StoreGuid   
					,Css.Number             StoreOrderNumber   
					,Mt.MaterialGuid   
					,Mt.MaterialName   
					,Mt.GroupGuid   
					,Mt.GroupName   
					,Mt.Path   
			  FROM #CenterStoreStores Css   
			  CROSS JOIN #Materials Mt   
		)CenterStoreStoresMaterials ON CenterStoreStoresMaterials.StoreGuid = St.Guid   
		LEFT JOIN
		(  
			SELECT  
				Mt.Guid MatGuid  
				,Bi.StoreGuid StoreGuid
				,SUM(ISNULL((Bi.Qty * CASE WHEN Bt.BillType IN (0, 3, 4) THEN 1 ELSE -1 END) , 0)) Stock  
			FROM   
				Mt000 Mt  
				INNER JOIN Bi000 Bi ON Mt.Guid = Bi.MatGuid  
				INNER JOIN Bu000 Bu ON Bu.Guid = Bi.ParentGuid
				INNER JOIN Bt000 Bt ON Bt.Guid = Bu.TypeGuid
			WHERE  
				Bi.StoreGuid IN (SELECT Guid FROM #CenterStoreStores)
				And Bu.Date Between @FirstPeriodDate AND @ToDate
			GROUP BY   
				Mt.Guid 
				,Bi.StoreGuid 
		)MaterialStock ON MaterialStock.MatGuid = CenterStoreStoresMaterials.MaterialGuid AND MaterialStock.StoreGuid = CenterStoreStoresMaterials.StoreGuid
	  
	INSERT INTO #Result   
	SELECT   
		CenterStoreStoresMaterials.MaterialGuid   
		,CenterStoreStoresMaterials.MaterialName   
		,CenterStoreStoresMaterials.GroupGuid   
		,CenterStoreStoresMaterials.GroupName   
		,St.Name   
		,9   
		,CenterStoreStoresMaterials.StoreOrderNumber   
		,CenterStoreStoresMaterials.Path   
		,1   
		,ISNULL(R1.Value, 0) + ISNULL(R6.Value, 0) - (ISNULL(MatTargets.TargetQuantity, 0) * @ActualWorkingDaysBeforePeriod / CASE WHEN (@PeriodDaysNumber - @PeriodVacationsNumber) = 0 THEN 1 ELSE (@PeriodDaysNumber - @PeriodVacationsNumber) END)  
	FROM    
		St000 St   
		INNER JOIN   
		(   
			  SELECT    
					Css.Guid                StoreGuid   
					,Css.Number             StoreOrderNumber   
					,Mt.MaterialGuid   
					,Mt.MaterialName   
					,Mt.GroupGuid   
					,Mt.GroupName   
					,Mt.Path   
			  FROM #CenterStoreStores Css   
			  CROSS JOIN #Materials Mt   
		)CenterStoreStoresMaterials ON CenterStoreStoresMaterials.StoreGuid = St.Guid   
		LEFT JOIN #Result R1 ON R1.ColName = St.Name AND R1.ColOrder = 1 AND CenterStoreStoresMaterials.MaterialGuid = R1.MaterialGuid   
		LEFT JOIN #Result R6 ON R6.ColName = St.Name AND R6.ColOrder = 6 AND CenterStoreStoresMaterials.MaterialGuid = R6.MaterialGuid   
		LEFT JOIN MatTargets000 MatTargets ON MatTargets.MtGuid = CenterStoreStoresMaterials.MaterialGuid AND MatTargets.StGuid = St.Guid AND MatTargets.BdpGuid = @PeriodGuid   
		  
	INSERT INTO #Result   
	SELECT   
		R.MaterialGuid   
		,R.MaterialName   
		,R.GroupGuid   
		,R.GroupName   
		,R.ColName   
		,10   
		,R.ColSubOrder   
		,R.Path   
		,1   
		,CASE ISNULL(MatTargets.TargetQuantity, 0) WHEN 0 THEN 0 ELSE R.Value * (@PeriodDaysNumber - @PeriodVacationsNumber) / ISNULL(MatTargets.TargetQuantity, 0) END --CASE CASE (@PeriodDaysNumber - @PeriodVacationsNumber) WHEN 0 THEN 0 ELSE ISNULL(MatTargets.TargetQuantity, 0) / (@PeriodDaysNumber - @PeriodVacationsNumber) END WHEN 0 THEN 0 ELSE ISNULL(R.Value, 0) / CASE (@PeriodDaysNumber - @PeriodVacationsNumber) WHEN 0 THEN 1 ELSE ISNULL(MatTargets.TargetQuantity, 0) / (@PeriodDaysNumber - @PeriodVacationsNumber) END END  
	FROM    
		#Result R   
		INNER JOIN St000 St ON St.Name = R.ColName  
		INNER JOIN #CenterStoreStores Css ON Css.Guid = St.Guid  
		LEFT JOIN MatTargets000 MatTargets ON MatTargets.MtGuid = R.MaterialGuid AND MatTargets.StGuid = St.Guid AND MatTargets.BdpGuid = @PeriodGuid   
	WHERE    
		R.ColOrder = 8   
		  
	INSERT INTO #Result   
	SELECT   
		CenterStoreStoresMaterials.MaterialGuid   
		,CenterStoreStoresMaterials.MaterialName   
		,CenterStoreStoresMaterials.GroupGuid   
		,CenterStoreStoresMaterials.GroupName   
		,St.Name   
		,11   
		,CenterStoreStoresMaterials.StoreOrderNumber   
		,CenterStoreStoresMaterials.Path   
		,1   
		,   
		(
			CASE 
				WHEN 0 > (( CASE (@PeriodDaysNumber - @PeriodVacationsNumber) WHEN 0 THEN 0 ELSE ISNULL(MatTargets.TargetQuantity, 0) / (@PeriodDaysNumber - @PeriodVacationsNumber) END * @SafeStockPeriod) 
							- CASE WHEN (ISNULL(R4.Value, 0) - (ISNULL(R1.Value, 0) + ISNULL(R6.Value, 0))) < 0  THEN ISNULL(R8.Value, 0) ELSE  0 end)
				THEN 0
				ELSE 
					(   
						(   -- ﬂ„Ì… «·„Œ“Ê‰ «·¬„‰
							CASE (@PeriodDaysNumber - @PeriodVacationsNumber)    
								  WHEN 0 THEN 0    
								  ELSE ISNULL(MatTargets.TargetQuantity, 0) / (@PeriodDaysNumber - @PeriodVacationsNumber)    
							END   
							*   
							@SafeStockPeriod   
						)   
						-   
						CASE WHEN (ISNULL(R4.Value, 0) - (ISNULL(R1.Value, 0) + ISNULL(R6.Value, 0))) < 0  THEN ISNULL(R8.Value, 0) ELSE  0 end
					)
				END
		)   
		+   
		CASE    
			WHEN (ISNULL(R4.Value, 0) - (ISNULL(R1.Value, 0) + ISNULL(R6.Value, 0))) < 0    
				  THEN 0   
			ELSE   
			(   
				ISNULL(R4.Value, 0)
				-
				(
				  ISNULL(R1.Value, 0)   
				  +   
				  ISNULL(R6.Value, 0)   
				)   
				     
			)   
		END   
	FROM    
	(   
		SELECT    
			Css.Guid                StoreGuid   
			,Css.Number             StoreOrderNumber   
			,Mt.MaterialGuid   
			,Mt.MaterialName   
			,Mt.GroupGuid   
			,Mt.GroupName   
			,Mt.Path   
		FROM #CenterStoreStores Css   
		CROSS JOIN #Materials Mt   
	)CenterStoreStoresMaterials   
	INNER JOIN St000 St ON St.Guid = CenterStoreStoresMaterials.StoreGuid   
	LEFT JOIN MatTargets000 MatTargets ON MatTargets.MtGuid = CenterStoreStoresMaterials.MaterialGuid AND MatTargets.StGuid = CenterStoreStoresMaterials.StoreGuid AND MatTargets.BdpGuid = @PeriodGuid	
	LEFT JOIN #Result R8 ON R8.MaterialGuid = CenterStoreStoresMaterials.MaterialGuid AND R8.ColName = St.Name AND R8.ColOrder = 8   
	LEFT JOIN #Result R1 ON R1.MaterialGuid = CenterStoreStoresMaterials.MaterialGuid AND R1.ColName = St.Name AND R1.ColOrder = 1   
	LEFT JOIN #Result R6 ON R6.MaterialGuid = CenterStoreStoresMaterials.MaterialGuid AND R6.ColName = St.Name AND R6.ColOrder = 6   
	LEFT JOIN #Result R4 ON R4.MaterialGuid = CenterStoreStoresMaterials.MaterialGuid AND R4.ColName = St.Name AND R4.ColOrder = 4   
	  
	INSERT INTO #Result   
	SELECT   
		Mt.MaterialGuid   
		,Mt.MaterialName   
		,Mt.GroupGuid   
		,Mt.GroupName   
		,''   
		,12   
		,0   
		,Mt.Path   
		,1   
		,CASE WHEN ISNULL(SUM(ISNULL(R8.Value, 0)), 0) > ISNULL(SUM(ISNULL(R11.Value, 0)), 0) THEN 0 ELSE ISNULL(SUM(ISNULL(R11.Value, 0)), 0) - ISNULL(SUM(ISNULL(R8.Value, 0)), 0) END   
	FROM    
		#Materials Mt   
		LEFT JOIN   
		(  
			SELECT MaterialGuid, SUM(Value) Value FROM #Result WHERE ColOrder = 11 GROUP BY MaterialGuid  
		)R11 ON R11.MaterialGuid = Mt.MaterialGuid  
		LEFT JOIN   
		(  
			SELECT MaterialGuid, SUM(Value) Value FROM #Result WHERE ColOrder = 8 AND ColSubOrder < 0 GROUP BY MaterialGuid  
		)R8 ON R8.MaterialGuid = Mt.MaterialGuid  
	GROUP BY Mt.MaterialGuid  
			,Mt.MaterialName  
			,Mt.GroupGuid  
			,Mt.GroupName  
			,Mt.Path  

	IF(@ShowFirstPeriodDetails <> 1)   
	BEGIN   
		UPDATE #Result SET ColOrder = 100 WHERE ColOrder = 1   
         
		INSERT INTO #Result   
		SELECT   
			MaterialGuid   
			,MaterialName   
			,GroupGuid   
			,GroupName   
			,''   
			,1   
			,0   
			,Path   
			,1   
			,SUM(Value)   
		FROM #Result   
		WHERE ColOrder = 100   
		GROUP BY MaterialGuid   
				  ,MaterialName   
				  ,GroupGuid   
				  ,GroupName   
				  ,Path   
         
		DELETE FROM #Result WHERE ColOrder = 100   
	END   
	IF(@ShowTargetDetails <> 1)   
	BEGIN   
		UPDATE #Result SET ColOrder = 100 WHERE ColOrder = 4   
         
		INSERT INTO #Result   
		SELECT   
			MaterialGuid   
			,MaterialName   
			,GroupGuid   
			,GroupName   
			,''   
			,4   
			,0   
			,Path   
			,1   
			,SUM(Value)   
		FROM #Result   
		WHERE ColOrder = 100   
		GROUP BY MaterialGuid   
				  ,MaterialName   
				  ,GroupGuid   
				  ,GroupName   
				  ,Path   
                   
		DELETE FROM #Result WHERE ColOrder = 100   
	END   
	IF(@ShowShippingDetails <> 1)   
	BEGIN   
		UPDATE #Result SET ColOrder = 100 WHERE ColOrder = 6   
         
		INSERT INTO #Result   
		SELECT   
			MaterialGuid   
			,MaterialName   
			,GroupGuid   
			,GroupName   
			,''   
			,6   
			,0   
			,Path   
			,1   
			,SUM(Value)   
		FROM #Result   
		WHERE ColOrder = 100   
		GROUP BY MaterialGuid   
				  ,MaterialName   
				  ,GroupGuid   
				  ,GroupName   
				  ,Path   
		DELETE FROM #Result WHERE ColOrder = 100   
	END   
	IF(@ShowSalesDetails <> 1)   
	BEGIN   
		UPDATE #Result SET ColOrder = 100 WHERE ColOrder = 7   
         
		INSERT INTO #Result   
		SELECT   
			MaterialGuid   
			,MaterialName   
			,GroupGuid   
			,GroupName   
			,''   
			,7   
			,0   
			,Path   
			,1   
			,SUM(Value)   
		FROM #Result   
		WHERE ColOrder = 100   
		GROUP BY MaterialGuid   
				  ,MaterialName   
				  ,GroupGuid   
				  ,GroupName   
				  ,Path   
		DELETE FROM #Result WHERE ColOrder = 100   
	END   
	IF(@ShowStockDetails <> 1)   
	BEGIN   
		UPDATE #Result SET ColOrder = 100 WHERE ColOrder = 8   

		INSERT INTO #Result   
		SELECT   
			MaterialGuid   
			,MaterialName   
			,GroupGuid   
			,GroupName   
			,''   
			,8   
			,0   
			,Path   
			,1   
			,SUM(Value)   
		FROM #Result   
		WHERE ColOrder = 100   
		GROUP BY MaterialGuid   
				  ,MaterialName   
				  ,GroupGuid   
				  ,GroupName   
				  ,Path   
		DELETE FROM #Result WHERE ColOrder = 100   
	END   
	IF(@ShowAvailableAfterTargetDetails <> 1)   
	BEGIN   
		UPDATE #Result SET ColOrder = 100 WHERE ColOrder = 9   
         
		INSERT INTO #Result   
		SELECT   
			MaterialGuid   
			,MaterialName   
			,GroupGuid   
			,GroupName   
			,''   
			,9   
			,0   
			,Path   
			,1   
			,SUM(Value)   
		FROM #Result   
		WHERE ColOrder = 100   
		GROUP BY MaterialGuid   
				  ,MaterialName   
				  ,GroupGuid   
				  ,GroupName   
				  ,Path   
		DELETE FROM #Result WHERE ColOrder = 100   
	END  	
	IF(@ShowStockAvailabilityPeriodDetails <> 1)   
	BEGIN   
		UPDATE #Result SET ColOrder = 100 WHERE ColOrder = 10   
		INSERT INTO #Result   
		SELECT   
			MaterialGuid   
			,MaterialName   
			,GroupGuid   
			,GroupName   
			,''   
			,10   
			,0   
			,Path   
			,1   
			,SUM(Value)   
		FROM #Result   
		WHERE ColOrder = 100  
		GROUP BY MaterialGuid   
				  ,MaterialName   
				  ,GroupGuid   
				  ,GroupName   
				  ,Path   
		DELETE FROM #Result WHERE ColOrder = 100   
	END   
	
	
	IF(@ShowRequiredShippingDetails <> 1)   
	BEGIN   
		UPDATE #Result SET ColOrder = 100 WHERE ColOrder = 11   
         
		INSERT INTO #Result   
		SELECT   
			MaterialGuid   
			,MaterialName   
			,GroupGuid   
			,GroupName   
			,''   
			,11   
			,0   
			,Path   
			,1   
			,SUM(Value)   
		FROM #Result   
		WHERE ColOrder = 100   
		GROUP BY MaterialGuid   
				  ,MaterialName   
				  ,GroupGuid   
				  ,GroupName   
				  ,Path   
		DELETE FROM #Result WHERE ColOrder = 100   
	END   

	


	 CREATE TABLE #temp_Tb1
	 (GroupGuid uniqueIdentifier , StName VARCHAR(50) COLLATE Arabic_CI_AI, AvailableQty FLOAT)
    
	 UPDATE #Result SET Value = R.Value / CASE @Unit WHEN 0 THEN 1 
	                                                WHEN 1 THEN (CASE Mt.Unit2Fact WHEN  0 THEN 
													(CASE Mt.DefUnit WHEN 1 THEN 1 WHEN 3 THEN Mt.Unit3Fact END)  ELSE Mt.Unit2Fact END)
	                                                WHEN 2 THEN (CASE Mt.Unit3Fact WHEN  0 THEN 
													(CASE Mt.DefUnit WHEN 1 THEN 1 WHEN 2 THEN Mt.Unit2Fact END)  ELSE Mt.Unit3Fact END)
													ELSE 
													CASE Mt.DefUnit WHEN 1 THEN 1 WHEN 2 THEN Mt.Unit2Fact WHEN 3 THEN Mt.Unit3Fact END 
													END
	FROM #Result R  
	INNER JOIN Mt000 Mt ON R.MaterialGuid = Mt.Guid  
	WHERE R.ColOrder <> 10 AND R.Type <> 0

	 INSERT INTO #temp_Tb1
	 SELECT Res.GroupGuid, Res.ColName, (SUM(Res.Value)) AS AvailableQty 
	  FROM 
		#Result Res WHERE Res.ColOrder =8  AND Res.ColSubOrder >= 0
	GROUP BY Res.GroupGuid, Res.ColName
	  

	 
	INSERT INTO #Result   
	SELECT   
		Gr.Guid   
		,Gr.Name   
		,Gr.Guid   
		,Gr.Name   
		,ResultGroup.ColName   
		,ResultGroup.ColOrder   
		,ResultGroup.ColSubOrder   
		,Groups.Path   
		,0   
		,ResultGroup.Value   
	FROM    
		#Groups Groups   
		INNER JOIN Gr000 Gr ON Gr.Guid = Groups.Guid   
		INNER JOIN   
		(   
			  SELECT    
					GroupGuid   
					,ColName   
					,ColOrder   
					,ColSubOrder   
					,SUM(Value) Value   
			  FROM #Result   
			  GROUP BY GroupGuid   
						  ,ColName   
						  ,ColOrder   
						  ,ColSubOrder   
		)ResultGroup ON ResultGroup.GroupGuid = Gr.Guid  
	--WHERE ResultGroup.ColOrder <> 10

	INSERT INTO #Result   
	SELECT   
		Gr.Guid   
		,Gr.Name   
		,Gr.Guid   
		,Gr.Name   
		,R1.ColName   
		,R1.ColOrder   
		,R1.ColSubOrder   
		,Groups.Path   
		,0  
		,R1.Value   
	FROM    
		#Groups Groups   
		INNER JOIN Gr000 Gr ON Gr.Guid = Groups.Guid   
		INNER JOIN   
		(   
			  SELECT    
					R.GroupGuid   
					,ColName   
					,ColOrder   
					,ColSubOrder   
					,ISNULL(AvailableQty / NULLIF(TargetQty, 0), 0)
					 AS Value
			  FROM 
				#Result R
				INNER JOIN (
					SELECT 
						R.GroupGuid,R.ColName AS StName, 
						R.Value / @ActualWorkingDays AS TargetQty  
					 FROM 
						#Result R 
						INNER JOIN #Groups gr ON gr.Guid = R.GroupGuid  
						INNER JOIN st000 st ON st.Name = R.ColName
						WHERE ColOrder = 4  AND R.Type =0 
					
				)  sums ON sums.GroupGuid = R.GroupGuid AND sums.StName = R.ColName
				INNER JOIN 
				(SELECT tb1.GroupGuid,tb1.StName,(AvailableQty ) AS AvailableQty  FROM #temp_Tb1 
				tb1 INNER JOIN mt000 Mt ON Mt.GroupGuid = tb1.GroupGuid) 
				temp_sums ON  temp_sums.StName = R.ColName AND temp_sums.GroupGuid = R.GroupGuid
			  GROUP BY R.GroupGuid   
						  ,ColName   
						  ,ColOrder   
						  ,ColSubOrder  
						  ,TargetQty 
						  ,AvailableQty
		)R1 ON R1.GroupGuid = Gr.Guid 
		WHERE  R1.ColOrder =10
	
	
	WHILE(@MaxLevel > 0)   
	BEGIN   
		SET @MaxLevel = @MaxLevel - 1   
		INSERT INTO #Result   
		SELECT   
			  Gr.Guid   
			  ,Gr.Name   
			  ,Gr.Guid   
			  ,Gr.Name   
			  ,ResultGroup.ColName   
			  ,ResultGroup.ColOrder   
			  ,ResultGroup.ColSubOrder   
			  ,Groups.Path   
			  ,0   
			  ,ResultGroup.Value   
		FROM #Groups Groups   
		INNER JOIN Gr000 Gr ON Gr.Guid = Groups.Guid   
		INNER JOIN   
		(   
			SELECT    
				Gr.ParentGuid AS GroupGuid   
				,ColName   
				,ColOrder   
				,ColSubOrder   
				,SUM(Value) Value   
			FROM #Result R   
			INNER JOIN #Groups Groups ON R.GroupGuid = Groups.Guid   
			INNER JOIN Gr000 Gr ON Gr.Guid = Groups.Guid   
			WHERE Groups.Level = @MaxLevel + 1   
			GROUP BY    
				Gr.ParentGuid   
				,ColName   
				,ColOrder   
				,ColSubOrder   
		)ResultGroup ON ResultGroup.GroupGuid = Gr.Guid   
	END   
	IF(@ShowMaterialsDetails = 0)   
		  DELETE FROM #Result WHERE Type = 1   
		    
	INSERT INTO #Result   
	SELECT   
		St.Guid   
		,''   
		,St.Guid   
		,St.Name   
		,St.Name   
		,Css.Number   
		,0   
		,'0'   
		,-1   
		,Css.Number   
	FROM   
		#CenterStoreStores Css   
		INNER JOIN St000 St ON Css.Guid = St.Guid
	  
	INSERT INTO #Result  
	SELECT  
		0x0  
		,'«·„Ã«„Ì⁄'  
		,0x0  
		,''  
		,R.ColName  
		,R.ColOrder   
		,R.ColSubOrder   
		,'«·„Ã«„Ì⁄'  
		,3  
		,SUM(ISNULL(R.Value , 0))	 
	FROM 
		#Result  R
	WHERE 
		R.Type = 0   AND R.ColOrder <> 10
	GROUP BY R.ColName
			,R.ColOrder
			,R.ColSubOrder

	INSERT INTO #Result  
	SELECT  
		0x0  
		,'«·„Ã«„Ì⁄'  
		,0x0  
		,''  
		,R.ColName  
		,R.ColOrder   
		,R.ColSubOrder   
		,'«·„Ã«„Ì⁄'  
		,3 
	    ,ISNULL(((tempTb.AvailableQty) /(R12.targetQty/@ActualWorkingDays)),0) AS Value
	FROM 
		#Result  R
		INNER JOIN
		(select R.ColName,SUM(R.Value) as targetQty 
		 FROM #Result  R
		 WHERE  R.Type = 0 AND R.ColOrder =4  
		 Group By 
		 R.ColName 
		
		)R12 ON R.ColName = R12.ColName   
		INNER JOIN 
		(SELECT temp.StName,SUM(temp.AvailableQty) as AvailableQty FROM #temp_Tb1 temp Group by temp.StName) tempTb 
		 ON tempTb.StName = R.ColName 
	WHERE 
		R.Type = 0   AND R.ColOrder = 10  
	GROUP BY R.ColName
			,R.ColOrder
			,R.ColSubOrder
			,R12.targetQty
			,tempTb.AvailableQty

	CREATE TABLE #tempTb
	(MatGuid uniqueidentifier
	,MatTotal FLOAT)

	INSERT INTO #tempTb
	SELECT 
	   R.MaterialGuid,SUM(r.Value) AS MatTotal
    FROM 
		#Result R INNER JOIN mt000 mt 
	 ON 
		R.MaterialGuid = mt.GUID  
	 WHERE
		 R.ColOrder = 8  AND R.ColSubOrder >=0   AND R.Type = 1
	GROUP BY R.MaterialGuid,
		 R.MaterialName 

		
	CREATE TABLE #temp(G uniqueidentifier , GroupTotal FLOAT)
	INSERT INTO #temp
	SELECT 
			R.GroupGuid,SUM(R.Value) AS GroupTotal 
	FROM 
			#Result R INNER JOIN gr000 GR ON R.GroupGuid = GR.GUID  
		  WHERE R.ColOrder = 8  AND R.ColSubOrder >=0   AND R.Type = 0
	GROUP BY R.GroupGuid,
			 R.GroupName 
	
SELECT 
		R.*,
		ISNULL(
			CASE @Unit 
				WHEN 0 THEN mt.mtUnity
				WHEN 1 THEN CASE mt.mtUnit2 WHEN  '' THEN mt.mtDefUnitName  ELSE mt.mtUnit2 END
				WHEN 2 THEN CASE mt.mtUnit3 WHEN  '' THEN mt.mtDefUnitName  ELSE mt.mtUnit3 END 
				ELSE mt.mtDefUnitName    
			END, '') AS UnitName
			,CASE R.type WHEN 1 THEN TTb.MatTotal WHEN 0 THEN temp.GroupTotal END AS total			
	FROM
		#Result R
		LEFT JOIN vwmt mt ON R.MaterialGuid = mt.mtGuid
		left join #tempTb  TTb on  R.MaterialGuid = TTb.MatGuid
		left join #temp temp on R.GroupGuid = temp.G
	  
	ORDER BY 
		[Path], 
		[Type], 
		MaterialName, 
		ColOrder, 
		ColSubOrder,
		total

--prcconnections_add2 '„œÌ— '
/*
EXECUTE [ReadyMaterialAvalability] '00000000-0000-0000-0000-000000000000', '00000000-0000-0000-0000-000000000000', 1, 'fcc63761-5f8e-415e-a654-51b70d56cad6', 3, 165
*/
###########################################################
#END