#####################################################################
CREATE PROCEDURE prcPOS_SO_Mixed_Item_Apply
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
	@SO_Mode INT,
	@SO_MatGUID UNIQUEIDENTIFIER,
	@SO_GroupGUID UNIQUEIDENTIFIER,
	@SO_Unit INT,
	@SO_ApplyOnce BIT,
	@SO_CheckExactQty BIT
AS
	SET NOCOUNT ON 

	DECLARE @ItemSOGroup INT 
	SET @ItemSOGroup = 0

	IF @SO_Condition = 0
	BEGIN
		DECLARE @OfferQty FLOAT
		IF @SO_CheckExactQty = 1
		BEGIN
			DECLARE @counter INT = 0;
			SELECT * INTO #OrderItems FROM vwPOSOrderItemsTempWithOutCanceledGroupedOnQty WHERE ParentID = @OrderGUID 

			WHILE EXISTS (SELECT * FROM #OrderItems)
			BEGIN
				IF NOT EXISTS(
					SELECT so.Guid 
					FROM 
						vwSpecialOfferDetail so
						LEFT JOIN #OrderItems oi ON so.ActualMatID = oi.MatID AND so.ActualQty <= oi.Qty
					WHERE oi.MatID IS NULL AND so.Guid = @SO_GUID
					GROUP BY oi.MatID, so.Guid)
				BEGIN
					UPDATE oi
						SET oi.Qty = oi.Qty - md.ActualQty
					FROM #OrderItems oi
					INNER JOIN vwMatOfferDetails md ON oi.MatID = md.MatID

					SET @counter = @counter + 1;

					DELETE #OrderItems WHERE Qty <= 0
				END
				ELSE
				BEGIN
					DELETE #OrderItems
				END
			END
			DROP TABLE #OrderItems
			SET @OfferQty = @counter;
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
						SET oi.SpecialOfferID = 0x0,
							oi.Discount = 0
					OUTPUT inserted.Guid, 1, 0x0 INTO #OfferedItems
					FROM POSOrderItemstemp000 oi
					WHERE oi.SpecialOfferID = @SO_GUID AND oi.ParentID = @OrderGUID

				UPDATE oi 
						SET oi.SpecialOfferID = @SO_GUID,
							oi.Discount = CASE @SO_DiscountType WHEN 0 THEN (@SO_Discount / 100) * (oi.Price * so.Qty)
								ELSE @SO_Discount * @OfferQty END
					OUTPUT inserted.Guid, 1, 0x0 INTO #OfferedItems
					FROM POSOrderItemsTemp000 oi
					INNER JOIN dbo.fnPOSGetOrderOfferedMatItem(@OfferQty, @SO_GUID, @OrderGUID) so ON oi.Guid = so.ItemGuid
			END
			ELSE
			BEGIN
				UPDATE oi
						SET oi.SpecialOfferID = @SO_GUID
					OUTPUT inserted.Guid, 1, 0x0 INTO #OfferedItems
					FROM POSOrderItemsTemp000 oi
					INNER JOIN dbo.fnPOSGetOrderOfferedMatItem(@OfferQty, @SO_GUID, @OrderGUID) so ON oi.Guid = so.ItemGuid

				DELETE di 
					FROM POSOrderDiscountTemp000 di
						INNER JOIN POSOrderItemsTemp000 oi ON di.OrderItemID = oi.Guid
					WHERE oi.SpecialOfferID = @SO_GUID AND di.ParentID = @OrderGUID AND SpecialOffer = 1

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
						INNER JOIN dbo.fnPOSGetOrderOfferedMatItem(@OfferQty, @SO_GUID, @OrderGUID) so ON oi.Guid = so.ItemGuid)
						 ELSE @SO_Discount * @OfferQty END
				, @DiscAccountGUID
				, ''
				, 0
				, 1
				, (select top 1 guid from POSOrderItemstemp000 where SpecialOfferID = @SO_GUID))
			END
		END
		ELSE
		BEGIN
			DELETE oi2
			OUTPUT deleted.Guid, 2, 0x0 INTO #OfferedItems
			FROM POSOrderItemsTemp000 oi2
			WHERE 
				oi2.OfferedItem = 1 AND oi2.SpecialOfferID IN(
					SELECT oi.SpecialOfferID 
					FROM 
						vwSpecialOfferDetail so
						LEFT JOIN POSOrderItemsTemp000 oi ON so.ActualMatID = oi.MatID
					WHERE so.Guid = @SO_GUID)

			DELETE di 
			FROM 
				POSOrderDiscountTemp000 di
				INNER JOIN POSOrderItemsTemp000 oi ON di.OrderItemID = oi.Guid
				INNER JOIN dbo.fnPOSGetOrderOfferedMatItem(@OfferQty, @SO_GUID, @OrderGUID) so ON oi.Guid = so.ItemGuid
		
			UPDATE oi
			SET oi.SpecialOfferID = @SO_GUID
			OUTPUT inserted.Guid, 1, 0x0 INTO #OfferedItems
			FROM 
				POSOrderItemstemp000 oi
				INNER JOIN dbo.fnPOSGetOrderOfferedMatItem(@OfferQty, @SO_GUID, @OrderGUID) so ON oi.Guid = so.ItemGuid

			INSERT INTO POSOrderItemsTemp000
				([Number]
			   ,[Guid]
			   ,[MatID]
			   ,[Type]
			   ,[Qty]
			   ,[MatPrice]
			   ,[VATValue]
			   ,[Price]
			   ,[PriceType]
			   ,[Unity]
			   ,[State]
			   ,[Discount]
			   ,[Added]
			   ,[Tax]
			   ,[ParentID]
			   ,[ItemParentID]
			   ,[SalesmanID]
			   ,[PrinterID]
			   ,[ExpirationDate]
			   ,[ProductionDate]
			   ,[AccountID]
			   ,[BillType]
			   ,[Note]
			   ,[SpecialOfferID]
			   ,[SpecialOfferIndex]
			   ,[OfferedItem]
			   ,[IsPrinted]
			   ,[SerialNumber]
			   ,[DiscountType]
			   ,[ClassPtr]
			   ,[RelatedBillID]
			   ,[BillItemID])
			OUTPUT inserted.Guid, 0, 0x0 INTO #OfferedItems
			SELECT
				   (SELECT ISNULL(MAX(Number), 0) + 1 FROM POSOrderItemsTemp000)
				   ,NEWID()
				   ,MatID
				   ,0
				   ,Qty * @OfferQty
				   ,Price
				   ,0
				   ,Price
				   ,PriceType
				   ,Unit
				   ,0
				   ,0
				   ,0
				   ,0
				   ,@OrderGUID
				   ,0x0
				   ,0x0
				   ,0
				   ,'1980-01-01'
				   ,'1980-01-01'
				   ,0x0
				   ,@ItemBillGUID
				   ,''
				   ,@SO_GUID
				   ,2
				   ,1
				   ,0
				   ,''
				   ,1
				   ,''
				   ,0x0
				   ,0x0
				FROM OfferedItems000
				WHERE ParentID = @SO_GUID
				ORDER BY Number
		END
	END
#####################################################################
#END
