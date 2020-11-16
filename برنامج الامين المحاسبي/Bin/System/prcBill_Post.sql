###########################################################################
CREATE PROCEDURE prcBill_post
	@GUID [UNIQUEIDENTIFIER],
	@Post [BIT]
AS
/*
This procedure:
	- handles the posting and unposting of a single bill.
	- is optimized for dealing with bi records holding distinct materials
	- updates the profits at bi000 and bu000.
	- updates ms.
	- udpates cp.
	- might set  mc 24 flag for the need of recalculating profits.
	- biUnity is assumed 1 when non-related units.
*/
	SET NOCOUNT ON
	-- mt variables declarations:
	DECLARE
		@mtQnt [FLOAT],
		@mtValue [FLOAT],
		@mtAvgPrice [FLOAT],
		@mtMaxPrice [FLOAT],
		@mtLastPrice [FLOAT],
		@mtLastPriceDate [DATETIME],
		@mtUnit2Fact [FLOAT],
		@mtUnit3Fact [FLOAT],
		@UnityFactor [FLOAT],
		@mtSecurity [INT]
	-- declare cursors and input variables:
	DECLARE
		@c CURSOR,
		@buType [UNIQUEIDENTIFIER],
		@buNumber [INT],
		@buDate [DATETIME],
		@buCustPtr [UNIQUEIDENTIFIER],
		@Direction [INT],
		@biGUID [UNIQUEIDENTIFIER],
		@biStorePtr [UNIQUEIDENTIFIER],
		@biMatPtr [UNIQUEIDENTIFIER],
		@biUnity [INT],
		@biQty [FLOAT],
		@biBonusQnt [FLOAT],
		@biUnitPrice [FLOAT],
		@biUnitDiscount [FLOAT],
		@biUnitExtra [FLOAT],
		@biDiscount [FLOAT],
		@biExtra [FLOAT],
		@btInputBill [BIT],
		@btAffectLastPrice [BIT],
		@btAffectCostPrice [BIT],
		@btAffectCustPrice [BIT],
		@btAffectProfit [BIT],
		@btExtraAffectCost [BIT],
		@btDiscAffectCost [BIT],
		@btExtraAffectProfit [BIT],
		@btDiscAffectProfit [BIT],
		@btIncludeTTCOnSales [BIT],
		@buCurrencyGUID [UNIQUEIDENTIFIER],
		@buCurrencyVal [FLOAT],
		@biVat [FLOAT],
		@btVatSystem [INT],
		@biVatRatio [FLOAT]
	-- helpfull vars:
	DECLARE
		@SumProfits [FLOAT],
		@Profit [FLOAT],
		@Tmp [FLOAT]
	-- get securiy info:
	SET @c = CURSOR FAST_FORWARD FOR
			SELECT
				[buType],
				[buNumber],
				[buDate],
				[buCustPtr],
				[biGUID],
				[biStorePtr],
				[biMatPtr],
				[biUnity],
				[biQty],
				[biBonusQnt],
				[biUnitPrice],
				[biUnitDiscount],
				[biUnitExtra],
				[biDiscount],
				[biExtra],
				[biVat],
				[btIsInput],
				[btAffectLastPrice],
				[btAffectCostPrice],
				[btAffectCustPrice],
				[btAffectProfit],
				[btDiscAffectCost],
				[btExtraAffectCost],
				[btDiscAffectProfit],
				[btExtraAffectProfit],
				[btIncludeTTCDiffOnSales],
				[buCurrencyVal],
				[buCurrencyPtr],
				[btVATSystem],
				[biVATr]
			FROM
				[dbo].[vwExtended_bi]
			WHERE
				[buGUID] = @GUID
	OPEN @c FETCH FROM @c INTO
								@buType, @buNumber, @buDate, @buCustPtr, @biGUID, @biStorePtr, @biMatPtr, @biUnity,
								@biQty, @biBonusQnt, @biUnitPrice, @biUnitDiscount, @biUnitExtra, @biDiscount, @biExtra, @biVat,
								@btInputBill, @btAffectLastPrice, @btAffectCostPrice, @btAffectCustPrice, @btAffectProfit,
								@btDiscAffectCost, @btExtraAffectCost, @btDiscAffectProfit, @btExtraAffectProfit, @btIncludeTTCOnSales, @buCurrencyVal, @buCurrencyGUID, @btVatSystem, @biVatRatio
	-- prepare @Direction and reset profits:
	-- notice that buDirection couldn't be used in this cotext, as its 0 for unposted bills  
	SET @Direction = ((@Post * 2) - 1) * ((@btInputBill * 2) - 1)
	SET @SumProfits = 0
	-- start @c loop
	WHILE @@FETCH_STATUS = 0
	BEGIN  
		SET @mtQnt = @Direction * (@biQty + @biBonusQnt)  
		-- get mt current statistics:
		SELECT
			@mtQnt =			ISNULL([Qty], 0),
			@mtAvgPrice =		ISNULL([AvgPrice], 0),
			@mtLastPrice =		ISNULL([LastPrice], 0),
			@mtLastPriceDate =	ISNULL([LastPriceDate], 0),
			@mtMaxPrice =		ISNULL([MaxPrice], 0),
			@mtUnit2Fact =		[Unit2Fact],
			@mtUnit3Fact =		[Unit3Fact],
			@mtSecurity =		[Security]
		FROM
			[mt000]
		WHERE
			[GUID] = @biMatPtr

		-- Unity is assumed 1 if non-related units
		SET @UnityFactor = CASE @biUnity WHEN 2 THEN @mtUnit2Fact WHEN 3 THEN @mtUnit3Fact ELSE 1 END
		-- reset UnityFactor:
		IF @UnityFactor = 0 SET @UnityFactor = 1
		-- calc new statistics:
		IF @btAffectCostPrice = 0
			SET @mtQnt = @mtQnt + @Direction * (@biQty + @biBonusQnt)
		ELSE
		BEGIN
			IF @mtQnt > 0
			BEGIN
				SET @mtValue = @mtAvgPrice * @mtQnt + @Direction * @biQty * (@biUnitPrice + (@biUnitExtra * @btExtraAffectCost) - (@biUnitDiscount * @btDiscAffectCost))
				SET @mtQnt = @mtQnt + @Direction * (@biQty + @biBonusQnt)
				IF @mtValue > 0 AND @mtQnt > 0
					SET @mtAvgPrice = @mtValue / @mtQnt
			END
			ELSE -- @mtQnt is <= 0
			BEGIN
				SET @mtValue = @biQty * (@biUnitPrice + @biUnitExtra * @btExtraAffectCost - @biUnitDiscount * @btDiscAffectCost)
				SET @mtQnt = @mtQnt + @Direction * (@biQty + @biBonusQnt)
				SET @Tmp = (@biQty + @biBonusQnt)
				IF @Tmp > 0 AND @mtValue > 0
					SET @mtAvgPrice =  @mtValue / @Tmp
			END
		END 
		-- update mt last price flags, if necessary: -- c_bi is sorted by date:
		IF @btAffectLastPrice <> 0 AND @mtLastPriceDate <= @buDate AND @biUnitPrice <> 0
		BEGIN
			SET @mtLastPrice = @biUnitPrice
			SET @mtLastPriceDate = @buDate
			-- get maxprice:
			IF @mtMaxPrice < @biUnitPrice
				SET @mtMaxPrice = @biUnitPrice
			-- update mt000 
			UPDATE [mt000] SET
				[Qty] = @mtQnt,
				[AvgPrice] = @mtAvgPrice,
				[MaxPrice] = @mtMaxPrice,
				[MaxPrice2] = @mtMaxPrice * @mtUnit2Fact,
				[MaxPrice3] = @mtMaxPrice * @mtUnit3Fact
			WHERE [GUID] = @biMatPtr

		END ELSE -- update mt qty and avgprice:
			UPDATE [mt000] SET  
					[Qty] = @mtQnt,
					[AvgPrice] = @mtAvgPrice
				WHERE [GUID] = @biMatPtr

		UPDATE mt 
		SET  
			mt.[Qty] = ISNULL(mt.[Qty], 0) + @Direction * (@biQty + @biBonusQnt)
		FROM  [mt000] mt INNER JOIN [mt000] m ON m.Parent = mt.GUID
		WHERE m.GUID = @biMatPtr
		
		-- insert / update cp:		
		-- Get Type of TTC Taxes
		IF @btAffectCustPrice <> 0 AND @biUnitPrice <> 0
		BEGIN 
			DECLARE @cpPrice FLOAT;
			SET @cpPrice = 
					(CASE @btVatSystem 
						WHEN 2 THEN 
							CASE @btIncludeTTCOnSales WHEN 1 THEN  @biUnitPrice + @biVat / (CASE @biQty WHEN 0 THEN 1 ELSE @biQty END) ELSE  @biUnitPrice * (1 + (@biVatRatio / 100)) END
						ELSE 
							@biUnitPrice 
					END) * @UnityFactor;

			IF @Post <> 0
			BEGIN
				DECLARE 
					@cpDiscVal FLOAT,
					@cpExtraVal FLOAT,
					@cpCurVal FLOAT,
					@cpCurGuid UNIQUEIDENTIFIER;

				SET @cpDiscVal = CASE @biQty WHEN 0 THEN 0 ELSE @biDiscount / @biQty * @UnityFactor END;
				SET @cpExtraVal = CASE @biQty WHEN 0 THEN 0 ELSE @biExtra / @biQty  * @UnityFactor END;

				SELECT 
					@cpCurVal = CASE WHEN mt.CurrencyGuid = @buCurrencyGUID THEN @buCurrencyVal ELSE dbo.fnGetCurVal(mt.CurrencyGuid, @buDate) END,
					@cpCurGuid = mt.CurrencyGuid
				FROM mt000 AS mt
				WHERE GUID = @biMatPtr

				IF EXISTS(SELECT * FROM cp000 WHERE CustGUID = @buCustPtr AND MatGUID = @biMatPtr AND Unity = @biUnity)
				BEGIN
					UPDATE cp000
					SET
						[Price] =			@cpPrice,
						[DiscValue] =		@cpDiscVal,
						[ExtraValue] =		@cpExtraVal,
						[CurrencyVal] =		@cpCurVal,
						[CurrencyGUID] =	@cpCurGuid,
						[Date] =			@buDate,
						BiGUID =			@biGUID,
						IsTransfered =		0
					WHERE
						Date <= @buDate
						AND CustGUID = @buCustPtr AND MatGUID = @biMatPtr AND Unity = @biUnity
				END
				ELSE BEGIN
					INSERT INTO cp000 ([CustGUID], [MatGUID], [Price], [Unity], [DiscValue], [ExtraValue], [CurrencyVal], [CurrencyGUID], [Date], [BiGUID], [IsTransfered])
					VALUES (@buCustPtr, @biMatPtr, @cpPrice, @biUnity, @cpDiscVal, @cpExtraVal, @cpCurVal, @cpCurGuid, @buDate, @biGUID, 0);
				END
			END
			ELSE
			BEGIN
				DELETE cp000 WHERE BiGUID = @biGUID
				IF @@ROWCOUNT > 0
					EXEC prcCP_Recalc_One @buCustPtr, @biMatPtr, @biUnity
			END
		END

		-- put bi000 profits, and accomulate bu's SumProfits:
		--IF @btAffectProfit <> 0
		BEGIN
			SET @Profit = [dbo].[fnGetProfit]( @biQty, @biBonusQnt, @mtAvgPrice, @biUnitPrice, @biUnitExtra, @biUnitDiscount, @btExtraAffectProfit, @btDiscAffectProfit)
			SET @SumProfits = @SumProfits + @Profit
			UPDATE [bi000] 
			SET 
				[Profits] = @Profit,
				[UnitCostPrice] = ISNULL(@mtAvgPrice, 0)
			WHERE [GUID] = @biGUID
		END

		FETCH FROM @c INTO
			@buType, @buNumber, @buDate, @buCustPtr, @biGUID, @biStorePtr, @biMatPtr, @biUnity,
			@biQty, @biBonusQnt, @biUnitPrice, @biUnitDiscount, @biUnitExtra, @biDiscount, @biExtra, @biVat,
			@btInputBill, @btAffectLastPrice, @btAffectCostPrice, @btAffectCustPrice, @btAffectProfit,
			@btDiscAffectCost, @btExtraAffectCost, @btDiscAffectProfit, @btExtraAffectProfit, @btIncludeTTCOnSales, @buCurrencyVal, @buCurrencyGUID, @btVatSystem, @biVatRatio
	END CLOSE @c DEALLOCATE @c -- @c loop

	IF @btAffectLastPrice <> 0 
	BEGIN
		UPDATE mt
		SET 
			DisableLastPrice =	CASE WHEN (fn.LastPriceDate IS NULL) OR (fn.FromHistory = 1) THEN 0 ELSE 1 END,
			[LastPriceDate] =	ISNULL(fn.LastPriceDate, mt.[LastPriceDate]),
			[LastPrice] =		ISNULL(fn.LastPrice, mt.[LastPrice]),
			[LastPrice2] =		ISNULL(fn.LastPrice * Unit2Fact, mt.[LastPrice2]),
			[LastPrice3] =		ISNULL(fn.LastPrice * Unit3Fact, mt.[LastPrice3]),
			[LastPriceCurVal] = ISNULL(fn.LastPriceCurVal, mt.LastPriceCurVal)
		FROM 
			mt000 mt
			OUTER APPLY dbo.fnMaterial_GetLastPrice(mt.GUID) fn
		WHERE EXISTS (SELECT * FROM bi000 WHERE ParentGUID = @GUID AND MatGUID = mt.GUID)
	END

	UPDATE ms000 SET [Qty] = ms.[Qty] + b.Qty
	FROM 
		ms000 ms 
		INNER JOIN (
			SELECT bi.StoreGUID AS StoreGUID, bi.MatGUID AS MatGUID, SUM(@Direction * (bi.Qty + bi.BonusQnt)) AS Qty 
			FROM 
				bi000 bi 
				INNER JOIN bu000 bu ON bu.GUID = bi.ParentGUID
			WHERE bu.GUID = @GUID GROUP BY bi.StoreGUID, bi.MatGUID) b ON ms.StoreGUID = b.StoreGUID AND ms.MatGUID = b.MatGUID
	
	INSERT INTO ms000 ([StoreGUID], [MatGUID], [Qty])
	SELECT 
		b.StoreGUID,
		b.MatGUID,
		b.Qty
	FROM 		
		(SELECT 
			bi.StoreGUID AS StoreGUID, bi.MatGUID AS MatGUID, SUM(@Direction * (bi.Qty + bi.BonusQnt)) AS Qty 
		FROM 
			bi000 bi 
			INNER JOIN bu000 bu ON bu.GUID = bi.ParentGUID
		WHERE bu.GUID = @GUID group by bi.StoreGUID, bi.MatGUID) b 		
		LEFT JOIN ms000 ms ON ms.StoreGUID = b.StoreGUID AND ms.MatGUID = b.MatGUID
	WHERE ms.GUID IS NULL

	-- update bu000 profits:
	UPDATE [bu000] SET [Profits] = @SumProfits WHERE [GUID] = @GUID
	-- study the need of prcBill_rePosting flag 100:  
	IF EXISTS(SELECT * FROM [bu000] WHERE [Date] > @buDate OR ([Date] = @buDate AND [Number] > @buNumber AND [TypeGUID] = @buType))
		EXEC [prcFlag_set] 100 -- Recalc profits
###########################################################################
CREATE PROC prcBill_Post1
	@buGUID	[UNIQUEIDENTIFIER],
	@bPost	[BIT]
AS 
	SET NOCOUNT ON 

	UPDATE [bu000] SET [IsPosted] = @bPost WHERE [guid] = @buGUID AND [IsPosted] <> @bPost
###########################################################################
#END
