################################################################################
CREATE PROCEDURE prcPOS_SO_Mixed_Qty_Apply
	@OrderGUID UNIQUEIDENTIFIER, 
	@ItemGUID UNIQUEIDENTIFIER,
	@ItemBillGUID UNIQUEIDENTIFIER,
	@ItemQty FLOAT,
	@ItemType INT,
	@SO_GUID UNIQUEIDENTIFIER, 
	@AccountGUID UNIQUEIDENTIFIER,
	@MatAccountGUID UNIQUEIDENTIFIER,
	@DiscAccountGUID UNIQUEIDENTIFIER,
	@SO_DivDiscount INT,
	@SO_Type INT,
	@SO_Condition INT,
	@SO_Qty FLOAT,
	@SO_Discount FLOAT,
	@SO_DiscountType INT,
	@SO_Mode	INT,
	@SO_MatGUID UNIQUEIDENTIFIER,
	@SO_GroupGUID UNIQUEIDENTIFIER,
	@SO_Unit INT,
	@SO_ApplyOnce BIT,
	@SO_CheckExactQty BIT,
	@ApplyCount FLOAT
AS
	SET NOCOUNT ON 

	IF @SO_Condition != 1
		RETURN

	DECLARE @ItemSOGroup INT 
	SET @ItemSOGroup = 0
	DECLARE @OfferQty FLOAT

	IF @SO_CheckExactQty = 1
	BEGIN
		SET @OfferQty = @ApplyCount;
	END
	ELSE IF @SO_ApplyOnce = 1
	BEGIN
		SET @OfferQty = 1
	END
	ELSE
	BEGIN
		SET @OfferQty = (SELECT SUM(Qty) FROM POSOrderItemsTemp000 WHERE ParentID = @OrderGUID)
	END

	IF @SO_Type = 0 -- Discount Offerr
	BEGIN
		IF @SO_DivDiscount <> 0
		BEGIN
			UPDATE oi 
			SET 
				oi.SpecialOfferID = 0x0,
				oi.Discount = 0
			OUTPUT inserted.Guid, 1, 0x0 INTO #OfferedItems
			FROM POSOrderItemstemp000 oi
			WHERE oi.SpecialOfferID = @SO_GUID AND oi.ParentID = @OrderGUID

			UPDATE oi 
			SET 
				oi.SpecialOfferID = @SO_GUID,
				oi.Discount = CASE @SO_DiscountType WHEN 0 THEN (@SO_Discount / 100) * (oi.Price * oi.Qty) ELSE @SO_Discount END
			OUTPUT inserted.Guid, 1, 0x0 INTO #OfferedItems
			FROM 
				POSOrderItemsTemp000 oi
				INNER JOIN dbo.fnPOSGetOrderOfferedWhole(@OfferQty, @SO_GUID, @OrderGUID) so ON oi.Guid = so.ItemGuid

		END ELSE BEGIN
			DELETE di 
			FROM 
				POSOrderDiscountTemp000 di
				INNER JOIN POSOrderItemstemp000 oi ON di.OrderItemID = oi.Guid
			WHERE di.ParentID = @OrderGUID AND SpecialOffer = 1 AND oi.SpecialOfferID = @SO_GUID

			UPDATE oi 
			SET 
				oi.SpecialOfferID = 0x0,
				oi.Discount = 0
			OUTPUT inserted.Guid, 1, 0x0 INTO #OfferedItems
			FROM POSOrderItemstemp000 oi
			WHERE oi.SpecialOfferID = @SO_GUID AND oi.ParentID = @OrderGUID

			UPDATE oi
			SET oi.SpecialOfferID = @SO_GUID
			OUTPUT inserted.Guid, 1, 0x0 INTO #OfferedItems
			FROM 
				POSOrderItemstemp000 oi
				INNER JOIN dbo.fnPOSGetOrderOfferedWhole(@OfferQty, @SO_GUID, @OrderGUID) so ON oi.Guid = so.ItemGuid

			INSERT INTO POSOrderDiscountTemp000 
				([Number]
				,[Guid]
				,[Type]
				,[ParentID]
				,[Value]
				,[AccountID]
				,[Notes]
				,[OrderType]
				,[SpecialOffer]
				,[OrderItemID])
			VALUES 
			((SELECT ISNULL(MAX(Number), 0) + 1 FROM POSOrderDiscount000)
			, NEWID()
			, @ItemType
			, @OrderGUID
			, CASE @SO_DiscountType WHEN 0 THEN (@SO_Discount / 100) * 
				(SELECT SUM(oi.Price * so.Qty) FROM vwPOSOrderItemsTempWithOutCanceled oi
					INNER JOIN dbo.fnPOSGetOrderOfferedWhole(@OfferQty, @SO_GUID, @OrderGUID) so ON oi.Guid = so.ItemGuid)
						ELSE @OfferQty * @SO_Discount END
			, @DiscAccountGUID
			, ''
			, 0
			, 1
			, (SELECT TOP 1 GUID FROM POSOrderItemstemp000 WHERE SpecialOfferID = @SO_GUID ORDER BY Number))
		END
	END
	ELSE
	BEGIN
		DELETE oi
		OUTPUT deleted.Guid, 2, 0x0 INTO #OfferedItems
		FROM POSOrderItemsTemp000 oi
		WHERE ParentID = @OrderGUID AND OfferedItem = 1 AND SpecialOfferID = @SO_GUID

		UPDATE oi
		SET 
			oi.SpecialOfferID = @SO_GUID
		OUTPUT inserted.Guid, 1, 0x0 INTO #OfferedItems
		FROM 
			POSOrderItemstemp000 oi
			INNER JOIN dbo.fnPOSGetOrderOfferedWhole(@OfferQty, @SO_GUID, @OrderGUID) so ON oi.Guid = so.ItemGuid

		DECLARE @Index INT 
		SET @Index = (SELECT MAX(Number) FROM POSOrderItemsTemp000 
			WHERE [ParentID] = @OrderGUID AND SOGroup = @ItemSOGroup AND OfferedItem != 1 AND SpecialOfferID = @SO_GUID)

		EXEC prcPOS_SO_AddOrderOfferedItems 
				@Index, @OrderGUID, @ItemBillGUID, @ItemQty, @SO_GUID, 
				@SO_Qty, @SO_ApplyOnce, @ItemSOGroup, 0x0

	END	
####################################################################################
#END