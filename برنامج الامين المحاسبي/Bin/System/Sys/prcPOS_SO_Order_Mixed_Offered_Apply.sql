################################################################################
CREATE PROC prcPOS_SO_Order_Mixed_Offered_Apply
	@OrderGUID UNIQUEIDENTIFIER, 
	@SO_Type INT,
	@SO_GUID UNIQUEIDENTIFIER, 
	@SO_Qty MONEY,
	@SO_Discount MONEY,
	@SO_DiscountType INT,
	@SO_MatGUID UNIQUEIDENTIFIER,
	@SO_GroupGUID UNIQUEIDENTIFIER,
	@SO_Unit INT,
	@SO_ApplyOnce BIT,
	@SO_CheckExactQty BIT,
	@SO_IsIncludeGroups BIT,
	@SO_Condition INT,
	@SO_AccountGUID UNIQUEIDENTIFIER,
	@SO_MatAccountGUID UNIQUEIDENTIFIER,
	@SO_DiscAccountGUID UNIQUEIDENTIFIER,
	@SO_DivDiscount INT,
	@SO_Mode INT,
	@IsReturned BIT = 0
AS 
	SET NOCOUNT ON

	IF @SO_Condition != 0
	BEGIN 
		IF (SELECT SUM(ItemQty * ItemUnitFact / SO_UnitFact) FROM #SO_OrderItems ) - @SO_QTY > -0.001
		BEGIN 
			IF @SO_ApplyOnce = 1
			BEGIN 
				DECLARE @stop_1 BIT = 0
				DECLARE 
					@items_1 CURSOR, 
					@GUID_1 UNIQUEIDENTIFIER,
					@qty_1 MONEY,
					@ItemBillGUID_1 UNIQUEIDENTIFIER,
					@ItemUnitFact_1 MONEY,
					@SOUnitFact_1 MONEY,
					@AcheivedQty_1 MONEY,
					@ItemSOGroup_1 INT

				SET @ItemSOGroup_1 = ISNULL((SELECT MAX(SOGroup) FROM POSOrderItemsTemp000 WHERE [ParentID] = @OrderGUID), 0) + 1
				SET @AcheivedQty_1 = 0 

				SET @items_1 = CURSOR FAST_FORWARD FOR SELECT ItemGUID, ItemQty, ItemUnitFact, SO_UnitFact, ItemBillGUID FROM #SO_OrderItems ORDER BY ItemNumber
				OPEN @items_1 FETCH NEXT FROM @items_1 INTO @GUID_1, @qty_1, @ItemUnitFact_1, @SOUnitFact_1, @ItemBillGUID_1
				WHILE @@FETCH_STATUS = 0 AND @stop_1 = 0
				BEGIN 
					SET @AcheivedQty_1 = @AcheivedQty_1 + (@qty_1 * @ItemUnitFact_1 / @SOUnitFact_1)
					IF @AcheivedQty_1 - @SO_Qty > -0.001
						SET @stop_1 = 1

					UPDATE POSOrderItemsTemp000
					SET 
						SpecialOfferID = @SO_GUID,
						SOGroup = @ItemSOGroup_1
					OUTPUT inserted.GUID, 1, 0x0 INTO #OfferedItems
					FROM POSOrderItemsTemp000 ori
					WHERE GUID = @GUID_1					
					
					IF @stop_1 = 1
					BEGIN
						DECLARE @Index_1 INT 
						SET @Index_1 = (SELECT MAX(Number) FROM POSOrderItemsTemp000 
							WHERE [ParentID] = @OrderGUID AND SOGroup = @ItemSOGroup_1 AND OfferedItem != 1 AND SpecialOfferID = @SO_GUID)
		
						DECLARE @ParentItemGUID_1 UNIQUEIDENTIFIER = 0X0
						IF ISNULL(@Index_1, 0) != 0
						BEGIN			
							SET @ParentItemGUID_1 = (SELECT TOP 1 GUID FROM POSOrderItemsTemp000 
								WHERE [ParentID] = @OrderGUID AND SOGroup = @ItemSOGroup_1 AND Number = @Index_1)
			
							UPDATE POSOrderItemsTemp000 
							SET Number = Number + (SELECT COUNT(*) FROM OfferedItems000 WHERE ParentID = @SO_GUID)
							WHERE Number > @Index_1 AND [ParentID] = @OrderGUID
							IF @@ROWCOUNT = 0
								SET @ParentItemGUID_1 = 0x0
						END

						EXEC prcPOS_SO_AddOrderOfferedItems 
								@Index_1, @OrderGUID, @ItemBillGUID_1, @AcheivedQty_1, @SO_GUID, 
								@SO_Qty, @SO_ApplyOnce, @ItemSOGroup_1, @ParentItemGUID_1, @IsReturned
					END

					FETCH NEXT FROM @items_1 INTO @GUID_1, @qty_1, @ItemUnitFact_1, @SOUnitFact_1, @ItemBillGUID_1
				END CLOSE @items_1 DEALLOCATE @items_1 

			END 
			ELSE BEGIN 
				DECLARE @stop_2 BIT = 0
				DECLARE 
					@items_2 CURSOR, 
					@GUID_2 UNIQUEIDENTIFIER,
					@qty_2 MONEY,
					@ItemUnitFact_2 MONEY,
					@SOUnitFact_2 MONEY,
					@AcheivedQty_2 MONEY,
					@TargetQty_2 MONEY,
					@SumItems_2 MONEY,
					@ItemBillGUID_2 UNIQUEIDENTIFIER,
					@ItemSOGroup_2 INT,
					@count_2 INT,
					@last_count INT

				SET @SumItems_2 = (SELECT SUM(ItemQty * ItemUnitFact / SO_UnitFact) FROM #SO_OrderItems)
				SET @TargetQty_2 = @SumItems_2 - (@SumItems_2 % CAST(@SO_Qty AS MONEY))
				SET @AcheivedQty_2 = 0 
				SET @count_2 = 1
				SET @last_count = 0

				SET @ItemSOGroup_2 = ISNULL((SELECT MAX(SOGroup) FROM POSOrderItemsTemp000 WHERE [ParentID] = @OrderGUID), 0) + 1

				SET @items_2 = CURSOR FAST_FORWARD FOR SELECT ItemGUID, ItemQty, ItemUnitFact, SO_UnitFact, ItemBillGUID FROM #SO_OrderItems ORDER BY ItemNumber
				OPEN @items_2 FETCH NEXT FROM @items_2 INTO @GUID_2, @qty_2, @ItemUnitFact_2, @SOUnitFact_2, @ItemBillGUID_2
				WHILE @@FETCH_STATUS = 0 AND @stop_2 = 0
				BEGIN 
					SET @AcheivedQty_2 = @AcheivedQty_2 + (@qty_2 * @ItemUnitFact_2 / @SOUnitFact_2)
					IF @AcheivedQty_2 - @TargetQty_2 > -0.001
						SET @stop_2 = 1

					UPDATE POSOrderItemsTemp000
					SET 
						SpecialOfferID = @SO_GUID,
						SOGroup = @ItemSOGroup_2
					OUTPUT inserted.GUID, 1, 0x0 INTO #OfferedItems
					FROM POSOrderItemsTemp000 ori
					WHERE GUID = @GUID_2					

					SET @count_2 = CASE @SO_Qty WHEN 0 THEN 0 ELSE CAST(@AcheivedQty_2 AS FLOAT) / CAST(@SO_Qty AS FLOAT) END 
					IF @count_2 > @last_count
					BEGIN
						DECLARE @Index_2 INT 
						SET @Index_2 = (SELECT MAX(Number) FROM POSOrderItemsTemp000 
							WHERE [ParentID] = @OrderGUID AND SOGroup = @ItemSOGroup_2 /*AND OfferedItem != 1*/ AND SpecialOfferID = @SO_GUID)
		
						DECLARE @ParentItemGUID_2 UNIQUEIDENTIFIER = 0X0
						IF ISNULL(@Index_2, 0) != 0
						BEGIN			
							SET @ParentItemGUID_2 = (SELECT TOP 1 GUID FROM POSOrderItemsTemp000 
								WHERE [ParentID] = @OrderGUID AND SOGroup = @ItemSOGroup_2 AND Number = @Index_2)

							UPDATE oi
							SET Number = h.Number							
							FROM 
								POSOrderItemsTemp000 oi
								INNER JOIN (SELECT GUID, ROW_NUMBER() OVER(ORDER BY Number, SOGroup) AS Number FROM POSOrderItemsTemp000 WHERE [ParentID] = @OrderGUID) h 
									ON h.GUID = oi.GUID
							WHERE oi.Number != h.Number
			
							UPDATE POSOrderItemsTemp000 
							SET Number = Number + (SELECT COUNT(*) FROM OfferedItems000 WHERE ParentID = @SO_GUID)
							WHERE Number > @Index_2 AND [ParentID] = @OrderGUID
							IF @@ROWCOUNT = 0
								SET @ParentItemGUID_2 = 0x0
						END

						DECLARE @cnt_2 INT 
						SET @cnt_2 = (@count_2 - @last_count) * @SO_Qty
						EXEC prcPOS_SO_AddOrderOfferedItems 
								@Index_2, @OrderGUID, @ItemBillGUID_2, @cnt_2, @SO_GUID, 
								@SO_Qty, @SO_ApplyOnce, @ItemSOGroup_2, @ParentItemGUID_2, @IsReturned

						SET @last_count = @count_2
						SET @ItemSOGroup_2 = @ItemSOGroup_2 + 1
					END

					FETCH NEXT FROM @items_2 INTO @GUID_2, @qty_2, @ItemUnitFact_2, @SOUnitFact_2, @ItemBillGUID_2
				END CLOSE @items_2 DEALLOCATE @items_2 					
			END 
		END
	END ELSE BEGIN -- @SO_Condition = 0
		SELECT
			SOD_GUID,
			MAX(SOD_Qty) AS SOD_Qty,
			MAX(SOD_Unit) AS SOD_Unit,
			CAST(SUM(ItemQty * ItemUnitFact / SOD_UnitFact) AS MONEY) AS SumItemQty,
			CAST(0 AS MONEY) AS AcheivedQty,
			CAST(0 AS MONEY) AS TargetQty,
			CAST(0 AS INT) AS CountQty
		INTO #SO_SumOrderItems
		FROM 
			#SO_OrderItems i 
		GROUP BY 
			SOD_GUID

		IF NOT EXISTS (
			SELECT * FROM 				
				SpecialOfferDetails000 d 
				LEFT JOIN #SO_SumOrderItems i ON d.GUID = i.SOD_GUID
			WHERE d.ParentID = @SO_GUID AND ((i.SOD_GUID IS NULL) OR (d.Qty > i.SumItemQty))) 
		BEGIN 
			IF @SO_ApplyOnce = 1
			BEGIN
				DECLARE @stop_3 BIT = 0
				DECLARE 
					@items_3 CURSOR, 
					@GUID_3 UNIQUEIDENTIFIER,
					@qty_3 MONEY,
					@SOD_GUID_3 UNIQUEIDENTIFIER,
					@SOD_QTY_3 MONEY,
					@AcheivedQty_3 MONEY,
					@ItemSOGroup_3 INT,
					@ItemUnitFact_3 MONEY,
					@SODUnitFact_3 MONEY,
					@ItemBillGUID_3 UNIQUEIDENTIFIER

				SET @ItemSOGroup_3 = ISNULL((SELECT MAX(SOGroup) FROM POSOrderItemsTemp000 WHERE [ParentID] = @OrderGUID), 0) + 1

				SET @items_3 = CURSOR FAST_FORWARD FOR SELECT ItemGUID, ItemQty, ItemUnitFact, SOD_UnitFact, SOD_GUID, ItemBillGUID FROM #SO_OrderItems ORDER BY ItemNumber
				OPEN @items_3 FETCH NEXT FROM @items_3 INTO @GUID_3, @qty_3, @ItemUnitFact_3, @SODUnitFact_3, @SOD_GUID_3, @ItemBillGUID_3
				WHILE @@FETCH_STATUS = 0 AND @stop_3 = 0
				BEGIN 
					UPDATE #SO_SumOrderItems SET AcheivedQty = AcheivedQty + (@qty_3 * @ItemUnitFact_3 / @SODUnitFact_3) 
					WHERE SOD_GUID = @SOD_GUID_3 AND AcheivedQty < SOD_Qty
					IF @@ROWCOUNT = 0
					BEGIN
						FETCH NEXT FROM @items_3 INTO @GUID_3, @qty_3, @ItemUnitFact_3, @SODUnitFact_3, @SOD_GUID_3, @ItemBillGUID_3
						CONTINUE
					END
					IF NOT EXISTS(SELECT * FROM #SO_SumOrderItems WHERE (AcheivedQty < SOD_Qty))
						SET @stop_3 = 1
						
					SELECT 
						@SOD_QTY_3 = SOD_Qty,
						@AcheivedQty_3 = AcheivedQty
					FROM #SO_SumOrderItems
					WHERE SOD_GUID = @SOD_GUID_3

					UPDATE POSOrderItemsTemp000
					SET 
						SpecialOfferID = @SO_GUID,
						SOGroup = @ItemSOGroup_3
					OUTPUT inserted.GUID, 1, 0x0 INTO #OfferedItems
					FROM POSOrderItemsTemp000 ori
					WHERE GUID = @GUID_3

					IF @stop_3 = 1
					BEGIN
						DECLARE @Index_3 INT 
						SET @Index_3 = (SELECT MAX(Number) FROM POSOrderItemsTemp000 
							WHERE [ParentID] = @OrderGUID AND SOGroup = @ItemSOGroup_3 AND OfferedItem != 1 AND SpecialOfferID = @SO_GUID)
		
						DECLARE @ParentItemGUID_3 UNIQUEIDENTIFIER = 0X0
						IF ISNULL(@Index_3, 0) != 0
						BEGIN			
							SET @ParentItemGUID_3 = (SELECT TOP 1 GUID FROM POSOrderItemsTemp000 
								WHERE [ParentID] = @OrderGUID AND SOGroup = @ItemSOGroup_3 AND Number = @Index_3)
			
							UPDATE POSOrderItemsTemp000 
							SET Number = Number + (SELECT COUNT(*) FROM OfferedItems000 WHERE ParentID = @SO_GUID)
							WHERE Number > @Index_3 AND [ParentID] = @OrderGUID
							IF @@ROWCOUNT = 0
								SET @ParentItemGUID_3 = 0x0
						END

						EXEC prcPOS_SO_AddOrderOfferedItems 
								@Index_3, @OrderGUID, @ItemBillGUID_3, 1, @SO_GUID, 
								@SO_Qty, @SO_ApplyOnce, @ItemSOGroup_3, @ParentItemGUID_3, @IsReturned
					END
					FETCH NEXT FROM @items_3 INTO @GUID_3, @qty_3, @ItemUnitFact_3, @SODUnitFact_3, @SOD_GUID_3, @ItemBillGUID_3
				END CLOSE @items_3 DEALLOCATE @items_3	
			END ELSE BEGIN
				UPDATE #SO_SumOrderItems SET TargetQty = SumItemQty - (CAST(SumItemQty AS MONEY) % CAST(SOD_Qty AS MONEY))
				DECLARE @count_4 INT
				SET @count_4 = (SELECT MIN(TargetQty / SOD_Qty) FROM #SO_SumOrderItems)
				UPDATE #SO_SumOrderItems SET TargetQty = CAST(SOD_Qty AS MONEY) * @count_4

				DECLARE @stop_4 BIT = 0
				DECLARE 
					@items_4 CURSOR, 
					@GUID_4 UNIQUEIDENTIFIER,
					@qty_4 MONEY,
					@SOD_GUID_4 UNIQUEIDENTIFIER,
					@TargetQty_4 MONEY,
					@AcheivedQty_4 MONEY,
					@ItemUnitFact_4 MONEY,
					@SODUnitFact_4 MONEY,
					@ItemBillGUID_4 UNIQUEIDENTIFIER,
					@ItemSOGroup_4 INT,
					@lastCount_4 INT,
					@MinCount_4 INT

				SET @lastCount_4 = 0
				SET @MinCount_4 = 0

				SET @ItemSOGroup_4 = ISNULL((SELECT MAX(SOGroup) FROM POSOrderItemsTemp000 WHERE [ParentID] = @OrderGUID), 0) + 1

				SET @items_4 = CURSOR FAST_FORWARD FOR SELECT ItemGUID, ItemQty, ItemUnitFact, SOD_UnitFact, SOD_GUID, ItemBillGUID FROM #SO_OrderItems ORDER BY ItemNumber
				OPEN @items_4 FETCH NEXT FROM @items_4 INTO @GUID_4, @qty_4, @ItemUnitFact_4, @SODUnitFact_4, @SOD_GUID_4, @ItemBillGUID_4
				WHILE @@FETCH_STATUS = 0 AND @stop_4 = 0
				BEGIN 
					UPDATE #SO_SumOrderItems SET AcheivedQty = AcheivedQty + (@qty_4 * @ItemUnitFact_4 / @SODUnitFact_4) 
					WHERE SOD_GUID = @SOD_GUID_4 AND AcheivedQty < TargetQty
					IF @@ROWCOUNT = 0
					BEGIN
						FETCH NEXT FROM @items_4 INTO @GUID_4, @qty_4, @ItemUnitFact_4, @SODUnitFact_4, @SOD_GUID_4, @ItemBillGUID_4
						CONTINUE
					END
					IF NOT EXISTS(SELECT * FROM #SO_SumOrderItems WHERE AcheivedQty < TargetQty)
						SET @stop_4 = 1
						
					SELECT 
						@TargetQty_4 = TargetQty,
						@AcheivedQty_4 = AcheivedQty
					FROM #SO_SumOrderItems
					WHERE SOD_GUID = @SOD_GUID_4

					UPDATE POSOrderItemsTemp000
					SET 
						SpecialOfferID = @SO_GUID,
						SOGroup = @ItemSOGroup_4
					OUTPUT inserted.GUID, 1, 0x0 INTO #OfferedItems
					FROM POSOrderItemsTemp000 ori
					WHERE GUID = @GUID_4

					UPDATE #SO_SumOrderItems SET CountQty = CAST(AcheivedQty AS FLOAT) / CAST(SOD_Qty AS FLOAT) WHERE SOD_GUID = @SOD_GUID_4

					SET @MinCount_4 = (SELECT MIN(CountQty) FROM #SO_SumOrderItems)

					IF @MinCount_4 > @lastCount_4
					BEGIN
						DECLARE @Index_4 INT 
						SET @Index_4 = (SELECT MAX(Number) FROM POSOrderItemsTemp000 
							WHERE [ParentID] = @OrderGUID AND SOGroup = @ItemSOGroup_4 AND SpecialOfferID = @SO_GUID)
		
						DECLARE @ParentItemGUID_4 UNIQUEIDENTIFIER = 0X0
						IF ISNULL(@Index_4, 0) != 0
						BEGIN			
							SET @ParentItemGUID_4 = (SELECT TOP 1 GUID FROM POSOrderItemsTemp000 
								WHERE [ParentID] = @OrderGUID AND SOGroup = @ItemSOGroup_4 AND Number = @Index_4)

							UPDATE oi
							SET Number = h.Number							
							FROM 
								POSOrderItemsTemp000 oi
								INNER JOIN (SELECT GUID, ROW_NUMBER() OVER(ORDER BY Number, SOGroup) AS Number FROM POSOrderItemsTemp000 WHERE [ParentID] = @OrderGUID) h 
									ON h.GUID = oi.GUID
							WHERE oi.Number != h.Number
			
							UPDATE POSOrderItemsTemp000 
							SET Number = Number + (SELECT COUNT(*) FROM OfferedItems000 WHERE ParentID = @SO_GUID)
							WHERE Number > @Index_4 AND [ParentID] = @OrderGUID
							IF @@ROWCOUNT = 0
								SET @ParentItemGUID_4 = 0x0
						END

						DECLARE @cnt_4 INT 
						SET @cnt_4 = (@MinCount_4 - @lastCount_4)
						EXEC prcPOS_SO_AddOrderOfferedItems 
								@Index_4, @OrderGUID, @ItemBillGUID_4, @cnt_4, @SO_GUID, 
								1, @SO_ApplyOnce, @ItemSOGroup_4, @ParentItemGUID_4, @IsReturned

						SET @lastCount_4 = @MinCount_4
						SET @ItemSOGroup_4 = @ItemSOGroup_4 + 1
					END

					FETCH NEXT FROM @items_4 INTO @GUID_4, @qty_4, @ItemUnitFact_4, @SODUnitFact_4, @SOD_GUID_4, @ItemBillGUID_4
				END CLOSE @items_4 DEALLOCATE @items_4
			END				
		END
	END  
####################################################################################
#END
