#########################################################
## fnGetTimeFromDT
CREATE FUNCTION fnGetTimeFromDT (@DT [DATETIME]) 
	RETURNS [DATETIME] 
AS BEGIN 
	RETURN  
		CAST(CAST(DatePart(Hour,@DT) AS [NVARCHAR](4)) + ':' + CAST(DatePart(Minute, @DT) AS [NVARCHAR](4)) + ':' + CAST(DatePart(Second,@DT) AS [NVARCHAR](4)) AS [DATETIME]) 
END 
#########################################################
CREATE PROCEDURE repDistributorActivety  
	@SrcGuid			AS UNIQUEIDENTIFIER,    
	@StartDate			AS DATETIME,  
	@EndDate			AS DATETIME,      
	@DistPtr			AS UNIQUEIDENTIFIER,  
	@HierarchyPtr		AS UNIQUEIDENTIFIER,  
	@AccGuid			AS UNIQUEIDENTIFIER, 
	@CurPtr				AS UNIQUEIDENTIFIER,  
	@UseUnit			AS INT,  
	@Rout				AS [INT] = 0,  
	@ShowTiming			AS [INT] = 0,  
	@PeriodGuid			AS UNIQUEIDENTIFIER = 0x00,  
	@NotSales			AS INT = 0,  
	@BillVisit			AS INT = 0,		-- 0  Bill From Ameen IS Visit		1 Bill From Amn Is Not Visit  
	@ShowActiveIn		AS INT = 1,		-- 0 Don't Show		1 Show      
	@ShowActiveOut		AS INT = 0, 
	@ShowInactiveIn		AS INT = 0, 
	@ShowInactiveOut	AS INT = 0, 
	@NoVisitInRoute		AS INT = 0,		-- 0 Don't Find no visit		1 Find no visit 
	@ShowSalesDetail 	AS INT = 0,
	@ShowBonusDetail 	AS INT = 0,
	@SalesDisplay		AS INT = 0,		-- 0 Material	1 Group
	@BonusDisplay		AS INT = 0		-- 0 Material	1 Group
