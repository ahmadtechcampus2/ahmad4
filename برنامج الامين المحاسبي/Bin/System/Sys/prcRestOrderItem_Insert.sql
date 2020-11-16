###########################
Create Procedure prcRestOrderItem_Insert
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
    ,@Note NVARCHAR(250)
    ,@SpecialOfferID uniqueidentifier
    ,@SpecialOfferIndex int
    ,@OfferedItem int
    ,@IsPrinted int
    ,@BillType uniqueidentifier
	,@Vat float
	,@VatRatio float
AS
Set NOCOUNT ON

INSERT INTO RestOrderItemTemp000
           ([Number]
           ,[Guid]
           ,[State]
           ,[Type]
           ,[Qty]
           ,[MatPrice]
           ,[Price]
           ,[PriceType]
           ,[Unity]
           ,[MatID]
           ,[Discount]
           ,[Added]
           ,[Tax]
           ,[ParentID]
           ,[ItemParentID]
           ,[KitchenID]
           ,[PrinterID]
           ,[AccountID]
           ,[Note]
           ,[SpecialOfferID]
           ,[SpecialOfferIndex]
           ,[OfferedItem]
           ,[IsPrinted]
           ,[BillType]
		   ,[IsNew]
		   ,[Vat]
		   ,[VatRatio])
     SELECT @Number
           ,@Guid
           ,@State
           ,@Type
           ,@Qty
           ,@MatPrice
           ,@Price
           ,@PriceType
           ,@Unity
           ,@MatID
           ,@Discount
           ,@Added
           ,@Tax
           ,@ParentID
           ,@ItemParentID
           ,@KitchenID
           ,@PrinterID
           ,@AccountID
           ,@Note
           ,@SpecialOfferID
           ,@SpecialOfferIndex
           ,@OfferedItem
           ,@IsPrinted
           ,@BillType
		   ,1
		   ,@Vat
		   ,@VatRatio
###########################
#END