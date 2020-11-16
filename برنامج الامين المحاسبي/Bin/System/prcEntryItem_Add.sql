#########################################################
CREATE PROCEDURE prcEntryItem_Add
	@Number [INT], 
	@Date [DATETIME], 
	@Debit [FLOAT], 
	@Credit [FLOAT], 
	@Notes [NVARCHAR](1000), 
	@CurrencyVal [FLOAT], 
	@Class [NVARCHAR](250), 
	@Num1 [FLOAT], 
	@Num2 [FLOAT], 
	@Vendor [FLOAT], 
	@SalesMan [FLOAT], 
	@GUID [UNIQUEIDENTIFIER], 
	@ParentGUID [UNIQUEIDENTIFIER],  
	@AccountGUID [UNIQUEIDENTIFIER],  
	@CurrencyGUID [UNIQUEIDENTIFIER],  
	@CostGUID [UNIQUEIDENTIFIER],  
	@ContraAccGUID [UNIQUEIDENTIFIER],  
	@AddedValue [FLOAT],
	@ParentVATGuid [UNIQUEIDENTIFIER],
	@LCGuid [UNIQUEIDENTIFIER],
	@CustomerGUID [UNIQUEIDENTIFIER],
	@EnType INT = 0,
	@GCCOriginDate DATE = '1-1-1980',
	@GCCOriginNumber NVARCHAR(255) = ''
AS  
	SET NOCOUNT ON 
	
	IF ISNULL(@ParentVATGuid, 0x0) != 0x0
	BEGIN
		DECLARE @TaxType INT , @etCostToTaxAcc BIT
		SELECT @TaxType = ISNULL(et.TaxType,0) , @etCostToTaxAcc = bCostToTaxAcc  FROM ce000 ce INNER JOIN et000 et ON ce.TypeGUID = et.GUID WHERE ce.GUID = @ParentGUID

		IF @TaxType != 0
		BEGIN
			IF dbo.fnOption_GetInt('AmnCfg_EnableGCCTaxSystem', '0') != 0
				SET @EnType = CASE @EnType WHEN 0 THEN 202 ELSE @EnType END -- Ì„ﬂ‰  „—Ì— ‰Ê⁄ «·÷—Ì»… «·⁄ﬂ”Ì… 407 
			ELSE BEGIN
				IF @TaxType = 1
					SET @EnType = 101 -- vat
				ELSE IF @TaxType = 2
					SET @EnType = 102 -- ttc
			END
			Set @CostGUID = (Case @etCostToTaxAcc when 1 then @CostGUID else 0x0 end)
		END
	END

	INSERT INTO [en000] 
	( 
		[Number],  
		[Date],  
		[Debit],  
		[Credit],  
		[Notes],  
		[CurrencyVal],  
		[Class],  
		[Num1],  
		[Num2],  
		[Vendor],  
		[SalesMan],  
		[GUID],  
		[ParentGUID],  
		[AccountGUID],  
		[CurrencyGUID],  
		[CostGUID],  
		[ContraAccGUID], 
		[AddedValue],
		[ParentVATGuid],
		[LCGUID],
		[CustomerGUID],
		[Type],
		[GCCOriginDate],
		[GCCOriginNumber]
	) 
	VALUES 
	( 
		@Number, 
		@Date, 
		@Debit, 
		@Credit, 
		@Notes, 
		@CurrencyVal, 
		@Class, 
		@Num1, 
		@Num2, 
		@Vendor, 
		@SalesMan, 
		@GUID, 
		@ParentGUID,  
		@AccountGUID,  
		@CurrencyGUID,  
		@CostGUID,  
		@ContraAccGUID, 
		@AddedValue,
		@ParentVATGuid,
		@LCGuid,
		@CustomerGUID,
		@EnType,
		@GCCOriginDate,
		@GCCOriginNumber
	) 
#########################################################
#END