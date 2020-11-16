################################################################################
CREATE PROC prcPOS_SO_Order_Simple_Disc_Apply
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
	@SO_IsIncludeGroups BIT,
	@IsReturned BIT = 0
AS 
	SET NOCOUNT ON

	DECLARE 
		@ItemGUID UNIQUEIDENTIFIER,
		@ItemMatGUID UNIQUEIDENTIFIER,
		@ItemGroupGUID UNIQUEIDENTIFIER,
		@ItemQty MONEY,
		@ItemUnitFact MONEY,
		@SO_UnitFact MONEY,
		@IsApplyed BIT,
		@ItemCompositionParentGuid UNIQUEIDENTIFIER

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
			WHEN 1 THEN CASE mt.Unit2Fact WHEN 0 THEN 1 ELSE mt.Unit2Fact END
			WHEN 2 THEN CASE mt.Unit3Fact WHEN 0 THEN 1 ELSE mt.Unit3Fact END
			ELSE 1
		END,
		mt.Parent
	FROM 
		dbo.fnPOS_SO_GetAvailableOrderItems(@OrderGUID, @IsReturned) oi
		INNER JOIN mt000 mt ON oi.MatID = mt.GUID 
	WHERE 
		ParentID = @OrderGUID 
		AND 
		ISNULL(oi.SpecialOfferID, 0x0) = 0x0
		AND 
		(@SO_MatGUID = 0x0 OR mt.GUID = @SO_MatGUID OR mt.Parent = @SO_MatGUID)
		AND 
		(
			@SO_GroupGUID = 0x0
			OR 
			@SO_GroupGUID = mt.GroupGUID
			OR 
			(@SO_GroupGUID != 0x0 AND @SO_IsIncludeGroups = 1)
			OR 
			(@SO_GroupGUID != 0x0 AND EXISTS(SELECT * FROM gr000 WHERE GUID = @SO_GroupGUID AND Kind = 1))
		)		
	ORDER BY oi.Number

	OPEN @Items FETCH NEXT FROM @Items INTO @ItemGUID, @ItemMatGUID, @ItemGroupGUID, @ItemQty, @ItemUnitFact, @SO_UnitFact, @ItemCompositionParentGuid 
	WHILE @@FETCH_STATUS = 0 AND ((@SO_ApplyOnce = 0) OR (NOT EXISTS(SELECT 1 FROM dbo.fnPOS_SO_GetAvailableOrderItems(@OrderGUID, @IsReturned) WHERE SpecialOfferID = @SO_GUID)))
	BEGIN 
		SET @IsApplyed = 0

		IF @SO_MatGUID != 0x0 AND (@ItemMatGUID = @SO_MatGUID OR (ISNULL(@ItemCompositionParentGuid,0x0) <> 0x0 AND @ItemCompositionParentGuid = @SO_MatGUID)) AND @ItemQty * @ItemUnitFact >= @SO_Qty * @SO_UnitFact
			SET @IsApplyed = 1
		ELSE IF @SO_GroupGUID != 0x0 AND @ItemQty * @ItemUnitFact >= @SO_Qty * @SO_UnitFact
		BEGIN
			IF @ItemGroupGUID = @SO_GroupGUID
				SET @IsApplyed = 1
			IF @IsApplyed = 0 
			BEGIN
				IF EXISTS(SELECT * FROM gr000 WHERE GUID = @SO_GroupGUID AND [Kind] = 1)
				BEGIN 
					IF dbo.fnIsMatfound(@ItemMatGUID, @SO_GroupGUID) = 1
						SET @IsApplyed = 1
				END 
				ELSE IF @SO_IsIncludeGroups = 1
				BEGIN 
					IF EXISTS(SELECT 1 FROM [dbo].[fnGetGroupParents](@ItemGroupGUID) WHERE [GUID] = @SO_GroupGUID) 						
						SET @IsApplyed = 1
				END 
			END
		END

		IF @IsApplyed = 1
		BEGIN 
			UPDATE POSOrderItemsTemp000
			SET 
				SpecialOfferID = @SO_GUID,
				Discount = 
					CASE @SO_DiscountType 
						WHEN 0 THEN (@SO_Discount / 100) * Price * 
							CASE 
								WHEN @SO_ApplyOnce = 1 THEN @SO_Qty * @SO_UnitFact / @ItemUnitFact
								WHEN @SO_CheckExactQty = 1 THEN (((@ItemQty * @ItemUnitFact) - (CAST(CAST((@ItemQty * @ItemUnitFact) AS MONEY) % CAST(@SO_Qty AS MONEY) AS FLOAT))) / @ItemUnitFact)
								ELSE @ItemQty
							END
						ELSE @SO_Discount * 
							CASE 
								WHEN @SO_ApplyOnce = 1 THEN @SO_Qty 
								WHEN @SO_CheckExactQty = 1 THEN (((@ItemQty * @ItemUnitFact) - (CAST(CAST((@ItemQty * @ItemUnitFact) AS MONEY) % CAST(@SO_Qty AS MONEY) AS FLOAT))) / @SO_UnitFact)
								ELSE @ItemQty * @ItemUnitFact / @SO_UnitFact
							END
					END,
				SOGroup = ISNULL((SELECT MAX(SOGroup) FROM POSOrderItemsTemp000 WHERE [ParentID] = @OrderGUID), 0) + 1
			OUTPUT inserted.Guid, 1, 0x0 INTO #OfferedItems
			WHERE Guid = @ItemGUID 
		END		 
		FETCH NEXT FROM @Items INTO @ItemGUID, @ItemMatGUID, @ItemGroupGUID, @ItemQty, @ItemUnitFact, @SO_UnitFact, @ItemCompositionParentGuid
	END CLOSE @Items DEALLOCATE @Items
####################################################################################
#END