###############################################################################
CREATE PROC prcSO_CheckBillContracts
	@BillDate			DATETIME,
	@BillTypeGuid		UNIQUEIDENTIFIER,
	@BillCostGuid		UNIQUEIDENTIFIER,
	@BillCustGuid		UNIQUEIDENTIFIER,
	@BillAccGuid		UNIQUEIDENTIFIER,
	@biMatGuid			UNIQUEIDENTIFIER,
	@biQty				FLOAT,
	@biUnit				INT,
	@biUnitFactor		FLOAT,
	@biPrice			FLOAT
AS
		
	SET NOCOUNT ON
	--- Get all contract Offers applicaple for the bill
	CREATE TABLE #SO( GUID UNIQUEIDENTIFIER)
	INSERT INTO #SO EXEC prcSO_GetBillContracts @BillDate, @BillTypeGuid, @BillCostGuid, @BillCustGuid, @BillAccGuid
	--- Check applicable contract offer for the mat
	IF NOT EXISTS(SELECT * FROM #SO)
		RETURN

	CREATE TABLE #OfferMats( mtGuid	UNIQUEIDENTIFIER, Security INT)	
	CREATE TABLE #SOResult(
		Price		FLOAT,
		Bonus		FLOAT,
		Discount	FLOAT	
	)	
	
	DECLARE	@C_SO			CURSOR,
			@SOGuid			UNIQUEIDENTIFIER,
			@SOItemsGuid	UNIQUEIDENTIFIER,
			@ItemType		INT,
			@MatGuid		UNIQUEIDENTIFIER,
			@GroupGuid		UNIQUEIDENTIFIER,
			@CondGuid		UNIQUEIDENTIFIER,
			@ItemQty		Float,
			@ItemUnit		INT,
			@ItemUnitFactor	FLOAT,
			@ItemBonusQty	Float,
			@ItemPriceKind	INT,
			@ItemPriceType	INT,
			@ItemPrice		Float,
			@ItemDiscountValue		Float,
			@ItemDiscountRatio		Float,
			@SOOfferedGuid			UNIQUEIDENTIFIER,
			@SOOfferedNotes			NVARCHAR(250),
			@SOOfferedPrice			FLOAT,
			@SOOfferedBonus			FLOAT,
			@SOOfferedDiscountRatio	FLOAT,
			@SOOfferedDiscountValue	FLOAT,
			@biUnitQty		FLOAT,
			@ItemUnitQty	FLOAT,
			@Factor			FLOAT
			
	SET @C_SO = CURSOR FAST_FORWARD FOR 
		SELECT 
			so.Guid AS SOGuid, ff.Name AS SONotes, it.Guid AS SOItemsGuid, it.ItemType, 
			CASE it.ItemType WHEN 0 THEN it.ItemGuid ELSE 0x00 END AS MatGuid,
			CASE it.ItemType WHEN 1 THEN it.ItemGuid ELSE 0x00 END AS GroupGuid,
			CASE it.ItemType WHEN 2 THEN it.ItemGuid ELSE 0x00 END AS CondGuid,
			it.Quantity, it.Unit, it.BonusQuantity, it.PriceKind, it.PriceType, it.Price, it.Discount, it.DiscountRatio
		FROM 
			#SO	AS so
			INNER JOIN SpecialOffers000 AS ff ON ff.Guid = so.Guid
			INNER JOIN SOItems000 AS it ON it.SpecialOfferGuid = so.Guid
		ORDER BY
			so.Guid, it.Number
	OPEN @C_SO 
	FETCH FROM @C_SO INTO @SOGuid, @SOOfferedNotes, @SOItemsGuid, @ItemType, @MatGuid, @GroupGuid, @CondGuid, @ItemQty, @ItemUnit, @ItemBonusQty, @ItemPriceKind, @ItemPriceType, @ItemPrice, @ItemDiscountValue, @ItemDiscountRatio
	WHILE @@FETCH_STATUS = 0
	BEGIN
		DELETE #OfferMats
		INSERT INTO #OfferMats EXEC [prcGetMatsList] @MatGuid, @GroupGuid, -1, @CondGuid
		IF EXISTS (SELECT * FROM #OfferMats WHERE mtGuid = @biMatGuid)
		BEGIN
			-- Check mat in this contract item
			SELECT @ItemUnitFactor = CASE @ItemUnit	WHEN 2 THEN Unit2Fact WHEN 3 THEN Unit3Fact WHEN 4 THEN CASE DefUnit WHEN 2 THEN Unit2Fact WHEN 3 THEN Unit3Fact ELSE 1 END ELSE 1 END FROM mt000 WHERE Guid = @biMatGuid	
			SET @ItemUnitQty = @ItemQty * @ItemUnitFactor
			SET @biUnitQty = @biQty * @biUnitFactor
			SET @Factor = (CASE @ItemUnitFactor WHEN 0 THEN 1 ELSE @biUnitFactor / @ItemUnitFactor END)
			IF @biUnitQty >= @ItemUnitQty 
			BEGIN
				-- Set Offer Guid
				SET @SOOfferedGuid = @SOItemsGuid
				-- Set Price
				IF @ItemPriceKind = 0			-- PK_NONE: Don't Change the price
					SET @SOOfferedPrice = @biPrice
				ELSE IF @ItemPriceKind = 1		-- PK_ZERO: The price is zero
					SET @SOOfferedPrice = 0
				ELSE IF @ItemPriceKind = 2		-- PK_SPECIFIED
					SET @SOOfferedPrice = @ItemPrice * @Factor
				ELSE IF @ItemPriceKind = 3		-- PK_PRICETYPE
				BEGIN
					IF @ItemPriceType = 2048	-- Customer Price
						SELECT @ItemPriceType = DefPrice FROM cu000 WHERE Guid = @BillCustGuid
					SET @biUnit = @biUnit - 1 	
					SELECT @SOOfferedPrice = Price FROM dbo.fnExtended_mt(@ItemPriceType, 0, @biUnit) WHERE mtGuid = @biMatGuid	
				END	
				-- Set Bonus
				IF @ItemQty <> 0
					SET @SOOfferedBonus = @ItemBonusQty * (CAST(@biUnitQty AS INT)/CAST(@ItemUnitQty AS INT)) * (1 / @Factor)
				ELSE	
					SET @SOOfferedBonus = @ItemBonusQty 
				-- Set Discount
				DECLARE @ApplyCount INT
				SET @ApplyCount = @biUnitQty / CASE @ItemUnitQty WHEN 0 THEN 1 ELSE @ItemUnitQty END

				IF @SOOfferedPrice <> 0 AND @biUnitQty <> 0
				BEGIN
					SET @SOOfferedDiscountRatio = @ItemDiscountRatio + (((@ItemDiscountValue * @ApplyCount) / (@SOOfferedPrice * (CASE @biUnit WHEN 1 THEN @biUnitQty ELSE @biUnitQty / @biUnitFactor END)))* 100)

					SET @SOOfferedDiscountValue = (@SOOfferedDiscountRatio / 100) * (@SOOfferedPrice * (CASE @biUnit WHEN 1 THEN @biUnitQty ELSE @biUnitQty / @biUnitFactor END))
				END
				ELSE
					SET @SOOfferedDiscountRatio = @ItemDiscountRatio
				-- Exit While
				BREAK
			END
		END
	
		FETCH FROM @C_SO INTO @SOGuid, @SOOfferedNotes, @SOItemsGuid, @ItemType, @MatGuid, @GroupGuid, @CondGuid, @ItemQty, @ItemUnit, @ItemBonusQty, @ItemPriceKind, @ItemPriceType, @ItemPrice, @ItemDiscountValue, @ItemDiscountRatio
	END		
	CLOSE @C_SO 
	DEALLOCATE @C_SO			
			
	SELECT 
		ISNULL(@SOOfferedGuid, 0x00)			AS SOGuid,
		ISNULL(@SOOfferedNotes, '')				AS SOOfferedNotes,
		ISNULL(@SOOfferedPrice, -1)				AS SOOfferedPrice, 
		ISNULL(@SOOfferedBonus, -1)				AS SOOfferedBonus, 
		ISNULL(@SOOfferedDiscountRatio, -1)		AS SOOfferedDiscountRatio, 
		ISNULL(@SOOfferedDiscountValue, -1)		AS SOOfferedDiscountValue
	
/*
EXEC [prcSO_CheckBillContracts] '3/26/2011', 'ecdd9382-1bfa-42e2-8616-fba223989577', '00000000-0000-0000-0000-000000000000', '51a873f5-a461-474f-8b76-cba41a62e350', '199f2d4c-b9e0-48c6-9291-d974d82882d0', 'ded64906-33c8-489c-8d7c-97ed39294e99', 10.000000, 1, 1.000000, 10.000000
*/		
################################################################################
#END
