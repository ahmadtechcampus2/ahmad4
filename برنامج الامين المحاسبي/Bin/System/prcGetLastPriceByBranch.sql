#################################################################
CREATE PROCEDURE prcGetLastPriceByBranch
	@StartDate 			[DATETIME],
	@EndDate 			[DATETIME],
	@MatGUID 			[UNIQUEIDENTIFIER], -- 0 All Mat or MatNumber
	@GroupGUID 			[UNIQUEIDENTIFIER],
	@StoreGUID 			[UNIQUEIDENTIFIER], -- 0 all stores so don't check store or list of stores
	@CostGUID 			[UNIQUEIDENTIFIER], -- 0 all costs so don't Check cost or list of costs
	@MatType 			[INT], -- 0 Store or 1 Service or -1 ALL
	@CurrencyGUID 		[UNIQUEIDENTIFIER], -- if 0x0 then use buy currencyPtr else use fixed Price
	@SrcTypesguid		[UNIQUEIDENTIFIER],
	@ShowUnLinked 		[INT] = 0,
	@UseUnit 			[INT],
	@CalcLastCost		[INT] = 0
AS
--- if @CurrencyGuid = 0x0 we need last price using its currency in the bill to be used in ProductProfit.
--- else if @CurrencyGuid has other value we will use FixedPrice.

