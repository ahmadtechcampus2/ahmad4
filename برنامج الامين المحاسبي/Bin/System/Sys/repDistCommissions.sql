########################################
CREATE PROCEDURE GetDistributionsList
	@DistGuid	UNIQUEIDENTIFIER = 0x00,
	@HiGuid 	UNIQUEIDENTIFIER = 0x00
AS
	IF @DistGuid <> 0X0 
	BEGIN
		SELECT [Guid],[Security] FROM [vwDistributor] WHERE  Guid = @DistGuid
		RETURN
	END
		SELECT [Guid],[Security] FROM [vwDistributor] 
			WHERE  [HierarchyGUID] IN (SELECT Guid FROM [fnGetHierarchyList](@HiGuid,0))
##################################################################################
CREATE PROCEDURE prcGetEfficiencyVisit
AS 
	CREATE TABLE [#DistCustInPeriod](
		[PeriodGuid]		[UNIQUEIDENTIFIER],
		[CustGuid] 		[UNIQUEIDENTIFIER],  
		[DistGuid] 		[UNIQUEIDENTIFIER],  
		[Route1]		[INT],  
		[Route2]		[INT], 
		[Route3]		[INT],  
		[Route4]		[INT],  
		[ExpectedCov]	[INT] 
	)
	INSERT INTO [#DistCustInPeriod]
	SELECT [t].[PeriodGuid], [CustGuid], [DistGuid], [Route1], [Route2], [Route3], [Route4], 0
	FROM [DistDistributionLines000],[#T] AS t
	UPDATE [#DistCustInPeriod] SET [ExpectedCov] = dbo.fnDistCalcExpectedCovBetweenDates (t.StartDate, t.EndDate, Route1, Route2, Route3, Route4)
	FROM [#T] AS t INNER JOIN [#DistCustInPeriod] AS dc ON [t].[PeriodGuid] = [dc].[PeriodGuid]
	
	DECLARE @TR TABLE([PeriodGUID] [UNIQUEIDENTIFIER],[DistributerGUID] [UNIQUEIDENTIFIER],[ReqVisit] [INT],[Security] [INT],[TypeGuid] [UNIQUEIDENTIFIER]) 
	INSERT INTO @TR SELECT dc.periodGuid,dc.DistGuid,sum([ExpectedCov]),d2.security,d2.typeGuid
	FROM [#DistCustInPeriod] AS dc INNER JOIN [#DistTble2] AS d2 ON dc.DistGuid = d2.DistGuid
	GROUP BY dc.periodGuid,dc.DistGuid,d2.security,d2.typeguid
	
	select  bucostptr,bucustptr,budate into [#custVisit]  from vwbu
	where btbilltype = 1
	

	DECLARE @VI TABLE([PeriodGUID] [UNIQUEIDENTIFIER],[DistributerGUID] [UNIQUEIDENTIFIER],[EfficiencyVisit] [INT]) 
	INSERT INTO @VI 
	SELECT [PeriodGUID],dt.[GUID],count(budate)
	FROM [#T] INNER JOIN [#custVisit] ON budate BETWEEN StartDate AND EndDate
	INNER JOIN [DistSalesman000] AS ds ON ds.CostGUID = bucostptr 
	INNER JOIN [Distributor000] AS dt ON dt.[PrimSalesmanGuid] = [ds].[Guid]
	GROUP BY [PeriodGUID],dt.[GUID]

	
	SELECT [t].[PeriodGUID],[t].[DistributerGUID],[EfficiencyVisit],[ReqVisit],[Security],[TypeGuid]
	FROM  @TR AS t INNER JOIN @VI AS [v] ON [t].[PeriodGUID] = [v].[PeriodGUID] AND [t].[DistributerGUID] = [v].[DistributerGUID]

########################################	
CREATE  PROCEDURE prcGetPreiorety 
AS  
	SELECT di.[DistGUID], COUNT(*) AS [STATE], [d2].[Security], [d2].[TypeGuid] 
	INTO [#PREIOR] 
	FROM [DistCe000] AS ce  
	INNER JOIN [DistDistributionLines000] 	AS [di] ON [di].[CustGuid] = [ce].[CustomerGuid] 
	INNER JOIN [#DistTble2] 		AS [d2] ON [Di].[DistGUID] = [d2].[DistGuid] 
	WHERE [STATE] = 0 
	GROUP BY di.[DistGUID], [d2].[Security], [d2].[TypeGuid] 
	 
	SELECT [PeriodGUID], [DistGuid] AS [DistributorGUID], [STATE], [Security], [TypeGuid] 
	FROM	[#T],[#PREIOR] 
########################################
CREATE PROCEDURE prcGetTarget
	@CurrGuid UNIQUEIDENTIFIER =0x0
AS 
	DECLARE @Ta TABLE([PeriodGUID] [UNIQUEIDENTIFIER],[DistGUID] [UNIQUEIDENTIFIER],[Target] [FLOAT],Security INT,TypeGuid UNIQUEIDENTIFIER) 
	INSERT INTO @Ta SELECT  [d].[PeriodGUID],[d].[DistGUID],[dbo].[fnCurrency_fix]([GeneralTargetVal], [d].[CurGuid], [d].[CurVal], @CurrGuid, NULL),[d2].[Security],[d2].[TypeGuid] 
	FROM [DistDistributorTarget000] AS [d]  
	INNER JOIN [#T] AS [t] ON [d].[PeriodGUID] = [t].[PeriodGUID] 
	INNER JOIN [#DistTble2] AS [d2] ON [d].[DistGUID] = [d2].[DistGuid] 
	
	DECLARE @Re TABLE([SalesmanGuid] [UNIQUEIDENTIFIER],[DistGuid] [UNIQUEIDENTIFIER],[CostGuid] [UNIQUEIDENTIFIER])
	-- DECLARE @Re TABLE([CustomerGuid] [UNIQUEIDENTIFIER],[DistGuid] [UNIQUEIDENTIFIER]) 
	INSERT INTO @Re 
		SELECT [ds].[Guid],[di].[Guid] , [CostGuid]
		 --FROM [DistCe000] AS [ce] INNER JOIN [Distributor000] AS [di] ON [di].[Guid] = [ce].[DistributorGuid] 
		 FROM [DistSalesman000] AS [ds] INNER JOIN [Distributor000] AS [di] ON [di].[PrimSalesmanGuid] = [ds].[Guid] 
	 
	IF @CurrGuid = 0X0 
		SELECT @CurrGuid = [GUID] FROM [My000] WHERE [CurrencyVal] = 1 
	DECLARE  @B TABLE([buGuid] [UNIQUEIDENTIFIER],[DistGUID] [UNIQUEIDENTIFIER],PeriodGUID UNIQUEIDENTIFIER,VAL FLOAT,BILLGUID UNIQUEIDENTIFIER) 
	INSERT INTO @B  
		SELECT  buGuid,DistGUID,PeriodGUID,-buDirection * (FixedBuTotal -  FixedbuTotalDisc + FixedBuTotalExtra),buGuid  
		FROM fnBu_Fixed(@CurrGuid) AS f   
		INNER JOIN @RE AS r ON r.CostGuid = f.buCostPtr
		-- INNER JOIN @RE AS r ON r.CustomerGuid = f.buCustPtr 
		INNER JOIN #T AS t ON f.buDate BETWEEN t.StartDate AND t.EndDate  
		WHERE btbillType = 1 OR btbillType = 3  
--
	DECLARE  @TB TABLE(DistGUID UNIQUEIDENTIFIER,PeriodGUID UNIQUEIDENTIFIER,VAL FLOAT) 
	INSERT INTO @TB SELECT DistGUID,PeriodGUID,SUM(VAL) FROM @B GROUP BY PeriodGUID , DistGUID
	
	SELECT  b.PeriodGUID,b.DistGUID,Val,Target,t.Security,t.TypeGuid  
	FROM @TB AS b INNER JOIN @Ta AS t ON  b.DistGUID = t.DistGUID AND b.PeriodGUID = t.PeriodGUID 
	
########################################
CREATE PROCEDURE repCommissions
	@DistGuid		[UNIQUEIDENTIFIER],
	@HtType			[UNIQUEIDENTIFIER],
	@HiGuid 		[UNIQUEIDENTIFIER],
	@PeriodGuid		[UNIQUEIDENTIFIER],
	@CurrencyGuid	[UNIQUEIDENTIFIER] = 0x0 ,
	@ShowHi			[INT] = 0,
	@Flag			[INT] = 0
AS
	SET NOCOUNT ON
	CREATE  TABLE [#T] ( [PeriodGUID] [UNIQUEIDENTIFIER], [StartDate] [DATETIME], [EndDate] [DATETIME])
	INSERT INTO [#T]   ( [PeriodGUID], [StartDate], [EndDate]) 
		SELECT [p].[GUID], [StartDate], [EndDate] 
		FROM vwPeriods AS p INNER JOIN  fnGetPeriodList(@PeriodGuid,1) AS f ON p.Guid = f.Guid WHERE NSons = 0 

	CREATE TABLE #T1 ( PeriodGUID UNIQUEIDENTIFIER, StartDate DATETIME, EndDate DATETIME )
	IF @Flag = 1 
	BEGIN
		INSERT INTO [#T1] SELECT DISTINCT t.PeriodGUID, t.StartDate, t.EndDate FROM DistCommPointPeriods000 AS d INNER JOIN #T AS t ON d.PeriodGuid = t.PeriodGUID
		DELETE [#T] 
	END
	
	DECLARE @Level INT
	DECLARE @Level2 INT
	IF @CurrencyGuid = 0X0
		SELECT @CurrencyGuid = GUID FROM my000 WHERE CurrencyVal = 1
	CREATE TABLE [#HtTbl]	( [HtGuid] 	[UNIQUEIDENTIFIER] )
	CREATE TABLE [#DistTble]( [DistGuid]	[UNIQUEIDENTIFIER], Security	INT )	
	
	INSERT INTO [#DistTble] EXEC [GetDistributionsList] @DistGuid, @HiGuid
	INSERT INTO [#HtTbl] SELECT [GUID] FROM [DistHt000] WHERE @HtType = 0X0 OR Guid = @HtType 
	SELECT [d].[DistGuid], d.Security, d2.TypeGuid INTO #DistTble2 FROM #DistTble AS d 
	INNER JOIN [Distributor000] AS d2 ON d.DistGuid = d2.Guid
	INNER JOIN [#HtTbl] AS [h] ON [h].[HtGuid] = [d2].[TypeGuid]
	
	CREATE TABLE [#Targettbl]	( [PeriodGUID] [UNIQUEIDENTIFIER], [DistributerGUID] [UNIQUEIDENTIFIER], [CurrentSales]    [FLOAT],[Target]  [FLOAT], [Security] [INT], [TypeGuid] [UNIQUEIDENTIFIER] )
	CREATE TABLE [#Efficiencytbl]	( [PeriodGUID] [UNIQUEIDENTIFIER], [DistributerGUID] [UNIQUEIDENTIFIER], [EfficiencyVisit] [INT], [ReqVisit] [INT],   [Security] [INT], [TypeGuid] [UNIQUEIDENTIFIER] ) 
	CREATE TABLE [#preiritytbl]	( [PeriodGUID] [UNIQUEIDENTIFIER], [DistributerGUID] [UNIQUEIDENTIFIER], [PreiorVisit]     [INT], [Security] [INT], [TypeGuid] [UNIQUEIDENTIFIER] ) 
	CREATE TABLE [#RESULT] 
	(
		[DistGUID]		[UNIQUEIDENTIFIER],
		[PeriodGUID]		[UNIQUEIDENTIFIER],
		[HtGuid]		[UNIQUEIDENTIFIER],
		[HiGuid]		[UNIQUEIDENTIFIER],
		[EfficiencyVisit]	[INT] 	DEFAULT 0,
		[ReqVisit]		[INT] 	DEFAULT 0,
		[CurrentSales]		[FLOAT] DEFAULT 0,
		[Target]		[FLOAT] DEFAULT 0,
		[PreiorVisit]		[INT] 	DEFAULT 0,
		[DistSecurity]		[INT],
		[Flag]			[INT]	 
	)
	CREATE TABLE [#T_RESULT]
	(
		[DistGUID]		[UNIQUEIDENTIFIER],
		[PeriodGUID]		[UNIQUEIDENTIFIER],
		[HtGuid]		[UNIQUEIDENTIFIER],
		[EfficiencyPoint]	[FLOAT] DEFAULT 0,
		TargetPoint		[FLOAT] DEFAULT 0,
		PreiorPoint		[FLOAT] DEFAULT 0,
		IntencivePoint		[FLOAT] DEFAULT 0
	)
	CREATE TABLE [#FinalResult]
	(
		[DistGUID]		[UNIQUEIDENTIFIER],
		[PeriodGUID]		[UNIQUEIDENTIFIER],
		[SalesManGUID]		[UNIQUEIDENTIFIER],
		[SalesManCode]		[NVARCHAR](256) COLLATE ARABIC_CI_AI,
		[SalesManName]		[NVARCHAR](256) COLLATE ARABIC_CI_AI,
		[HtGuid]		[UNIQUEIDENTIFIER],
		[HiGuid]		[UNIQUEIDENTIFIER],
		[EfficiencyPoint]	[FLOAT] DEFAULT 0,
		[TargetPoint]		[FLOAT] DEFAULT 0,
		[PreiorPoint]		[FLOAT] DEFAULT 0,
		[IntencivePoint]	[FLOAT] DEFAULT 0,
		[TotalPoints]		[FLOAT] DEFAULT 0,
		[Path]			[NVARCHAR](256) COLLATE ARABIC_CI_AI,
		[FLAG]			[INT] DEFAULT 0,
		[PricePoint]		[FLOAT] DEFAULT 0
	)
	IF @Flag = 1 
	BEGIN
	---
			INSERT INTO [#FinalResult] ( [DistGUID], [PeriodGUID], [HtGuid], [EfficiencyPoint], [TargetPoint], [PreiorPoint], [IntencivePoint], [TotalPoints], [FLAG], [PricePoint] )
			SELECT DISTINCT [d].[DistGuid], [d].[PeriodGuid], [d2].[TypeGuid], [d].[Efficiency], [d].[Target], [d].[Priority], [d].[Incentive], [d].[Total], 0, [dbo].[fnCurrency_fix]( [P].[CommPointPrice], [P].[CommPrCurrencyGuid], [p].[CommPrCurrencyVal], @CurrencyGuid, 0)
			FROM [DistCommPointPeriods000] AS d 
			INNER JOIN [#DistTble2] 		AS [d2] ON [d].[DistGuid] = [d2].[DistGuid]
			LEFT JOIN [vwDistCommissionPrice] 	AS [p] 	ON [d2].[Typeguid] = [p].[CommPrHtGuid] 
								AND [p].[CommPointFrom] = (SELECT MAX([d3].[CommPointFrom]) FROM  [vwDistCommissionPrice] AS [d3] WHERE [d3].[CommPointFrom] < [d].[Total] AND [d3].[CommPrHtGuid] = [p].[CommPrHtGuid] AND [p].[CommPrPeriodGuid] = [d3].[CommPrPeriodGuid]) AND [d].[PeriodGuid] = [p].[CommPrPeriodGuid]
	
	END

	INSERT INTO [#Targettbl] 	EXEC [prcGetTarget] @CurrencyGuid	
	INSERT INTO [#Efficiencytbl] 	EXEC [prcGetEfficiencyVisit]	
	INSERT INTO [#preiritytbl] 	EXEC [prcGetPreiorety]
	-- Efficiency 

	INSERT INTO [#RESULT] ( [DistGUID], [PeriodGUID], [EfficiencyVisit], [ReqVisit], [DistSecurity], [HtGuid], [Flag])
		SELECT [DistributerGUID], [PeriodGUID], [EfficiencyVisit], [ReqVisit], [f].[Security], [f].[TypeGuid], 0 
		FROM #Efficiencytbl AS f
	--Target 
	INSERT INTO [#RESULT] ( [DistGUID], [PeriodGUID], [CurrentSales], [Target], [DistSecurity], [HtGuid], [Flag])
		SELECT [DistributerGUID],[PeriodGUID],[CurrentSales],[Target],[f].[Security],[f].[TypeGuid],1
		FROM [#Targettbl] AS [f] 
	--Preirity
	INSERT INTO [#RESULT] ([DistGUID],[PeriodGUID],[PreiorVisit],[DistSecurity],[HtGuid],[Flag])
	SELECT [DistributerGUID],[PeriodGUID],[PreiorVisit],[Security],[f].[TypeGuid],2 
	FROM [#preiritytbl] AS [f] 
	-- Efficiency Points
	INSERT INTO [#T_RESULT] ([DistGUID],[PeriodGUID],[HtGuid],[EfficiencyPoint]) 
		SELECT r.DistGUID,r.PeriodGUID,r.HtGuid,CASE WHEN CAST([r].[EfficiencyVisit] AS FLOAT)/CAST([r].[ReqVisit] AS FLOAT) > 1 THEN [d].[CommPointEfficiency] ELSE CAST([r].[EfficiencyVisit] AS FLOAT)* [d].[CommPointEfficiency]/CAST([r].[ReqVisit] AS [FLOAT])    END
		FROM [#RESULT] AS r INNER JOIN vwDistCommPoint AS d ON r.HtGuid = d.CommPointHtGuid WHERE Flag = 0 
	--Target Points
	INSERT INTO [#T_RESULT] (DistGUID,PeriodGUID,HtGuid,TargetPoint) 
		SELECT [r].[DistGUID],[r].[PeriodGUID],r.HtGuid,r.CurrentSales/r.Target * d.CommPointTarget 
		FROM [#RESULT] AS r INNER JOIN vwDistCommPoint AS d ON r.HtGuid = d.CommPointHtGuid WHERE Flag = 1 
	--	Preior Points
	INSERT INTO [#T_RESULT] ([DistGUID],[PeriodGUID],[HtGuid],PreiorPoint) 
		SELECT r.DistGUID,r.PeriodGUID,r.HtGuid,CASE WHEN CommPointPriority > (select MAX(PrPointPOINT)  FROM vwDistPrPoint AS v WHERE  v.PrPointPrFrom <= r.PreiorVisit ) then 
		(select MAX(PrPointPOINT)  FROM vwDistPrPoint AS v WHERE  v.PrPointPrFrom <= r.PreiorVisit ) ELSE CommPointPriority  END 
		FROM #RESULT AS r INNER JOIN vwDistCommPoint AS d ON r.HtGuid = d.CommPointHtGuid WHERE Flag = 2 
	
	--Incentive Point
	INSERT INTO #T_RESULT (DistGUID,PeriodGUID,HtGuid,IntencivePoint)
	SELECT DISTINCT DistCommIncDistGuid,r.PeriodGUID,r.HtGuid,CASE WHEN d.DistCommIncIncPoint > (SELECT CommPointIncentive FROM vwDistCommPoint where CommPointHtGUID = r.HtGUID) THEN
	(SELECT CommPointIncentive FROM vwDistCommPoint where CommPointHtGUID = r.HtGUID) ELSE d.DistCommIncIncPoint END
	FROM #RESULT AS r INNER JOIN vwDistCommIncentive As d ON r.DistGUID = d.DistCommIncDistGuid AND r.PeriodGUID = d.DistCommIncPeriodGuid

	INSERT INTO #FinalResult(DistGUID,PeriodGUID,HtGuid,EfficiencyPoint,TargetPoint,PreiorPoint,IntencivePoint)
		SELECT DistGUID	,PeriodGUID,HtGuid,SUM(EfficiencyPoint),SUM(TargetPoint),SUM(PreiorPoint),SUM(IntencivePoint) 
		FROM #T_RESULT 
		GROUP BY DistGUID,PeriodGUID,HtGuid
	UPDATE [#FinalResult] SET TotalPoints = EfficiencyPoint + 	TargetPoint + PreiorPoint + IntencivePoint
	UPDATE [#FinalResult] SET SalesManGUID = sl.Guid,SalesManCode = sl.Code,SalesManName = sl.Name,HiGuid = d.HierarchyGUID
	FROM [#FinalResult] AS f 
	INNER JOIN [Distributor000] AS [d] ON [d].[Guid] = [f].[DistGUID] 
	INNER JOIN DistSalesMan000 AS sl ON [d].[PrimSalesmanGUID] = [sl].[Guid]
	
	IF @ShowHi = 1
	BEGIN 
		SELECT [f].[Guid],[f].[Level], [f].[Path],[hi].[Name],[hi].[TypeGuid],[hi].[ParentGuid] INTO [#HI] 
		FROM [fnGetHierarchyList](@HiGuid,1) AS [F] INNER JOIN [vwDistHi] AS [hi] ON [f].[Guid] = [hi].[Guid]
		SELECT @Level = MAX([Level]) FROM [#HI]
		WHILE @Level >= 0 
		BEGIN
			INSERT INTO [#FinalResult]([DistGUID],[PeriodGUID],[SalesManGUID],[SalesManName],[HiGuid],[HtGuid],[Path],[Flag],[TotalPoints])
			SELECT DISTINCT [hi].[Guid],[PeriodGUID],[hi].[Guid],[hi].[Name],[hi].[ParentGuid],[hi].[TypeGuid],[hi].[Path],1,Avg(TotalPoints) 
			FROM [#FinalResult] AS f  INNER JOIN [#HI] AS [hi] ON [f].[HiGuid] = [hi].[Guid] WHERE [hi].[Level] = @Level
			GROUP BY [PeriodGUID],[hi].[Guid],[hi].[Name],[hi].[ParentGuid],[hi].[TypeGuid],[hi].[Path]
			SET @Level = @Level -1


		END
		UPDATE [#FinalResult] SET [Path] = [h].[Path]
		FROM [#FinalResult] AS [f] INNER JOIN [#HI] AS [h] ON [h].[Guid] = [f].[HiGuid]
		WHERE Flag = 0
	END
	
	IF @Flag = 0
	BEGIN
		UPDATE [#FinalResult] SET [PricePoint] = dbo.fnCurrency_fix([d].[CommPointPrice], d.CommPrCurrencyGuid, d.CommPrCurrencyVal, @CurrencyGuid, NULL)
		FROM [#FinalResult] AS [r] INNER JOIN [vwDistCommissionPrice] AS d ON r.HtGuid = d.CommPrHtGuid AND d.CommPointFrom = (SELECT MAX(d2.CommPointFrom) FROM  vwDistCommissionPrice AS d2 WHERE d2.CommPointFrom < r.TotalPoints AND d.CommPrHtGuid = d2.CommPrHtGuid AND ISNULL(d2.CommPrPeriodGuid,0X0)= 0X0)
		WHERE ISNULL([d].[CommPrPeriodGuid],0X0)= 0X0
		
	END
	ELSE
	BEGIN
		UPDATE [#FinalResult] SET [PricePoint] = dbo.fnCurrency_fix(isnull(d.CommPointPrice,0), d.CommPrCurrencyGuid, d.CommPrCurrencyVal, @CurrencyGuid, NULL)
		FROM [#FinalResult] AS [r] JOIN [vwDistCommissionPrice] AS [d] ON [r].[HtGuid] = [d].[CommPrHtGuid] AND [r].[PeriodGUID] = [d].[CommPrPeriodGuid] AND [d].[CommPointFrom] = (SELECT MAX(d2.CommPointFrom) FROM  vwDistCommissionPrice AS d2 WHERE d2.CommPointFrom < r.TotalPoints AND d.CommPrHtGuid = d2.CommPrHtGuid AND r.PeriodGUID = d2.CommPrPeriodGuid)
		--WHERE  r.PeriodGUID IN (SELECT t.PeriodGUID FROM #T1 AS t)
	END
	IF @Flag = 1 
	BEGIN
		
		SELECT [GUID],[Level] INTO [#PT] FROM  [fnGetPeriodList](@PeriodGuid,1) 
		SELECT @Level2 = MAX([LeveL])- 1 FROM [#PT] 
		WHILE (@Level2 >= 0)
		BEGIN
			INSERT INTO [#FinalResult](DistGUID,PeriodGUID,SalesManGUID,SalesManName,HiGuid,HtGuid,EfficiencyPoint,TargetPoint,[PreiorPoint],[IntencivePoint],[TotalPoints],[Path],[Flag],[PricePoint])
			SELECT [DistGUID],[pt].[Guid],[SalesManGUID],[SalesManName],[HiGuid],[HtGuid],SUM([EfficiencyPoint]),SUM([TargetPoint]),SUM(PreiorPoint),SUM([IntencivePoint]),SUM([TotalPoints]),[f].[Path],[Flag],SUM([TotalPoints]*[PricePoint])/CASE SUM(TotalPoints) WHEN 0 THEN 1 ELSE SUM([TotalPoints]) END
			FROM  [#FinalResult] as f 
			INNER JOIN [vwPeriods] AS [p] ON [PeriodGUID] = [p].[Guid] 
			INNER JOIN [#PT] AS [pt] ON [pt].[Guid] = [p].[ParentGuid]
			WHERE pt.Level = @Level2 
			GROUP BY [DistGUID],[pt].[Guid],[SalesManGUID],[SalesManName],[HiGuid],[HtGuid],[f].[Path],[Flag]
			
			SET @Level2 = @Level2 -1 
		END
		
	END
	
	IF @ShowHi = 0
		SELECT [DistGUID],[dp].[Name] AS [PeriodName],[SalesManGUID],[r].[PeriodGuid],
				[SalesManCode],[SalesManName],[EfficiencyPoint],
				SUM([TargetPoint]) AS [TargetPoint],SUM([PreiorPoint]) AS [PreiorPoint],SUM([IntencivePoint]) AS [IntencivePoint],
				SUM([TotalPoints]) AS [TotalPoints],SUM([PricePoint]) AS [PricePoint] ,[r].[PeriodGuid],[F].[PATH],[dp].[StartDate]
		FROM [#FinalResult] AS r INNER JOIN [bdp000]  AS [dp] ON [r].[PeriodGuid] = [dp].[Guid]
		INNER JOIN fnGetPeriodList(@PeriodGuid,0) AS f ON f.GUID = r.PeriodGuid
		GROUP BY [DistGUID],[dp].[Name] ,[SalesManGUID],[r].[PeriodGuid],[SalesManCode],[SalesManName],[EfficiencyPoint],[r].[PeriodGuid],[f].[PATH],[dp].[StartDate],[SalesManCode]
		ORDER BY dp.StartDate ,F.PATH,SalesManCode
	ELSE
		SELECT [DistGUID],[dp].[Name] AS [PeriodName],[SalesManGUID],r.PeriodGuid,
				[SalesManCode],SalesManName,EfficiencyPoint,
				SUM([TargetPoint]) AS [TargetPoint],SUM([PreiorPoint]) AS [PreiorPoint],SUM([IntencivePoint]) AS [IntencivePoint],
				SUM([TotalPoints]) AS [TotalPoints],SUM([PricePoint]) AS [PricePoint] ,[r].[PeriodGuid],[f].[Path] AS [FP],[r].[Path] AS [RP],[Flag],[dp].[StartDate]
		FROM [#FinalResult] AS [r] INNER JOIN [bdp000]  AS [dp] ON r.PeriodGuid = dp.Guid
		INNER JOIN [fnGetPeriodList](@PeriodGuid,0) AS [f] ON f.GUID = r.PeriodGuid
		GROUP BY [DistGUID],[dp].[Name] ,[SalesManGUID],[r].[PeriodGuid],[SalesManCode],[SalesManName],[EfficiencyPoint],[r].[PeriodGuid],[f].[PATH],[dp].[StartDate],[SalesManCode],[r].[Path],[r].[Flag]
		ORDER BY [dp].[StartDate],[f].[Path],[r].[Path],[Flag] DESC

/*
prcConnections_add2 '„œÌ—'
exec  repCommissions '00000000-0000-0000-0000-000000000000', '00000000-0000-0000-0000-000000000000', '00000000-0000-0000-0000-000000000000', '00000000-0000-0000-0000-000000000000', '870964d8-8e50-46e3-8b4f-3fa34af22286', 0, 1 
*/
#############################
#END