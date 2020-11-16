################################################################################
CREATE PROC prcPOS_SO_Order_Mixed_Disc_Apply
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
			IF @SO_ApplyOnce = 0 AND @SO_CheckExactQty = 0
			BEGIN 
				UPDATE ori
				SET 
					SpecialOfferID = @SO_GUID,
					Discount = 
						CASE @SO_DiscountType 
							WHEN 0 THEN (@SO_Discount / 100) * ori.Price * ori.Qty -- unit
							ELSE @SO_Discount * so.ItemQty * so.ItemUnitFact / so.SO_UnitFact -- unit
						END,
					SOGroup = CASE @IsReturned WHEN 0 THEN 0 ELSE ISNULL((SELECT MAX(SOGroup) FROM POSOrderItemsTemp000 WHERE [ParentID] = @OrderGUID), 0) + 1 END
				OUTPUT inserted.GUID, 1, 0x0 INTO #OfferedItems
				FROM 
					POSOrderItemsTemp000 ori
					INNER JOIN #SO_OrderItems so ON ori.GUID = so.ItemGUID
				WHERE 
					ori.SpecialOfferID = 0x0
			END ELSE IF @SO_ApplyOnce = 1
			BEGIN 
				DECLARE @stop_1 BIT = 0
				DECLARE 
					@items_1 CURSOR, 
					@GUID_1 UNIQUEIDENTIFIER,
					@qty_1 MONEY,
					@ItemUnitFact_1 MONEY,
					@SOUnitFact_1 MONEY,
					@AcheivedQty_1 MONEY,
					@SOGroup_1 INT 

				SET @SOGroup_1 = CASE @IsReturned WHEN 0 THEN 0 ELSE ISNULL((SELECT MAX(SOGroup) FROM POSOrderItemsTemp000 WHERE [ParentID] = @OrderGUID), 0) + 1 END
				SET @AcheivedQty_1 = 0 
				SET @items_1 = CURSOR FAST_FORWARD FOR SELECT ItemGUID, ItemQty, ItemUnitFact, SO_UnitFact FROM #SO_OrderItems ORDER BY ItemNumber
				OPEN @items_1 FETCH NEXT FROM @items_1 INTO @GUID_1, @qty_1, @ItemUnitFact_1, @SOUnitFact_1
				WHILE @@FETCH_STATUS = 0 AND @stop_1 = 0
				BEGIN 
					SET @AcheivedQty_1 = @AcheivedQty_1 + (@qty_1 * @ItemUnitFact_1 / @SOUnitFact_1)
					IF @AcheivedQty_1 - @SO_Qty > -0.001
						SET @stop_1 = 1

					UPDATE POSOrderItemsTemp000
					SET 
						SpecialOfferID = @SO_GUID,
						Discount = 
							CASE @SO_DiscountType 
								WHEN 0 THEN (@SO_Discount / 100) * ori.Price * (CASE @stop_1 WHEN 0 THEN ori.Qty ELSE ( ( @SO_Qty - (@AcheivedQty_1 - (@qty_1 * @ItemUnitFact_1 / @SOUnitFact_1) ) ) * @SOUnitFact_1 / @ItemUnitFact_1 ) END) -- unit
								ELSE @SO_Discount * (CASE @stop_1 WHEN 0 THEN ori.Qty * @ItemUnitFact_1 / @SOUnitFact_1 ELSE ( @SO_Qty - (@AcheivedQty_1 - (@qty_1 * @ItemUnitFact_1 / @SOUnitFact_1) ) ) END) -- unit
							END,
						SOGroup = @SOGroup_1
					OUTPUT inserted.GUID, 1, 0x0 INTO #OfferedItems
					FROM POSOrderItemsTemp000 ori
					WHERE 
						GUID = @GUID_1
						AND ori.SpecialOfferID = 0x0

					FETCH NEXT FROM @items_1 INTO @GUID_1, @qty_1, @ItemUnitFact_1, @SOUnitFact_1
				END CLOSE @items_1 DEALLOCATE @items_1 

			END ELSE IF @SO_CheckExactQty = 1
			BEGIN 
				DECLARE @stop_2 BIT = 0
				DECLARE 
					@items_2 CURSOR, 
					@GUID_2 UNIQUEIDENTIFIER,
					@ItemUnitFact_2 MONEY,
					@SOUnitFact_2 MONEY,
					@qty_2 MONEY,
					@AcheivedQty_2 MONEY,
					@TargetQty_2 MONEY,
					@SumItems_2 MONEY,
					@SOGroup_2 INT

				SET @SOGroup_2 = CASE @IsReturned WHEN 0 THEN 0 ELSE ISNULL((SELECT MAX(SOGroup) FROM POSOrderItemsTemp000 WHERE [ParentID] = @OrderGUID), 0) + 1 END
				SET @SumItems_2 = (SELECT SUM(ItemQty * ItemUnitFact / SO_UnitFact) FROM #SO_OrderItems)
				SET @TargetQty_2 = @SumItems_2 - (@SumItems_2 % CAST(@SO_Qty AS MONEY))
				SET @AcheivedQty_2 = 0 

				SET @items_2 = CURSOR FAST_FORWARD FOR SELECT ItemGUID, ItemQty, ItemUnitFact, SO_UnitFact FROM #SO_OrderItems ORDER BY ItemNumber
				OPEN @items_2 FETCH NEXT FROM @items_2 INTO @GUID_2, @qty_2, @ItemUnitFact_2, @SOUnitFact_2
				WHILE @@FETCH_STATUS = 0 AND @stop_2 = 0
				BEGIN 
					SET @AcheivedQty_2 = @AcheivedQty_2 + (@qty_2 * @ItemUnitFact_2 / @SOUnitFact_2)
					IF @AcheivedQty_2 - @TargetQty_2 > -0.001
						SET @stop_2 = 1

					UPDATE POSOrderItemsTemp000
					SET 
						SpecialOfferID = @SO_GUID,
						Discount = 
							CASE @SO_DiscountType 
								WHEN 0 THEN (@SO_Discount / 100) * ori.Price * (CASE @stop_2 WHEN 0 THEN ori.Qty ELSE CAST(( ( @TargetQty_2 - (@AcheivedQty_2 - (@qty_2 * @ItemUnitFact_2 / @SOUnitFact_2) ) ) * @SOUnitFact_2 / @ItemUnitFact_2 ) AS FLOAT) END) -- unit
								ELSE @SO_Discount * (CASE @stop_2 WHEN 0 THEN ori.Qty * @ItemUnitFact_2 / @SOUnitFact_2 ELSE ( @TargetQty_2 - (@AcheivedQty_2 - (@qty_2 * @ItemUnitFact_2 / @SOUnitFact_2) ) ) END) -- unit
							END	,
						SOGroup = @SOGroup_2
					OUTPUT inserted.GUID, 1, 0x0 INTO #OfferedItems
					FROM POSOrderItemsTemp000 ori
					WHERE 
						GUID = @GUID_2 
						AND ori.SpecialOfferID = 0x0

					FETCH NEXT FROM @items_2 INTO @GUID_2, @qty_2, @ItemUnitFact_2, @SOUnitFact_2
				END CLOSE @items_2 DEALLOCATE @items_2 					
			END 
		END 
	END 
	ELSE BEGIN 
		SELECT
			SOD_GUID,
			MAX(SOD_Qty) AS SOD_Qty,
			MAX(SOD_Unit) AS SOD_Unit,
			CAST(SUM(ItemQty * ItemUnitFact / SOD_UnitFact) AS MONEY) AS SumItemQty,
			CAST(0 AS MONEY) AS AcheivedQty,
			CAST(0 AS MONEY) AS TargetQty
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
			IF @SO_ApplyOnce = 0 AND @SO_CheckExactQty = 0
			BEGIN 
				UPDATE POSOrderItemsTemp000
				SET 
					SpecialOfferID = @SO_GUID,
					Discount = 
						CASE @SO_DiscountType 
							WHEN 0 THEN (@SO_Discount / 100) * Price * ori.Qty -- unit
							ELSE @SO_Discount * ori.Qty * so.ItemUnitFact / so.SOD_UnitFact -- unit
						END,
					SOGroup = CASE @IsReturned WHEN 0 THEN 0 ELSE ISNULL((SELECT MAX(SOGroup) FROM POSOrderItemsTemp000 WHERE [ParentID] = @OrderGUID), 0) + 1 END
				OUTPUT inserted.GUID, 1, 0x0 INTO #OfferedItems
				FROM 
					POSOrderItemsTemp000 ori
					INNER JOIN #SO_OrderItems so ON so.ItemGUID = ori.GUID
				WHERE ori.SpecialOfferID = 0x0
			END ELSE IF @SO_ApplyOnce = 1
			BEGIN
				DECLARE @stop_3 BIT = 0
				DECLARE 
					@items_3 CURSOR, 
					@GUID_3 UNIQUEIDENTIFIER,
					@qty_3 MONEY,
					@SOD_GUID_3 UNIQUEIDENTIFIER,
					@SOD_QTY_3 MONEY,
					@ItemUnitFact_3 MONEY,
					@SODUnitFact_3 MONEY,
					@AcheivedQty_3 MONEY,
					@SOGroup_3 INT
				
				SET @SOGroup_3 = CASE @IsReturned WHEN 0 THEN 0 ELSE ISNULL((SELECT MAX(SOGroup) FROM POSOrderItemsTemp000 WHERE [ParentID] = @OrderGUID), 0) + 1 END
				SET @items_3 = CURSOR FAST_FORWARD FOR SELECT ItemGUID, ItemQty, ItemUnitFact, SOD_UnitFact, SOD_GUID FROM #SO_OrderItems ORDER BY ItemNumber
				OPEN @items_3 FETCH NEXT FROM @items_3 INTO @GUID_3, @qty_3, @ItemUnitFact_3, @SODUnitFact_3, @SOD_GUID_3
				WHILE @@FETCH_STATUS = 0 AND @stop_3 = 0 
				BEGIN 
					UPDATE #SO_SumOrderItems SET AcheivedQty = AcheivedQty + (@qty_3 * @ItemUnitFact_3 / @SODUnitFact_3) 
					WHERE SOD_GUID = @SOD_GUID_3 AND (AcheivedQty < SOD_Qty)
					IF @@ROWCOUNT = 0
					BEGIN
						FETCH NEXT FROM @items_3 INTO @GUID_3, @qty_3, @ItemUnitFact_3, @SODUnitFact_3, @SOD_GUID_3
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
						Discount = 
							CASE @SO_DiscountType 
								WHEN 0 THEN (@SO_Discount / 100) * ori.Price * (CASE WHEN @AcheivedQty_3 <= @SOD_QTY_3 THEN ori.Qty ELSE 
									( ( @SOD_QTY_3 - (@AcheivedQty_3 - (@qty_3 * @ItemUnitFact_3 / @SODUnitFact_3) ) ) * @SODUnitFact_3 / @ItemUnitFact_3 ) END)
								ELSE @SO_Discount * (CASE WHEN @AcheivedQty_3 <= @SOD_QTY_3 THEN ori.Qty * @ItemUnitFact_3 / @SODUnitFact_3 ELSE 
									( @SOD_QTY_3 - (@AcheivedQty_3 - (@qty_3 * @ItemUnitFact_3 / @SODUnitFact_3) ) ) END) -- unit
							END,
						SOGroup = @SOGroup_3
					OUTPUT inserted.GUID, 1, 0x0 INTO #OfferedItems
					FROM POSOrderItemsTemp000 ori
					WHERE 
						GUID = @GUID_3
						AND SpecialOfferID = 0x0

					FETCH NEXT FROM @items_3 INTO @GUID_3, @qty_3, @ItemUnitFact_3, @SODUnitFact_3, @SOD_GUID_3
				END CLOSE @items_3 DEALLOCATE @items_3					
			END ELSE IF @SO_CheckExactQty = 1
			BEGIN
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
					@ItemUnitFact_4 MONEY,
					@SODUnitFact_4 MONEY,
					@AcheivedQty_4 MONEY,
					@SOGroup_4 INT
				
				SET @SOGroup_4 = CASE @IsReturned WHEN 0 THEN 0 ELSE ISNULL((SELECT MAX(SOGroup) FROM POSOrderItemsTemp000 WHERE [ParentID] = @OrderGUID), 0) + 1 END
				SET @items_4 = CURSOR FAST_FORWARD FOR SELECT ItemGUID, ItemQty, ItemUnitFact, SOD_UnitFact, SOD_GUID FROM #SO_OrderItems ORDER BY ItemNumber
				OPEN @items_4 FETCH NEXT FROM @items_4 INTO @GUID_4, @qty_4, @ItemUnitFact_4, @SODUnitFact_4, @SOD_GUID_4
				WHILE @@FETCH_STATUS = 0 AND @stop_4 = 0
				BEGIN 
					UPDATE #SO_SumOrderItems SET AcheivedQty = AcheivedQty + (@qty_4 * @ItemUnitFact_4 / @SODUnitFact_4) 
					WHERE SOD_GUID = @SOD_GUID_4 AND (AcheivedQty < TargetQty)
					IF @@ROWCOUNT = 0
					BEGIN
						FETCH NEXT FROM @items_4 INTO @GUID_4, @qty_4, @ItemUnitFact_4, @SODUnitFact_4, @SOD_GUID_4
						CONTINUE
					END
					IF NOT EXISTS(SELECT * FROM #SO_SumOrderItems WHERE (AcheivedQty < TargetQty))
						SET @stop_4 = 1
						
					SELECT 
						@TargetQty_4 = TargetQty,
						@AcheivedQty_4 = AcheivedQty
					FROM #SO_SumOrderItems
					WHERE SOD_GUID = @SOD_GUID_4

					UPDATE POSOrderItemsTemp000
					SET 
						SpecialOfferID = @SO_GUID,
						Discount = 
							CASE @SO_DiscountType 
								WHEN 0 THEN (@SO_Discount / 100) * ori.Price * (CASE WHEN @AcheivedQty_4 <= @TargetQty_4 THEN ori.Qty ELSE
								( ( @TargetQty_4 - (@AcheivedQty_4 - (@qty_4 * @ItemUnitFact_4 / @SODUnitFact_4) ) ) * @SODUnitFact_4 / @ItemUnitFact_4 ) END)

								ELSE @SO_Discount * (CASE WHEN @AcheivedQty_4 <= @TargetQty_4 
									THEN ori.Qty * @ItemUnitFact_4 / @SODUnitFact_4 ELSE 
									( @TargetQty_4 - (@AcheivedQty_4 - (@qty_4 * @ItemUnitFact_4 / @SODUnitFact_4) ) ) END) -- unit								
							END,
						SOGroup = @SOGroup_4
					OUTPUT inserted.GUID, 1, 0x0 INTO #OfferedItems
					FROM POSOrderItemsTemp000 ori
					WHERE GUID = @GUID_4

					FETCH NEXT FROM @items_4 INTO @GUID_4, @qty_4, @ItemUnitFact_4, @SODUnitFact_4, @SOD_GUID_4
				END CLOSE @items_4 DEALLOCATE @items_4
			END				
		END
	END  
####################################################################################
#END
