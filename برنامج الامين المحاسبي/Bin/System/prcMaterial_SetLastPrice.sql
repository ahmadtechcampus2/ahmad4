########################################################
CREATE PROCEDURE prcMaterial_SetLastPrice 
	@MaterialGUID UNIQUEIDENTIFIER,
	@IgnoreLastPriceAndCost BIT = 1
AS 
	SET NOCOUNT ON 

	DECLARE @buDate DATE, @biPrice FLOAT, @biUnitFact FLOAT, @buCurrencyGUID UNIQUEIDENTIFIER, @buCurrencyVal FLOAT, @mtCurrencyGUID UNIQUEIDENTIFIER
			
	SELECT TOP 1 
		@buDate = bu.date,
		@biPrice = [bi].[Price],
		@biUnitFact = 
			(CASE [bi].[Unity]
				WHEN 2 THEN (CASE [mt].[Unit2FactFlag] WHEN 0 THEN [mt].[Unit2Fact] ELSE bi.[Qty] / (CASE bi.[Qty2] WHEN 0 THEN 1 ELSE bi.[Qty2] END) END)
				WHEN 3 THEN (CASE [mt].[Unit3FactFlag] WHEN 0 THEN [mt].[Unit3Fact] ELSE bi.[Qty] / (CASE bi.[Qty3] WHEN 0 THEN 1 ELSE bi.[Qty3] END) END)
				ELSE 1
			END),
		@buCurrencyGUID = bu.CurrencyGUID,
		@buCurrencyVal = bu.CurrencyVal,
		@mtCurrencyGUID = mt.CurrencyGUID
	FROM
		bu000 bu 
		INNER JOIN bi000 bi ON bu.GUID = bi.ParentGUID 
		INNER JOIN mt000 mt ON mt.GUID = bi.MatGUID 
		INNER JOIN bt000 bt ON bt.GUID = bu.TypeGUID 
	WHERE 
		bt.bAffectLastPrice = 1 
		AND 
		bi.matguid = @MaterialGUID
		AND
		bu.IsPosted = 1
	ORDER BY 
		bu.date DESC,
		bt.[SortFlag] DESC,
		bu.Number DESC,
		bi.Number DESC

	IF (@buDate IS NULL)
	BEGIN 
		UPDATE mt000 
			SET DisableLastPrice = 0 
		WHERE 
			Guid = @MaterialGUID AND DisableLastPrice <> 0;

		UPDATE mt000 
		SET 
			[LastPriceDate] = '19800101',
			[LastPrice] = 0,
			[LastPrice2] = 0,
			[LastPrice3] = 0,
			[LastPriceCurVal] = CurrencyVal
		WHERE 
			[GUID] = @MaterialGUID
			AND @ignoreLastPriceAndCost = 0;
	END ELSE BEGIN 
		DECLARE @LastPrice FLOAT 
		DECLARE @LastPrice_CurrencyVal FLOAT 
				
		SET @LastPrice = (CASE @biUnitFact WHEN 0 THEN 0 ELSE @biPrice / @biUnitFact END)
		SET @LastPrice_CurrencyVal = @buCurrencyVal

		IF @buCurrencyGUID <> @mtCurrencyGUID
		BEGIN 
			DECLARE @mtCurrencyVal_ByDate FLOAT 
			SET @mtCurrencyVal_ByDate = [dbo].fnGetCurVal(@mtCurrencyGUID, @buDate);
			IF ISNULL(@mtCurrencyVal_ByDate, 0) <> 0
			BEGIN 
				SET @LastPrice_CurrencyVal = @mtCurrencyVal_ByDate
				--SET @LastPrice = @LastPrice* @buCurrencyVal/ @mtCurrencyVal_ByDate
			END 
		END 

		UPDATE mt000 
		SET 
			[DisableLastPrice] = 1,
			[LastPriceDate] = @buDate,
			[LastPrice] = @LastPrice ,
			[LastPrice2] = @LastPrice  * Unit2Fact, 
			[LastPrice3] = @LastPrice  * Unit3Fact, 
			[LastPriceCurVal] = @LastPrice_CurrencyVal
		WHERE 
			[GUID] = @MaterialGUID 	
						 
	END
########################################################
#END 
