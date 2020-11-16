################################################################################
CREATE PROC prcPOS_SO_Item_Simple_Offered_Apply
	@OrderGUID UNIQUEIDENTIFIER, 
	@SO_GUID UNIQUEIDENTIFIER, 
	@SO_Qty FLOAT,
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
		@ItemBillGUID UNIQUEIDENTIFIER,
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
		END,
		oi.BillType
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

	OPEN @Items FETCH NEXT FROM @Items INTO @ItemGUID, @ItemMatGUID, @ItemGroupGUID, @ItemQty, @ItemUnitFact, @SO_UnitFact, @ItemBillGUID
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
			DECLARE @ItemSOGroup INT
			SET @ItemSOGroup = ISNULL((SELECT MAX(SOGroup) FROM POSOrderItemsTemp000 WHERE [ParentID] = @OrderGUID), 0) + 1

			UPDATE POSOrderItemstemp000
			SET 
				SpecialOfferID = @SO_GUID,
				SOGroup = @ItemSOGroup
			OUTPUT inserted.Guid, 1, 0x0 INTO #OfferedItems
			WHERE Guid = @ItemGUID

			DECLARE @Index INT 
			SET @Index = (SELECT MAX(Number) FROM POSOrderItemsTemp000 
				WHERE [ParentID] = @OrderGUID AND SOGroup = @ItemSOGroup AND OfferedItem != 1 AND SpecialOfferID = @SO_GUID)
		
			DECLARE @ParentItemGUID UNIQUEIDENTIFIER = 0X0
			IF ISNULL(@Index, 0) != 0
			BEGIN			
				SET @ParentItemGUID = (SELECT TOP 1 GUID FROM POSOrderItemsTemp000 
					WHERE [ParentID] = @OrderGUID AND SOGroup = @ItemSOGroup AND Number = @Index)
			
				UPDATE POSOrderItemsTemp000 
				SET Number = Number + (SELECT COUNT(*) FROM OfferedItems000 WHERE ParentID = @SpecialOfferGUID)
				WHERE Number > @Index AND [ParentID] = @OrderGUID
				IF @@ROWCOUNT = 0
					SET @ParentItemGUID = 0x0
			END

			EXEC prcPOS_SO_AddOrderOfferedItems 
					@Index, @OrderGUID, @ItemBillGUID, @ItemQty, @SO_GUID, 
					@SO_Qty, @SO_ApplyOnce, @ItemSOGroup, @ParentItemGUID
		END		 
		FETCH NEXT FROM @Items INTO @ItemGUID, @ItemMatGUID, @ItemGroupGUID, @ItemQty, @ItemUnitFact, @SO_UnitFact, @ItemBillGUID
	END CLOSE @Items DEALLOCATE @Items
####################################################################################
#END