SET NOCOUNT ON
DECLARE @IsAdmin [INT]
SELECT @IsAdmin = [dbo].[fnIsAdmin]( [dbo].[fnGetCurrentUserGUID]())
	CREATE TABLE [#Result]
	(
		[biMatPtr] 				[UNIQUEIDENTIFIER],
		[buDate]				[DATETIME],
		[buBranch]				[UNIQUEIDENTIFIER],
--- don't delete the following five fields
		[biPrice]				[FLOAT],
		[FixedbiPrice]			[FLOAT],
		[biCurrencyVal]			[FLOAT],
		[biUnitDiscount]		[FLOAT],
		[biUnitExtra]			[FLOAT],

		[buType]				[UNIQUEIDENTIFIER],
		[Security]				[INT],
		[UserReadPriceSecurity]	[INT],
		[UserSecurity] 			[INT],
		[MtSecurity]			[INT],
		[mtUnitFact]			[FLOAT],
		[biStorePtr]			[UNIQUEIDENTIFIER]
	)

	INSERT INTO [#Result]
	SELECT
		[r].[biMatPtr],
		[r].[buDate],
		[r].[buBranch],
		CASE WHEN [UserReadPriceSecurity] >= [BuSecurity] THEN [r].[biPrice] ELSE 0 END AS [biPrice],
		CASE WHEN [UserReadPriceSecurity] >= [BuSecurity] THEN [r].[FixedbiPrice] ELSE 0 END AS [FixedbiPrice],
		[r].[biCurrencyVal],
		CASE WHEN [UserReadPriceSecurity] >= [BuSecurity] THEN [r].[biUnitDiscount] ELSE 0 END AS [biUnitDiscount],
		CASE WHEN [UserReadPriceSecurity] >= [BuSecurity] THEN [r].[biUnitExtra] ELSE 0 END AS [biUnitExtra],

		[r].[buType],
		[r].[buSecurity],
		[bt].[UserSecurity],
		[bt].[UserReadPriceSecurity],
		[r].[MtSecurity],
		[r].[mtUnitFact],
		[r].[biStorePtr]
	FROM
		[dbo].[fnExtended_Bi_Fixed]( @CurrencyGUID) AS [r]
		INNER JOIN [#BillsTypesTbl] AS [bt] ON [r].[buType] = [bt].[TypeGuid]
		INNER JOIN [#MatTbl] AS [mtTbl] ON [r].[biMatPtr] = [mtTbl].[MatGUID]
	WHERE
		((@CostGUID = 0x0) OR ([BiCostPtr] IN( SELECT [CostGUID] FROM [#CostTbl])))
		AND [buDate] BETWEEN @StartDate AND @EndDate 
		AND [btAffectLastPrice] <> 0
		--	Last Price does'nt depend on store 
		--AND((@StoreGUID = 0) OR (biStorePtr IN( SELECT StoreGUID FROM #StoreTbl)))
		AND ((@MatType = -1) OR ([mtType] = @MatType))
		AND [buIsPosted] <> 0 

---check Sec
	EXEC [prcCheckSecurity]

-----
	INSERT INTO [#t_Prices]
	SELECT
		[vwmtGr].[mtGUID],
		[bi5].[BuBranch],
		ISNULL( [bi5].[LastPrice], 0) AS [APrice]
	FROM
		[vwmtGr] INNER JOIN [#MatTbl] AS [mtTbl] ON [vwmtGr].[mtGUID] = [mtTbl].[MatGUID]
		INNER JOIN
		(
			SELECT
				[bi3].[biMatPtr],
				[bi3].[buDate] AS [LastPriceDate],
				[bi3].[buBranch],
				MAX([bi3].[biPrice]) AS [LastPrice]
			FROM
			(
				SELECT
					[biMatPtr],
					(CASE @CurrencyGUID
						WHEN 0x0 THEN [biPrice] / [mtUnitFact] / (CASE [biCurrencyVal] WHEN 0 THEN 1 ELSE [biCurrencyVal] END) 
						ELSE (CASE @CalcLastCost WHEN 1 THEN ( [FixedbiPrice] / [mtUnitFact] + [biUnitExtra] - [biUnitDiscount])
												 ELSE ( [FixedbiPrice] / [mtUnitFact]) END)
					END) AS [biPrice],
					[buDate],
					[buBranch]
			FROM
				[#Result] AS [bi1]
			WHERE
				[buDate] =(
							SELECT
								MAX([buDate])
							FROM
								[#Result] AS [bi2]
							WHERE
								[bi2].[biMatPtr] = [bi1].[biMatPtr]
								AND [bi2].[buBranch] = [bi1].[BuBranch]
								AND [UserSecurity] >= [Security]
						)
				AND [UserSecurity] >= [Security]
		) AS [bi3]
	GROUP BY
			[bi3].[biMatPtr],
			[bi3].[buDate],
			[bi3].[buBranch]
	)AS [bi5]
		ON [vwMtGr].[mtGUID] = [bi5].[biMatPtr]
	WHERE
		((@MatType = -1) OR ([mtType] = @MatType))

/*

CREATE TABLE #SecViol( Type INT, Cnt INTEGER)
CREATE TABLE #CostTbl( CostGUID UNIQUEIDENTIFIER, Security INT)

CREATE TABLE #MatTbl(MatGuid UNIQUEIDENTIFIER, mtSecurity INT)
INSERT INTO #MatTbl( MatGuid, mtSecurity) VALUES ('F251FC9F-3229-4314-926C-3323B4DD80EE', 1)
INSERT INTO #MatTbl( MatGuid, mtSecurity) VALUES ('9018D2C1-05E3-4360-A453-C8A8065A456B', 1)

CREATE TABLE #StoreTbl(	StoreGUID UNIQUEIDENTIFIER, Security INT)
INSERT INTO #StoreTbl VALUES ('EF638244-A716-47B1-81E2-4841CA711D46', 1)
INSERT INTO #StoreTbl VALUES ('DB8B5A7F-C8C9-4CA0-9D94-60F6815B5DC7', 1)
INSERT INTO #StoreTbl VALUES ('20EFB511-7672-4B12-8D70-F0B10466C2D1', 1)

CREATE TABLE #BillsTypesTbl( TypeGuid UNIQUEIDENTIFIER, UserSecurity INTEGER, UserReadPriceSecurity INTEGER)
INSERT INTO #BillsTypesTbl	EXEC prcGetBillsTypesList 	0x0
CREATE TABLE #t_Prices( mtNumber UNIQUEIDENTIFIER, Branch UNIQUEIDENTIFIER, APrice FLOAT)

EXEC prcGetLastPriceByBranch
'1/1/2000'	--	@StartDate
,'5/13/2007'--	@EndDate
,0x0--	@MatGUID
,0x0--	@GroupGUID
,0x0--	@StoreGUID
,0x0--	@CostGUID
,0--	@MatType
,'BB123651-A15E-4AAA-AEBE-F5B44211DDA3'--	@CurrencyGUID
,0x0 --@SrcTypesguid		UNIQUEIDENTIFIER,
,0	--	@ShowUnLinked
,0	--	@UseUnit
,0	--	@CalcLastCost		INT = 0
SELECT * FROM #t_Prices
DROP TABLE #StoreTbl
DROP TABLE #BillsTypesTbl
DROP TABLE #CostTbl
DROP TABLE #MatTbl
DROP TABLE #t_Prices
DROP TABLE #SecViol

*/
#############################################################
#END