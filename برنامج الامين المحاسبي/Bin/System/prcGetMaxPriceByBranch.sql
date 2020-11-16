####################################################
CREATE PROCEDURE prcGetMaxPriceByBranch
	@StartDate 			[DATETIME],
	@EndDate 			[DATETIME],
	@MatGUID 			[UNIQUEIDENTIFIER], -- 0 All Mat or MatNumber
	@GroupGUID 			[UNIQUEIDENTIFIER],
	@StoreGUID 			[UNIQUEIDENTIFIER], -- 0 all stores so don't check store or list of stores
	@CostGUID 			[UNIQUEIDENTIFIER], -- 0 all costs so don't Check cost or list of costs
	@MatType 			[INT], -- 0 Store or 1 Service or -1 ALL
	@CurrencyGUID 		[UNIQUEIDENTIFIER],
	@CurrencyVal 		[FLOAT],
	@SrcTypesguid		[UNIQUEIDENTIFIER],
	@ShowUnLinked 		[INT] = 0,
	@UseUnit 			[INT]
AS

	SET NOCOUNT ON

	CREATE TABLE [#Result]
	(
		[biMatPtr] 				[UNIQUEIDENTIFIER],
		[buBranch]				[UNIQUEIDENTIFIER],
		[buDate]				[DATETIME],
		[biPrice]				[FLOAT],
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
		[r].[buBranch],
		[r].[buDate],
		CASE WHEN [UserReadPriceSecurity] >= [BuSecurity] THEN [r].[biPrice] ELSE 0 END AS [biPrice],
		[r].[buType],
		
		[r].[buSecurity],
		[bt].[UserReadPriceSecurity],
		[bt].[UserSecurity],

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
		AND [btIsInput] = 1
		AND [btAffectLastPrice] <> 0
		--AND ((@IsAllMats = 1) OR (biMatPtr IN( SELECT MatGUID FROM #MatTbl) ) )
----------- Max Price does'nt depend on store 
		--AND((@StoreGUID = 0) OR (biStorePtr IN( SELECT StoreGUID FROM #StoreTbl)))
		AND ((@MatType = -1) OR ([mtType] = @MatType))
		AND [buIsPosted] <> 0 

	INSERT INTO [#t_Prices]
	SELECT
		[biMatPtr],
		[buBranch],
		ISNULL( (CASE WHEN @CurrencyVal <> 0 THEN ( MAX([biPrice] / [mtUnitFact]) / @CurrencyVal) ELSE (MAX([biPrice] / [mtUnitFact])) END), 0) AS [APrice]
	FROM
		[#Result] AS [bi1]
	WHERE
		[UserSecurity] >= [Security]
	GROUP BY
		[biMatPtr],
		[buBranch]
----add sec flags to #SecViol
	EXEC [prcCheckSecurity]

/*

CREATE TABLE #SecViol( Type INT, Cnt INTEGER)
CREATE TABLE #MatTbl(MatGuid UNIQUEIDENTIFIER, mtSecurity INT)
INSERT INTO #MatTbl( MatGuid, mtSecurity) VALUES ('F251FC9F-3229-4314-926C-3323B4DD80EE', 1)
INSERT INTO #MatTbl( MatGuid, mtSecurity) VALUES ('9018D2C1-05E3-4360-A453-C8A8065A456B', 1)

CREATE TABLE #StoreTbl(	StoreGUID UNIQUEIDENTIFIER, Security INT)
INSERT INTO #StoreTbl VALUES ('EF638244-A716-47B1-81E2-4841CA711D46', 1)
INSERT INTO #StoreTbl VALUES ('DB8B5A7F-C8C9-4CA0-9D94-60F6815B5DC7', 1)
INSERT INTO #StoreTbl VALUES ('20EFB511-7672-4B12-8D70-F0B10466C2D1', 1)

CREATE TABLE #BillsTypesTbl( TypeGuid UNIQUEIDENTIFIER, UserSecurity INTEGER, UserReadPriceSecurity INTEGER)
INSERT INTO #BillsTypesTbl	EXEC prcGetBillsTypesList 	0x0
CREATE TABLE #CostTbl( CostGUID UNIQUEIDENTIFIER, Security INT)
CREATE TABLE #t_Prices( mtNumber UNIQUEIDENTIFIER, Branch UNIQUEIDENTIFIER, APrice FLOAT)

EXEC prcGetMaxPriceByBranch
'1/1/2000'	--	@StartDate
,'5/13/2007'--	@EndDate
,0x0--	@MatGUID
,0x0--	@GroupGUID
,0x0--	@StoreGUID
,0x0--	@CostGUID
--,0x0--	@BranchGuid
,0--	@MatType
,'BB123651-A15E-4AAA-AEBE-F5B44211DDA3'--	@CurrencyGUID
,1--	@CurrencyVal
,0x0--	@SrcTypes
,0--	@ShowUnLinked
,0--	@UseUnit

SELECT * FROM #t_Prices
DROP TABLE #StoreTbl
DROP TABLE #BillsTypesTbl
DROP TABLE #CostTbl
DROP TABLE #MatTbl
DROP TABLE #t_Prices
DROP TABLE #SecViol

*/
##########################################
#END