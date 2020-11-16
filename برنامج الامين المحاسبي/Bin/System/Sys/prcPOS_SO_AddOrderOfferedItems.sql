################################################################################
CREATE PROCEDURE prcPOS_SO_AddOrderOfferedItems
	@Index INT,
	@OrderGUID UNIQUEIDENTIFIER, 
	@ItemBillGUID UNIQUEIDENTIFIER,
	@ItemQty FLOAT,
	@SO_GUID UNIQUEIDENTIFIER, 
	@SO_Qty FLOAT,
	@SO_ApplyOnce BIT,
	@ItemSOGroup INT,
	@ParentItemGUID UNIQUEIDENTIFIER = 0x0,
	@IsReturned BIT = 0
AS
	SET NOCOUNT ON

	INSERT INTO POSOrderItemsTemp000 (
		[Number],  
		[Guid], 
		[MatID], 
		[Type], 
		[Qty], 
		[MatPrice], 
		[VATValue], 
		[Price], 
		[PriceType], 
		[Unity], 
		[State], 
		[Discount], 
		[Added], 
		[Tax], 
		[ParentID], 
		[ItemParentID], 
		[SalesmanID], 
		[PrinterID], 
		[ExpirationDate], 
		[ProductionDate], 
		[AccountID], 
		[BillType], 
		[Note], 
		[SpecialOfferID], 
		[SpecialOfferIndex], 
		[OfferedItem], 
		[IsPrinted], 
		[SerialNumber], 
		[DiscountType], 
		[ClassPtr], 
		[RelatedBillID], 
		[BillItemID], 
		[SOGroup])
	OUTPUT inserted.Guid, 0, ISNULL(@ParentItemGUID, 0x0) INTO #OfferedItems
	SELECT
		CASE ISNULL(@ParentItemGUID, 0x0) 
			WHEN 0x0 THEN (ROW_NUMBER() OVER(ORDER BY Number)) 
			ELSE (ROW_NUMBER() OVER(ORDER BY Number DESC)) 
		END + @Index, 
		NEWID(), 
		MatID,
		CASE @IsReturned WHEN 0 THEN 0 ELSE 1 END, -- Item type 
		Qty *
		(CASE 
			WHEN @SO_ApplyOnce = 1 THEN 1 
			ELSE ((@ItemQty - (CAST(CAST(@ItemQty AS MONEY) % CAST(@SO_Qty AS MONEY) AS FLOAT))) / @SO_Qty)
		END),
		Price,
		0,
		[ItemUnitPrice],
		PriceType,
		Unit,
		0,
		Qty *
		(CASE 
			WHEN @SO_ApplyOnce = 1 THEN 1 
			ELSE ((@ItemQty - (CAST(CAST(@ItemQty AS MONEY) % CAST(@SO_Qty AS MONEY) AS FLOAT))) / @SO_Qty)
		END) * [ItemUnitPrice] * Discount / 100,
		0,
		0,
		@OrderGUID,
		0x0,
		0x0,
		0,
		'1980-01-01',
		'1980-01-01',
		0x0,
		@ItemBillGUID,
		'',
		@SO_GUID,
		2,
		1,
		0,
		'',
		0,
		'',
		0x0,
		0x0,
		@ItemSOGroup
	FROM vwOfferedItems
	WHERE ParentID = @SO_GUID
	ORDER BY Number
####################################################################################
#END
