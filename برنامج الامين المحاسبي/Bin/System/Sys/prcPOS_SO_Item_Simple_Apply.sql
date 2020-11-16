################################################################################
CREATE PROC prcPOS_SO_Item_Simple_Apply
	@ItemGUID UNIQUEIDENTIFIER, 
	@SO_Type INT,
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
		@OrderGUID UNIQUEIDENTIFIER,
		@OrderCustGUID UNIQUEIDENTIFIER,
		@OrderUserBillsGUID UNIQUEIDENTIFIER,
		@ItemBillGUID UNIQUEIDENTIFIER,
		@ItemMatGUID UNIQUEIDENTIFIER,
		@ItemGroupGUID UNIQUEIDENTIFIER,
		@ItemQty MONEY,
		@ItemType INT,
		@ItemUnitFact MONEY,
		@SO_UnitFact MONEY,
		@ItemOfferGUID UNIQUEIDENTIFIER,
		@ItemUnit INT,
		@ItemSOGroup INT,
		@ItemCompositionParentGuid UNIQUEIDENTIFIER

	SELECT 
		@OrderGUID = ord.GUID,
		@OrderCustGUID = ord.CustomerID,
		@OrderUserBillsGUID = ord.UserBillsID,
		@ItemMatGUID = ordi.MatID,
		@ItemQty = CAST(ordi.Qty AS MONEY),
		@ItemType = ordi.[Type],
		@ItemBillGUID = ordi.BillType,
		@ItemOfferGUID = ISNULL(ordi.SpecialOfferID, 0x0),
		@ItemUnit = ordi.Unity,
		@ItemSOGroup = ISNULL(ordi.SOGroup, 0),
		@ItemGroupGUID = mt.GroupGUID,
		@ItemUnitFact = CASE ordi.Unity 
			WHEN 2 THEN CASE mt.Unit2Fact WHEN 0 THEN 1 ELSE mt.Unit2Fact END
			WHEN 3 THEN CASE mt.Unit3Fact WHEN 0 THEN 1 ELSE mt.Unit3Fact END
			ELSE 1
		END,
		@SO_UnitFact = CASE @SO_Unit
			WHEN 1 THEN CASE mt.Unit2Fact WHEN 0 THEN 1 ELSE mt.Unit2Fact END
			WHEN 2 THEN CASE mt.Unit3Fact WHEN 0 THEN 1 ELSE mt.Unit3Fact END
			ELSE 1
		END,
		@ItemCompositionParentGuid = mt.Parent		
	FROM 
		POSOrderTemp000 ord
		INNER JOIN POSOrderItemsTemp000 ordi ON ord.GUID = ordi.ParentID
		INNER JOIN mt000 mt ON mt.GUID = ordi.MatID
	WHERE ordi.GUID = @ItemGUID
	
	IF @SO_ApplyOnce = 0 OR NOT EXISTS(SELECT 1 FROM dbo.fnPOS_SO_GetAvailableOrderItems(@OrderGUID, @IsReturned) WHERE SpecialOfferId = @SO_GUID)
	BEGIN 
		SET @ItemQty = @ItemQty * @ItemUnitFact
		DECLARE @SO_Qty2 FLOAT = @SO_Qty * @SO_UnitFact

		DECLARE @IsApplyed BIT = 0

		--Check If Mat Offer
		IF (@ItemMatGUID = @SO_MatGUID OR (ISNULL(@ItemCompositionParentGuid,0x0) <> 0x0 AND @ItemCompositionParentGuid = @SO_MatGUID) ) AND @ItemQty >= @SO_Qty2
		BEGIN
			SET @IsApplyed = 1
		END		

		--Check If Group Offer
		IF @IsApplyed = 0 AND ISNULL(@SO_GroupGUID, 0x0) != 0x0 AND @ItemQty >= @SO_Qty2
		BEGIN
			IF @SO_GroupGUID = @ItemGroupGUID 
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

		IF @IsApplyed = 0
			RETURN 

		IF @SO_Type = 0 -- Discount Offerr
		BEGIN
			UPDATE POSOrderItemstemp000
			SET 
				SpecialOfferID = @SO_GUID,
				Discount = 
					CAST((CASE @SO_DiscountType 
						WHEN 0 THEN (@SO_Discount / 100) * Price * 
							CASE 
								WHEN @SO_ApplyOnce = 1 THEN @SO_Qty * @SO_UnitFact / @ItemUnitFact
								WHEN @SO_CheckExactQty = 1 THEN ((@ItemQty - (CAST(CAST(@ItemQty AS MONEY) % CAST(@SO_Qty AS MONEY) AS FLOAT))) / @ItemUnitFact)
								ELSE @ItemQty / @ItemUnitFact 
							END
						ELSE @SO_Discount * 
							CASE 
								WHEN @SO_ApplyOnce = 1 THEN @SO_Qty 
								WHEN @SO_CheckExactQty = 1 THEN ((@ItemQty - (CAST(CAST(@ItemQty AS MONEY) % CAST(@SO_Qty AS MONEY) AS FLOAT))) / @SO_UnitFact)
								ELSE @ItemQty / @SO_UnitFact 
							END
					END) AS MONEY),
				SOGroup = ISNULL((SELECT MAX(SOGroup) FROM POSOrderItemsTemp000 WHERE ParentID = @OrderGUID), 0) + 1
			OUTPUT inserted.Guid, 1, 0x0 INTO #OfferedItems
			WHERE Guid = @ItemGUID 
		END ELSE BEGIN

			DECLARE @GR INT
			SET @GR = ISNULL(@ItemSOGroup, 0)

			DELETE FROM POSOrderItemsTemp000
			OUTPUT deleted.Guid, 2, 0x0 INTO #OfferedItems
			WHERE ParentID = @OrderGUID AND OfferedItem = 1 AND SpecialOfferID = @SO_GUID AND (SOGroup = @GR)

			IF ISNULL(@GR, 0) = 0
				SET @GR = ISNULL((SELECT MAX(SOGroup) FROM POSOrderItemsTemp000 WHERE [ParentID] = @OrderGUID), 0) + 1

			UPDATE POSOrderItemstemp000
			SET 
				SpecialOfferID = @SO_GUID,
				SOGroup = @GR
			OUTPUT inserted.Guid, 1, 0x0 INTO #OfferedItems
			WHERE Guid = @ItemGUID

			DECLARE @Index INT 
			SET @Index = (SELECT MAX(Number) FROM POSOrderItemsTemp000 
				WHERE [ParentID] = @OrderGUID AND SOGroup = @GR AND OfferedItem != 1 AND SpecialOfferID = @SO_GUID)
		
			DECLARE @ParentItemGUID UNIQUEIDENTIFIER = 0X0
			IF ISNULL(@Index, 0) != 0
			BEGIN			
				SET @ParentItemGUID = (SELECT TOP 1 GUID FROM POSOrderItemsTemp000 
					WHERE [ParentID] = @OrderGUID AND SOGroup = @GR AND Number = @Index)
			
				UPDATE POSOrderItemsTemp000 
				SET Number = Number + (SELECT COUNT(*) FROM OfferedItems000 WHERE ParentID = @SO_GUID)
				WHERE Number > @Index AND [ParentID] = @OrderGUID
				IF @@ROWCOUNT = 0
					SET @ParentItemGUID = 0x0
			END

			EXEC prcPOS_SO_AddOrderOfferedItems 
					@Index, @OrderGUID, @ItemBillGUID, @ItemQty, @SO_GUID, 
					@SO_Qty2, @SO_ApplyOnce, @GR, @ParentItemGUID, @IsReturned
		END
	END
####################################################################################
#END
