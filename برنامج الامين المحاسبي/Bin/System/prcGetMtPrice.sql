#########################################################
###--«·”⁄— „‰ »ÿ«ﬁ… «·„«œ…
CREATE PROCEDURE prcGetMtPrice
	@MatGUID 		[UNIQUEIDENTIFIER], -- 0 All Mat or MatNumber
	@GroupGUID 		[UNIQUEIDENTIFIER],
	@MatType 		[INT], -- 0 Store or 1 Service or -1 ALL
	@CurrencyGUID 	[UNIQUEIDENTIFIER],
	@CurrencyVal 	[FLOAT],
	@SrcTypesguid	[UNIQUEIDENTIFIER],
	@PriceType 		[INT],
	@PricePolicy 	[INT],
	@ShowUnLinked 	[INT] = 0,
	@UseUnit		[INT],
	@CurrnecyDate	[Date] = NULL
AS
	SET NOCOUNT ON
	IF @CurrnecyDate IS NULL
		SET @CurrnecyDate = GETDATE()
	--DECLARE @EPDate [DATETIME]
	--SELECT @EPDate = GETDATE() -- value FROM op000 WHERE Name = 'AmnCfg_EPDate'

	INSERT INTO [#t_Prices]
	SELECT
		[v_mt].[mtGUID],
		ISNULL( [v_mt].[mtPrice], 0)AS [APrice]
		--ISNULL(( CASE WHEN @CurrencyVal <> 0 THEN v_mt.mtPrice  / @CurrencyVal ELSE v_mt.mtPrice END), 0)AS APrice
	FROM
		[dbo].[fnGetMtPricesWithSec]( @PriceType, @PricePolicy, @UseUnit, @CurrencyGUID, @CurrnecyDate) AS [v_mt]
		INNER JOIN [#MatTbl] AS [mtTbl] ON [v_mt].[mtGUID] = [mtTbl].[MatGUID]
	WHERE
		((@MatType = -1) 						OR ([mtType] = @MatType))
		--AND( (@IsAllMats = 1) 					OR (mtNumber IN( SELECT MatGUID FROM #MatTbl)))

/*
select * from dbo.fnGetMtPricesWithSec(1,1,1)
prcConnections_add 1
CREATE TABLE #MatTbl( MatGUID INT, mtSecurity INT)
CREATE TABLE #StoreTbl(	StoreGUID INTEGER)
CREATE TABLE #BillsTypesTbl( BillType INTEGER, BillBrowseSec INTEGER, ReadPriceSec INTEGER)
CREATE TABLE #CostTbl( CostGUID INTEGER, Security INT)

CREATE TABLE #t_Prices
(
	mtNumber 	INT,
	APrice 		FLOAT
)

EXEC prcGetMtPrice
0,	--@MatGUID INT, -- 0 All Mat or MatNumber
0,	--@GroupGUID INT, --0 ?? ???????? ?? ?????? ?????
-1,	--@MatType INT, -- 0 Store or 1 Service or -1 ALL
1,	--@CurrencyGUID INT, --??? ??????
1,	--@CurrencyVal FLOAT, --??? ????? ??????
'',	--@SrcTypes VARCHAR(2000),-- bill types
122,	--@PriceType INT,
4,	--@PricePolicy INT,
0,	--@ShowUnLinked INT = 0,
0	--@UseUnit
SELECT *FROM #t_Prices
DROP TABLE #t_Prices
*/
#########################################################
#END