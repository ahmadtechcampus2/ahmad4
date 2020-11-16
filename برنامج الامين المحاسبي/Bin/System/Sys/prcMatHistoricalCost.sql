############################################################################
CREATE PROCEDURE prcMatHistoricalCost
	@MatGUID	[UNIQUEIDENTIFIER],
	@Days		INT 
AS 
	SET NOCOUNT ON 

	DECLARE 
		@StartDate			[DATETIME], 
		@EndDate 			[DATETIME],
		@tempdate			[DATE],
		@HistCostOutRange	BIT = 0

	SET  @tempdate = (DATEADD(DAY, -@Days, GETDATE())) 
	SET @StartDate = @tempdate
	SET @EndDate = GETDATE()
	
	CREATE TABLE [#EndResult] ( 
		[BiPrice] [FLOAT],
		[biQty] [FLOAT],
		[BiBonusQnt] [FLOAT],
		[TotalItemPrice] [FLOAT],
		[TotalDisc] [FLOAT],
		[TotalExtra] [FLOAT],
		[BuTotal] [FLOAT],
		[BuTotalDisc] [FLOAT],
		[BuTotalExtra] [FLOAT],
		[BuItemsDisc] [FLOAT],
		[BuBonusDisc] [FLOAT],
		[BiDiscount] [FLOAT],
		[BiBonusDisc] [FLOAT],
		[BiExtra] [FLOAT],
		[btDiscAffectCost] [BIT],
		[btDiscAffectProfit] [BIT] ,
		[btExtraAffectCost] [BIT],
		[btExtraAffectProfit] [BIT],
		[unit_price] [FLOAT],
		[biVat] [FLOAT],
		[btVATSystem] [INT])

	INSERT INTO[#EndResult]
	SELECT 
		budirection * BiPrice,
		budirection * biQty,
		budirection * BiBonusQnt,
		budirection * BiPrice * biQty,
		budirection * BuTotalDisc - BuItemsDisc + BuBonusDisc,
		budirection * BuTotalExtra ,
		BuTotal,
		budirection * BuTotalDisc,
		budirection * BuTotalExtra,
		budirection * BuItemsDisc,
		budirection * BuBonusDisc,
		budirection * BiDiscount,
		budirection * BiBonusDisc,
		budirection * BiExtra,
		btDiscAffectCost,
		btDiscAffectProfit,
		btExtraAffectCost,
		btExtraAffectProfit,
		0,
		biVAT,
		btVATSystem 
	FROM 
		[dbo].[vwExtended_bi] AS [r]
	WHERE	
		[budate] BETWEEN @StartDate AND @EndDate
		AND btAffectCostPrice = 1 AND buIsPosted = 1 
		AND biMatPtr = @MatGUID

	DECLARE @count INT = (SELECT COUNT(BiPrice) FROM [#EndResult])

	IF @count = 0 
	BEGIN
		SET @HistCostOutRange = 1 
	
		INSERT INTO[#EndResult]
		SELECT budirection * BiPrice,
				budirection * biQty,
				budirection * BiBonusQnt,
				budirection * BiPrice * biQty,
				budirection * BuTotalDisc - BuItemsDisc + BuBonusDisc,
				budirection * BuTotalExtra ,
				BuTotal,
				budirection * BuTotalDisc,
				budirection * BuTotalExtra,
				budirection * BuItemsDisc,
				budirection * BuBonusDisc,
				budirection * BiDiscount,
				budirection * BiBonusDisc,
				budirection * BiExtra,
				btDiscAffectCost,
				btDiscAffectProfit,
				btExtraAffectCost,
				btExtraAffectProfit,
				0,
				biVAT,
				btVATSystem 
			FROM 
				[dbo].[vwExtended_bi] AS [r]

			WHERE	
				[budate] < @StartDate
				AND btAffectCostPrice = 1  AND buIsPosted = 1 
				AND biMatPtr = @MatGUID
	END  

	UPDATE [#EndResult]
	SET 
		TotalDisc = (BiDiscount + BiBonusDisc) + (BuTotalDisc - BuItemsDisc + 	BuBonusDisc) * (BiPrice * biQty) / BuTotal,
		TotalExtra = BiExtra + BuTotalExtra * (BiPrice * biQty) / BuTotal
	WHERE BuTotal <> 0

	UPDATE [#EndResult]
	SET 
		TotalItemPrice = TotalItemPrice - TotalDisc
	WHERE
			btDiscAffectCost = 1 OR btDiscAffectProfit = 1

	UPDATE [#EndResult]
	SET 
		TotalItemPrice = TotalItemPrice  + TotalExtra
	WHERE
			btExtraAffectCost = 1 OR btExtraAffectProfit = 1

	UPDATE [#EndResult]
	SET 
		unit_price = TotalItemPrice  / biQty,
		bivat = bivat / biQty
	WHERE 
		biQty <> 0

	UPDATE [#EndResult]
	SET 
		unit_price = 
			(CASE btVATSystem
				WHEN 1 then ((unit_price * biQty) + ((unit_price * biQty) * (bivat / 100))) / biQty
				WHEN 2 then ((unit_price * biQty) / ((bivat / 100) + 1)) / biQty 
			END)
	WHERE 
		btVATSystem > 0

	DECLARE
		 @TotalPrice FLOAT,
		 @TotalQnt FLOAT,
		 @AvgPrice FLOAT
	SET @TotalPrice = (SELECT SUM(unit_price * biQty) FROM [#EndResult])
	SET @TotalQnt = (SELECT SUM(BiBonusQnt + biQty) FROM [#EndResult])
	SET @AvgPrice = @TotalPrice / (CASE @TotalQnt WHEN 0 THEN 1 ELSE @TotalQnt END)

	SELECT 
		ISNULL(@AvgPrice, 0) AS HistoricalCost, 
		@HistCostOutRange HistCostOutRange
###############################################################################
#END
