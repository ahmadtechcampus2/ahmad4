#########################################################
CREATE Proc prcRestOrderItem_Update
	@Number float
    ,@Guid uniqueidentifier
    ,@State int
    ,@Type int
    ,@Qty float
    ,@MatPrice float
    ,@Price float
    ,@PriceType int
    ,@Unity int
    ,@MatID uniqueidentifier
    ,@Discount float
    ,@Added float
    ,@Tax float
    ,@ParentID uniqueidentifier
    ,@ItemParentID uniqueidentifier
    ,@KitchenID uniqueidentifier
    ,@PrinterID int
    ,@AccountID uniqueidentifier
    ,@Note nvarchar(250)
    ,@SpecialOfferID uniqueidentifier
    ,@SpecialOfferIndex int
    ,@OfferedItem int
    ,@IsPrinted int
    ,@BillType uniqueidentifier
	,@Vat float
	,@VatRatio float
AS
	Set NOCOUNT ON
	DECLARE 
		@OldIsNew BIT,
		@OldQtyDiff FLOAT,
		@OldQty FLOAT,
		@QtyDiff FLOAT,
		@ChangedQty FLOAT,
		@OldChangedQty FLOAT
	SET @QtyDiff = 0
	SET @ChangedQty = 0
	SET @OldChangedQty = 0
	SELECT @OldIsNew = IsNew, @OldQtyDiff = QtyDiff, @OldQty = ISNULL(Qty,0), @OldChangedQty = ISNULL(ChangedQty,0) FROM RestOrderItemTemp000 WHERE Guid = @Guid
	SET @ChangedQty = 0
	IF ISNULL(@OldIsNew, 1) = 0 AND (@Qty != @OldQty)
	BEGIN 
		SET @QtyDiff = @Qty - @OldQty + @OldQtyDiff
	END 
	ELSE 
		IF ISNULL(@OldIsNew, 1) = 1
			SET @QtyDiff = ISNULL(@OldQtyDiff, 0)


	IF ISNULL(@OldIsNew, 1) = 0 AND (@Qty != @OldQty)
	BEGIN 
		SET @ChangedQty = @Qty - @OldQty
	END 
	ELSE 
		IF ISNULL(@OldIsNew, 1) = 1 OR (@Qty = @OldQty)
		BEGIN
			SET @ChangedQty = @OldChangedQty
		END

	Update RestOrderItemTemp000 SET @Number = Number
	   ,State = @State
	   ,Type = @Type
	   ,Qty = @Qty
	   ,ChangedQty = @ChangedQty
	   ,MatPrice = @MatPrice
	   ,Price = @Price
	   ,PriceType = @PriceType
	   ,Unity = @Unity
	   ,MatID = @MatID
	   ,Discount = @Discount
	   ,Added = @Added
	   ,Tax = @Tax
	   ,ParentID = @ParentID
	   ,ItemParentID = @ItemParentID
	   ,KitchenID = @KitchenID
	   ,PrinterID = @PrinterID
	   ,AccountID = @AccountID
	   ,Note = @Note
	   ,SpecialOfferID = @SpecialOfferID
	   ,SpecialOfferIndex = @SpecialOfferIndex
	   ,OfferedItem = @OfferedItem
	   ,IsPrinted = @IsPrinted
	   ,BillType = @BillType
	   ,QtyDiff = @QtyDiff
	   ,Vat = @Vat
	   ,VatRatio = @VatRatio
	where Guid = @Guid

#########################################################
#END