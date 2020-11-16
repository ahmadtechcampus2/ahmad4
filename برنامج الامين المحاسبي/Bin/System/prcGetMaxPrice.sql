#########################################################
##--Ì⁄Ìœ —ﬁ„ «·„«œ… Ê«·”⁄— «·√⁄Ÿ„Ì
##-----ÌÃ» „⁄«·Ã… «·’·«ÕÌ…  ··›Ê« Ì— Ê’·«ÕÌ… ﬁ—«¡… ”⁄—
CREATE PROCEDURE prcGetMaxPrice
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
DECLARE @IsAdmin [INT]
SELECT @IsAdmin = [dbo].[fnIsAdmin]( [dbo].[fnGetCurrentUserGUID]())

IF( EXISTS( SELECT * FROM [vwbu] WHERE [buDate] < @StartDate OR [buDate]> @EndDate) 
	OR @CostGUID <> 0X00 --selected cost so from bu , bi
	OR @SrcTypesguid <> 0X00   -- selected src types so from bi, bu
	OR @ShowUnLinked = 1  --we must calc sum(qty2), Sum(Qty3) from bi, bu
	OR @IsAdmin = 0 -- not Admin
	)
BEGIN
	CREATE TABLE [#Result]
	(
		[biMatPtr] 				[UNIQUEIDENTIFIER],
		[buDate]				[DATETIME],
		[biPrice]				[FLOAT],
		[buType]				[UNIQUEIDENTIFIER],
		[Security]				[INT],
		[UserReadPriceSecurity]	[INT],
		[UserSecurity] 			[INT],
		[MtSecurity]			[INT],
		[mtUnitFact]			[FLOAT]
		--[biStorePtr]			[UNIQUEIDENTIFIER]
	)

	INSERT INTO [#Result]
	SELECT
		[r].[biMatPtr],
		[r].[buDate],
		CASE WHEN [UserReadPriceSecurity] >= [BuSecurity] THEN [r].[biPrice] ELSE 0 END AS [biPrice],
		[r].[buType],
		
		[r].[buSecurity],
		[bt].[UserReadPriceSecurity],
		[bt].[UserSecurity],

		[r].[MtSecurity],
		[r].[mtUnitFact]
		--[r].[biStorePtr]
	FROM
		[dbo].[vwExtended_Bi] AS [r]
		INNER JOIN [#BillsTypesTbl] AS [bt] ON [r].[buType] = [bt].[TypeGuid]
		INNER JOIN [#MatTbl] AS [mtTbl] ON [r].[biMatPtr] = [mtTbl].[MatGUID]
	WHERE
		((@CostGUID = 0x0) OR ([BiCostPtr] IN( SELECT [CostGUID] FROM [#CostTbl])))
		AND [buDate] BETWEEN @StartDate AND @EndDate
		AND [btIsInput] = 1
		AND [btAffectLastPrice] <> 0
		
		AND ((@MatType = -1) OR ([mtType] = @MatType))
		AND [buIsPosted] <> 0 
	INSERT INTO [#t_Prices]
	SELECT
		[biMatPtr],
		ISNULL( (CASE WHEN @CurrencyVal <> 0 THEN ( MAX([biPrice] / [mtUnitFact])/@CurrencyVal ) ELSE (MAX([biPrice] / [mtUnitFact])) END), 0) AS [APrice]
	FROM
		[#Result] AS [bi1]
	WHERE
		[UserSecurity] >= [Security]
	GROUP BY
		[biMatPtr]
----add sec flags to #SecViol
	EXEC [prcCheckSecurity]
END
ELSE
BEGIN
	--Calc From mt, ms
	--print 'mt ms'
	INSERT INTO [#t_Prices] SELECT
		[v_mt].[mtGUID],
		--ISNULL((CASE WHEN @CurrencyVal <> 0 THEN v_mt.mtPrice / @CurrencyVal ELSE v_mt.mtPrice END), 0)AS APrice
		ISNULL( [v_mt].[mtPrice], 0)AS [APrice]
	FROM
		[dbo].[fnGetMtPricesWithSec]( 2/*@PriceType*/,120 /*@PricePolicy*/, @UseUnit, @CurrencyGUID, @EndDate) AS [v_mt]
		INNER JOIN [#MatTbl] AS [mtTbl] ON [v_mt].[mtGUID] = [mtTbl].[MatGUID]
	WHERE
		((@MatType = -1) 						OR ([mtType] = @MatType))
		--AND( (@IsAllMats = 1) 					OR (mtNumber IN( SELECT MatGUID FROM #MatTbl)))
END

/*

prcConnections_add2 '„œÌ—'

*/
#########################################################
#END