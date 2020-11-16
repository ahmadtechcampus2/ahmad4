#########################################################
##--Ì⁄Ìœ —ﬁ„ «·„«œ… Ê«·ﬂ„Ì… Ê«·„” Êœ⁄
##---ÌÃ» „⁄«·Ã… «·’·«ÕÌ… ›Ì Õ”«» «·ﬂ„Ì… 
CREATE PROCEDURE prcGetQnt
	@StartDate 			[DATETIME],
	@EndDate 			[DATETIME],
	@MatGUID 			[UNIQUEIDENTIFIER] = NULL,
	@GroupGUID 			[UNIQUEIDENTIFIER] = NULL,
	@StoreGUID 			[UNIQUEIDENTIFIER] = NULL,
	@CostGUID 			[UNIQUEIDENTIFIER] = NULL,
	@MatType 			[INT] = 0, -- 0 Store or 1 Service or -1 ALL
	@DetailsStores 		[INT] = 1, -- 1 show details 0 no details
	@SrcTypesguid		[UNIQUEIDENTIFIER],
	@ShowUnLinked 		[INT] = 0,
	@ShowGroups 		[INT] = 0, -- if 1 add 3 new columns for groups
	@UseUnit 			[INT] = 0
AS
 SET NOCOUNT ON
	-- important dont change the place of these three lines
	IF( EXISTS( SELECT * FROM [vwbu] WHERE [buDate] < @StartDate OR [buDate]> @EndDate)
		OR @CostGUID IS NOT NULL --selected cost so from bu , bi
		OR @ShowUnLinked = 1  -- we must calc sum(qty2), Sum(Qty3) from bi, bu
		OR EXISTS(SELECT * FROM op000 WHERE name like 'AmncfgMultiFiles' and value = '1'))
	BEGIN
	-- Calc From bu, bi
		CREATE TABLE [#Result]
		(
			[biMatPtr] 			[UNIQUEIDENTIFIER],
			[buDirection]		[INT],
			[biQty]  			[FLOAT],
			[biBonusQnt]		[FLOAT],
			[biQty2]			[FLOAT],
			[biQty3]			[FLOAT],
			[biStorePtr]		[UNIQUEIDENTIFIER],
			[buType]			[UNIQUEIDENTIFIER],
			[Security]			[INT],
			[UserSecurity] 		[INT],
			[MtSecurity]		[INT]
		)

		INSERT INTO [#Result]
		(
			[biMatPtr],
			[buDirection],
			[biQty],
			[biBonusQnt],
			[biQty2],
			[biQty3],
			[biStorePtr],
			[buType],

			[Security],
			[UserSecurity],

			[MtSecurity]
		)
		SELECT
			[r].[biMatPtr],
			[r].[buDirection],
			[r].[biQty],
			[r].[biBonusQnt],
			[r].[biCalculatedQty2],
			[r].[biCalculatedQty3],
			[r].[biStorePtr],
			[r].[buType],

			[r].[buSecurity],
			[bt].[UserSecurity],
	
			[r].[MtSecurity]
		FROM
			[vwExtended_bi] AS [r]
			INNER JOIN [#BillsTypesTbl] AS [bt] ON [r].[buType] = [bt].[TypeGuid]
			INNER JOIN [#MatTbl] AS [mtTbl] ON [r].[biMatPtr] = [mtTbl].[MatGUID]
			INNER JOIN [#StoreTbl] AS [st] ON [st].[StoreGUID] = [biStorePtr]
		WHERE
			[budate] BETWEEN @StartDate AND @EndDate
			AND ((@MatType = -1) OR ([mtType] = @MatType))
			AND((@CostGUID = 0x0) OR ([BiCostPtr] IN( SELECT [CostGUID] FROM [#CostTbl])))
			AND [buIsPosted] > 0
		EXEC [prcCheckSecurity]
		
		CREATE TABLE [#t_QtysWithStores]
		(
			[mtGUID] 	[UNIQUEIDENTIFIER],
			[Qnt] 		[FLOAT],
			[Qnt2]		[FLOAT],
			[Qnt3]		[FLOAT],
			[StoreGUID]	[UNIQUEIDENTIFIER]
		)
		INSERT INTO [#t_QtysWithStores]
		SELECT
			[biMatPtr],
			SUM([buDirection] * ([biQty] + [biBonusQnt])) AS [Qnt],
			SUM([buDirection] * [biQty2]) AS [Qnt2],
			SUM([buDirection] * [biQty3]) AS [Qnt3],
			[biStorePtr]
		FROM
			[#Result] AS [r]
		WHERE
			[UserSecurity] >= [Security]
		GROUP BY
			[biMatPtr],
			[biStorePtr]
		
		--commmit (@StoreGUID = 0) on 30-9-2002
		IF (/*(@StoreGUID = 0) AND */(@DetailsStores = 0))
			INSERT INTO [#t_Qtys]
				SELECT
					[mtGUID],
					SUM([Qnt]),
					SUM([Qnt2]),
					SUM([Qnt3]),
					0x0 AS [StorePtr]
				FROM
					[#t_QtysWithStores]
				GROUP BY
					[mtGUID]
		ELSE
			INSERT INTO [#t_Qtys] SELECT * FROM [#t_QtysWithStores]
		----add sec flags to #SecViol
	END
	ELSE
	BEGIN
		--Calc From mt, ms
		--print 'mt ms'
		IF /*(@StoreGUID = 0) AND */(@DetailsStores = 0)
		BEGIN
			INSERT INTO [#t_Qtys] SELECT 
				[mtGUID],
				ISNULL([mtQty], 0) AS [Qnt],
				0 AS [Qnt2],
				0 AS [Qnt3],
				0x0 AS [StorePtr]
			FROM
				[vwmt] AS [mt] INNER JOIN [#MatTbl] AS [mtTbl] ON [mt].[mtGUID] = [mtTbl].[MatGUID]
			WHERE
				((@MatType = -1) OR ([mtType] = @MatType))
				--AND ((@IsAllMats = 1) OR (mtGUID IN( SELECT MatPtr FROM #MatTbl) ) ) 
		END
		ELSE
		BEGIN  ---select *from VwMsSt

			INSERT INTO [#t_Qtys] SELECT 
				[v_mt].[mtGUID],
				ISNULL( [VMsSt].[msQty], 0) AS [Qnt],
				0 AS [Qnt2],
				0 AS [Qnt3],
				ISNULL([VMsSt].[msStorePtr]	, 0x0) AS [StorePtr]
			FROM
				[vwmt] AS [v_mt]
				INNER JOIN [#MatTbl] AS [mtTbl] ON [v_mt].[mtGUID] = [mtTbl].[MatGUID]
				LEFT JOIN [VwMsSt] AS [VMsSt] ON [v_mt].[mtGUID] = [VMsSt].[msMatPtr]
			WHERE
				((@MatType = -1) 						OR (mtType = @MatType))
				--AND((@IsAllMats = 1) 					OR (mtNumber IN( SELECT MatPtr FROM #MatTbl)))
				AND((@StoreGUID = 0x0) 	OR ([VMsSt].[msStorePtr] IN( SELECT [StoreGUID] FROM [#StoreTbl])))
				--AND(VMsSt.msStorePtr IN( SELECT StorePtr FROM #StoreTbl))
			--END
		END
	END
	--- calc Groups
--------------------------
	/*
	CREATE TABLE #MainRes
	(
		mtGUID 			UNIQUEIDENTIFIER,
		Qnt 			FLOAT,
		Qnt2			FLOAT,
		Qnt3			FLOAT,
		StoreGUID		UNIQUEIDENTIFIER,

		mtUnit2Fact		FLOAT,
		mtUnit3Fact		FLOAT,
		mtDefUnitFact	FLOAT,

		MtGroup			UNIQUEIDENTIFIER,
		GroupParentPtr  UNIQUEIDENTIFIER,
		RecType 		VARCHAR(1) COLLATE ARABIC_CI_AI DEFAULT 'm' NOT NULL,
		[Level] 		INT DEFAULT 0 NOT NULL--,
--		STName 			VARCHAR(255) COLLATE ARABIC_CI_AI
	)


	CREATE TABLE #SecViol( Type INT, Cnt INTEGER)
	CREATE TABLE #MatTbl( MatGUID UNIQUEIDENTIFIER, mtSecurity INT)
	CREATE TABLE #StoreTbl(	StoreGUID UNIQUEIDENTIFIER, Security INT)
	CREATE TABLE #BillsTypesTbl( TypeGuid UNIQUEIDENTIFIER, UserSecurity INTEGER, UserReadPriceSecurity INTEGER)
	CREATE TABLE #CostTbl( CostGUID UNIQUEIDENTIFIER, Securitty INT)
	DECLARE @MatGUID UNIQUEIDENTIFIER
	SET @MatGUID = 0x0
	DECLARE @GroupGUID UNIQUEIDENTIFIER
	SET @GroupGUID = 0x0
	DECLARE @StoreGUID UNIQUEIDENTIFIER
	SET @StoreGUID = 0x0
	DECLARE @CostGUID UNIQUEIDENTIFIER
	SET @CostGUID = 0x0
	-- Filling temporary tables
	INSERT INTO #MatTbl			EXEC prcGetMatsList 		@MatGUID, @GroupGUID, -1--@MatType
	INSERT INTO #StoreTbl		EXEC prcGetStoresList 		@StoreGUID
	INSERT INTO #BillsTypesTbl	EXEC prcGetBillsTypesList 	0x0
	INSERT INTO #CostTbl		EXEC prcGetCostsList 		@CostGUID

	CREATE TABLE #t_Qtys
	(
		mtNumber 	UNIQUEIDENTIFIER,
		Qnt 		FLOAT,
		Qnt2 		FLOAT,
		Qnt3 		FLOAT,
		StorePtr	UNIQUEIDENTIFIER
	)

	EXEC prcGetQnt
	'1/1/2000'		--	@StartDate DATETIME,
	,'8/31/2005'	--	@EndDate DATETIME,
	,0x0--	@MatGUID INT, -- 0 All Mat or MatNumber
	,0x0--	@GroupGUID INT,
	,0x0--	@StoreGUID INT, -- 0 all stores so don't check store or list of stores
	,0x0--	@CostGUID INT, -- 0 all costs so don't Check cost or list of costs
	,0--	@MatType INT, -- 0 Store or 1 Service or -1 ALL
	,1--	@DetailsStores INT, -- 1 show details 0 no details
	,0x0--	@SrcTypes VARCHAR(2000),-- bill types
	,0--	@ShowUnLinked INT = 0,
	,1--	@ShowGroups 		INT = 0 -- if 1 add 3 new columns for groups
	select *from #t_Qtys order by mtNumber
	select *from #MainRes
	DROP TABLE #t_Qtys
	DROP TABLE #MatTbl
	DROP TABLE #StoreTbl
	DROP TABLE #BillsTypesTbl
	DROP TABLE #CostTbl
	DROP TABLE #SecViol
	drop table #MainRes

	*/
#####################################################
#END