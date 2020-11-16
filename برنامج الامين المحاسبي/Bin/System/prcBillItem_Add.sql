#########################################################
CREATE PROCEDURE prcBillItem_Add
	@Number [FLOAT],
	@Qty [FLOAT],
	@Order [FLOAT],
	@OrderQnt [FLOAT],
	@Unity [FLOAT],
	@Price [FLOAT],
	@BonusQnt [FLOAT],
	@Discount [FLOAT],
	@BonusDisc [FLOAT],
	@Extra [FLOAT],
	@CurrencyVal [FLOAT],
	@Notes [NVARCHAR](1000), 
	@Profits [FLOAT],
	@Num1 [FLOAT],
	@Num2 [FLOAT],
	@Qty2 [FLOAT],
	@Qty3 [FLOAT],
	@ClassPtr [NVARCHAR](250), 
	@ExpireDate [DATETIME],
	@ProductionDate [DATETIME],
	@Length [FLOAT],
	@Width [FLOAT],
	@Height [FLOAT],
	@GUID [UNIQUEIDENTIFIER],
	@VAT [FLOAT],
	@VATRatio [FLOAT],
	@ParentGUID [UNIQUEIDENTIFIER],
	@MatGUID [UNIQUEIDENTIFIER],
	@CurrencyGUID [UNIQUEIDENTIFIER],
	@StoreGUID [UNIQUEIDENTIFIER],
	@CostGUID [UNIQUEIDENTIFIER],
	@SOType [INT], 
	@SOGuid [UNIQUEIDENTIFIER],
	@Count [FLOAT],
	@SOGroup [INT],
	@TotalDiscountPercent	FLOAT,
	@TotalExtraPercent		FLOAT,
	@ContractItemGuid [UNIQUEIDENTIFIER] = 0x00,
	@ContractDiscount [FLOAT] = 0,
	@ClassPrice [FLOAT] = 0,
	@IsDiscountValue	BIT = 0,
	@IsExtraValue BIT = 0,
	@TaxCode INT = 0,
	@ExciseTaxVal FLOAT = 0,
	@PurchaseVal FLOAT = 0,
	@ReversChargeVal FLOAT = 0,
	@ExciseTaxPercent FLOAT = 0,
	@ExciseTaxCode INT = 0,
	@RelatedTo [UNIQUEIDENTIFIER]= 0x,
	@CustomsRate FLOAT = 0,
	@OrginalTaxCode INT = 0
AS 
	SET NOCOUNT ON 

	DECLARE @MatCurVal FLOAT 
	SET @MatCurVal = 0 
	IF @ClassPrice > 0 
	BEGIN 
		DECLARE @MatCurrencyGUID UNIQUEIDENTIFIER 
		SELECT @MatCurrencyGUID = CurrencyGUID FROM mt000 WHERE guid = @MatGUID
		IF ISNULL(@MatCurrencyGUID, 0x0) != 0x0 
		BEGIN 
			SET @MatCurVal = @CurrencyVal
			IF @MatCurrencyGUID != @CurrencyGUID
			BEGIN 
				DECLARE @BillDate DATE 
				SELECT @BillDate = [date] FROM bu000 WHERE guid = @ParentGUID
				IF (@BillDate IS NOT NULL) 
				BEGIN 
					SET @MatCurVal = [dbo].fnGetCurVal(@MatCurrencyGUID, @BillDate)
				END 
			END 
		END 
	END 

	INSERT INTO [bi000]( 
		[Number],
		[Qty],
		[Order], 
		[OrderQnt], 
		[Unity], 
		[Price], 
		[BonusQnt], 
		[Discount], 
		[BonusDisc], 
		[Extra], 
		[CurrencyVal], 
		[Notes], 
		[Profits], 
		[Num1], 
		[Num2], 
		[Qty2], 
		[Qty3], 
		[ClassPtr], 
		[ExpireDate], 
		[ProductionDate], 
		[Length], 
		[Width], 
		[Height], 
		[GUID], 
		[VAT], 
		[VATRatio], 
		[ParentGUID], 
		[MatGUID], 
		[CurrencyGUID], 
		[StoreGUID], 
		[CostGUID], 
		[SOType], 
		[SOGuid], 
		[Count],
		[SOGroup],
		TotalDiscountPercent,
		TotalExtraPercent,
		IsDiscountValue,
		IsExtraValue,
		[ClassPrice],
		[MatCurVal],
		TaxCode,
		PurchaseVal,
		ReversChargeVal,
		ExciseTaxVal,
		ExciseTaxPercent,
		ExciseTaxCode,
		[RelatedTo],
		CustomsRate,
		OrginalTaxCode)
	VALUES( 
		@Number,
		@Qty,
		@Order,
		@OrderQnt,
		@Unity,
		@Price,
		@BonusQnt,
		@Discount,
		@BonusDisc,
		@Extra,
		@CurrencyVal,
		@Notes, 
		@Profits,
		@Num1,
		@Num2,
		@Qty2,
		@Qty3,
		@ClassPtr, 
		@ExpireDate,
		@ProductionDate,
		@Length,
		@Width,
		@Height,
		@GUID,
		@VAT,
		@VATRatio,
		@ParentGUID,
		@MatGUID,
		@CurrencyGUID,
		@StoreGUID,
		@CostGUID,
		@SOType, 
		@SOGuid,
		@Count,
		@SOGroup,
		@TotalDiscountPercent,
		@TotalExtraPercent, 
		@IsDiscountValue,
		@IsExtraValue,
		@ClassPrice, 
		@MatCurVal,
		@TaxCode,
		@PurchaseVal,
		@ReversChargeVal,
		@ExciseTaxVal,
		@ExciseTaxPercent,
		@ExciseTaxCode,
		@RelatedTo,
		@CustomsRate,
		@OrginalTaxCode
	)
	-- Save Contracts Data	
	IF ISNULL(@ContractItemGuid, 0x00) <> 0x00
	BEGIN
		INSERT INTO ContractBillItems000(
			ContractItemGuid,
			BillItemGuid,
			Discount
		)
		VALUES(
			@ContractItemGuid,
			@Guid,
			@ContractDiscount		
		)
	END	
#########################################################
#END