AS  
	SET NOCOUNT ON 
	DECLARE @UserId UNIQUEIDENTIFIER, @NormalEntry	AS INT 
	CREATE TABLE [#DistCust] 	( [Number] 	[UNIQUEIDENTIFIER], [Security]	 	[INT], [AccountGuid] 		[UNIQUEIDENTIFIER], [DistributorGUID] 	[uniqueidentifier]) 
	CREATE TABLE [#Custtbl] (cuGuid UNIQUEIDENTIFIER, cuCustomerName NVARCHAR(250) COLLATE ARABIC_CI_AI, cuSecurity INT, cuAccount UNIQUEIDENTIFIER) 
	CREATE TABLE [#CostTbl] ( [Guid] 	[UNIQUEIDENTIFIER], [Security] 		[INT], [DistGuid] 		[UNIQUEIDENTIFIER] )     
	CREATE TABLE [#BillTbl] ( [Type] 	[UNIQUEIDENTIFIER], [Security] 		[INT], [ReadPriceSecurity] 	[INT], [UnPostedSecurity] 	[INT]) 
	CREATE TABLE [#EntryTbl]( [Type] 	[UNIQUEIDENTIFIER], [Security]  	[INT])  
	SET @HierarchyPtr = ISNULL(@HierarchyPtr, 0x00)	 
	CREATE TABLE #DistTbl( [DistGUID]	[UNIQUEIDENTIFIER], [distSecurity]	[INT]) 
	INSERT INTO [#DistTbl] EXEC GetDistributionsList @DistPtr, @HierarchyPtr  
	 
	INSERT INTO #CostTbl 
	SELECT co.coGUID, co.coSecurity, D.Guid 
	FROM 
		vwCo AS co 
		INNER JOIN vwDistSalesMan 	AS sm 	ON sm.CostGUID = co.coGUID 
		INNER JOIN vwDistributor	AS d 	ON d.PrimSalesManGUID = sm.GUID 
		INNER JOIN #DistTbl 		AS dt 	ON dt.DistGUID = d.GUID 
	CREATE TABLE [#SecViol] ( [Type]	[INT], [Cnt]	[INT]) 
	CREATE TABLE [#RESULT] 
	(
		[CustPtr]				[UNIQUEIDENTIFIER], 
		[RouteTime]				[DATETIME], 
		[CustSecurity]			[INT]   DEFAULT	0,     
		[Security]				[INT]   DEFAULT 0, 
		[buGuid]				[UNIQUEIDENTIFIER],      
		[BuTotal]				[FLOAT] DEFAULT 0,      
		[BuVAT]					[FLOAT] DEFAULT 0,     
		[BuDiscount]			[FLOAT] DEFAULT 0,     
		[BuExtra]				[FLOAT] DEFAULT 0,      
		[Reseved]				[FLOAT] DEFAULT 0, 
		[Payied]				[FLOAT] DEFAULT 0, 
		[BuDirection]			[INT]   DEFAULT 0, 
		[PayType]				[INT]   DEFAULT 0, 
		[State]					[INT]   DEFAULT 0, 
		[TripTime]				[DATETIME], 
		[StartTime]				[DATETIME], 
		[FinishTime]			[DATETIME], 
		[TimeArrive]			[DATETIME], 
		[StackRecorded]			[INT]   DEFAULT 0, 
		[ApperenceRecorded]		[INT]   DEFAULT 0, 
		[UserSecurity]			[INT], 
		[DistributorGUID]		[UNIQUEIDENTIFIER], 
		[Date]					[DateTime], 
		[GUID]					[uniqueidentifier], 
		[CeTotal]				[FLOAT] DEFAULT 0, 
		[VisitGUID]				[uniqueidentifier] DEFAULT 0x00, 
		[VdGuid]				[uniqueidentifier] DEFAULT 0x00,
		[CustWithDist]			INT DEFAULT 0	-- 1 Cust Related To Dist 	2 Cust Not Related To Dist 
	) 

	SET @UserId = dbo.fnGetCurrentUserGUID()  
	SET @NormalEntry = dbo.fnIsNormalEntry( @SrcGuid)      
	 
	INSERT INTO [#BillTbl] EXEC [prcGetBillsTypesList2] @SrcGuid, @UserID     
	INSERT INTO [#EntryTbl] EXEC [prcGetEntriesTypesList] @SrcGuid, @UserID     
	---------------------------------------------------------------- 
	INSERT INTO #DistCust
		SELECT
			cu.cuGuid,
			cu.cuSecurity,
			cu.cuAccount,
			dl.DistGuid
		FROM
			distdistributionlines000 AS dl
			INNER JOIN vwcu AS cu ON dl.CustGuid = cu.CuGuid
--select * from #DistCust
--  INSERT INTO #DistCust ([Number] , [Security]) EXEC prcGetDistGustsList @DistPtr, 0x00, 0x00, @HierarchyPtr  
--	UPDATE #DistCust SET 	[AccountGuid] = Cu.cuAccount, 
--				[DistributorGUID] = Dl.DistGuid 
--	FROM #DistCust AS C 
--		INNER JOIN vwCu AS Cu	ON Cu.CuGuid = C.Number 
--		INNEr JOIN DistDistributionLines000	AS Dl	ON Dl.CustGuid = Cu.CuGuid	 

	----------------------------------------------------------------
	INSERT INTO #Custtbl
		SELECT	cuGuid,
				cuCustomerName,
				cuSecurity,
				cuAccount
		FROM vwcu AS cu
		INNER JOIN [dbo].[fnGetCustsOfAcc](@AccGUID) AS fCu ON Cu.cuGuid = fCu.Guid 
		
	----------------------------------------------------------------------------
	--To calculate the account balance for each of the customers 
	CREATE TABLE [#AccBalList] ([AccGuid] [UNIQUEIDENTIFIER], [AccBalance] [float])
	INSERT INTO [#AccBalList]
	SELECT [cu].[cuAccount], SUM([en].[enDebit] - [en].[enCredit])
		FROM
			[vwCeEn] AS [en]
			INNER JOIN [#Custtbl] AS [cu] ON [cu].[cuAccount] = en.[enAccount]
		Where
			[en].[ceIsPosted] <> 0
		GROUP BY
			[cu].[cuAccount]

	--To calculate the account balance for each one of the customer according to the distributor costguid
	DECLARE @DistCostGuid [UNIQUEIDENTIFIER]	
	SELECT @DistCostGuid = ds.CostGuid FROM DistSalesman000 AS ds
							INNER JOIN Distributor000 AS d ON d.PrimSalesmanGuid = ds.Guid
							WHERE d.Guid = @DistPtr

	CREATE TABLE [#CostBalList] ([AccGuid] [UNIQUEIDENTIFIER], [AccBalance] [float])
	INSERT INTO [#CostBalList]
	SELECT [cu].[cuAccount], Sum([en].[enDebit] - [en].[enCredit])
		FROM
			[vwCeEn] AS [en]
			INNER JOIN [#Custtbl] AS [cu] ON [cu].[cuAccount] = en.[enAccount]
		Where
			[en].[ceIsPosted] <> 0 AND [en].[enCostPoint] = @DistCostGuid
		GROUP BY
			[cu].[cuAccount]

----------------------------------------------------------------------------

	--------- Get Visits States ----------------------------------------------------------------- 
	CREATE TABLE #TotalVisitsStates (VisitGuid UNIQUEIDENTIFIER, CustGuid UNIQUEIDENTIFIER, DistGuid UNIQUEIDENTIFIER, State INT, VisitDate DATETIME) -- State: 1 Active , 0 Inactive
	INSERT INTO #TotalVisitsStates EXEC prcDistGetVisitsState @StartDate, @EndDate, @HierarchyPtr, @DistPtr, @BillVisit, @SrcGuid
	---------------------------------------------------------------- 
	CREATE CLUSTERED INDEX [IND] ON [#DistCust]([NUMBER]) 
	---------------------------------------------------------------- 
	INSERT INTO [#RESULT] 
		SELECT --DISTINCT 
			[VCu].[CuGuid], 
			'1/1/1980', 
			[VCu].[CuSecurity], 
			[buSecurity], 
			[buGUID], 
			[FixedBuTotal], 
			[FixedBuVAT], 
			[FixedbuItemsDisc] + [FixedBuBonusDisc] + ISNULL((SELECT SUM([di2].[Discount]) FROM [di000] AS di2 WHERE di2.ParentGuid=bi.buGuid AND (di2.ContraAccGuid = Vcu.CuAccount OR (ISNULL(di2.ContraAccGuid,0X0) =0X0))  AND di2.Discount!=0) *[FixedCurrencyFactor] ,0),--FixedBuTotalDisc, 
			ISNULL((SELECT SUM([di].[Extra]) FROM [di000] AS [di] WHERE di.ParentGuid=bi.buGuid AND ([di].[ContraAccGuid] = [Vcu].[CuAccount]  OR (ISNULL(di.ContraAccGuid,0X0) =0X0))  AND di.Extra!=0),0) * FixedCurrencyFactor,--FixedBuTotalExtra, 
			CASE ( CASE [btIsInput] WHEN 0 THEN -1 ELSE 1 END) WHEN -1 THEN 1 ELSE 0 END * FixedBuFirstPay , 
			CASE ( CASE [btIsInput] WHEN 0 THEN -1 ELSE 1 END) WHEN  1 THEN 1 ELSE 0 END * FixedBuFirstPay , 
			CASE [btIsInput] WHEN 0 THEN -1 ELSE 1 END , 
			[buPayType], 
			0, 
			'1/1/1980', 
			'1/1/1980', 
			'1/1/1980', 
			'1/1/1980', 
			0, 
			0, 
			CASE [buIsPosted] WHEN 1 THEN [bt].[Security] ELSE [UnPostedSecurity] END, 
			Co.DistGuid,	 
			[buDate], 
			newid(), 
			0,
			ISNULL(Vd.VistGuid, 0x00), 
			ISNULL(Vd.Guid, 0x0),
			CASE ISNULL( cu.Number, 0x0) WHEN 0x0 THEN 2 ELSE 1 END  -- Cu.Number Is Null : Cust Not Related To Dist 
		FROM 
			[dbo].[fn_bubi_Fixed]( @CurPtr) AS bi 
			INNER JOIN #Custtbl		AS vCu	ON vCu.CuGuid    = [bi].[buCustPtr] 
			INNER JOIN [#BillTbl] 	AS [bt] ON [bt].[Type]   = [bi].[buType] 
			INNER JOIN [#CostTbl] 	AS [co] ON [co].[GUID]   = bi.buCostPtr 
			LEFT  JOIN [#DistCust]  AS [cu] ON [cu].[Number] = [bi].[buCustPtr] AND [cu].[DistributorGuid] = [co].[DistGuid]
			LEFT  JOIN DistVd000	AS Vd 	ON vd.ObjectGuid = bi.buGuid 
		WHERE	 
			( [bi].[BuDate] BETWEEN @StartDate AND @EndDate ) 	 
			AND ( ISNULL(Vd.ObjectGuid, 0x00) <> 0x00 OR @BillVisit = 1 ) 
		GROUP BY 
			[cu].[Number], 
			[Vcu].[CuGuid], 
			[Vcu].[CuSecurity], 
			[buSecurity], 
			[buGUID], 
			[FixedBuTotal], 
			[FixedBuVAT], 
			[FixedbuItemsDisc], 
			[FixedBuBonusDisc], 
			bi.buGuid, 
			Vcu.CuAccount, 
			FixedCurrencyFactor,			 
			btIsInput, 
			btIsInput, 
			[buPayType], 
			[bt].[Security], 
			UnPostedSecurity, 
			[cu].[DistributorGUID],		 
			[co].[DistGUID],		 
			[bi].[FixedbuFirstPay], 
			[bi].[buIsPosted], 
			[bi].[buDate], 
			[vd].[VistGuid],
			[vd].[Guid]
--Select * from #Result 
----------------------------------------------------------------------------------------- 

----------------------------------------------------------------------------------------- 
	-- if (@Rout <> 0 OR @ShowTiming <> 0 OR @NotSales <> 0) 
	-- begin 
		CREATE TABLE #Visit( 
			GUID 		uniqueidentifier, 
			CustGUID 	uniqueidentifier, 
			DistributorGUID uniqueidentifier, 
			InDate 		datetime, 
			OutDate 	datetime, 
			State 		int, 
			EntryStockOfCust int, 
			EntryVisibility int, 
			CustWithDist	INT DEFAULT(0), 
			UseCustBarcode	BIT,	-- 1 Dist Read CustBarcode 0 Dist Does Not Read CustBarcode  
			UseCustGPS	BIT
		) 
		INSERT INTO #Visit 
		SELECT 
			vi.GUID, 
			vi.CustomerGUID, 
			tr.DistributorGUID, 
			vi.StartTime AS InDate, 
			vi.FinishTime AS OutDate, 
			-- vi.State, 
			ISNULL(vi.State, 0), 
			vi.EntryStockOfCust, 
			vi.EntryVisibility, 
			CASE ISNULL( cu.Number, 0x0) WHEN 0x0 THEN 2 ELSE 1 END,  -- Cu.Number Is Null : Cust Not Related To Dist 
			vi.UseCustBarcode,
			vi.UseCustGPS 
		FROM 
			DistVi000 AS vi 
			INNER JOIN DistTr000 	AS tr	ON tr.GUID = vi.TripGUID 
			INNER JOIN #DistTbl  	AS d 	ON d.DistGUID = tr.DistributorGUID 
			LEFT  JOIN  #DistCust 	AS Cu	ON Cu.Number = vi.CustomerGuid AND Cu.DistributorGuid = tr.DistributorGuid
		WHERE 
			ISNULL([vi].[StartTime], '1/1/2000') BETWEEN  @StartDate AND @EndDate 
-- SELECT * FROM #Visit Order By InDate , CustGuid 
	-- end 
	------------------------------------------------------------------------------------ 
	---- Compare With Route 
	--DECLARE @Rout INT	 
	SELECT @Rout = dbo.fnDistGetRouteNumOfDate(@StartDate)	 
	CREATE TABLE #CustRoute 
	( 
		CustGUID 	uniqueidentifier, 
		DistributorGUID uniqueidentifier, 
		Route		INT default (-1), 
		RouteTime	DateTime, 
		RouteDate	DateTime 
	) 
	if (@Rout <> 0)						 
	begin 
		DECLARE  @dGUID 	uniqueidentifier, 
			 @cGUID 	uniqueidentifier, 
			 @t datetime, 
			 @RT datetime 
		SET @t = dbo.FnGetDateFromDt(@StartDate)
		DECLARE c CURSOR FOR SELECT DistGUID FROM #DistTbl 
		OPEN c 
		FETCH NEXT FROM c INTO @dGUID 
		 
		WHILE @@FETCH_STATUS = 0 
		BEGIN 
			WHILE(@t<= @EndDate) 
			BEGIN 
				SELECT @Rout = dbo.fnDistGetRouteNumOfDate(@t) 
				INSERT INTO #CustRoute(CustGUID,RouteTime) EXEC prcDistGetRouteOfDistributor @dGUID, @Rout 
				UPDATE #CustRoute  
					SET 	DistributorGUID = @dGUID, 
						Route = @Rout, 
						RouteDate =@t 
				WHERE DistributorGUID IS NULL OR DistributorGUID = 0x00 
				SET @t=DATEADD ( d , 1, @t )  
			END	 
			FETCH NEXT FROM c INTO @dGUID 
			SET @t = dbo.FnGetDateFromDt(@StartDate)
		END 
		CLOSE c 
		DEALLOCATE c 
		 
		--SELECT * FROM #CustRoute	---- 
		--------------------- 
----------------------------------------------------------------------------- 
--SELECT * FROM #Result
		INSERT INTO #Result( 
			[CustPtr], 
			[RouteTime], 
			[CustSecurity], 
			[Security], 
			[buGuid], 
			[BuTotal], 
			[BuVAT], 
			[BuDiscount], 
			[BuExtra], 
			[Reseved], 
			[Payied], 
			[BuDirection], 
			[PayType], 
			[State], 
			[TripTime], 
			[StartTime], 
			[FinishTime], 
			[TimeArrive], 
			[StackRecorded], 
			[ApperenceRecorded], 
			[UserSecurity], 
			[DistributorGUID], 
			[Date], 
			[GUID], 
			[CeTotal],
			[VisitGuid],
			[VdGuid],
			[CustWithDist] 
		) 
		SELECT 
			v.CustGUID, 
			'1/1/1980', 
			cu.cuSecurity, 
			1, 
			ISNULL(Vd.ObjectGuid, 0x00),
			0, 
			0, 
			0, 
			0, 
			0, 
			0, 
			0, 
			0, 
			v.State,				-- State = 0  
			'1/1/1980', 
			'1/1/1980', 
			'1/1/1980', 
			'1/1/1980', 
			v.EntryStockOfCust, 
			v.EntryVisibility, 
			1,			 
			v.DistributorGUID,
			[dbo].[fnGetDateFromDT](ISNULL([v].[InDate],'1/1/2000')),
			newid(),
			0,
			v.Guid,
			ISNULL(Vd.Guid, 0x0),
			v.CustWithDist 
		FROM 
			#Visit AS v
			LEFT JOIN DistVd000 AS Vd ON v.Guid = Vd.VistGuid AND Vd.Type = 2
			INNER JOIN #Custtbl  AS cu ON cu.cuGUID = v.CustGUID 
			LEFT JOIN #Result AS r ON r.VisitGuid = v.Guid 
		WHERE 
			r.buGUID IS NULL
 --SELECT * FROM #Result 

--------------------------------------------------------------------------------
		-- set the states of the visits
		-- Active + In Route = State1
		UPDATE #Result SET State = 1
		FROM
			#Result AS b
			INNER JOIN #TotalVisitsStates AS tvs ON b.VisitGuid = tvs.VisitGuid
			INNER JOIN #CustRoute AS r ON b.DistributorGUID = r.DistributorGUID AND b.CustPtr = r.CustGUID AND b.[Date]=r.RouteDate
		WHERE tvs.State = 1

		--- Not Active + In Route = State3
		/*UPDATE #Result SET State = 3
		FROM
			#Result AS b
			INNER JOIN #TotalVisitsStates AS tvs ON b.VisitGuid = tvs.VisitGuid
			INNER JOIN #CustRoute AS r ON b.DistributorGUID = r.DistributorGUID AND b.CustPtr = r.CustGUID  AND r.RouteDate=b.[Date]  
		WHERE tvs.State = 0*/

		-- Active + Out of Route = State2  
		UPDATE #Result SET State = 2
		FROM
			#Result AS b
			INNER JOIN #TotalVisitsStates AS tvs ON b.VisitGuid = tvs.VisitGuid
		WHERE tvs.State = 1 AND b.State = 0

		--- Not Active + Out of Route = State4  
		UPDATE #Result SET State = 4 WHERE State = 0  
		------------------------------------------------------------- 
		 
	end 
-- SELECT * FROM #Result 
	-------------------------------------------------------------------- 
	UPDATE #Result SET RouteTime = r.RouteTime 
		FROM 
			#CustRoute AS r 
			INNER JOIN #Result AS b ON b.DistributorGUID = r.DistributorGUID AND b.CustPtr = r.CustGUID  AND r.RouteDate=b.[Date] 
		WHERE 
			b.State = 1  or b.State=3 or b.State=5 
	-------------------------------------------------------------------- 
	-------------------------------------------------------------------- 
	---- Calc Entry Stock & Shelf Share 
	--if (@Rout > 0) 
	--begin 
		UPDATE #Result  
		SET  
			StackRecorded = EntryStockOfCust, 
			ApperenceRecorded = EntryVisibility 
		FROM 
			#Result AS r, #Visit AS v 
		WHERE 
			r.VisitGuid = v.Guid  
	--end 
	-------------------------------------------------------------------- 
	------------------------------------------------------ 
	UPDATE [#RESULT] SET  
			[Reseved] = CASE [buDirection] WHEN -1 THEN 1 ELSE 0 END * ( [BuTotal] + [BuVAT] - [BuDiscount] + [BuExtra]),	   
			-- [Payied]  = CASE [buDirection] WHEN  1 THEN 1 ELSE 0 END * ( [BuTotal] + [BuVAT] - [BuDiscount] + [BuExtra]) 
			[Payied]  = [Payied] + CASE [buDirection] WHEN  1 THEN 1 ELSE 0 END * ( [BuTotal] + [BuVAT] - [BuDiscount] + [BuExtra]) 
	WHERE [PayType] = 0 
	------------------------------------------------------ 
----------------------------------------------------------------------------------------- 
------- Get Payments 
	CREATE TABLE #CeTotals (GUID UNIQUEIDENTIFIER, EnGuid UNIQUEIDENTIFIER, CeDate DATETIME, CuGuid UNIQUEIDENTIFIER, AccGuid UNIQUEIDENTIFIER,  
				CeSecurity INT, CuSecurity INT, CuDistGuid UNIQUEIDENTIFIER, TotalCredit FLOAT, TotalDebit FLOAT, CustWithDist INT DEFAULT 0, VisitGuid UNIQUEIDENTIFIER, VdGuid UNIQUEIDENTIFIER) 
	INSERT INTO #CeTotals 
	SELECT 	NewId(), En.enGuid, En.CeDate, VCu.CuGuid, VCu.CuAccount, 1, Vcu.CuSecurity, [Co].[DistGUID],  
			(ISNULL(En.EnCredit, 0)), (ISNULL(En.EnDebit, 0)),  
			CASE ISNULL(Cu.Number, 0x0) WHEN 0x0 THEN 2 ELSE 1 END,
			Vd.VistGuid, Vd.Guid
	FROM  
		[dbo].[fnCeEn_Fixed](@CurPtr) 	AS En  
		INNER JOIN #Custtbl 	AS VCu  ON En.enAccount = VCu.CuAccount  
		INNER JOIN vwEr 	AS Er ON Er.erEntryGuid = En.CeGuid 
		INNER JOIN vwPy 	AS Py ON Py.pyGuid = Er.erParentGuid 
		INNER JOIN #EntryTbl	AS [Et] ON [Et].[Type] = [En].[ceTypeGuid]  
		INNER JOIN [#CostTbl] 	AS [co] ON [co].[GUID] = [en].[enCostPoint]
		LEFT  JOIN #DistCust 	AS [Cu] ON En.enAccount = Cu.AccountGuid AND Cu.DistributorGuid = Co.DistGuid
		INNER JOIN DistVd000	AS Vd	ON Vd.ObjectGuid = En.enGuid
	WHERE 
		[En].[CeDate] BETWEEN  @StartDate AND @EndDate 
	
 --Select * from #CeTotals
	DECLARE @C 					Cursor, 
			@Dist_Guid			UNIQUEIDENTIFIER, 
			@Cu_Guid			UNIQUEIDENTIFIER, 
			@Guid				UNIQUEIDENTIFIER, 
			@En_Guid			UNIQUEIDENTIFIER, 
			@Ce_Date			DATETIME, 
			@Ce_Security		INT, 
			@Cu_Security		INT, 
			@Ce_TotalDebit		FLOAT, 
			@Ce_TotalCredit		FLOAT, 
			@Ce_CustWithDist	INT,
			@VisitGuid			UNIQUEIDENTIFIER,
			@VdGuid				UNIQUEIDENTIFIER
--select * from #Result
	SET @C = CURSOR FAST_FORWARD FOR  
		SELECT EnGuid, CuDistGuid, CuGuid, CeDate, CuSecurity, TotalCredit, TotalDebit, CustWithDist, VisitGuid, VdGuid FROM #CeTotals 
	OPEN @C FETCH FROM @C INTO @En_Guid, @Dist_Guid, @Cu_Guid, @Ce_Date, @Cu_Security, @Ce_TotalCredit, @Ce_TotalDebit, @Ce_CustWithDist, @Visitguid, @VdGuid
	WHILE @@FETCH_STATUS = 0  
	BEGIN  

		SET @Guid = 0x0

		SELECT @Guid = Guid FROM #Result Where VdGuid = @VdGuid
-- WHERE DistributorGUID = @Dist_Guid AND CustPtr = @Cu_Guid AND Date = @Ce_Date

		IF ISNULL(@Guid, 0x00) <> 0x00 
		BEGIN
			IF @Ce_TotalCredit <> 0
			BEGIN 
				UPDATE #Result SET CeTotal = CeTotal + @Ce_TotalCredit WHERE Guid = @Guid 
			END 
			IF @Ce_TotalDebit <> 0  
			BEGIN 
				UPdATE #Result SET Payied = Payied + @Ce_TotalDebit WHERE Guid = @Guid 
			END 
		END 
		ELSE 
		BEGIN 
			IF (@Ce_TotalCredit <> 0) 
			BEGIN 
				INSERT INTO [#RESULT] 
					SELECT	@Cu_Guid,'1/1/1980', @Cu_Security,	1, @En_Guid, 0, 0, 0, 0, 0, 0, -1, 0, 0, --state = 0, 
						'1/1/1980', '1/1/1980',	'1/1/1980', '1/1/1980',	0, 0, 1,  
						@Dist_Guid, @Ce_Date, newid(), @Ce_TotalCredit, @VisitGuid, @VdGuid, @Ce_CustWithDist
			END 
			IF (@Ce_TotalDebit <> 0) 
			BEGIN
				INSERT INTO [#RESULT] 
					SELECT	@Cu_Guid,'1/1/1980', @Cu_Security,	1, @En_Guid, 0, 0, 0, 0, 0, @Ce_TotalDebit, 1, 0, 0, --state = 0, 
						'1/1/1980', '1/1/1980',	'1/1/1980', '1/1/1980',	0, 0, 1,  
						@Dist_Guid, @Ce_Date, newid(), 0, @VisitGuid, @VdGuid, @Ce_CustWithDist
			END 
		END		 
		FETCH FROM @C INTO @En_Guid, @Dist_Guid, @Cu_Guid, @Ce_Date, @Cu_Security, @Ce_TotalCredit, @Ce_TotalDebit, @Ce_CustWithDist, @VisitGuid, @VdGuid
	END -- @C loop  
	CLOSE @C DEALLOCATE @C  
	--------------------------------------------------------------------------------
	--Set the state of the entries inserted above
		--- Active + In Route = State1
		UPDATE #Result SET State = 1, VisitGuid = tvs.VisitGuid
		FROM
			#Result AS b
			INNER JOIN [dbo].[fnCeEn_Fixed](@CurPtr) AS En ON b.buGuid = En.enGuid
			INNER JOIN DistVd000 AS vd ON vd.ObjectGuid = En.enGuid
			INNER JOIN #TotalVisitsStates AS tvs ON vd.VistGuid = tvs.VisitGuid
			INNER JOIN #CustRoute AS r ON b.DistributorGUID = r.DistributorGUID AND b.CustPtr = r.CustGUID AND b.[Date]=r.RouteDate
		WHERE tvs.State = 1 AND b.State = 0

		--- Not Active + In Route = State3
		UPDATE #Result SET State = 3, VisitGuid = tvs.VisitGuid
		FROM
			#Result AS b
			INNER JOIN [dbo].[fnCeEn_Fixed](@CurPtr) AS En ON b.buGuid = En.enGuid
			INNER JOIN DistVd000 AS vd ON vd.ObjectGuid = En.enGuid
			INNER JOIN #TotalVisitsStates AS tvs ON vd.VistGuid = tvs.VisitGuid
			INNER JOIN #CustRoute AS r ON b.DistributorGUID = r.DistributorGUID AND b.CustPtr = r.CustGUID  AND r.RouteDate=b.[Date]  
		WHERE tvs.State = 0 AND b.State = 0

		-- Active + Out of Route = State2  
		UPDATE #Result SET State = 2, VisitGuid = tvs.VisitGuid
		FROM
			#Result AS b
			INNER JOIN [dbo].[fnCeEn_Fixed](@CurPtr) AS En ON b.buGuid = En.enGuid
			INNER JOIN DistVd000 AS vd ON vd.ObjectGuid = En.enGuid
			INNER JOIN #TotalVisitsStates AS tvs ON vd.VistGuid = tvs.VisitGuid
		WHERE tvs.State = 1 AND b.State = 0

		--- Not Active + Out of Route = State4  
		UPDATE #Result SET State = 4, VisitGuid = tvs.VisitGuid
		FROM
			#Result AS b
			INNER JOIN [dbo].[fnCeEn_Fixed](@CurPtr) AS En ON b.buGuid = En.enGuid
			INNER JOIN DistVd000 AS vd ON vd.ObjectGuid = En.enGuid
			INNER JOIN #TotalVisitsStates AS tvs ON vd.VistGuid = tvs.VisitGuid
		WHERE b.State = 0  

--------------------------------------------------------------------------------
		-- Delete the visits not in #TotalVisitsStates to solve the manual bills problem
		-- Because the DistVd000 now contains all the visits generated by manual bills and entries
		-- So this DELETE elemenates these results if the parameter @BillVisit = 0
		DELETE FROM #Result
		WHERE VisitGuid Not IN (SELECT VisitGuid FROM #TotalVisitsStates)

	----------------------------------------------------------------------------------------- 
	----- Timing 
		UPDATE #Result  
		SET  
			StartTime = InDate,  
			FinishTime = OutDate, 
			StackRecorded = EntryStockOfCust, 
			ApperenceRecorded = EntryVisibility 
		FROM 
			#Result AS r, #Visit AS v 
		WHERE 
			r.VisitGuid = V.Guid 
		 
		--SELECT GUID, StartTime, FinishTime FROM #Result  WHERE StartTime <> '1-1-1980' ORDER BY StartTime 
		DECLARE		@rGUID			uniqueidentifier,  
					@StartTime 		datetime,  
					@FinishTime 	datetime,  
					@PrevFinishTime datetime 
		DECLARE vCur CURSOR FOR  
			SELECT GUID, StartTime, FinishTIme FROM #Result WHERE StartTime <> '1-1-1980' ORDER BY StartTime 
		OPEN vCur FETCH NEXT FROM vCur INTO @rGUID, @StartTime, @FinishTime 
		--SET @PrevFinishTime = @FinishTime 
		DECLARE @Counter int 
		SET @Counter = 1 
		WHILE @@FETCH_STATUS = 0 
		BEGIN 
			-- if (@Counter <> 1) 
			if (@Counter <> 1 AND @PrevFinishTime <> @FinishTime) 
				UPDATE #Result SET TimeArrive = @StartTime - @PrevFinishTime WHERE GUID = @rGUID 
			SET @PrevFinishTime = @FinishTime 
			SET @Counter = @Counter + 1 
			FETCH NEXT FROM vCur INTO @rGUID, @StartTime, @FinishTime 
		END 
		CLOSE vCur 
		DEALLOCATE vCur 
--	end 
	------------------------------------------------------			  
	EXEC [prcCheckSecurity] @UserId  
	------------------------------------------------------			  
	-- Result 1 
	--SELECT * FROM #Result 
	CREATE TABLE #EndResult( 
		ID 		int IDENTITY(1, 1), 
		CustPtr 	uniqueidentifier, 
		CustBalance	float,
		CustCostBalance	float,
		DistPtr 	uniqueidentifier, 
		RoutTime 	datetime, 
		CustName 	NVARCHAR(250) COLLATE ARABIC_CI_AI , 
		DistName 	NVARCHAR(250) COLLATE ARABIC_CI_AI , 
		BillGUID 	uniqueidentifier, 
		Sales 		float, 
		RetSales 	float,       
		Vat 		float, 
		Discount 	float,     
		Extra 		float, 
		Reseved 	float,   -- œ›⁄«  «·›Ê« Ì— 
		Payied 		float, 
		CeTotal		FLOAT ,-- œ›⁄«  ”‰œ«  «·ﬁÌœ √Ê «· Õ’Ì·  
		State 		float, 
		StartTime 	datetime, 
		FinishTime 	datetime, 
		TimeArrive 	datetime, 
		Date	 	datetime, 
		StackRecorded 	int, 
		ApperenceRecorded int, 
		CustWithDist	INT, 
		VisitGuid		UNIQUEIDENTIFIER, 
		UseCustBarcode	BIT ,  
		UseCustGPS		BIT
	) 
-- Select * from  #RESULT	Order By StartTime 
	INSERT INTO #EndResult 
	( 
		CustPtr, 
		CustName, 
		CustBalance,
		CustCostBalance,
		DistPtr, 
		DistName, 
		BillGUID, 
		Sales, 
		RetSales, 
		Vat, 
		Discount, 
		Extra, 
		Reseved, 
		Payied, 
		CeTotal, 
		State, 
		StartTime, 
		FinishTime, 
		TimeArrive, 
		Date, 
		StackRecorded, 
		ApperenceRecorded, 
		CustWithDist, 
		RoutTime, 
		VisitGuid, 
		UseCustBarcode,
		UseCustGPS	  	 
	) 
	SELECT  
		[CustPtr]			AS CustPtr,		 
		[cuCustomerName]	AS CustName, 
		ISNULL(ab.[AccBalance], 0)	AS CustBalance,
		ISNULL(cb.[AccBalance], 0)	AS CustCostBalance,
		r.[DistributorGUID] AS DistPtr,
		d.[Name]			AS DistName,
		[BuGUID]			AS [BillGUID], 
		SUM([BuTotal]*CASE [BuDirection] WHEN -1 THEN 1 ELSE 0 END) AS [Sales], 
		SUM([BuTotal]*CASE [BuDirection] WHEN 1 THEN 1 ELSE 0 END) 	AS [RetSales],       
		SUM([BuVAT]*-[BuDirection]) 	AS Vat,      
		SUM([BuDiscount]*-[BuDirection])AS Discount,     
		SUM([BuExtra]*-[BuDirection]) 	AS Extra,      
		SUM([Reseved]) 	AS [Reseved], 
		SUM([Payied]) 	AS [Payied], 
		SUM([CeTotal]) 	AS [CeTotal], 
		-- SUM([State]) 	AS [State], 
		r.State, 
		r.[StartTime], 
		r.[FinishTime], 
		r.[TimeArrive], 
		r.[Date], 
		SUM(r.[StackRecorded]) 	 AS [StackRecorded], 
		SUM(r.[ApperenceRecorded]) AS [ApperenceRecorded], 
		r.CustWithDist, 
		r.RouteTime, 
		r.VisitGuid, 
		ISNULL(vi.UseCustBarcode, 0) ,
		ISNULL(vi.UseCustGPS, 0) 
	FROM  
		[#RESULT] AS [r]  
		INNER JOIN #Custtbl AS [cu] ON [cu].[cuGuid] = [CustPtr]  
		LEFT JOIN [#AccBalList] AS ab ON ab.AccGuid = cu.cuAccount
		LEFT JOIN [#CostBalList] AS cb ON cb.AccGuid = cu.cuAccount
		INNER JOIN vwDistributor AS d ON r.DistributorGUID = d.GUID 
		LEFT JOIN #Visit AS Vi ON vi.Guid = r.VisitGuid 
		-- INNER JOIN bu000 AS bu ON bu.Guid = BuGuid
	Where  
		(@ShowActiveIn		= 1		AND r.state = 1) OR
		(@ShowActiveOut		= 1		AND r.state = 2) OR
		(@ShowInactiveIn	= 1		AND r.state = 3) OR
		(@ShowInactiveOut	= 1		AND r.state = 4) OR
		(@NoVisitInRoute	= 1		AND r.state = 5)

	GROUP BY 
		r.[DistributorGUID],
		[d].[Name],
		r.[Date],	 
		[CustPtr], 
		[cuCustomerName], 
		[BuGUID], 
		r.State, 
		r.[StartTime], 
		r.[FinishTime], 
		r.[TimeArrive], 
		r.[TripTime], 
		r.CustWithDist, 
		r.VisitGuid, 
		r.RouteTime, 
		vi.UseCustBarcode,
		vi.UseCustGPS,
		ab.[AccBalance],
		cb.[AccBalance]
	ORDER BY 
		r.[DistributorGUID],
		r.[Date],	 
		[CustPtr],
		r.[TripTime], 
		r.[StartTime], 
		r.TimeArrive	-- ·Õ· „‘ﬂ·… «·Œÿ√ ›Ì Õ”«» “„‰ «·Ê’Ê· ⁄‰œ ÊÃÊœ √ﬂÀ— „‰ “Ì«—… »‰›” «·Êﬁ   
	------------------------------------------------------------------------------------ 
	---- 
	CREATE TABLE #EndResult2( 
		ID 			int default 0, 
		CustPtr 	uniqueidentifier, 
		CustBalance	float,
		CustCostBalance	float,
		DistPtr 	uniqueidentifier, 
		RoutTime 	datetime, 
		CustName 	NVARCHAR(250) COLLATE ARABIC_CI_AI , 
		DistName 	NVARCHAR(250) COLLATE ARABIC_CI_AI , 
		BillGUID 	uniqueidentifier, 
		Sales 		float, 
		RetSales 	float,       
		Vat 		float, 
		Discount 	float,     
		Extra 		float, 
		Reseved 	float,   -- œ›⁄«  «·›Ê« Ì— 
		Payied 		float, 
		CeTotal		FLOAT ,-- œ›⁄«  ”‰œ«  «·ﬁÌœ √Ê «· Õ’Ì·  
		State 		float, 
		StartTime 	datetime, 
		FinishTime 	datetime, 
		TimeArrive 	datetime, 
		Date	 	datetime, 
		StackRecorded 	int, 
		ApperenceRecorded int, 
		CustWithDist	INT, 
		VisitGuid		UNIQUEIDENTIFIER, 
		UseCustBarcode	BIT  ,
		UseCustGPS		BIT
	) 

	INSERT INTO #EndResult2
		SELECT * FROM #EndResult
	
	-----------------------------------------------------------------------------------------
		-- Insert the visits that is In Route And outof Bills And outof Visit = State5 
	IF(@NoVisitInRoute = 1)
	BEGIN
		INSERT INTO #EndResult2( 
			CustPtr, 
			CustName, 
			CustBalance,
			CustCostBalance,
			DistPtr, 
			DistName,
			BillGUID, 
			Sales, 
			RetSales, 
			Vat, 
			Discount, 
			Extra, 
			Reseved, 
			Payied, 
			CeTotal, 
			State, 
			StartTime, 
			FinishTime, 
			TimeArrive, 
			Date, 
			StackRecorded, 
			ApperenceRecorded, 
			CustWithDist, 
			RoutTime, 
			VisitGuid, 
			UseCustBarcode,
			UseCustGPS  	 
		) 
		SELECT DISTINCT
			dc.Number			AS CustPtr,		 
			cu.cuCustomerName	AS CustName,
			ISNULL(ab.[AccBalance], 0)	AS CustBalance,
			ISNULL(cb.[AccBalance], 0)	AS CustCostBalance,
			d.GUID				AS DistPtr,
			d.Name				AS DistName,
			0x00, 
			0, 
			0, 
			0, 
			0, 
			0, 
			0, 
			0, 
			0, 
			5,				-- State = 5 
			'1/1/3000', 
			'1/1/3000', 
			'1/1/3000', 
			'1/1/3000', 
			0, 
			0, 
			1,
			'1/1/3000',
			0x0,
			0 ,
			0
		FROM 
			#DistCust AS dc 
			INNER JOIN #Custtbl AS cu ON cu.cuGUID = dc.Number
			LEFT JOIN [#AccBalList] AS ab ON ab.AccGuid = cu.cuAccount
			LEFT JOIN [#CostBalList] AS cb ON cb.AccGuid = cu.cuAccount
			INNER JOIN vwDistributor AS d ON dc.DistributorGUID = d.GUID 
			INNER JOIN #CostTbl AS ct ON dc.DistributorGUID = ct.DistGuid
			INNER JOIN #CustRoute AS cr ON cr.DistributorGUID = dc.DistributorGUID AND cr.CustGuid = dc.Number
			--LEFT JOIN #Result AS r ON r.CustPtr = rt.CustGUID AND r.DistributorGUID = rt.DistributorGUID  AND rt.RouteDate=r.[Date] 

		WHERE 
			--r.buGUID IS null
			dc.Number NOT IN (SELECT CustPtr FROM #EndResult2 r2 WHERE r2.DistPtr = d.Guid)
			
		UPDATE #EndResult2
			SET VisitGuid = newid()
		WHERE VisitGuid = 0x0
	END
	-----------------------------------------------------------------------------------------
	--calculate the sales details and bonus details
	IF (@ShowSalesDetail = 1 OR @ShowBonusDetail = 1)
	BEGIN
		CREATE TABLE [#T_RESULT] 
		(
			CustPtr				UNIQUEIDENTIFIER,
			CustSecurity		INT,
			buGuid				UNIQUEIDENTIFIER,
			Security			INT,
			MatGuid				UNIQUEIDENTIFIER,
			MatSecurity			INT,
			GroupGuid			UNIQUEIDENTIFIER,
			Qty					FLOAT,
			Bonus				FLOAT,
			BuDirection			INT,
			DistributorGUID		UNIQUEIDENTIFIER,
			buDate				DATETIME
		) 
	
		INSERT INTO [#T_RESULT]
			SELECT
				cu.cuGuid,
				cu.cuSecurity,
				bubi.buGuid,
				bubi.buSecurity,
				bubi.biMatPtr,
				mt.Security,
				mt.GroupGuid,
				bubi.biQty / CASE @UseUnit + 1 
									WHEN 2 THEN CASE Unit2Fact WHEN 0 THEN 1 ELSE Unit2Fact END
									WHEN 3 THEN CASE Unit3Fact WHEN 0 THEN 1 ELSE Unit3Fact END 
									WHEN 4 THEN CASE DefUnit 
													WHEN 2 THEN CASE Unit2Fact WHEN 0 THEN 1 ELSE Unit2Fact END
													WHEN 3 THEN CASE Unit3Fact WHEN 0 THEN 1 ELSE Unit3Fact END
													ELSE 1
												END
									ELSE 1		
							 END,
				bubi.biBonusQnt / CASE @UseUnit + 1 
									WHEN 2 THEN CASE Unit2Fact WHEN 0 THEN 1 ELSE Unit2Fact END
									WHEN 3 THEN CASE Unit3Fact WHEN 0 THEN 1 ELSE Unit3Fact END 
									WHEN 4 THEN CASE DefUnit 
													WHEN 2 THEN CASE Unit2Fact WHEN 0 THEN 1 ELSE Unit2Fact END
													WHEN 3 THEN CASE Unit3Fact WHEN 0 THEN 1 ELSE Unit3Fact END
													ELSE 1
												END
									ELSE 1		
							 END,
				CASE bubi.btIsInput WHEN 1 THEN -1 ELSE 1 END,
				d.DistGuid,
				bubi.buDate
			FROM
				fn_bubi_Fixed (@CurPtr) AS bubi
				INNER JOIN #Custtbl AS cu ON bubi.buCustPtr = cu.cuGuid
				INNER JOIN mt000 AS mt ON mt.Guid = bubi.biMatPtr
				INNER JOIN #CostTbl AS d ON d.Guid = bubi.buCostPtr
			WHERE
				bubi.buDate BETWEEN @StartDate AND @EndDate


		CREATE TABLE #SalesDetails
		(
			CustGuid			UNIQUEIDENTIFIER,
			buGuid				UNIQUEIDENTIFIER,
			MatGuid				UNIQUEIDENTIFIER,
			Qty					FLOAT,
			DistributorGUID		UNIQUEIDENTIFIER,
		)
		
		CREATE TABLE #BonusDetails
		(
			CustGuid			UNIQUEIDENTIFIER,
			buGuid				UNIQUEIDENTIFIER,
			MatGuid				UNIQUEIDENTIFIER,
			Qty					FLOAT,
			DistributorGUID		UNIQUEIDENTIFIER,
		)
			
		--claculate the sales details depending on the @SalesDisplay flag  1: group  0: material
		IF (@SalesDisplay = 1)
		BEGIN
			INSERT INTO #SalesDetails
				SELECT
					r.CustPtr,
					r.buGuid,
					r.GroupGuid,
					SUM(r.Qty * r.buDirection),
					r.DistributorGuid
				FROM
					[#T_RESULT] AS r
					INNER JOIN #EndResult AS r2 ON r2.BillGuid = r.buGuid
				GROUP BY
					r.DistributorGuid,
					r.CustPtr,
					r.GroupGuid,
					r.buGuid
		END
		ELSE
		BEGIN
			INSERT INTO #SalesDetails
				SELECT
					r.CustPtr,
					r.buGuid,
					r.MatGuid,
					r.Qty * r.buDirection,
					r.DistributorGuid
				FROM
					[#T_RESULT] AS r
					INNER JOIN #EndResult AS r2 ON r2.BillGuid = r.buGuid
		END
		
		--claculate the bonus details depending on the @BonusDisplay flag  1: group  0: material
		IF (@BonusDisplay = 1)
		BEGIN
			INSERT INTO #BonusDetails
				SELECT
					r.CustPtr,
					r.buGuid,
					r.GroupGuid,
					SUM(r.Bonus * r.buDirection),
					r.DistributorGuid
				FROM
					[#T_RESULT] AS r
					INNER JOIN #EndResult AS r2 ON r2.BillGuid = r.buGuid
				GROUP BY
					r.DistributorGuid,
					r.CustPtr,
					r.GroupGuid,
					r.buGuid
		END
		ELSE
		BEGIN
			INSERT INTO #BonusDetails
				SELECT
					r.CustPtr,
					r.buGuid,
					r.MatGuid,
					r.Bonus * r.buDirection,
					r.DistributorGuid
				FROM
					[#T_RESULT] AS r
					INNER JOIN #EndResult AS r2 ON r2.BillGuid = r.buGuid
		END
		
		CREATE TABLE #SalesMaterials (Guid UNIQUEIDENTIFIER, Name NVARCHAR(250), Total FLOAT)
		CREATE TABLE #BonusMaterials (Guid UNIQUEIDENTIFIER, Name NVARCHAR(250), Total FLOAT)
		----------------------
		--Sales Datails Dispaly option (material or group)
		IF (@SalesDisplay = 0)
		BEGIN
			INSERT INTO #SalesMaterials
			SELECT
				r.MatGuid,
				mt.Name,
				SUM(r.Qty)
			FROM #SalesDetails AS r
			INNER JOIN mt000 AS mt ON mt.Guid = r.MatGuid
			GROUP BY r.MatGuid, mt.Code, mt.Name
			ORDER BY mt.Code
		END
		ELSE
		BEGIN
			INSERT INTO #SalesMaterials
			SELECT
				r.MatGuid,
				gr.Name,
				SUM(r.Qty)
			FROM #SalesDetails AS r
			INNER JOIN gr000 AS gr ON gr.Guid = r.MatGuid
			GROUP BY r.MatGuid, gr.Code, gr.Name
			ORDER BY gr.Code
		END
		
		----------------------
		--Bonus Datails Dispaly option (material or group)
		IF (@BonusDisplay = 0)
		BEGIN
			INSERT INTO #BonusMaterials
			SELECT
				r.MatGuid,
				mt.Name,
				SUM(r.Qty)
			FROM #BonusDetails AS r
			INNER JOIN mt000 AS mt ON mt.Guid = r.MatGuid
			GROUP BY r.MatGuid, mt.Code, mt.Name
			ORDER BY mt.Code
		END
		ELSE
		BEGIN
			INSERT INTO #BonusMaterials
			SELECT
				r.MatGuid,
				gr.Name,
				SUM(r.Qty)
			FROM #BonusDetails AS r
			INNER JOIN gr000 AS gr ON gr.Guid = r.MatGuid
			GROUP BY r.MatGuid, gr.Code, gr.Name
			ORDER BY gr.Code
		END
	END
	
	------------------------------------------------------
	-- Result 1 
	SELECT * FROM #EndResult2 ORDER BY DistPtr, Date, StartTime, State, CustName, ID, VisitGuid

	------------------------------------------------------
	IF (@ShowSalesDetail = 1)
	BEGIN
		-- Result 2
		SELECT
			Guid,
			Name,
			Total
		FROM #SalesMaterials
		WHERE Total <> 0
		
		--Result 3
		SELECT
			s.CustGuid,
			s.buGuid,
			s.MatGuid,
			SUM(s.Qty) AS Qty,
			s.DistributorGuid
		FROM #SalesDetails AS s
		WHERE s.Qty <> 0
		GROUP BY 
			s.CustGuid,
			s.buGuid,
			s.MatGuid,
			s.DistributorGuid
	END

	IF (@ShowBonusDetail = 1)
	BEGIN
		-- Result 4
		SELECT
			Guid,
			Name,
			Total
		FROM #BonusMaterials
		WHERE Total <> 0
		
		--Result 5
		SELECT
			b.CustGuid,
			b.buGuid,
			b.MatGuid AS GroupGuid,
			SUM(b.Qty) AS Qty,
			b.DistributorGuid
		FROM #BonusDetails AS b
		WHERE b.Qty <> 0
		GROUP BY 
			b.CustGuid,
			b.buGuid,
			b.MatGuid,
			b.DistributorGuid
	END
	
	
	------------------------------------------------------			   
	-- Result 6 
	IF (@PeriodGuid <> 0X00) 
	BEGIN 
		SELECT COUNT(DISTINCT CAST ([ViGuid] AS NVARCHAR(40))) AS [viCnt]  
		FROM [vwDistTrvi]  
		WHERE 	[TrDistributorGUID] = @DistPtr	AND 
			[dbo].[fnGetDateFromDT]([ViStartTime]) BETWEEN(SELECT [StartDate] FROM [vwPeriods] WHERE [GUID] = @PeriodGuid) AND @EndDate 
	END 
	------------------------------------------------------
			  
	-- Result 7 
	IF @NotSales = 1 
	BEGIN 
		SELECT  
			v.Guid	AS VisitGuid, 
			[v].[CustGUID] AS [CustPtr], 
			[Name] AS [UnSalesName] 
		FROM  
			[#Visit] AS [v] 
			INNER JOIN [DistVd000] 		AS [vd] ON [vd].[VistGuid] = [v].[Guid] 
			INNER JOIN [DistLookup000] 	AS [l] ON [vd].[ObjectGuid] = [l].[Guid] 
		WHERE 
			[l].[Type] = 0  
			-- AND [v].[State] = 0 
		ORDER BY 
			v.Guid, 
			[CustGUID] 
	END 
	------------------------------------------------------	
		  
	-- Result 8 
	SELECT * FROM [#SecViol] 
/*  
prcConnections_Add2 '„œÌ—'   
exec [repDistributorActivety] '6392cc88-87c4-4d98-818f-1baccd03ae70', '1/1/2008 0:0:0.0', '1/1/2009 23:59:54.373', 'f6adb10a-0de6-40a0-94d5-04409efa8293', '00000000-0000-0000-0000-000000000000', '00000000-0000-0000-0000-000000000000', '47d90150-4405-4bfc-9f9d-910d3853431c', 3, 1, 1, '00000000-0000-0000-0000-000000000000', 0, 0, 1, 1, 1, 1, 0, 1, 1, 1, 1
*/
###########################################################
#END
