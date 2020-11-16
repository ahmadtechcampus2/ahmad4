################################################################################
CREATE PROC prcFillTempPricesTable
	@PriceType			INT,
	@PricePolicy		INT,
	@StartDate 			DATETIME, 
	@EndDate 			DATETIME, 
	@MatGUID 			UNIQUEIDENTIFIER,
	@GroupGUID 			UNIQUEIDENTIFIER, 
	@StoreGUID 			UNIQUEIDENTIFIER,
	@CostGUID 			UNIQUEIDENTIFIER,
	@MatType 			INT,
	@CurrencyGUID 		UNIQUEIDENTIFIER,
	@CurrencyVal 		FLOAT, 
	@SrcTypesGUID		UNIQUEIDENTIFIER, 
	@ShowUnLinked 		INT, 
	@UseUnit 			INT, 
	@CalcLastCost		INT, 
	@ProcessExtra		INT
AS
	SET @CurrencyVal = dbo.fnGetCurVal(@CurrencyGUID, @EndDate);

	IF @PriceType = 2
	BEGIN
		DECLARE @DefCur UNIQUEIDENTIFIER = (SELECT TOP 1 GUID FROM my000 WHERE CurrencyVal = 1);

		IF @PricePolicy = 122
			EXEC prcGetLastPriceNewEquation @StartDate, @EndDate, @MatGUID, @GroupGUID, @StoreGUID, @CostGUID, -1, @CurrencyGUID, @SrcTypesguid, 0, 0, 0, 0, @PricePolicy	
		ELSE IF @PricePolicy = 120
			EXEC prcGetMaxPrice @StartDate, @EndDate, @MatGUID, @GroupGUID, @StoreGUID, @CostGUID, -1, @DefCur, 1, @SrcTypesguid, 0, 0;
		ELSE IF @PricePolicy = 121
			EXEC prcGetAvgPrice	@StartDate,	@EndDate, @MatGUID, @GroupGUID, @StoreGUID, @CostGUID, -1, @DefCur, 1, @SrcTypesguid, 0, 0;
		ELSE IF @PricePolicy = 124
			EXEC prcGetLastPriceNewEquation @StartDate, @EndDate, @MatGUID, @GroupGUID, @StoreGUID, @CostGUID, -1, @CurrencyGUID, @SrcTypesguid, 0, 0, 0, 1, @PricePolicy	

		IF @PricePolicy = 120 OR @PricePolicy = 121
			UPDATE #t_Prices
			SET APrice = APrice / @CurrencyVal;
	END
	ELSE IF @PriceType = 0x8000 
	BEGIN
		INSERT INTO #t_Prices 
		SELECT 
			[Guid],
			[dbo].[fnGetOutbalanceAveragePrice]([Guid], @EndDate) / @CurrencyVal
		FROM mt000 
		WHERE [Guid] = @MatGUID OR @MatGUID = 0x
	END
	ELSE IF @PriceType <> -1
		EXEC [prcGetMtPrice] @MatGUID, @GroupGUID, -1, @CurrencyGUID, @CurrencyVal, @SrcTypesguid, @PriceType, @PricePolicy, 0, @UseUnit, @EndDate;
################################################################################
#END
