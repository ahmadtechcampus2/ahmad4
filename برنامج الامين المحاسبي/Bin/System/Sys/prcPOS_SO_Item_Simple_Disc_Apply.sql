################################################################################
CREATE PROC prcPOS_SO_Simple_Disc_Apply
	@OrderGUID UNIQUEIDENTIFIER, 
	@SO_GUID UNIQUEIDENTIFIER, 
	@SO_Qty FLOAT,
	@SO_Discount FLOAT,
	@SO_DiscountType INT,
	@SO_MatGUID UNIQUEIDENTIFIER,
	@SO_GroupGUID UNIQUEIDENTIFIER,
	@SO_Unit INT,
	@SO_ApplyOnce BIT,
	@SO_CheckExactQty BIT,
	@SO_IsIncludeGroups BIT
AS 
	SET NOCOUNT ON

	DECLARE 
		@ItemGUID UNIQUEIDENTIFIER,
		@ItemMatGUID UNIQUEIDENTIFIER,
		@ItemGroupGUID UNIQUEIDENTIFIER,
		@ItemQty MONEY,
		@ItemUnitFact MONEY,
		@SO_UnitFact MONEY,
		@IsApplyed BIT

	DECLARE @Items CURSOR 
	
	SET @Items = CURSOR FAST_FORWARD FOR 
	SELECT 
		oi.GUID, oi.MatID, mt.GroupGUID, oi.Qty, 
		CASE oi.Unity 
			WHEN 2 THEN CASE mt.Unit2Fact WHEN 0 THEN 1 ELSE mt.Unit2Fact END
			WHEN 3 THEN CASE mt.Unit3Fact WHEN 0 THEN 1 ELSE mt.Unit3Fact END
			ELSE 1
		END,
		CASE @SO_Unit
			WHEN 2 THEN CASE mt.Unit2Fact WHEN 0 THEN 1 ELSE mt.Unit2Fact END
			WHEN 3 THEN CASE mt.Unit3Fact WHEN 0 THEN 1 ELSE mt.Unit3Fact END
			ELSE 1
		END			
	FROM 
		POSOrderItemstemp000 oi
		INNER JOIN mt000 mt ON oi.MatID = mt.GUID 
	WHERE 
		ParentID = @OrderGUID 
		AND 
		ISNULL(oi.SpecialOfferID, 0x0) = 0x0
		AND 
		@SO_MatGUID = 0x0 OR mt.GUID = @SO_MatGUID
		AND 
		(
			@SO_GroupGUID = 0x0
			OR 
			@SO_GroupGUID = mt.GroupGUID
			OR 
			(@SO_GroupGUID != 0x0  AND @SO_IsIncludeGroups = 1)
		)
	ORDER BY oi.Number

	OPEN @Items FETCH NEXT FROM @Items INTO @ItemGUID, @ItemMatGUID, @ItemGroupGUID, @ItemQty, @ItemUnitFact, @SO_UnitFact
	WHILE @@FETCH_STATUS = 0 AND ((@SO_ApplyOnce = 0) OR (NOT EXISTS(SELECT 1 FROM POSOrderItemstemp000 WHERE ParentID = @OrderGUID AND SpecialOfferID = @SO_GUID)))
	BEGIN 
		SET @IsApplyed = 0

		IF @SO_MatGUID != 0x0 AND @ItemMatGUID = @SO_MatGUID AND @OrderItemQty >= @SO_Qty * @SO_UnitFact
			SET @IsApplyed = 1
		ELSE IF @SO_GroupGUID != 0x0 AND @OrderItemQty >= @SO_Qty * @SO_UnitFact
		BEGIN
			IF @ItemGroupGUID = @SO_GroupGUID
				SET @IsApplyed = 1
			IF @IsApplyed = 0 AND @SO_IsIncludeGroups = 1
			BEGIN 
				IF EXISTS(SELECT 1 FROM [dbo].[fnGetGroupParents](@ItemGroupGUID) WHERE [GUID] = @SO_GroupGUID)
					SET @IsApplyed = 1
			END
		END

		IF @IsApplyed = 1
		BEGIN 
			UPDATE POSOrderItemstemp000
			SET 
				SpecialOfferID = @SO_GUID,
				Discount = 
					CASE @SO_DiscountType 
						WHEN 0 THEN (@SO_Discount / 100) * Price * 
							CASE 
								WHEN @SO_ApplyOnce = 1 THEN @SO_Qty / @SO_UnitFact 
								WHEN @SO_CheckExactQty = 1 THEN ((@ItemQty - (CAST(CAST(@ItemQty AS MONEY) % CAST(@SO_Qty AS MONEY) AS FLOAT))) / @ItemUnitFact)
								ELSE @ItemQty / @ItemUnitFact 
							END
						ELSE @SO_Discount * 
							CASE 
								WHEN @SO_ApplyOnce = 1 THEN 1 
								WHEN @SO_CheckExactQty = 1 THEN ((@ItemQty - (CAST(CAST(@ItemQty AS MONEY) % CAST(@SO_Qty AS MONEY) AS FLOAT))) / @ItemUnitFact) / @SO_Qty
								ELSE @ItemQty / @ItemUnitFact 
							END
					END
			OUTPUT inserted.Guid, 1, 0x0 INTO #OfferedItems
			WHERE Guid = @ItemGUID 
		END		 
		FETCH NEXT FROM @Items INTO @ItemGUID, @ItemMatGUID, @ItemGroupGUID, @ItemQty, @ItemUnitFact, @SO_UnitFact
	END CLOSE @Items DEALLOCATE @Items
####################################################################################
#END