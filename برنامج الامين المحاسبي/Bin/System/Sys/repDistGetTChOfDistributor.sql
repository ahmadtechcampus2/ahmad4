###################################################################
CREATE  PROC repDistGetTChOfDistributor
	@HierarchyGUID		[UNIQUEIDENTIFIER] = 0x00,
	@DistributorGUID	[UNIQUEIDENTIFIER] = 0x00,
	@ShowHi			[INT] = 0,
	@HiLevel		[INT] = 0,
	@ShowCoverage		[INT] = 0,
	@StartDate		[DATETIME] = '1/1/1980',
	@EndDate		[DATETIME] = '1/1/1980',
	@ShowVisit		[INT] = 0,
	@ShowActive		[INT] = 0
AS 
	SET NOCOUNT ON
	
	DECLARE @MaxLevel INT
	DECLARE @RealDaysNum INT
	SET @RealDaysNum = 1
	CREATE TABLE [#Cust] 	( [Number] 	[UNIQUEIDENTIFIER], 	[Security] 	[INT] )
	CREATE TABLE [#SecViol]	( [Type] 	[INT], 			[Cnt] 		[INT] )
	CREATE TABLE [#DistTble]( [DistGuid]	[UNIQUEIDENTIFIER],	[Security]	[INT], [SalesManGuid]	[UNIQUEIDENTIFIER],  [CostGuid]	[UNIQUEIDENTIFIER]) 
	
	INSERT INTO [#Cust] 	EXEC prcGetDistGustsList @DistributorGUID, 0x00, 0x00, @HierarchyGUID
	INSERT INTO [#DistTble] ( [DistGuid], [Security] ) EXEC [GetDistributionsList] @DistributorGUID, @HierarchyGUID
	UPDATE [Ds] 
		SET 	[SalesManGuid] = [d].[PrimSalesManGUID], 
				[CostGuid]     = [sm].[CostGuid]
	FROM 
		[#DistTble]  AS [Ds]     
		INNER JOIN [vwDistributor] 	AS [d] 	ON [d].[Guid] = [ds].[DistGuid]
		INNER JOIN [vwDistSalesMan] 	AS [sm]	ON [d].[PrimSalesManGUID] = [sm].[GUID]     

	CREATE TABLE [#Result]
	(
		[CustPtr]		[UNIQUEIDENTIFIER],
		[DistPtr]		[UNIQUEIDENTIFIER],
		[HiPtr]			[UNIQUEIDENTIFIER],
		[CustSecurity]		[INT] 	DEFAULT	0,
		[DistSecurity]		[INT] 	DEFAULT	0,
		[chGuid]		[UNIQUEIDENTIFIER],
		[chCode]		[NVARCHAR](256) COLLATE ARABIC_CI_AI,
		[chName]		[NVARCHAR](256) COLLATE ARABIC_CI_AI,
		[DistCode]		[NVARCHAR](256) COLLATE ARABIC_CI_AI,
		[DistName]		[NVARCHAR](256) COLLATE ARABIC_CI_AI,
		[Contracted]		[INT]  	DEFAULT  0,
		[Flag]			[INT]  	DEFAULT  0,
		[Level]			[INT]  	DEFAULT  0,
		[State]			[INT]  	DEFAULT  0,
		[Path]			[NVARCHAR](3000) DEFAULT '',
		[viCnt]			[INT]	DEFAULT  0,
		[ActviCnt]		[INT]	DEFAULT  0,
		[CustCnt]		[INT]	DEFAULT  1
	)

	CREATE TABLE [#T_RESULT]
	(
		[DistPtr]		[UNIQUEIDENTIFIER],
		[HiPtr]			[UNIQUEIDENTIFIER],
		[ActiveGuid]		[UNIQUEIDENTIFIER],
		[ActiveName]		[NVARCHAR](256) COLLATE ARABIC_CI_AI,
		[ActiveCnt]		[INT],
		[CustActiveCnt]		[INT],
		[Level]			[INT] DEFAULT 0,
		[FLAG]			[INT] DEFAULT 0
	)

	INSERT INTO [#Result]
	SELECT 	[c].[Number], [Dl].[DistGuid], [HierarchyGUID], [c].[Security], [d].[Security], 
		ISNULL([ch].[Guid],0x00), ISNULL([ch].[Code],''), ISNULL([ch].[Name],'<»œÊ‰>'), 
		[di].[Code],  [di].[Name], 
		ISNULL(Contracted, 0), 0, 0, 0, '', 0, 0, 1
	FROM [#DistTble] AS [d]
	INNER JOIN [vwDistributor] 		AS [di] ON [di].[Guid] = [d].[DistGuid]
	INNER JOIN [DistDistributionLines000]	AS [Dl] ON [Dl].[DistGuid] = [di].[Guid]
	LEFT  JOIN [DistCe000] 			AS [dc] ON [dc].[CustomerGuid] = [Dl].[CustGuid] 
	LEFT  JOIN [DistTCh000] 		AS [ch] ON [ch].[Guid] = [dc].[TradeChannelGuid]
	INNER JOIN [#Cust] 			AS [c] 	ON [c].[Number] = dL.cUSTgUID

	EXEC [prcCheckSecurity]

	IF @ShowVisit = 1
	BEGIN
		SELECT 	[TrDistributorGUID], [viCustomerGUID], 
			-- COUNT(DISTINCT CAST([ViGuid] AS NVARCHAR(40))) AS [ViCnt] ,   
			COUNT(DISTINCT CAST([ViGuid] AS NVARCHAR(40)))  + 
				( SELECT COUNT(DISTINCT [BuDate]) FROM vwbu AS bu WHERE bu.buCustPtr = viCustomerGuid AND buDate BETWEEN @StartDate AND @EndDate AND buDate NOT IN ( SELECT [dbo].[fnGetDateFromDT]([StartTime]) FROM DistVi000 AS t WHERE t.CustomerGuid = bu.buCustPtr)  ) AS [ViCnt]
			-- ,SUM(CASE ISNULL([Type], 0) WHEN 1 THEN 1 ELSE 0 END) AS [ActViCnt] 
		INTO [#VI]
		FROM [vwDistTrvi] AS [v] LEFT JOIN [DistVd000] AS [vd] ON [ViGuid] = [VistGuid]
		WHERE [dbo].[fnGetDateFromDT] ([TrDate]) BETWEEN @StartDate AND @EndDate
		GROUP BY  [TrDistributorGUID], [viCustomerGUID]-- , [TrDate]
		UPDATE  [r] SET [viCnt] = [vi].[ViCnt] 
				-- ,[ActviCnt] = [vi].[ActViCnt]
		FROM [#Result] AS [r] INNER JOIN [#VI] AS [vi] ON [r].[CustPtr] = [viCustomerGUID] AND [r].[DistPtr] = [TrDistributorGUID]
		
		UPDATE  [r] SET [ActviCnt] = ( SELECT COUNT(DISTINCT [BuDate]) FROM vwbu AS bu WHERE bu.buCustPtr = r.CustPTr AND buDate BETWEEN @StartDate AND @EndDate  ) 
		FROM [#Result] AS [r] 

 		UPDATE [#Result] SET [ViCnt] = CASE  WHEN ([ViCnt] > [ActViCnt]) THEN [ViCnt] ELSE [ActViCnt] END
		SET @RealDaysNum = DATEDIFF(d, @StartDate, @EndDate) + 1 - ( SELECT COUNT(*) FROM DistCalendar000 WHERE ([date] BETWEEN @StartDate AND @EndDate) AND (STATE = 0) )
		IF @RealDaysNum = 0
			SET @RealDaysNum = 1
	END
	IF (@ShowActive = 1)
	BEGIN
		INSERT INTO [#T_RESULT]
			SELECT 	[TrDistributorGUID], [HierarchyGUID], [lo].[GUID], [lo].[Name], 
				COUNT( DISTINCT CAST([vd].[GUID] AS NVARCHAR(40))), COUNT( DISTINCT CAST([viCustomerGUID] AS NVARCHAR(40))), 0, 0 
			FROM ([vwDistTrvi] AS [v] 
			INNER JOIN [Distvd000] 		AS [vd] ON [ViGuid] 	= [VistGuid])
			INNER JOIN [DistLookup000] 	AS [lo] ON [lo].[GUID] 	= [vd].[ObjectGuid]
			INNER JOIN [vwDistributor] 	AS [d] 	ON [d].[Guid] 	= [TrDistributorGUID]
			WHERE [dbo].[fnGetDateFromDT]([TrDate]) BETWEEN @StartDate AND @EndDate AND [lo].[Type] = 1
			GROUP BY [TrDistributorGUID], [HierarchyGUID], [lo].[Name], [lo].[GUID]
	END
	
	INSERT INTO [#Result] ( [chGuid], [chCode], [chName], [Flag] ) SELECT DISTINCT [chGuid], [chCode], [chName], 15 FROM  [#Result] 
	IF (@ShowCoverage = 1)
	BEGIN
		SELECT DISTINCT [viCustomerGUID], [TrDistributorGUID] 
		INTO [#COV]
		FROM [vwDistTrvi]
		WHERE [dbo].[fnGetDateFromDT] ([TrDate]) BETWEEN @StartDate AND @EndDate
		
		UPDATE [r] SET [State] = 1 
		FROM [#Result] AS [r] 
		LEFT JOIN [vwDistTrvi] AS [tr] ON [DistPtr] = [TrDistributorGUID]  AND [CustPtr] = [viCustomerGUID]
		INNER JOIN [#DistTble] AS ds ON ds.DistGuid = r.DistPtr
		LEFT JOIN vwbu AS bu on bu.buCustPtr = r.[CustPtr] AND bu.buCostPtr = ds.CostGuid
		WHERE (ISNULL( tr.[viCustomerGUID], 0x00) <> 0x00) OR (ISNULL(bu.buCustPtr, 0x00) <> 0x00)
	END

----------------------------------------------------------------------

	IF (@ShowHi = 1)
	BEGIN
		SELECT [f].[Guid], [hi].[Code], [hi].[Name], [ParentGUID], [Level] + 1 AS [Level], [Path] 
		INTO [#HI] 
		FROM fnGetHierarchyList (@HierarchyGUID, 1) AS [f] INNER JOIN [vwDistHi] AS [hi] ON [f].[Guid] = [hi].[GUID]
		CREATE CLUSTERED INDEX [hiInd] ON [#HI] ([Guid], [ParentGUID])
	
		INSERT INTO [#Result] ( [CustPtr], [DistPtr], [HiPtr], [chGuid], [chCode], [chName], [DistCode], [DistName], [Contracted], [Flag], [Level], [Path], [State], [viCnt], [ActviCnt], [CustCnt] )
			SELECT DISTINCT [CustPtr], [hi].[Guid], [hi].[ParentGUID], [chGuid], [chCode], [chName], [Hi].[Code], [Hi].[Name], SUM([Contracted]), 1, [hi].[Level], [hi].[Path], [State], SUM([viCnt]), SUM([ActviCnt]), SUM(CustCnt)
			FROM [#Result] AS [r] INNER JOIN [#HI] as [hi] ON [r].[HiPtr] = [hi].[Guid] 
			GROUP BY [CustPtr], [hi].[Guid], [hi].[ParentGUID], [chGuid], [chCode], [chName], [Hi].[Code], [Hi].[Name], [hi].[Level], [hi].[Path], [State]


		IF (@ShowActive = 1)
		BEGIN
			INSERT INTO [#T_RESULT]
				SELECT [hi].[Guid], [hi].[ParentGuid], [ActiveGuid], [ActiveName], SUM([ActiveCnt]), SUM([CustActiveCnt]), [Hi].[Level], 0
			FROM [#T_RESULT] AS [t] INNER JOIN [#HI] AS [hi] ON [hi].[Guid] = [t].[HiPtr]
			GROUP BY [hi].[Guid], [hi].[ParentGuid], [ActiveGuid], [ActiveName], [Hi].[Level]
		END		

		SELECT @MaxLevel = MAX([LEVEL]) FROM  [#HI]
		WHILE @MaxLevel > 1
		BEGIN
			INSERT INTO [#Result] ( [CustPtr], [DistPtr], [HiPtr], [chGuid], [chCode], [chName], [DistCode], [DistName], [Contracted], [Flag], [Level], [Path], [State], [viCnt], [ActviCnt], [CustCnt] )
				SELECT DISTINCT [CustPtr], [hi].[Guid], [hi].[ParentGUID], [chGuid], [chCode], [chName], [Hi].[Code], [Hi].[Name], SUM([Contracted]), 1, [hi].[Level], [hi].[Path], [State], SUM([viCnt]), SUM([ActviCnt]), SUM(CustCnt)
					FROM [#Result] AS [r] INNER JOIN [#HI] as [hi] ON [r].[HiPtr] = [hi].[Guid] 
				WHERE [r].[Level] = @MaxLevel
				GROUP BY [CustPtr], [hi].[Guid], [hi].[ParentGUID], [chGuid], [chCode], [chName], [Hi].[Code], [Hi].[Name], [hi].[Level], [hi].[Path], [State]

			IF (@ShowActive = 1)
			BEGIN

				INSERT INTO [#T_RESULT]
					SELECT [hi].[Guid], [hi].[ParentGuid], [ActiveGuid], [ActiveName], SUM([ActiveCnt]), SUM([CustActiveCnt]), [Hi].[Level], 0
				FROM [#T_RESULT] AS [t] INNER JOIN [#HI] AS [hi] ON [hi].[Guid] = [t].[HiPtr]
				WHERE [t].[Level] = @MaxLevel
				GROUP BY [hi].[Guid], [hi].[ParentGuid], [ActiveGuid], [ActiveName], [Hi].[Level]
			END	
			
			SET @MaxLevel = @MaxLevel - 1
		
		END
		IF @HiLevel >= 1
		BEGIN
			SELECT @MaxLevel = MAX([LEVEL]) FROM  [#HI]
			WHILE (@MaxLevel > @HiLevel)
			BEGIN
				UPDATE [r] SET [HiPtr]	= [hi].[ParentGUID]
				FROM [#Result] AS [r] INNER JOIN [#HI] as [hi] ON [r].[HiPtr] = [hi].[Guid] 
				WHERE [hi].[Level] = @MaxLevel AND [r].[Flag] = 0
				
				DELETE [#Result] 
				FROM [#Result] AS [r] INNER JOIN [#HI] as [hi] ON [r].[DistPtr] = [hi].[Guid] 
				WHERE [hi].[Level] = @MaxLevel AND [r].[Flag] = 1
				
				SET @MaxLevel = @MaxLevel - 1
			END
		END
		UPDATE [r] SET [Path] = [hi].[Path]
			FROM [#Result] AS [r] INNER JOIN [#HI] as [hi] ON [r].[HiPtr] = [hi].[Guid]
			WHERE [r].[Path] = '' 
	END

	SELECT 
		
		[HiPtr]			AS [HierarchyGUID],
		[DistPtr]		AS [DistributorGUID],
		[DistCode]		AS [DistributorCode],
		[DistName]		AS [DistributorName],
		[chGuid]		AS [TchGUID],
		[chCode]		AS [TchCode],
		[chName]		AS [TchName],
		SUM([State])		AS [Coverage],
		SUM([Contracted]) 	AS CountContractedTradeChannel,		
		SUM([CustCnt]) 		AS CountTradeChannel,
		CAST (SUM([viCnt]) AS [FLOAT]) / @RealDaysNum 		AS [viCnt], 
		CAST (SUM([ActviCnt])  AS [FLOAT]) / @RealDaysNum  	AS [ActviCnt], 
		[Flag]	
	FROM 
		[#Result]   AS E
	GROUP BY
		[HiPtr], [DistPtr], [DistCode], [DistName], [chGuid], [chCode], [chName], [Flag], [Path] 
	ORDER BY
		 [Path], [Flag] DESC, [DistCode], [DistName], [DistPtr], [chCode], [chName]
	IF (@ShowActive = 1)
	BEGIN
		INSERT INTO [#T_RESULT] ( [ActiveGuid], [ActiveName], [FLAG] ) SELECT DISTINCT [ActiveGuid], [ActiveName], -3 FROM [#T_RESULT] 
		SELECT * FROM [#T_RESULT] ORDER BY [FLAG], [ActiveName], [ActiveGuid]
	END
	
	SELECT * FROM [#SecViol]

/*
 Exec prcConnections_add2 '„œÌ—'
 Exec repDistGetTChOfDistributor 0x00, 0x00, 1, 0, 0, '01-01-2006', '12-31-2006', 1, 1
*/
###################################################################
###End