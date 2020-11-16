################################################################################
CREATE PROCEDURE prcPOS_SO_Apply
	@ItemGUID UNIQUEIDENTIFIER,
	@IsCanceled BIT = 0,
	@RecalcOnAllOrder BIT = 1,
	@IsReturned BIT = 0
AS
	SET NOCOUNT ON

	IF NOT EXISTS(
		SELECT 1 FROM vwPOSSpecialOffer 
		WHERE [Active] = 1 AND CAST(GETDATE() AS DATE) BETWEEN StartDate AND EndDate)
			RETURN

	DECLARE @OrderGUID UNIQUEIDENTIFIER
	SELECT @OrderGUID = ParentID FROM POSOrderItemsTemp000 WHERE GUID = @ItemGUID

	DECLARE @OldItems TABLE(Number INT, ItemGUID UNIQUEIDENTIFIER, Qty FLOAT, Unit INT, SO_GUID UNIQUEIDENTIFIER, Discount FLOAT, IsOffered BIT, SOGroup INT)

	INSERT INTO @OldItems(Number, ItemGUID, Qty, Unit, SO_GUID, Discount, IsOffered, SOGroup)
	SELECT Number, GUID, Qty, Unity, SpecialOfferID, Discount, OfferedItem, SOGroup
	FROM dbo.fnPOS_SO_GetAvailableOrderItems(@OrderGUID, @IsReturned)
	WHERE ISNULL(SpecialOfferID, 0x0) != 0x0
		
	CREATE TABLE #OfferedItems (
		[ItemGUID] UNIQUEIDENTIFIER, 
		[OfferItemType] INT, 
		[ParentItemGUID] UNIQUEIDENTIFIER DEFAULT 0x0)

	IF @RecalcOnAllOrder = 1
		EXEC prcPOS_SO_Order_Apply @OrderGUID, @IsReturned
	ELSE 
		EXEC prcPOS_SO_Item_Apply @ItemGUID, @IsCanceled, @IsReturned

	IF NOT EXISTS (SELECT * FROM #OfferedItems WHERE ISNULL([ItemGUID], 0x0) != 0x0)
		RETURN 

	IF EXISTS (
		SELECT * 
		FROM 
			@OldItems old 
			INNER JOIN POSOrderItemsTemp000 oi ON oi.Number = old.Number
			INNER JOIN #OfferedItems o ON o.ItemGUID = old.ItemGUID
		WHERE 
			o.[OfferItemType] = 2
			AND old.Discount = oi.Discount AND old.SO_GUID = oi.SpecialOfferID AND old.Unit = oi.Unity
			AND old.IsOffered = oi.OfferedItem AND old.SOGroup = oi.SOGroup AND old.Qty = oi.Qty)
	BEGIN 
		UPDATE POSOrderItemsTemp000
		SET GUID = old.ItemGUID
		FROM 
			@OldItems old 
			INNER JOIN POSOrderItemsTemp000 oi ON oi.Number = old.Number
			INNER JOIN #OfferedItems o ON o.ItemGUID = old.ItemGUID
		WHERE 
			o.[OfferItemType] = 2
			AND old.Discount = oi.Discount AND old.SO_GUID = oi.SpecialOfferID AND old.Unit = oi.Unity
			AND old.IsOffered = oi.OfferedItem AND old.SOGroup = oi.SOGroup AND old.Qty = oi.Qty
	END 

	DELETE o
	FROM 
		#OfferedItems o 
		INNER JOIN POSOrderItemsTemp000 oi ON o.ItemGUID = oi.GUID
	WHERE 
		o.[OfferItemType] = 2

	DELETE o
	FROM 
		#OfferedItems o 
		LEFT JOIN POSOrderItemsTemp000 oi ON o.ItemGUID = oi.GUID
	WHERE 
		o.[OfferItemType] = 0 AND o.ItemGUID IS NULL
	
	IF EXISTS (SELECT 1 FROM POSOrderItemsTemp000 WHERE ParentID = @OrderGUID AND OfferedItem = 1 AND SpecialOfferID = 0x0)
	BEGIN 
		DELETE POSOrderItemsTemp000
		OUTPUT deleted.GUID, 2, 0x0 INTO #OfferedItems
		WHERE ParentID = @OrderGUID AND OfferedItem = 1 AND SpecialOfferID = 0x0 
	END 

	IF EXISTS (SELECT 1 FROM POSOrderItemsTemp000 WHERE ParentID = @OrderGUID AND SpecialOfferID != 0x0 AND (Discount > Qty * Price))
	BEGIN 
		UPDATE POSOrderItemsTemp000
		SET Discount = Qty * Price 
		OUTPUT inserted.GUID, 1, 0x0 INTO #OfferedItems
		WHERE ParentID = @OrderGUID AND SpecialOfferID != 0x0 AND (Discount > Qty * Price)		
	END 

	SELECT * FROM #OfferedItems 
	WHERE
		ISNULL([ItemGUID], 0x0) != 0x0
		AND 
		(
			[OfferItemType] = 2 /* DELETED ITEMS */ 
			OR 
			[ParentItemGUID] != 0x0 /* INSERTED AFTER PARENT */
		)

	SELECT * FROM vwPOSOrderItemsTemp o 
	WHERE 
		EXISTS(SELECT 1 FROM #OfferedItems WHERE [ItemGUID] = o.GUID) 
		AND
		NOT EXISTS(SELECT 1 FROM @OldItems WHERE [ItemGUID] = o.GUID AND SO_GUID = o.SpecialOfferID AND Discount = o.DiscountValue AND Qty = o.Qty AND SOGroup = o.SOGroup AND Unit = o.Unity)
	ORDER BY Number 
####################################################################################
#END
